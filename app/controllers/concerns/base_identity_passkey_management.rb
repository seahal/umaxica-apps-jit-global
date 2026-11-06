# frozen_string_literal: true

# Base-owned inventory and lifecycle entry for passkeys. Visa creates the O-9 admission; Auth owns
# attestation verification and the source credential write.
module BaseIdentityPasskeyManagement
  extend ActiveSupport::Concern

  public

  def index
    authorize!(passkey_class, to: :index?)
    @passkeys = passkey_relation.order(created_at: :asc)
    render inertia: passkey_index_component, props: {
      title: t("base.shared.identity.passkeys.title"),
      description: t("base.shared.identity.passkeys.description"),
      back_link: { label: t("base.shared.identity.up_link"), href: identity_path },
      new_link: { label: t("actions.add"), href: new_passkey_path },
      remove_label: t("actions.delete"),
      remove_confirm: t("messages.confirm_destroy"),
      empty_message: t("views.sign.app.settings.passkeys.index.empty"),
      passkeys: @passkeys.map { |passkey| serialize_passkey(passkey) },
    }
  end

  def show
    @passkey = passkey_relation.find_by!(passkey_reference_attribute => params.expect(:id))
    authorize!(@passkey)
    render inertia: passkey_show_component, props: passkey_show_props
  end

  def new
    authorize!(passkey_class, to: :new?)
    apply_base_browser_continuation_headers!
    response.headers["Referrer-Policy"] = "strict-origin"
    render "base/shared/credential_registration", layout: false,
                                                  locals: { action_url: passkeys_path, restart_binding: nil }
  end

  def create
    authorize!(passkey_class, to: :create?)
    apply_base_browser_continuation_headers!
    browser_nonce = ensure_base_admission_browser_nonce!
    actor = identity_actor
    rp_session = browser_rp_access_state.rp_session
    unless rp_session.is_a?(rp_session_class) && rp_session.active? &&
        rp_session.absolute_expires_at > rp_record_class.database_now && actor.login_allowed?
      return render plain: I18n.t("errors.messages.invalid_request"), status: :unauthorized
    end

    verifier = SecureRandom.urlsafe_base64(48)
    challenge = Base64.urlsafe_encode64(Digest::SHA256.digest(verifier), padding: false)
    nonce = SecureRandom.urlsafe_base64(32)
    state, jti = OidcStateJwt.issue(
      client_id: oidc_client_id, target_link_uri: RpTargetLinkUri.normalize(passkeys_path),
    )
    remember_oidc_pending_flow!(jti:, verifier:, nonce:)
    browser_digest = AuthAdmissionBinding.browser_digest(
      surface: registration_surface, entry_ref: rp_session.public_id, nonce: browser_nonce,
    )
    attributes = {
      response_type: "code",
      client_id: oidc_client_id,
      redirect_uri: oidc_callback_url,
      scope: "openid profile",
      state: state,
      nonce: nonce,
      code_challenge: challenge,
      code_challenge_method: "S256",
      claims: OidcAuthorizeRequestResolver::STEP_UP_CLAIMS,
      ri: RequestContextContract.normalize_region(params[:ri]),
      rp_session_ref: rp_session.public_id,
      rp_session_expires_at: rp_session.absolute_expires_at.iso8601(6),
      browser_binding_digest: browser_digest,
      purpose: "passkey_registration",
      provider: "none",
    }
    access_token = BrowserCredentialCookie.read(cookies, OidcRpBrowserCredentialContract::ACCESS_COOKIE)
    result = VisaSensitiveAdmissionClient.new(
      surface: registration_surface, access_token:,
    ).issue_admission!(attributes:)
    return head :service_unavailable if result.status == :dependency
    return head :unauthorized if result.status == :unauthorized
    return render plain: I18n.t("errors.messages.invalid_request"), status: :bad_request unless result.ok?

    redirect_to(result.authorization_url, status: :see_other, allow_other_host: true)
  rescue ArgumentError, OidcAuthorizeRequestResolver::RequestError
    render plain: I18n.t("errors.messages.invalid_request"), status: :bad_request
  end

  private

  def passkey_relation
    case identity_actor
    when Client then identity_actor.client_passkeys.active
    when Operator then identity_actor.staff_passkeys.active
    else raise ArgumentError, "unsupported passkey owner"
    end
  end

  def serialize_passkey(passkey)
    {
      public_id: passkey_reference(passkey),
      description: passkey.description,
      created_at: passkey.created_at&.iso8601,
      last_used_at: passkey.last_used_at&.iso8601,
      show_href: passkey_path(passkey_reference(passkey)),
      destroy_action: passkey_path(passkey_reference(passkey)),
    }
  end

  def passkey_index_component = "base/#{registration_surface}/identity/passkeys/index"

  def passkey_show_component = "base/#{registration_surface}/identity/passkeys/show"

  def passkey_show_props(error: nil)
    {
      title: t("base.shared.identity.passkeys.title"),
      description: @passkey.description,
      back_link: { label: t("actions.back"), href: passkeys_path },
      passkey: serialize_passkey(@passkey),
      form: {
        action: passkey_path(passkey_reference(@passkey)),
        description: @passkey.description,
        label: t("activerecord.attributes.user_passkey.description"),
        submit_label: t("actions.save"),
      },
      destroy: {
        action: passkey_path(passkey_reference(@passkey)),
        label: t("actions.delete"),
        confirm: t("messages.confirm_destroy"),
      },
      error: error,
    }
  end

  def identity_path
    case registration_surface
    when "app" then base_app_identity_path(ri: params[:ri])
    when "org" then base_org_identity_path(ri: params[:ri])
    else raise ArgumentError, "unsupported passkey surface"
    end
  end

  def passkeys_path
    case registration_surface
    when "app" then base_app_identity_passkeys_path(ri: params[:ri])
    when "org" then base_org_identity_passkeys_path(ri: params[:ri])
    else raise ArgumentError, "unsupported passkey surface"
    end
  end

  def passkey_path(public_id)
    case registration_surface
    when "app" then base_app_identity_passkey_path(public_id, ri: params[:ri])
    when "org" then base_org_identity_passkey_path(public_id, ri: params[:ri])
    else raise ArgumentError, "unsupported passkey surface"
    end
  end

  def passkey_reference_attribute = :public_id

  def passkey_reference(passkey)
    case passkey
    when OperatorPasskey then passkey.external_id
    when ClientPasskey then passkey.public_id
    else raise ArgumentError, "unsupported passkey credential"
    end
  end

  def new_passkey_path
    case registration_surface
    when "app" then new_base_app_identity_passkey_path(ri: params[:ri])
    when "org" then new_base_org_identity_passkey_path(ri: params[:ri])
    else raise ArgumentError, "unsupported passkey surface"
    end
  end

  def rp_session_class
    case registration_surface
    when "app" then RpBaseAppSession
    when "org" then RpBaseOrgSession
    else raise ArgumentError, "unsupported passkey surface"
    end
  end

  def rp_record_class
    case registration_surface
    when "app" then RpBaseAppRecord
    when "org" then RpBaseOrgRecord
    else raise ArgumentError, "unsupported passkey surface"
    end
  end

  def registration_surface
    raise NotImplementedError, "#{self.class} must define #registration_surface"
  end

  def identity_actor
    raise NotImplementedError, "#{self.class} must define #identity_actor"
  end

  def passkey_class
    raise NotImplementedError, "#{self.class} must define #passkey_class"
  end

  def passkey_association
    raise NotImplementedError, "#{self.class} must define #passkey_association"
  end
end
