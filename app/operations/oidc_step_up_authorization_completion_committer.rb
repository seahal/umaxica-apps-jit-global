# frozen_string_literal: true

# Completes only the OP authorization ceremony. It records the verified Auth
# ticket result on the pending OIDC transaction without establishing or
# rotating a root login. The grant event and OP commit fact are written later,
# atomically with token issuance.
class OidcStepUpAuthorizationCompletionCommitter
  class << self
    public

    def call!(surface:, actor:, token:, context:, ticket:, authorization_transaction:, admission_binding:,
              result_payload:)
      new(
        surface:, actor:, token:, context:, ticket:, authorization_transaction:, admission_binding:,
        result_payload:,
      ).call
    end
  end

  public

  def initialize(surface:, actor:, token:, context:, ticket:, authorization_transaction:, admission_binding:,
                 result_payload:)
    @surface = surface.to_s
    @actor = actor
    @token = token
    @context = context
    @ticket = ticket
    @authorization_transaction = authorization_transaction
    @admission_binding = admission_binding
    @result_payload = result_payload
  end

  def call
    validate_types!
    actor.class.connection_class_for_self.connected_to(role: :writing) do
      actor.with_lock do
        raise BaseAuthAdmissionCoordinator::Denied.new("OP actor is unavailable", code: "authorization_denied") unless
          actor.login_allowed?

        device_session = token.device_session_record!
        device_session.with_lock do
          token.with_lock do
            owner.transaction do
              grant = grant_model.lock.find(context.grant_id)
              authorization_transaction.with_lock do
                context.with_lock do
                  ticket.with_lock do
                    admission_binding.with_lock do
                      complete_locked!(grant:, device_session:)
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
    raise BaseAuthAdmissionCoordinator::Denied.new("step-up binding is unavailable", code: "invalid_admission")
  end

  private

  attr_reader :surface, :actor, :token, :context, :ticket, :authorization_transaction, :admission_binding,
              :result_payload

  def owner = authorization_transaction.class.connection_owner

  def context_model = { "app" => ClientStepUpContext, "org" => OperatorStepUpContext }.fetch(surface)

  def context_state_model
    { "app" => ClientStepUpContextState, "org" => OperatorStepUpContextState }.fetch(surface)
  end

  def ticket_model
    { "app" => ClientStepUpCeremonyTransaction, "org" => OperatorStepUpCeremonyTransaction }.fetch(surface)
  end

  def session_model = { "app" => ClientStepUpSession, "org" => OperatorStepUpSession }.fetch(surface)

  def admission_model = { "app" => ClientAuthAdmissionBinding, "org" => OperatorAuthAdmissionBinding }.fetch(surface)

  def ceremony_model = { "app" => ClientAuthCeremonySession, "org" => OperatorAuthCeremonySession }.fetch(surface)

  def grant_model = { "app" => OpAppGrant, "org" => OpOrgGrant }.fetch(surface)

  def grant_root_id(grant)
    case [grant, token]
    in [OpAppGrant, ClientToken] then grant.client_token_id
    in [OpOrgGrant, OperatorToken] then grant.operator_token_id
    else nil
    end
  end

  def token_actor_matches?
    case [actor, token]
    in [Client, ClientToken] then token.user_id == actor.id
    in [Operator, OperatorToken] then token.staff_id == actor.id && !token.standby_authentication_context?
    else false
    end
  end

  def session_record_token_matches?(record)
    case [record, token]
    in [ClientStepUpSession, ClientToken] then record.user_token_id == token.id
    in [OperatorStepUpSession, OperatorToken] then record.staff_token_id == token.id
    else false
    end
  end

  def validate_types!
    expected_actor = { "app" => Client, "org" => Operator }.fetch(surface)
    expected_token = { "app" => ClientToken, "org" => OperatorToken }.fetch(surface)
    unless actor.is_a?(expected_actor) && token.is_a?(expected_token) &&
        context.is_a?(context_model) && ticket.is_a?(ticket_model) &&
        authorization_transaction.is_a?(OidcAuthorizationTransactionCoordinator.model_for(surface)) &&
        admission_binding.is_a?(admission_model) && result_payload.is_a?(Hash)
      raise ArgumentError, "OIDC step-up completion types are invalid"
    end
  end

  def complete_locked!(grant:, device_session:)
    now = owner.database_now
    validate_live_root!(device_session, now:)
    if context.state_id == context_state_model::PENDING && context.expires_at <= now
      expire_context!(now:)
      return :expired
    end
    validate_context_binding!(grant:, now:)
    ceremony = validate_auth_result!(now:)

    unless authorization_transaction.pending?
      raise BaseAuthAdmissionCoordinator::Denied.new(
        "OIDC authorization is no longer pending", code: "invalid_admission",
      )
    end
    raise BaseAuthAdmissionCoordinator::Denied.new("OIDC authorization expired", code: "expired_admission") if
      authorization_transaction.expired?(now:) || authorization_transaction.login_challenge_expired?(now:)

    unless OidcStepUpAllowedMethodsResolver.call(actor:).include?(ticket.method.to_sym)
      refuse_current_policy!(ceremony:, now:)
      return :policy_refused
    end

    authorization_transaction.register_authentication!(
      actor_ref: actor.public_id,
      session_ref: token.public_id,
      auth_method: ticket.method,
      acr: OidcAuthorizeRequestResolver::STEP_UP_ACR,
      authentication_event_at: ticket.verified_at,
    )
    ticket.commit_consumption!(now:)
    ceremony.complete!
    :completed
  end

  def validate_auth_result!(now:)
    validate_ticket_binding!(now:)
    session_record = session_model.lock.find_by!(step_up_ceremony_transaction_ref: ticket.transaction_id)
    unless session_record_token_matches?(session_record) && session_record.scope == ticket.required_scope &&
        session_record.status == "PENDING" && session_record.discard_at > now
      raise BaseAuthAdmissionCoordinator::Denied.new("step-up session no longer matches", code: "invalid_admission")
    end

    ceremony = ceremony_model.lock.find(admission_binding.admitted_auth_ceremony_session_id)
    validate_auth_ceremony_binding!(ceremony:, now:)
    validate_result_delivery!(ceremony:, now:)
    ceremony
  end

  def validate_live_root!(device_session, now:)
    device_owner_matches =
      case [actor, device_session]
      in [Client, ClientDeviceSession] then device_session.user_id == actor.id
      in [Operator, OperatorDeviceSession] then device_session.staff_id == actor.id
      else false
      end
    unless token_actor_matches? && device_owner_matches && token.active_status?(now) && device_session.usable? &&
        token.device_session_id == device_session.id && device_session.current_refresh_token_id == token.id
      raise BaseAuthAdmissionCoordinator::Denied.new("OP session is unavailable", code: "session_expired")
    end
  end

  def validate_context_binding!(grant:, now:)
    expected_resource_type = { "app" => "client", "org" => "operator" }.fetch(surface)
    expected_subject = OidcSubject.for(actor, resource_type: expected_resource_type)
    unless context.oidc_authorization_transaction_id == authorization_transaction.id &&
        context.state_id == context_state_model::PENDING && context.expires_at > now &&
        context.bound_subject == expected_subject && context.grant_id == grant.id &&
        context.requested_acr == OidcAuthorizeRequestResolver::STEP_UP_ACR &&
        authorization_transaction.intent == "step_up" && authorization_transaction.surface == surface &&
        authorization_transaction.client_id == grant.oidc_client_id && grant_root_id(grant) == token.id &&
        grant.device_session_id == token.device_session_id && grant.active?(now)
      raise BaseAuthAdmissionCoordinator::Denied.new("OP context binding is unavailable", code: "invalid_admission")
    end
  end

  def validate_ticket_binding!(now:)
    unless ticket_matches_context?(now:)
      raise BaseAuthAdmissionCoordinator::Denied.new("Auth step-up result is unavailable", code: "invalid_admission")
    end

    return if admission_binding_matches?(now:)

    raise BaseAuthAdmissionCoordinator::Denied.new("Auth admission is unavailable", code: "invalid_admission")
  end

  def ticket_matches_context?(now:)
    ticket.surface == surface && ticket.status == "verified" && !ticket.expired?(now:) &&
      ticket.purpose == "step_up" && ticket.required_scope == OidcAuthorizeRequestResolver::STEP_UP_SCOPE &&
      ticket.return_to == OidcAuthorizeRequestResolver::STEP_UP_RETURN_TO &&
      ticket.actor_ref == actor.public_id && ticket.session_ref == token.public_id &&
      ticket.resource_ref == context.public_id && ticket.verified_at && ticket.verified_at <= now &&
      ticket.allowed_methods_array.include?(ticket.method)
  end

  def admission_binding_matches?(now:)
    admission_binding.is_a?(admission_model) && admission_binding.redeemed? &&
      admission_binding.purpose == "step_up_handoff" && admission_binding.entry_intent == "not_applicable" &&
      admission_binding.parent_kind == :step_up_ceremony_transaction &&
      admission_binding.step_up_ceremony_transaction_id == ticket.id && admission_binding.base_token_id == token.id &&
      admission_binding.expires_at > now && admission_binding.curfew_at > now &&
      admission_binding.base_browser_digest == AuthAdmissionBinding.browser_digest(
        surface:, entry_ref: admission_binding.entry_ref, nonce: authorization_transaction.login_challenge,
      )
  end

  def validate_auth_ceremony_binding!(ceremony:, now:)
    unless ceremony.admission_purpose == "step_up_handoff" &&
        ceremony.step_up_ceremony_transaction_ref == ticket.transaction_id &&
        ceremony.active?(now:) && ceremony.admitted?
      raise BaseAuthAdmissionCoordinator::Denied.new("Auth ceremony binding is unavailable", code: "invalid_admission")
    end
  end

  def validate_result_delivery!(ceremony:, now:)
    generation = Integer(result_payload.fetch("result_generation").to_s, 10)
    unless result_payload.fetch("ceremony_session_ref").to_s == ceremony.id.to_s &&
        admission_binding.admitted_auth_ceremony_session_id == ceremony.id &&
        ticket.result_delivery_matches?(
          result_digest: ticket.result_digest, result_generation: generation, now:,
        )
      raise BaseAuthAdmissionCoordinator::Denied.new("Auth result generation is stale", code: "invalid_admission")
    end
  rescue KeyError, ArgumentError
    raise BaseAuthAdmissionCoordinator::Denied.new("Auth result generation is invalid", code: "invalid_admission")
  end

  def refuse_current_policy!(ceremony:, now:)
    transition_context!(to_state_id: context_state_model::FAILED, reason_code: "policy_refused", now:)
    ticket.commit_revocation!(now:)
    ceremony.revoke! unless ceremony.terminal?
    StepUpAuditOutboxWriter.call(
      source_key: { "app" => "op_app", "org" => "op_org" }.fetch(surface),
      event_type: "step_up.failed",
      realm: { "app" => "APP", "org" => "ORG" }.fetch(surface),
      client_id: authorization_transaction.client_id,
      subject_ref: context.bound_subject,
      context_ref: context.public_id,
      reason_code: "policy_refused",
      payload: { op_context_ref: context.public_id, failure_code: "policy_refused" },
      occurred_at: now,
    )
  end

  def transition_context!(to_state_id:, reason_code:, now:)
    writer = { "app" => ClientStepUpContextTransitionWriter, "org" => OperatorStepUpContextTransitionWriter }
      .fetch(surface)
    transitioned = writer.call!(context:, to_state_id:, reason_code:)
    unless transitioned
      raise BaseAuthAdmissionCoordinator::Denied.new("OP context changed concurrently", code: "invalid_admission")
    end

    context.reload
  end

  def expire_context!(now:)
    transition_context!(to_state_id: context_state_model::EXPIRED, reason_code: "expired", now:)
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
