# frozen_string_literal: true

# Installs verified OP credentials into the initiating RP session generation.
class RpStepUpInstaller
  Result = Data.define(:outcome, :token_response)

  class << self
    public

    def call(...)
      new(...).call
    end
  end

  def initialize(cell:, state_ref:, actor:, access_payload:, id_payload:, token_response:)
    @entry = RpStepUpCellRegistry.fetch(cell)
    @state_ref = state_ref
    @actor = actor
    @access_payload = access_payload
    @id_payload = id_payload
    @token_response = token_response
  end

  public

  def call
    validate_inputs!
    transition =
      RpStepUpStateTransitionWriter.call(cell: entry.cell, state_ref:) do |state, session, binding, now|
        install_decision(state:, session:, binding:, now:)
      end
    installed = transition.outcome == :installed
    Result.new(outcome: transition.outcome, token_response: installed ? token_response : nil)
  end

  private

  attr_reader :entry, :state_ref, :actor, :access_payload, :id_payload, :token_response

  def validate_inputs!
    unless access_payload.is_a?(Hash) && id_payload.is_a?(Hash) && token_response.is_a?(Hash) &&
        actor.instance_of?(entry.actor_class)
      raise ArgumentError, "step-up installation inputs are invalid"
    end

    OidcRpBrowserCredentialContract.require_token_response!(token_response)
  end

  def install_decision(state:, session:, binding:, now:)
    dispatch = entry.transition_class.find_by(owner_id: state.id, to_state_id: entry.status_class::DISPATCHING)
    return unless dispatch
    if now >= dispatch.occurred_at + 60.seconds || state.expires_at <= now
      return decision(
        entry.status_class::INDETERMINATE,
        "dispatch_deadline_passed",
        "step_up.indeterminate",
        outcome: :indeterminate,
      )
    end

    identity = entry.identity_binding_class.lock.find_by(id: binding.identity_binding_id)
    principal = entry.principal_class.lock.find_by(id: identity&.principal_id)
    refusal = installation_refusal(state:, session:, binding:, identity:, principal:, now:)
    return refusal if refusal

    session.update!(
      installed_generation: session.installed_generation + 1,
      current_access_jti_digest: Digest::SHA256.hexdigest(access_payload.fetch("jti")),
      current_access_expires_at: Time.zone.at(access_payload.fetch("exp")),
    )
    decision(
      entry.status_class::INSTALLED,
      "completed",
      "step_up.installed",
      outcome: :installed,
    )
  end

  def installation_refusal(state:, session:, binding:, identity:, principal:, now:)
    return decision(entry.status_class::REFUSED, "session_invalid", "step_up.refused") unless
      live_session?(session, binding, identity, principal, now)
    return decision(entry.status_class::REFUSED, "generation_superseded", "step_up.refused") unless
      session.installed_generation == state.initiating_generation
    return decision(entry.status_class::REFUSED, "session_invalid", "step_up.refused") unless
      token_binding_matches?(state, binding, identity, principal)
    return decision(entry.status_class::REFUSED, "policy_refused", "step_up.refused") unless
      evidence_valid?(session:, principal:)

    nil
  end

  def live_session?(session, binding, identity, principal, now)
    session.revoked_at.nil? && session.absolute_expires_at > now && binding.revoked_at.nil? && identity && principal &&
      !principal.deactivated?
  end

  def token_binding_matches?(state, binding, identity, principal)
    return false unless identity && principal

    issuer = state.issuer
    subject = identity.subject
    access_expected = {
      "iss" => issuer,
      "sid" => binding.sid,
      "sub" => subject,
      "client_id" => state.client_id,
    }
    id_expected = access_expected.except("client_id")
    access_expected.all? { |claim, value| access_payload[claim] == value } &&
      id_expected.all? { |claim, value| id_payload[claim] == value } && binding.issuer == issuer &&
      binding.realm == state.realm.downcase &&
      binding.client_id == state.client_id && identity.issuer == issuer && identity.realm == binding.realm &&
      identity.client_id == state.client_id && identity.principal_id == principal.id &&
      access_payload["aud"] == [state.client_id] && id_payload["aud"] == [state.client_id]
  end

  def evidence_valid?(session:, principal:)
    access_state = BrowserRpAuthentication::AccessState.new(
      status: :valid,
      resource: principal,
      rp_session: session,
      payload: access_payload,
      security_context: nil,
    )
    StepUpEvidenceResolver.call(access_state:, actor:, cell: entry.cell).present?
  end

  def decision(status_id, reason_code, event_type, outcome: :refused)
    RpStepUpStateTransitionWriter::Decision.new(
      to_status_id: status_id,
      reason_code:,
      event_type:,
      payload: nil,
      outcome:,
    )
  end
end
