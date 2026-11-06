# frozen_string_literal: true

# Visa derives the identity and fresh Step-Up event from the authenticated Base Access JWT,
# then creates the OIDC context, Auth admission and O-9 row under the actor-first owner boundary.
class VisaSensitiveAdmissionIssuer
  Issuance = Data.define(:admission, :authorization_url, :auth_entry_ref)

  class InvalidRequest < StandardError; end

  CONFIG = {
    "app" => {
      actor_class: Client,
      token_class: ClientToken,
      grant_class: OpAppGrant,
      admission_model: ClientVisaSensitiveAdmission,
      social_admission_model: ClientVisaSocialLinkAdmission,
      transaction_model: ClientStepUpCeremonyTransaction,
      session_model: ClientStepUpSession,
      binding_model: ClientAuthAdmissionBinding,
      client_id: "base-app-ww",
      resource_type: "client",
      realm: "app",
      return_to: "/identity/passkeys",
      scope: "settings_passkey",
      audit_surface: "app",
    },
    "org" => {
      actor_class: Operator,
      token_class: OperatorToken,
      grant_class: OpOrgGrant,
      admission_model: OperatorVisaSensitiveAdmission,
      transaction_model: OperatorStepUpCeremonyTransaction,
      session_model: OperatorStepUpSession,
      binding_model: OperatorAuthAdmissionBinding,
      client_id: "base-org-ww",
      resource_type: "operator",
      realm: "org",
      return_to: "/identity/passkeys",
      scope: "settings_passkey",
      audit_surface: "org",
    },
  }.freeze

  class << self
    public

    def call!(surface:, actor:, token:, grant:, payload:, request_params:)
      new(surface:, actor:, token:, grant:, payload:, request_params:).call
    end
  end

  public

  def initialize(surface:, actor:, token:, grant:, payload:, request_params:)
    @surface = surface.to_s
    @actor = actor
    @token = token
    @grant = grant
    @payload = payload
    @request_params = request_params
  end

  def call
    config = CONFIG.fetch(surface)
    validate_types!(config)
    validate_request!(config)
    evidence = evidence_from_payload!

    actor.class.connection_class_for_self.connected_to(role: :writing) do
      actor.with_lock do
        raise InvalidRequest unless actor.login_allowed?

        owner.connected_to(role: :writing) do
          owner.transaction do
            device_session = token.device_session_record!
            device_session.with_lock do
              token.with_lock do
                grant.with_lock do
                  now = owner.database_now
                  validate_live_authority!(config, device_session, now)
                  raise InvalidRequest unless StepUpEvidenceVerifier.call(evidence:, actor:, token:)
                  raise InvalidRequest unless StepUpResolver.call(
                    token:, requirement: current_step_up_requirement(config), now:,
                  ).satisfied?

                  create_admission!(config, evidence:, now:)
                end
              end
            end
          end
        end
      end
    end
  rescue ActiveRecord::RecordNotFound
    raise InvalidRequest
  end

  private

  attr_reader :surface, :actor, :token, :grant, :payload, :request_params

  def owner = CONFIG.fetch(surface).fetch(:admission_model).connection_owner

  def validate_types!(config)
    unless actor.is_a?(config.fetch(:actor_class)) && token.is_a?(config.fetch(:token_class)) &&
        grant.is_a?(config.fetch(:grant_class)) && payload.is_a?(Hash) && request_params.is_a?(Hash)
      raise InvalidRequest
    end
  end

  def validate_request!(config)
    request = OidcAuthorizeRequestResolver.call(
      params: request_params, resource: actor, resource_type: config.fetch(:resource_type),
    )
    purpose = request_params.fetch(:purpose).to_s
    provider = request_params.fetch(:provider).to_s
    purpose_provider_valid =
      if surface == "app"
        (purpose == "passkey_registration" && provider == "none") ||
          (purpose == "social_link" && provider.in?(%w(google apple)))
      else
        purpose == "passkey_registration" && provider == "none"
      end
    unless purpose_provider_valid && request.step_up_requested &&
        request.client.client_id == config.fetch(:client_id) &&
        request_params[:client_id].to_s == config.fetch(:client_id) &&
        request_params[:redirect_uri].to_s.in?(request.client.redirect_uris)
      raise InvalidRequest
    end

    request
  rescue OidcAuthorizeRequestResolver::RequestError, OidcAuthorizeRequestResolver::UnsupportedPrompt,
         ArgumentError, KeyError, OidcClientRegistry::ClientNotFound, OidcClientRegistry::InvalidRedirectUri
    raise InvalidRequest
  end

  def evidence_from_payload!
    StepUpEvidenceValue.new(
      acr: payload.fetch("acr"),
      amr: payload.fetch("amr"),
      auth_time: payload.fetch("auth_time"),
      sid: payload.fetch("sid"),
      sub: payload.fetch("sub"),
      client_id: payload.fetch("client_id"),
      aud: payload.fetch("aud"),
      jti: payload.fetch("jti"),
    )
  rescue KeyError, ArgumentError, TypeError
    raise InvalidRequest
  end

  def validate_live_authority!(config, device_session, now)
    actor_key =
      case token
      when ClientToken then :user_id
      when OperatorToken then :staff_id
      else raise InvalidRequest
      end
    expected_subject = OidcSubject.for(actor, resource_type: config.fetch(:resource_type))
    grant_root_id =
      case [grant, token]
      in [OpAppGrant, ClientToken] then grant.client_token_id
      in [OpOrgGrant, OperatorToken] then grant.operator_token_id
      else nil
      end
    unless token[actor_key] == actor.id && token.active_status?(now) && device_session.usable? &&
        device_session.current_refresh_token_id == token.id && grant.active?(now) &&
        grant_root_id == token.id && grant.device_session_id == device_session.id &&
        grant.oidc_client_id == config.fetch(:client_id) &&
        grant.public_id == evidence_from_payload_sid && payload["sub"] == expected_subject
      raise InvalidRequest
    end
  end

  def evidence_from_payload_sid
    payload.fetch("sid")
  end

  def create_admission!(config, evidence:, now:)
    raise InvalidRequest unless rp_session_expires_at > now

    admission_model = admission_model_for(config)
    existing = find_existing_admission(config, admission_model)
    return issuance_for(existing, config) if existing

    oidc_transaction = OidcAuthorizationTransactionCoordinator.issue!(
      surface:,
      intent: "step_up",
      params: request_params,
      now:,
      ttl: 15.minutes,
    ).transaction
    purpose = request_params.fetch(:purpose).to_s
    provider = request_params.fetch(:provider).to_s
    requirement, return_to = auth_admission_requirement(config, purpose:, provider:)
    auth_issuance = BaseStepUpAdmissionIssuer.call!(
      actor:, token:, requirement:, return_to:, base_browser_digest:,
      base_token: token, step_up_evidence: evidence,
    )
    raise InvalidRequest unless auth_issuance.is_a?(BaseAuthAdmissionCoordinator::Issuance)

    binding = config.fetch(:binding_model).find_by!(entry_ref: auth_issuance.reference)
    expires_at = [now + 15.minutes, rp_session_expires_at].min
    raise InvalidRequest unless expires_at > now

    social_transaction =
      if purpose == "social_link"
        ClientSocialCeremonyTransaction.create_transaction!(
          actor_ref: actor.public_id, session_ref: token.device_session_record!.public_id,
          operation: "link", provider:,
          expires_at:, now:,
        )
      end
    admission_attributes = {
      public_ref: PublicId.generate,
      oidc_authorization_transaction: oidc_transaction,
      step_up_ceremony_transaction: auth_issuance.transaction,
      auth_admission_binding: binding,
      realm: config.fetch(:realm),
      client_id: config.fetch(:client_id),
      actor_subject: OidcSubject.for(actor, resource_type: config.fetch(:resource_type)),
      grant_sid: grant.public_id,
      rp_session_ref:,
      rp_session_expires_at:,
      browser_binding_digest: base_browser_digest,
      purpose:,
      provider:,
      event_jti: evidence.jti,
      event_auth_time: evidence.auth_time,
      event_acr: evidence.acr,
      event_amr: evidence.amr,
      status: "issued",
      expires_at:,
      created_at: now,
      updated_at: now,
    }
    admission_attributes[:social_ceremony_transaction] = social_transaction if social_transaction
    admission = admission_model.create!(admission_attributes)
    issuance_for(admission, config, auth_entry_ref: auth_issuance.reference)
  end

  def current_step_up_requirement(config)
    allowed_methods = actor.is_a?(Operator) ? [:passkey] : %i(email_otp passkey totp)
    StepUpRequirement.new(
      scope: (request_params.fetch(:purpose).to_s == "social_link") ? "social_link" : config.fetch(:scope),
      step_up_required: true, allowed_methods:, phishing_resistant_required: false,
      user_verification_required: false, full_reauthentication_required: false,
      audience: "step_up:#{surface}", session_binding: token.public_id, token_binding: token.public_id,
      require_session_binding: true, ttl: 15.minutes, purpose: "step_up",
      actor_ref: actor.public_id, resource_ref: nil, tenant_ref: nil,
    )
  end

  def auth_admission_requirement(config, purpose:, provider:)
    if purpose == "social_link"
      return [
        StepUpRequirement.new(
          # This ticket only admits the Auth browser session; the Visa social-link row owns the
          # operation and current Step-Up authorization was already checked above.
          scope: "social_link", step_up_required: false, allowed_methods: [:passkey],
          phishing_resistant_required: false, user_verification_required: false,
          full_reauthentication_required: false, audience: "step_up:#{surface}",
          session_binding: token.public_id, token_binding: token.public_id, require_session_binding: true,
          ttl: 15.minutes, purpose: "credential_registration", actor_ref: actor.public_id,
          resource_ref: nil, tenant_ref: nil,
        ),
        "/settings/#{provider}",
      ]
    end

    [
      StepUpRequirement.new(
        scope: config.fetch(:scope), step_up_required: false, allowed_methods: [:passkey],
        phishing_resistant_required: false, user_verification_required: false,
        full_reauthentication_required: false, audience: "step_up:#{surface}",
        session_binding: token.public_id, token_binding: token.public_id, require_session_binding: true,
        ttl: 15.minutes, purpose: "credential_registration", actor_ref: actor.public_id,
        resource_ref: nil, tenant_ref: nil,
      ),
      config.fetch(:return_to),
    ]
  end

  def admission_model_for(config)
    return config.fetch(:admission_model) if request_params.fetch(:purpose).to_s == "passkey_registration"

    config.fetch(:social_admission_model) { raise InvalidRequest }
  end

  def find_existing_admission(config, admission_model)
    authorization_model = oidc_authorization_model(admission_model)
    matches = admission_model.joins(:oidc_authorization_transaction)
      .where(
        authorization_model.table_name => {
          client_id: config.fetch(:client_id),
          state: request_params.fetch(:state),
        },
      ).lock.to_a
    raise InvalidRequest unless matches.length <= 1
    return if matches.empty?

    admission = matches.first
    authorization = authorization_model.find(admission.oidc_authorization_transaction_id)
    expected_subject = OidcSubject.for(actor, resource_type: config.fetch(:resource_type))
    now = owner.database_now
    valid = admission.status == "issued" && authorization.pending? &&
      admission.expires_at > now && admission.rp_session_expires_at > now &&
      !authorization.expired?(now:) && !authorization.login_challenge_expired?(now:) &&
      authorization.surface == surface && authorization.client_id == config.fetch(:client_id) &&
      authorization.redirect_uri == request_params.fetch(:redirect_uri) &&
      authorization.response_type == request_params.fetch(:response_type) &&
      authorization.scope == request_params.fetch(:scope) &&
      authorization.state == request_params.fetch(:state) &&
      authorization.nonce == request_params.fetch(:nonce) &&
      authorization.code_challenge == request_params.fetch(:code_challenge) &&
      authorization.code_challenge_method == request_params.fetch(:code_challenge_method) &&
      authorization.oidc_prompt == OidcAuthorizeRequestResolver.normalize_prompt(request_params[:prompt]) &&
      authorization.oidc_max_age == OidcAuthorizeRequestResolver.normalize_max_age(request_params[:max_age]) &&
      admission.purpose == request_params.fetch(:purpose).to_s &&
      admission.provider == request_params.fetch(:provider).to_s &&
      admission.actor_subject == expected_subject && admission.grant_sid == grant.public_id &&
      admission.rp_session_ref == rp_session_ref && admission.rp_session_expires_at == rp_session_expires_at &&
      admission.browser_binding_digest == base_browser_digest && event_matches?(admission, evidence_from_payload!)
    raise InvalidRequest unless valid

    admission
  rescue ActiveRecord::RecordNotFound, KeyError
    raise InvalidRequest
  end

  def event_matches?(admission, evidence)
    admission.event_jti == evidence.jti && admission.event_auth_time == evidence.auth_time &&
      admission.event_acr == evidence.acr && admission.event_amr == evidence.amr
  end

  def issuance_for(admission, config, auth_entry_ref: nil)
    binding = config.fetch(:binding_model).find(admission.auth_admission_binding_id)
    Issuance.new(
      admission:,
      authorization_url: OidcIssuer.authorization_endpoint(config.fetch(:resource_type)) +
        "?#{authorization_query(config)}",
      auth_entry_ref: auth_entry_ref || binding.entry_ref,
    )
  end

  def oidc_authorization_model(admission_model)
    admission_model.reflect_on_association(:oidc_authorization_transaction).klass
  end

  def authorization_query(config)
    %i(response_type client_id redirect_uri scope state nonce code_challenge code_challenge_method claims prompt
       max_age ri).each_with_object({}) do |key, query|
      value = request_params[key]
      query[key] = value if value.present?
    end.merge(client_id: config.fetch(:client_id)).to_query
  end

  def rp_session_ref
    value = request_params.fetch(:rp_session_ref)
    raise InvalidRequest unless value.is_a?(String) && value.present? && value.length <= 64

    value
  end

  def rp_session_expires_at
    value = Time.iso8601(request_params.fetch(:rp_session_expires_at).to_s)
    raise InvalidRequest unless value > owner.database_now

    value
  rescue ArgumentError
    raise InvalidRequest
  end

  def base_browser_digest
    value = request_params.fetch(:browser_binding_digest)
    return value if value.is_a?(String) && value.match?(ClientVisaSensitiveAdmission::DIGEST_PATTERN)

    raise InvalidRequest
  end
end
