# frozen_string_literal: true

# Base-owned inventory and lifecycle entry for passkeys. Registration leaves Base through the
# purpose-scoped credential-registration admission; Auth only verifies the attestation and Base
# finalization remains the credential writer.
module BaseIdentityPasskeyManagement
  extend ActiveSupport::Concern

  include ::BaseStepUpTransactionMarker

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
    restart_binding = base_registration_restart_binding!(scope: "settings_passkey", method: :passkey)
    render "base/shared/credential_registration", layout: false,
                                                  locals: { action_url: passkeys_path, restart_binding: }
  rescue BaseAuthAdmissionCoordinator::Denied, ArgumentError, ActiveRecord::RecordNotFound
    render plain: I18n.t("errors.messages.invalid_request"), status: :bad_request
  end

  def create
    authorize!(passkey_class, to: :create?)
    apply_base_browser_continuation_headers!
    nonce = base_admission_browser_nonce_for_request!
    token = current_session_token
    actor = identity_actor
    requirement = StepUpRequirement.new(
      scope: "settings_passkey", purpose: "credential_registration", step_up_required: false,
      allowed_methods: [:passkey], phishing_resistant_required: false,
      user_verification_required: false, full_reauthentication_required: false,
      audience: "step_up:#{registration_surface}", session_binding: token.public_id,
      token_binding: token.public_id, require_session_binding: true, ttl: VerificationBase::STEP_UP_TTL,
      actor_ref: actor.public_id, resource_ref: nil, tenant_ref: nil,
    )
    issuance = BaseStepUpAdmissionIssuer.call!(
      actor: actor, token: token, requirement: requirement, return_to: passkeys_path,
      base_browser_nonce: nonce, base_token: token, restart_of: params[:restart_of],
    )
    if issuance.is_a?(BaseAuthAdmissionCoordinator::TerminalOutcome)
      return redirect_to(issuance.transaction.return_to, status: :see_other, allow_other_host: false)
    end

    remember_base_step_up_transaction!(transaction: issuance.transaction, actor:, token:)
    redirect_to(
      registration_auth_url(entry_ref: issuance.reference), status: :see_other, allow_other_host: true,
    )
  rescue BaseAuthAdmissionCoordinator::Denied, ArgumentError, ActiveRecord::RecordNotFound
    render plain: I18n.t("errors.messages.invalid_request"), status: :bad_request
  rescue Umaxica::Valkey::Unavailable, Umaxica::Valkey::OperationError
    render plain: I18n.t("errors.rate_limit.backend_unavailable"), status: :service_unavailable
  end

  private

  def passkey_relation
    case identity_actor
    when Client then identity_actor.client_passkeys.active
    when Visitor then identity_actor.visitor_passkeys.active
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
    when "com" then base_com_identity_path(ri: params[:ri])
    when "org" then base_org_identity_path(ri: params[:ri])
    else raise ArgumentError, "unsupported passkey surface"
    end
  end

  def passkeys_path
    case registration_surface
    when "app" then base_app_identity_passkeys_path(ri: params[:ri])
    when "com" then base_com_identity_passkeys_path(ri: params[:ri])
    when "org" then base_org_identity_passkeys_path(ri: params[:ri])
    else raise ArgumentError, "unsupported passkey surface"
    end
  end

  def passkey_path(public_id)
    case registration_surface
    when "app" then base_app_identity_passkey_path(public_id, ri: params[:ri])
    when "com" then base_com_identity_passkey_path(public_id, ri: params[:ri])
    when "org" then base_org_identity_passkey_path(public_id, ri: params[:ri])
    else raise ArgumentError, "unsupported passkey surface"
    end
  end

  def passkey_reference_attribute = :public_id

  def passkey_reference(passkey)
    case passkey
    when OperatorPasskey then passkey.external_id
    when ClientPasskey, VisitorPasskey then passkey.public_id
    else raise ArgumentError, "unsupported passkey credential"
    end
  end

  def new_passkey_path
    case registration_surface
    when "app" then new_base_app_identity_passkey_path(ri: params[:ri])
    when "com" then new_base_com_identity_passkey_path(ri: params[:ri])
    when "org" then new_base_org_identity_passkey_path(ri: params[:ri])
    else raise ArgumentError, "unsupported passkey surface"
    end
  end

  def registration_auth_url(entry_ref:)
    query = { entry_ref: entry_ref, ri: params[:ri], host: registration_auth_host, protocol: "https" }
    case registration_surface
    when "app" then new_auth_app_verification_registration_passkey_url(**query)
    when "com" then new_auth_com_verification_registration_passkey_url(**query)
    when "org" then new_auth_org_verification_registration_passkey_url(**query)
    else raise ArgumentError, "unsupported passkey surface"
    end
  end

  def registration_auth_host
    case registration_surface
    when "app" then ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    when "com" then ENV.fetch("PUBLIC_AUTH_CORPORATE_URL")
    when "org" then ENV.fetch("PUBLIC_AUTH_STAFF_URL")
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
