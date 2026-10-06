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
      title: t("base.identity.passkeys.title", default: "Passkeys"),
      description: t("base.identity.passkeys.description", default: "Manage your passkeys."),
      back_link: { label: t("base.shared.identity.up_link"), href: identity_path },
      new_link: { label: t("actions.add", default: "Add passkey"), href: new_passkey_path },
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
    nonce = ensure_base_admission_browser_nonce!
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
      base_browser_nonce: nonce, base_token: token,
    )
    remember_base_step_up_transaction!(transaction: issuance.transaction, actor:, token:)
    redirect_to(
      registration_auth_url(entry_ref: issuance.reference), status: :see_other, allow_other_host: true,
    )
  rescue BaseAuthAdmissionCoordinator::Denied, ArgumentError, ActiveRecord::RecordNotFound
    render plain: I18n.t("errors.messages.invalid_request"), status: :bad_request
  rescue Umaxica::Valkey::Unavailable, Umaxica::Valkey::OperationError
    render plain: I18n.t("errors.rate_limit.backend_unavailable"), status: :service_unavailable
  end

  def update
    @passkey = passkey_relation.find_by!(passkey_reference_attribute => params.expect(:id))
    authorize!(@passkey)
    description = params.expect(passkey: [:description]).fetch(:description)
    @passkey.update!(description: description.to_s.strip)
    redirect_to(passkey_path(@passkey.public_id), status: :see_other)
  rescue ActiveRecord::RecordInvalid, ActionController::ParameterMissing
    render inertia: passkey_show_component, props: passkey_show_props(error: I18n.t("errors.messages.invalid_request")),
           status: :unprocessable_content
  end

  def destroy
    @passkey = passkey_relation.find_by!(passkey_reference_attribute => params.expect(:id))
    authorize!(@passkey)
    removed = IdentityCredentialRemovalCommitter.call!(
      actor: identity_actor, credential: @passkey, current_session: current_session_token, request: request,
    )
    unless removed
      return render inertia: passkey_show_component,
                    props: passkey_show_props(error: I18n.t("errors.messages.invalid_request")),
                    status: :unprocessable_content
    end
    redirect_to(passkeys_path, status: :see_other)
  rescue ArgumentError, ActiveRecord::RecordInvalid
    render inertia: passkey_show_component,
           props: passkey_show_props(error: I18n.t("errors.messages.invalid_request")),
           status: :unprocessable_content
  end

  private

  def passkey_relation
    identity_actor.public_send(passkey_association).public_send(:active)
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
      title: t("base.identity.passkeys.title", default: "Passkey"),
      description: @passkey.description,
      back_link: { label: t("actions.back", default: "Back"), href: passkeys_path },
      passkey: serialize_passkey(@passkey),
      form: {
        action: passkey_path(passkey_reference(@passkey)),
        description: @passkey.description,
        label: t("activerecord.attributes.user_passkey.description", default: "Description"),
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
    public_send("base_#{registration_surface}_identity_path", ri: params[:ri])
  end

  def passkeys_path
    public_send("base_#{registration_surface}_identity_passkeys_path", ri: params[:ri])
  end

  def passkey_path(public_id)
    public_send("base_#{registration_surface}_identity_passkey_path", public_id, ri: params[:ri])
  end

  def passkey_reference_attribute = :public_id

  def passkey_reference(passkey) = passkey.public_send(passkey_reference_attribute)

  def new_passkey_path
    public_send("new_base_#{registration_surface}_identity_passkey_path", ri: params[:ri])
  end

  def registration_auth_url(entry_ref:)
    public_send(
      "new_auth_#{registration_surface}_verification_registration_passkey_url",
      entry_ref: entry_ref, ri: params[:ri], host: registration_auth_host, protocol: "https",
    )
  end

  def registration_auth_host
    {
      "app" => ENV.fetch("PUBLIC_AUTH_SERVICE_URL"),
      "com" => ENV.fetch("PUBLIC_AUTH_CORPORATE_URL"),
      "org" => ENV.fetch("PUBLIC_AUTH_STAFF_URL"),
    }.fetch(registration_surface)
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
