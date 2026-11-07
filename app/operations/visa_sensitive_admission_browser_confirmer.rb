# frozen_string_literal: true

# Makes Base's CSRF-protected browser confirmation authoritative at Visa before Auth may write.
class VisaSensitiveAdmissionBrowserConfirmer
  class InvalidAuthority < StandardError; end

  ADMISSION_MODELS = {
    Client => [ClientVisaSensitiveAdmission, ClientVisaSocialLinkAdmission],
    Operator => [OperatorVisaSensitiveAdmission],
  }.freeze

  class << self
    public

    def call!(actor:, token:, grant:, payload:, client_id:, rp_session_ref:, public_ref:, browser_digest:)
      new(
        actor:, token:, grant:, payload:, client_id:, rp_session_ref:, public_ref:, browser_digest:,
      ).call
    end
  end

  public

  def initialize(actor:, token:, grant:, payload:, client_id:, rp_session_ref:, public_ref:, browser_digest:)
    @actor = actor
    @token = token
    @grant = grant
    @payload = payload
    @client_id = client_id
    @rp_session_ref = rp_session_ref
    @public_ref = public_ref
    @browser_digest = browser_digest
  end

  def call
    validate_record_pair!
    validate_request_shape!

    actor.class.connection_class_for_self.connected_to(role: :writing) do
      actor.with_lock do
        raise InvalidAuthority unless actor.login_allowed?

        admission_model.connection_owner.connected_to(role: :writing) do
          admission_model.transaction do
            device_session = token.device_session_record!
            device_session.with_lock do
              token.with_lock do
                grant.with_lock do
                  now = admission_model.database_now
                  validate_locked_authority!(device_session, now)
                  admission = find_admission!
                  admission.with_lock do
                    confirm_locked!(admission, now)
                  end
                end
              end
            end
          end
        end
      end
    end
  end

  private

  attr_reader :actor, :token, :grant, :payload, :client_id, :rp_session_ref, :public_ref, :browser_digest

  def validate_record_pair!
    valid_pair = (actor.is_a?(Client) && token.is_a?(ClientToken) && grant.is_a?(OpAppGrant)) ||
      (actor.is_a?(Operator) && token.is_a?(OperatorToken) && grant.is_a?(OpOrgGrant))
    raise InvalidAuthority unless valid_pair
  end

  def validate_request_shape!
    unless public_ref.is_a?(String) && public_ref.match?(ClientVisaSensitiveAdmission::PUBLIC_REF_PATTERN) &&
        browser_digest.is_a?(String) && browser_digest.match?(ClientVisaSensitiveAdmission::DIGEST_PATTERN) &&
        rp_session_ref.is_a?(String) && rp_session_ref.present? && payload.is_a?(Hash)
      raise InvalidAuthority
    end
  end

  def validate_locked_authority!(device_session, now)
    owner_matches = owner_matches?
    expected_subject = OidcSubject.for(actor, resource_type: actor.is_a?(Client) ? "client" : "operator")
    unless owner_matches && live_token_session?(device_session, now) &&
        live_grant_binding?(device_session, now) && payload_authority_matches?(expected_subject)
      raise InvalidAuthority
    end
  end

  def owner_matches?
    case [actor, token, grant]
    in [Client, ClientToken, OpAppGrant]
      token.user_id == actor.id && grant.client_token_id == token.id && client_id == "base-app-ww"
    in [Operator, OperatorToken, OpOrgGrant]
      token.staff_id == actor.id && grant.operator_token_id == token.id && client_id == "base-org-ww"
    else
      false
    end
  end

  def live_token_session?(device_session, now)
    token.active_status?(now) && device_session.usable? && device_session.current_refresh_token_id == token.id
  end

  def live_grant_binding?(device_session, now)
    grant.device_session_id == device_session.id && grant.oidc_client_id == client_id && grant.active?(now)
  end

  def payload_authority_matches?(expected_subject)
    exact?(payload["sub"], expected_subject) && exact?(payload["sid"], grant.public_id) &&
      exact?(payload["client_id"], client_id)
  end

  def find_admission!
    matches =
      admission_models.filter_map do |model|
        model.includes(:auth_admission_binding, :step_up_ceremony_transaction, :oidc_authorization_transaction)
          .lock.find_by(public_ref: public_ref)
      end
    raise InvalidAuthority unless matches.one?

    matches.first
  end

  def confirm_locked!(admission, now)
    binding = admission.auth_admission_binding
    ticket = admission.step_up_ceremony_transaction
    authorization = admission.oidc_authorization_transaction
    expected_actor_subject = OidcSubject.for(actor, resource_type: actor.is_a?(Client) ? "client" : "operator")
    binding.with_lock do
      raise InvalidAuthority unless admission_confirmation_valid?(
        admission, binding, ticket, authorization, expected_actor_subject, now,
      )

      confirm_admission!(admission, binding, now)
    end
  end

  def admission_confirmation_valid?(admission, binding, ticket, authorization, expected_actor_subject, now)
    digest_matches = exact?(admission.browser_binding_digest, browser_digest) &&
      exact?(admission.browser_binding_digest, binding.base_browser_digest)

    admission_identity_matches?(admission, expected_actor_subject, now) &&
      authorization_current?(authorization, admission, now) &&
      ticket_matches?(ticket, now) && binding_matches?(binding, ticket, now) && digest_matches
  end

  def admission_identity_matches?(admission, expected_actor_subject, now)
    admission.actor_subject == expected_actor_subject && admission.grant_sid == grant.public_id &&
      admission.realm == (actor.is_a?(Client) ? "app" : "org") &&
      admission.client_id == client_id && admission.rp_session_ref == rp_session_ref &&
      admission.expires_at > now && admission.rp_session_expires_at > now &&
      admission.expires_at <= admission.rp_session_expires_at && event_matches?(admission)
  end

  def authorization_current?(authorization, admission, now)
    authorization.pending? && authorization.surface == admission.realm && authorization.client_id == client_id &&
      !authorization.expired?(now:) && !authorization.login_challenge_expired?(now:)
  end

  def ticket_matches?(ticket, now)
    ticket.actor_ref == actor.public_id && ticket.session_ref == token.public_id &&
      %w(pending verified).include?(ticket.status) && !ticket.expired?(now:)
  end

  def binding_matches?(binding, ticket, now)
    binding.step_up_ceremony_transaction_id == ticket.id && binding.base_token_id == token.id &&
      binding.purpose == "credential_registration_handoff" && binding.attached? && binding.live?(now:) &&
      binding.auth_ceremony_session_id.present? && auth_session_active?(binding, now:)
  end

  def confirm_admission!(admission, binding, now)
    if admission.status == "browser_confirmed"
      binding.confirm_base!(base_token: token, browser_digest: binding.base_browser_digest)
      return admission
    end
    raise InvalidAuthority unless admission.status == "issued"

    binding.confirm_base!(base_token: token, browser_digest: binding.base_browser_digest)
    admission.update!(status: "browser_confirmed", updated_at: now)
    admission
  end

  def auth_session_active?(binding, now:)
    session_model =
      case binding
      when ClientAuthAdmissionBinding then ClientAuthCeremonySession
      when OperatorAuthAdmissionBinding then OperatorAuthCeremonySession
      else return false
      end
    session = session_model.lock.find_by(id: binding.auth_ceremony_session_id)
    session&.active?(now:)
  end

  def event_matches?(admission)
    event_amr = payload["amr"]
    admission.event_jti == payload["jti"] && admission.event_auth_time == payload["auth_time"] &&
      admission.event_acr == payload["acr"] && admission.event_amr == event_amr &&
      grant.oidc_jti == admission.event_jti && grant.oidc_auth_time&.to_i == admission.event_auth_time &&
      grant.oidc_acr == admission.event_acr && parsed_grant_amr == admission.event_amr
  end

  def parsed_grant_amr
    parsed = JSON.parse(grant.oidc_amr.to_s)
    return unless parsed.is_a?(Array) && parsed.all? { |method| method.is_a?(String) && method.present? }

    parsed
  rescue JSON::ParserError
    nil
  end

  def admission_models
    ADMISSION_MODELS.fetch(actor.class) { raise InvalidAuthority }
  end

  def admission_model
    case actor
    when Client then ClientVisaSensitiveAdmission
    when Operator then OperatorVisaSensitiveAdmission
    else raise InvalidAuthority
    end
  end

  def exact?(actual, expected)
    actual.is_a?(String) && expected.is_a?(String) && actual.bytesize == expected.bytesize &&
      ActiveSupport::SecurityUtils.secure_compare(actual, expected)
  end
end
