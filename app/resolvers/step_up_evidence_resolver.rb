# frozen_string_literal: true

# Builds ordinary step-up evidence only from the already authenticated Base RP access state.
# Writers still recheck the evidence against their own live actor/session boundary.
class StepUpEvidenceResolver
  STEP_UP_ACR = "https://visa.umaxica.app/acr/reauthentication".freeze

  class << self
    public

    def call(access_state:, actor:, cell:)
      new(access_state:, actor:, cell:).call
    end
  end

  public

  def initialize(access_state:, actor:, cell:)
    @access_state = access_state
    @actor = actor
    @cell = cell
  end

  def call
    record_class, session_class, principal_class, expected_actor, resource_type = boundary
    return unless valid_access_context?(expected_actor)

    if access_state.rp_session.is_a?(session_class)
      return unless access_state.resource.is_a?(principal_class)

      local_session_evidence(record_class:, session_class:, resource_type:)
    elsif access_state.rp_session.is_a?(op_session_class)
      return unless access_state.resource.is_a?(expected_actor) && same_actor?(access_state.resource, actor)

      op_session_evidence(resource_type:)
    end
  end

  private

  attr_reader :access_state, :actor, :cell

  def valid_access_context?(expected_actor)
    access_state.is_a?(BrowserRpAuthentication::AccessState) && access_state.status == :valid &&
      actor.is_a?(expected_actor) && actor.login_allowed? && !actor.deactivated? && access_state.payload.is_a?(Hash)
  end

  def local_session_evidence(record_class:, session_class:, resource_type:)
    record_class.connected_to(role: :writing) do
      session = session_class.includes(op_session_binding: { identity_binding: :principal })
        .find_by(id: access_state.rp_session.id, public_id: access_state.rp_session.public_id)
      next unless session

      verified_evidence(session:, resource_type:, now: record_class.database_now)
    end
  end

  def op_session_evidence(resource_type:)
    record_class = op_record_class
    session_class = op_session_class
    record_class.connected_to(role: :writing) do
      session = session_class.find_by(
        id: access_state.rp_session.id, public_id: access_state.rp_session.public_id,
      )
      next unless session

      verified_op_grant_evidence(session:, resource_type:, now: record_class.database_now)
    end
  end

  def boundary
    case cell
    when RpCellBinding::Cell
      case cell.connection
      when "rp_base_app"
        [RpBaseAppRecord, RpBaseAppSession, RpBaseAppPrincipal, Client, "client"]
      when "rp_base_org"
        [RpBaseOrgRecord, RpBaseOrgSession, RpBaseOrgPrincipal, Operator, "operator"]
      else
        raise ArgumentError, "step-up evidence is supported only by Base RP cells"
      end
    else
      raise ArgumentError, "step-up evidence requires a registered RP cell"
    end
  end

  def op_grant_boundary
    case cell.connection
    when "rp_base_app"
      [OpBaseAppRecord, OpAppGrant, ClientToken, ClientDeviceSession, Client]
    when "rp_base_org"
      [OpBaseOrgRecord, OpOrgGrant, OperatorToken, OperatorDeviceSession, Operator]
    else
      raise ArgumentError, "step-up evidence is supported only by Base RP cells"
    end
  end

  def op_record_class = op_grant_boundary.fetch(0)

  def op_session_class = op_grant_boundary.fetch(1)

  def verified_evidence(session:, resource_type:, now:)
    binding = session.op_session_binding
    identity = binding&.identity_binding
    return unless active_session_binding?(session:, binding:, identity:, now:)

    issuer = OidcIssuer.for_resource_type(resource_type)
    payload = access_state.payload
    return unless token_binding_matches?(payload:, binding:, identity:, issuer:, resource_type:)
    return unless authentication_evidence_valid?(payload:, now:)

    StepUpEvidenceValue.new(
      acr: payload.fetch("acr"), amr: payload.fetch("amr"), auth_time: payload.fetch("auth_time"),
      sid: payload.fetch("sid"), sub: payload.fetch("sub"), client_id: payload.fetch("client_id"),
      aud: payload.fetch("aud"), jti: payload.fetch("jti"),
    )
  end

  def verified_op_grant_evidence(session:, resource_type:, now:)
    _op_record, op_session_class, token_class, device_class, actor_class = op_grant_boundary
    return unless op_grant_owner_chain_matches?(
      session:, op_session_class:, token_class:, device_class:, actor_class:,
      now:,
    )

    issuer = OidcIssuer.for_resource_type(resource_type)
    payload = access_state.payload
    return unless op_grant_token_binding_matches?(payload:, session:, actor:, issuer:, resource_type:)
    return unless op_grant_event_matches?(payload:, session:)
    return unless authentication_evidence_valid?(payload:, now:)

    StepUpEvidenceValue.new(
      acr: payload.fetch("acr"), amr: payload.fetch("amr"), auth_time: payload.fetch("auth_time"),
      sid: payload.fetch("sid"), sub: payload.fetch("sub"), client_id: payload.fetch("client_id"),
      aud: payload.fetch("aud"), jti: payload.fetch("jti"),
    )
  end

  def op_grant_owner_chain_matches?(session:, op_session_class:, token_class:, device_class:, actor_class:, now:)
    return false unless session.is_a?(op_session_class) && actor.is_a?(actor_class)
    return false unless session.oidc_client_id == cell.client_id && session.active?(now)

    token = session.parent_token
    device = session.parent_device_session
    token.is_a?(token_class) && token_actor_matches?(token) && token.active_status?(now) &&
      device.is_a?(device_class) && device_actor_matches?(device) && device.usable? &&
      device.current_refresh_token_id == token.id && session.authentication_epoch == token.authentication_epoch &&
      access_state.payload[AuthenticationContextValue::CLAIM] == token.strict_authentication_context_value.to_s &&
      token.dpop_jkt.blank? && device.dpop_jkt.blank? && session.dpop_jkt.blank?
  end

  def op_grant_token_binding_matches?(payload:, session:, actor:, issuer:, resource_type:)
    client = OidcClientRegistry.find!(cell.client_id)
    subject = OidcSubject.for(actor, resource_type:)
    exact?(payload["iss"], issuer) && exact?(payload["sub"], subject) &&
      exact?(session.public_id, payload["sid"]) &&
      exact?(payload["client_id"], cell.client_id) && payload["aud"] == [client.aud]
  end

  # The access token and the active grant must describe the same committed event. AMR is compared as
  # event data here; it is never consulted to choose authorization or policy.
  def op_grant_event_matches?(payload:, session:)
    payload["auth_time"] == session.oidc_auth_time&.to_i &&
      exact?(payload["acr"], session.oidc_acr.to_s) &&
      payload["amr"] == parse_stored_amr(session.oidc_amr) &&
      exact?(payload["jti"], session.oidc_jti.to_s)
  end

  def parse_stored_amr(value)
    parsed = JSON.parse(value.to_s)
    return unless parsed.is_a?(Array) && parsed.all? { |method| method.is_a?(String) && method.present? }

    parsed
  rescue JSON::ParserError
    nil
  end

  def active_session_binding?(session:, binding:, identity:, now:)
    session.revoked_at.nil? && session.absolute_expires_at.present? && session.absolute_expires_at > now &&
      binding && identity && binding.revoked_at.nil? && identity.principal.disabled_at.nil?
  end

  def token_binding_matches?(payload:, binding:, identity:, issuer:, resource_type:)
    subject = payload["sub"]
    exact?(payload["iss"], issuer) && exact?(identity.issuer, issuer) &&
      identity.realm == cell.realm && identity.client_id == cell.client_id &&
      identity.principal_id == access_state.resource.id && exact?(identity.subject, subject) &&
      exact?(binding.issuer, issuer) && exact?(binding.sid, payload["sid"]) &&
      exact?(OidcSubject.for(actor, resource_type:), subject) &&
      exact?(payload["client_id"], cell.client_id) && payload["aud"] == [OidcClientRegistry.find!(cell.client_id).aud]
  end

  def authentication_evidence_valid?(payload:, now:)
    auth_time = payload["auth_time"]
    authentication_context_permits_step_up?(payload) && exact?(payload["acr"], STEP_UP_ACR) &&
      payload["amr"].is_a?(Array) && payload["amr"].all? { |method| method.is_a?(String) && method.present? } &&
      auth_time.is_a?(Integer) && auth_time <= now.to_i && recent_authentication?(auth_time, now) &&
      payload["exp"].is_a?(Integer) && payload.fetch("exp") > now.to_i &&
      payload["jti"].is_a?(String) && payload["jti"].present?
  end

  def authentication_context_permits_step_up?(payload)
    context = payload[AuthenticationContextValue::CLAIM]
    return false unless AuthenticationContextValue::KEYS.include?(context)

    AuthenticationContextValue.for(context).step_up_permitted?
  end

  def recent_authentication?(auth_time, now)
    now.to_i < auth_time + StepUpEvidenceValue::MAX_AGE_SECONDS
  end

  def exact?(actual, expected)
    actual.is_a?(String) && expected.is_a?(String) && actual.bytesize == expected.bytesize &&
      ActiveSupport::SecurityUtils.secure_compare(actual, expected)
  end

  def same_actor?(left, right)
    left.class == right.class && left.id == right.id
  end

  def token_actor_matches?(token)
    case token
    when ClientToken then token.user_id == actor.id
    when OperatorToken then token.staff_id == actor.id
    else false
    end
  end

  def device_actor_matches?(device)
    case device
    when ClientDeviceSession then device.user_id == actor.id
    when OperatorDeviceSession then device.staff_id == actor.id
    else false
    end
  end
end
