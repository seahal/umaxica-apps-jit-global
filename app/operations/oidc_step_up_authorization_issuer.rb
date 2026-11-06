# frozen_string_literal: true

# Creates the OP-owned authorization context and delegates its ceremony through
# the existing ticket-scoped Base/Auth admission. The ticket's resource_ref is
# the only link from Auth back to this exact OP context.
class OidcStepUpAuthorizationIssuer
  Issuance = Data.define(:authorization_transaction, :context, :ticket, :entry_ref, :outcome)

  class NoActiveGrant < StandardError; end

  class << self
    public

    def call!(surface:, actor:, token:, client:, params:, validated_request:)
      new(surface:, actor:, token:, client:, params:, validated_request:).call
    end
  end

  public

  def initialize(surface:, actor:, token:, client:, params:, validated_request:)
    @surface = surface.to_s
    @actor = actor
    @token = token
    @client = client
    @params = params
    @validated_request = validated_request
  end

  def call
    validate_request!
    actor.class.connection_class_for_self.connected_to(role: :writing) do
      actor.with_lock do
        owner.connected_to(role: :writing) do
          owner.transaction do
            device_session = token.device_session_record!
            device_session.with_lock do
              token.with_lock do
                now = owner.database_now
                validate_live_root!(device_session, now:)
                grant = lock_live_grant!(device_session, now:)
                issue_for_locked_session!(grant:, now:)
              end
            end
          end
        end
      end
    end
  rescue ActiveRecord::RecordNotFound
    raise NoActiveGrant
  end

  private

  attr_reader :surface, :actor, :token, :client, :params, :validated_request

  def owner = transaction_model.connection_owner

  def transaction_model
    OidcAuthorizationTransactionCoordinator.model_for(surface)
  end

  def context_model
    { "app" => ClientStepUpContext, "org" => OperatorStepUpContext }.fetch(surface)
  end

  def context_state_model
    { "app" => ClientStepUpContextState, "org" => OperatorStepUpContextState }.fetch(surface)
  end

  def grant_model
    { "app" => OpAppGrant, "org" => OpOrgGrant }.fetch(surface)
  end

  def realm = { "app" => "APP", "org" => "ORG" }.fetch(surface)

  def source_key = { "app" => "op_app", "org" => "op_org" }.fetch(surface)

  def validate_request!
    expected_actor = { "app" => Client, "org" => Operator }.fetch(surface)
    expected_resource_type = { "app" => "client", "org" => "operator" }.fetch(surface)
    unless actor.is_a?(expected_actor) && validated_request.step_up_requested &&
        OidcSubject.normalize_resource_type(client.resource_type) == expected_resource_type &&
        validated_request.client.client_id == client.client_id && params[:client_id].to_s == client.client_id
      raise ArgumentError, "OIDC step-up authorization binding is invalid"
    end
  end

  def validate_live_root!(device_session, now:)
    actor_token_match =
      case [actor, token]
      in [Client, ClientToken] then token.user_id == actor.id
      in [Operator, OperatorToken] then token.staff_id == actor.id && !token.standby_authentication_context?
      else false
      end
    unless actor_token_match && actor.login_allowed? && token.active_status?(now) && device_session.usable? &&
        device_session.current_refresh_token_id == token.id
      raise NoActiveGrant
    end
  end

  def lock_live_grant!(device_session, now:)
    grant = grant_model.lock.find_by!(oidc_client_id: client.client_id, device_session_id: device_session.id)
    root_id =
      case [grant, token]
      in [OpAppGrant, ClientToken] then grant.client_token_id
      in [OpOrgGrant, OperatorToken] then grant.operator_token_id
      else nil
      end
    raise NoActiveGrant unless root_id == token.id && grant.active?(now)

    grant
  end

  def issue_for_locked_session!(grant:, now:)
    subject = OidcSubject.for(actor, resource_type: validated_request.client.resource_type)
    authorization = OidcAuthorizationTransactionCoordinator.issue!(
      surface:, intent: "step_up", params:, now:,
    ).transaction
    expires_at = authorization.expires_at
    context = context_model.create!(
      public_id: PublicId.generate,
      oidc_authorization_transaction: authorization,
      grant: grant,
      bound_subject: subject,
      requested_acr: OidcAuthorizeRequestResolver::STEP_UP_ACR,
      state_id: context_state_model::PENDING,
      expires_at: expires_at,
      created_at: now,
      updated_at: now,
    )

    available = StepUpMethodsResolver.call(
      actor:, ticket: nil, supported_methods: OidcStepUpAllowedMethodsResolver.call(actor:),
    ).available
    if available.empty?
      transition_context!(context, to_state_id: context_state_model::FAILED, reason_code: "unsatisfiable_class")
      write_outbox!(
        event_type: "step_up.failed", context:, reason_code: "unsatisfiable_class",
        payload: { op_context_ref: context.public_id, failure_code: "unsatisfiable_class" },
      )
      return Issuance.new(
        authorization_transaction: authorization, context: context, ticket: nil, entry_ref: nil,
        outcome: :unsatisfiable,
      )
    end

    requirement = step_up_requirement(context:, methods: available, expires_at:, now:)
    auth_issuance = BaseStepUpAdmissionIssuer.call!(
      actor:, token:, requirement:, return_to: OidcAuthorizeRequestResolver::STEP_UP_RETURN_TO,
      base_browser_nonce: authorization.login_challenge, base_token: token, oidc_step_up_context: context,
    )
    unless auth_issuance.is_a?(BaseAuthAdmissionCoordinator::Issuance)
      raise BaseAuthAdmissionCoordinator::Denied.new("OIDC step-up admission was not issued", code: "invalid_admission")
    end

    Issuance.new(
      authorization_transaction: authorization, context:, ticket: auth_issuance.transaction,
      entry_ref: auth_issuance.reference, outcome: :issued,
    )
  end

  def step_up_requirement(context:, methods:, expires_at:, now:)
    StepUpRequirement.new(
      scope: OidcAuthorizeRequestResolver::STEP_UP_SCOPE,
      step_up_required: true,
      allowed_methods: methods,
      phishing_resistant_required: false,
      user_verification_required: false,
      full_reauthentication_required: false,
      audience: "step_up:#{surface}",
      session_binding: token.public_id,
      token_binding: token.public_id,
      require_session_binding: true,
      ttl: expires_at - now,
      purpose: "step_up",
      actor_ref: actor.public_id,
      resource_ref: context.public_id,
      tenant_ref: nil,
    )
  end

  def transition_context!(context, to_state_id:, reason_code:)
    writer = { "app" => ClientStepUpContextTransitionWriter, "org" => OperatorStepUpContextTransitionWriter }
      .fetch(surface)
    writer.call!(context:, to_state_id:, reason_code:)
  end

  def write_outbox!(event_type:, context:, reason_code:, payload:)
    StepUpAuditOutboxWriter.call(
      source_key:, event_type:, realm:, client_id: client.client_id, subject_ref: context.bound_subject,
      context_ref: context.public_id, reason_code:, payload:, occurred_at: owner.database_now,
    )
  end
end
