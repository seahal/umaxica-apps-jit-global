# frozen_string_literal: true

# Commits Auth cancellation and the OP context outcome in one OP database
# transaction; the authorization transaction remains a short-lived request.
class OidcStepUpAuthorizationCancellationCommitter
  class << self
    public

    def call!(surface:, actor:, token:, context:, ticket:, authorization_transaction:, admission_binding:,
              cancellation_handoff:)
      new(
        surface:, actor:, token:, context:, ticket:, authorization_transaction:, admission_binding:,
        cancellation_handoff:,
      ).call
    end
  end

  public

  def initialize(surface:, actor:, token:, context:, ticket:, authorization_transaction:, admission_binding:,
                 cancellation_handoff:)
    @surface = surface.to_s
    @actor = actor
    @token = token
    @context = context
    @ticket = ticket
    @authorization_transaction = authorization_transaction
    @admission_binding = admission_binding
    @cancellation_handoff = cancellation_handoff
  end

  def call
    validate_types!
    actor.class.connection_class_for_self.connected_to(role: :writing) do
      actor.with_lock do
        device_session = token.device_session_record!
        device_session.with_lock do
          token.with_lock do
            owner.transaction do
              grant = grant_model.lock.find(context.grant_id)
              authorization_transaction.with_lock do
                context.with_lock do
                  now = owner.database_now
                  expired_context = context.state_id == context_state_model::PENDING && context.expires_at <= now
                  validate_locked_binding!(
                    grant:, device_session:, now:, allow_expired_context: expired_context,
                  )
                  ticket.with_lock do
                    admission_binding.with_lock do
                      cancel_locked!(now:)
                    end
                  end
                end
              end
            end
          end
        end
      end
    end
  rescue ActiveRecord::RecordNotFound
    raise BaseAuthAdmissionCoordinator::Denied.new(
      "OP cancellation binding is unavailable", code: "invalid_admission",
    )
  end

  private

  attr_reader :surface, :actor, :token, :context, :ticket, :authorization_transaction, :admission_binding,
              :cancellation_handoff

  def owner = authorization_transaction.class.connection_owner

  def context_state_model
    { "app" => ClientStepUpContextState, "org" => OperatorStepUpContextState }.fetch(surface)
  end

  def grant_model = { "app" => OpAppGrant, "org" => OpOrgGrant }.fetch(surface)

  def admission_model = { "app" => ClientAuthAdmissionBinding, "org" => OperatorAuthAdmissionBinding }.fetch(surface)

  def cancel_locked!(now:)
    if context.expires_at <= now
      expire_context!(now:)
      return :expired
    end
    unless context.state_id == context_state_model::PENDING && authorization_transaction.pending? &&
        authorization_transaction.intent == "step_up" &&
        context.oidc_authorization_transaction_id == authorization_transaction.id
      return :expired if authorization_transaction.expired?(now:)

      raise BaseAuthAdmissionCoordinator::Denied.new(
        "OP cancellation is no longer available",
        code: "invalid_admission",
      )
    end

    cancelled = IdentityStepUpCeremonyCancellationCommitter.call!(
      actor:, token:, transaction: ticket,
      cancellation_handoff_digest: BaseAuthAdmissionCoordinator.cancellation_handoff_digest(cancellation_handoff),
    )
    unless cancelled
      raise BaseAuthAdmissionCoordinator::Denied.new(
        "Auth cancellation handoff is unavailable", code: "invalid_admission",
      )
    end

    transition_context!(to_state_id: context_state_model::CANCELLED, reason_code: "user_cancelled")
    StepUpAuditOutboxWriter.call(
      source_key: { "app" => "op_app", "org" => "op_org" }.fetch(surface),
      event_type: "step_up.cancelled",
      realm: { "app" => "APP", "org" => "ORG" }.fetch(surface),
      client_id: authorization_transaction.client_id,
      subject_ref: context.bound_subject,
      context_ref: context.public_id,
      reason_code: "user_cancelled",
      payload: { op_context_ref: context.public_id },
      occurred_at: owner.database_now,
    )
    :cancelled
  end

  def validate_locked_binding!(grant:, device_session:, now:, allow_expired_context:)
    valid = identity_binding_valid?(device_session:, now:) && context_binding_valid?(grant:) &&
      ticket_binding_valid? && admission_binding_valid?(now:, allow_expired_context:)
    return if valid

    raise BaseAuthAdmissionCoordinator::Denied.new("OP cancellation binding is unavailable", code: "invalid_admission")
  end

  def identity_binding_valid?(device_session:, now:)
    actor.login_allowed? && token_actor_matches? && device_actor_matches?(device_session) &&
      token.active_status?(now) && device_session.usable? && token.device_session_id == device_session.id &&
      device_session.current_refresh_token_id == token.id
  end

  def token_actor_matches?
    case [actor, token]
    in [Client, ClientToken] then token.user_id == actor.id
    in [Operator, OperatorToken] then token.staff_id == actor.id && !token.standby_authentication_context?
    else false
    end
  end

  def device_actor_matches?(device_session)
    case [actor, device_session]
    in [Client, ClientDeviceSession] then device_session.user_id == actor.id
    in [Operator, OperatorDeviceSession] then device_session.staff_id == actor.id
    else false
    end
  end

  def context_binding_valid?(grant:)
    expected_resource_type = { "app" => "client", "org" => "operator" }.fetch(surface)
    expected_subject = OidcSubject.for(actor, resource_type: expected_resource_type)
    grant_root_id =
      case [grant, token]
      in [OpAppGrant, ClientToken] then grant.client_token_id
      in [OpOrgGrant, OperatorToken] then grant.operator_token_id
      else nil
      end
    context.bound_subject == expected_subject && context.grant_id == grant.id &&
      context.oidc_authorization_transaction_id == authorization_transaction.id &&
      authorization_transaction.surface == surface && authorization_transaction.client_id == grant.oidc_client_id &&
      grant_root_id == token.id
  end

  def ticket_binding_valid?
    ticket.surface == surface && ticket.purpose == "step_up" && ticket.actor_ref == actor.public_id &&
      ticket.session_ref == token.public_id && ticket.resource_ref == context.public_id &&
      ticket.required_scope == OidcAuthorizeRequestResolver::STEP_UP_SCOPE &&
      ticket.return_to == OidcAuthorizeRequestResolver::STEP_UP_RETURN_TO
  end

  def admission_binding_valid?(now:, allow_expired_context:)
    admission_binding.redeemed? && admission_binding.purpose == "step_up_handoff" &&
      admission_binding.entry_intent == "not_applicable" &&
      admission_binding.parent_kind == :step_up_ceremony_transaction &&
      admission_binding.step_up_ceremony_transaction_id == ticket.id && admission_binding.base_token_id == token.id &&
      (allow_expired_context || (admission_binding.expires_at > now && admission_binding.curfew_at > now)) &&
      admission_binding.base_browser_digest == AuthAdmissionBinding.browser_digest(
        surface:, entry_ref: admission_binding.entry_ref, nonce: authorization_transaction.login_challenge,
      )
  end

  def validate_types!
    expected_actor = { "app" => Client, "org" => Operator }.fetch(surface)
    expected_token = { "app" => ClientToken, "org" => OperatorToken }.fetch(surface)
    expected_context = { "app" => ClientStepUpContext, "org" => OperatorStepUpContext }.fetch(surface)
    expected_ticket = { "app" => ClientStepUpCeremonyTransaction, "org" => OperatorStepUpCeremonyTransaction }
      .fetch(surface)
    expected_transaction = OidcAuthorizationTransactionCoordinator.model_for(surface)
    unless actor.is_a?(expected_actor) && token.is_a?(expected_token) && context.is_a?(expected_context) &&
        ticket.is_a?(expected_ticket) && authorization_transaction.is_a?(expected_transaction) &&
        admission_binding.is_a?(admission_model) && cancellation_handoff.is_a?(String) && cancellation_handoff.present?
      raise ArgumentError, "OIDC step-up cancellation types are invalid"
    end
  end

  def transition_context!(to_state_id:, reason_code:)
    writer = { "app" => ClientStepUpContextTransitionWriter, "org" => OperatorStepUpContextTransitionWriter }
      .fetch(surface)
    transitioned = writer.call!(context:, to_state_id:, reason_code:)
    raise BaseAuthAdmissionCoordinator::Denied.new("OP context changed concurrently", code: "invalid_admission") unless
      transitioned
  end

  def expire_context!(now:)
    transition_context!(to_state_id: context_state_model::EXPIRED, reason_code: "expired")
    StepUpAuditOutboxWriter.call(
      source_key: { "app" => "op_app", "org" => "op_org" }.fetch(surface),
      event_type: "step_up.expired",
      realm: { "app" => "APP", "org" => "ORG" }.fetch(surface),
      client_id: authorization_transaction.client_id,
      subject_ref: context.bound_subject,
      context_ref: context.public_id,
      reason_code: "expired",
      payload: { op_context_ref: context.public_id },
      occurred_at: now,
    )
  end
end
