# frozen_string_literal: true

# Creates one session-bound pending step-up request and its after-commit audit fact.
class RpStepUpStartIssuer
  Result = Data.define(:authorization_url, :state_ref, :return_target)

  STEP_UP_ACR = "https://visa.umaxica.app/acr/reauthentication"
  PENDING_TTL = 15.minutes

  class Refused < StandardError
    REASON_CODES = %w(
      authentication_context_invalid browser_binding_invalid op_binding_unavailable rp_binding_changed
      rp_session_unavailable
    ).freeze

    attr_reader :reason_code

    def initialize(reason_code:)
      raise ArgumentError, "unsupported step-up start refusal reason" unless REASON_CODES.include?(reason_code)

      @reason_code = reason_code
      super(reason_code)
    end
  end

  class << self
    public

    def call(...) = new(...).call
  end

  def initialize(cell:, access_state:, actor:, browser_binding:, return_target:)
    @entry = RpStepUpCellRegistry.fetch(cell)
    @access_state = access_state
    @actor = actor
    @browser_binding = browser_binding
    @return_target = return_target
  end

  public

  def call
    validate_request!
    result = nil
    record_class.connected_to(role: :writing) do
      record_class.transaction do
        session, binding, identity, principal, now = lock_current_binding!
        validate_current_binding!(session, binding, identity, principal, now)
        state, raw_state, raw_nonce = create_pending_state!(session, now)
        write_requested_audit!(state, identity.subject, now)
        result = Result.new(
          authorization_url: authorization_url(
            raw_state:, raw_nonce:, pkce_challenge: state.pkce_challenge,
          ),
          state_ref: state.public_id,
          return_target:,
        )
      end
    end
    result
  end

  private

  attr_reader :entry, :access_state, :actor, :browser_binding, :return_target

  def record_class = entry.record_class

  def session_class = entry.session_class

  def state_class = entry.state_class

  def status_class = entry.status_class

  def validate_request!
    unless access_state.is_a?(BrowserRpAuthentication::AccessState) && access_state.status == :valid &&
        access_state.rp_session.instance_of?(session_class) &&
        access_state.resource.instance_of?(entry.principal_class) &&
        access_state.payload.is_a?(Hash) && actor.instance_of?(entry.actor_class) && actor.login_allowed? &&
        !actor.deactivated? && step_up_permitted_authentication_context?
      raise Refused.new(reason_code: "authentication_context_invalid")
    end
    raise Refused.new(reason_code: "browser_binding_invalid") unless
      browser_binding.is_a?(String) && browser_binding.match?(/\A[A-Za-z0-9_-]{43}\z/)
    unless return_target.is_a?(String) && RpTargetLinkUri.normalize(return_target) == return_target
      raise ActionController::BadRequest, "step-up return target is invalid"
    end
    raise ActionController::BadRequest, "step-up return target is too long" if return_target.length > 512
  end

  def step_up_permitted_authentication_context?
    context = access_state.payload[AuthenticationContextValue::CLAIM]
    return false unless AuthenticationContextValue::KEYS.include?(context)

    AuthenticationContextValue.for(context).step_up_permitted?
  end

  def lock_current_binding!
    session = session_class.find_by(
      id: access_state.rp_session.id,
      public_id: access_state.rp_session.public_id,
    )
    raise Refused.new(reason_code: "rp_session_unavailable") unless session

    binding_id = session.op_session_binding_id
    binding = entry.binding_class.lock.find_by(id: binding_id)
    raise Refused.new(reason_code: "op_binding_unavailable") unless binding

    session.lock!
    identity = entry.identity_binding_class.lock.find_by(id: binding.identity_binding_id)
    principal = entry.principal_class.lock.find_by(id: identity.principal_id) if identity
    now = record_class.database_now
    [session, binding, identity, principal, now]
  end

  def validate_current_binding!(session, binding, identity, principal, now)
    unless current_session_binding?(session, binding, now) && current_identity_binding?(binding, identity, principal) &&
        current_actor_claims?(binding, identity)
      raise Refused.new(reason_code: "rp_binding_changed")
    end
  end

  def current_session_binding?(session, binding, now)
    session.op_session_binding_id == binding.id && session.revoked_at.nil? && session.absolute_expires_at > now &&
      binding.revoked_at.nil?
  end

  def current_identity_binding?(binding, identity, principal)
    identity && principal && binding.identity_binding_id == identity.id &&
      identity.principal_id == access_state.resource.id && identity.realm == entry.cell.realm &&
      identity.client_id == entry.cell.client_id &&
      identity.issuer == OidcIssuer.for_resource_type(entry.resource_type) &&
      identity.subject == OidcSubject.for(actor, resource_type: entry.resource_type) && !principal.deactivated?
  end

  def current_actor_claims?(binding, identity)
    payload = access_state.payload
    issuer = OidcIssuer.for_resource_type(entry.resource_type)
    payload["iss"] == issuer && payload["sid"] == binding.sid && payload["sub"] == identity.subject &&
      payload["client_id"] == entry.cell.client_id && payload["aud"] == [entry.cell.client_id]
  end

  def create_pending_state!(session, now)
    raw_state = SecureRandom.urlsafe_base64(32)
    raw_nonce = SecureRandom.urlsafe_base64(32)
    verifier = SecureRandom.urlsafe_base64(32)
    state = state_class.create!(
      public_id: PublicId.generate,
      rp_session: session,
      state_digest: Digest::SHA256.hexdigest(raw_state),
      browser_binding_digest: digest_browser_binding,
      nonce_digest: Digest::SHA256.hexdigest(raw_nonce),
      pkce_challenge: OidcPkce.challenge_for(verifier),
      pkce_verifier_ciphertext: StepUpPkceVerifierCipherAdapter.encrypt(verifier:),
      issuer: OidcIssuer.for_resource_type(entry.resource_type),
      realm: entry.cell.realm.upcase,
      client_id: entry.cell.client_id,
      return_target:,
      initiating_generation: session.installed_generation,
      state_id: status_class::PENDING,
      expires_at: now + PENDING_TTL,
    )
    [state, raw_state, raw_nonce]
  end

  def write_requested_audit!(state, subject, now)
    StepUpAuditOutboxWriter.call(
      source_key: entry.audit_source_key,
      event_type: "step_up.requested",
      realm: entry.cell.realm.upcase,
      client_id: entry.cell.client_id,
      subject_ref: subject,
      context_ref: state.public_id,
      reason_code: "requested",
      payload: { rp_state_ref: state.public_id, return_target_kind: "relative" },
      occurred_at: now,
    )
  end

  def authorization_url(raw_state:, raw_nonce:, pkce_challenge:)
    client = OidcClientRegistry.find!(entry.cell.client_id)
    redirect_uri =
      client.redirect_uris_by_realm.fetch(entry.resource_type).find do |candidate|
        URI.parse(candidate).path == entry.callback_path
      end
    raise KeyError, "Base step-up callback URI is not registered" unless redirect_uri

    claims = {
      id_token: {
        acr: { essential: true, value: STEP_UP_ACR },
        auth_time: { essential: true },
      },
    }
    query = {
      response_type: "code",
      client_id: entry.cell.client_id,
      redirect_uri: redirect_uri,
      scope: "openid",
      state: raw_state,
      nonce: raw_nonce,
      code_challenge: pkce_challenge,
      code_challenge_method: "S256",
      prompt: "login",
      claims: JSON.generate(claims),
    }
    "#{OidcIssuer.authorization_endpoint(entry.resource_type)}?#{query.to_query}"
  end

  def digest_browser_binding
    Digest::SHA256.hexdigest(["op-mediated-step-up", entry.cell.client_id, browser_binding].join("\0"))
  end
end
