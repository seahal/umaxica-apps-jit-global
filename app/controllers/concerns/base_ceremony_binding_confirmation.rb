# typed: false
# frozen_string_literal: true

# Base-side receiver for the Auth attachment handoff. GET is a representation
# only; the CSRF-protected POST is the sole operation that records
# base_confirmed_at and returns the browser to Auth.
module BaseCeremonyBindingConfirmation
  extend ActiveSupport::Concern
  include AdmissionReferenceParameters

  public

  def show
    apply_base_browser_continuation_headers!
    binding = load_ceremony_binding!
    validate_binding_base_context!(binding)
    render "base/shared/ceremony_binding_confirmation", layout: false,
                                                        locals: { binding_ref: params[:binding_ref] }
  rescue BaseAuthAdmissionCoordinator::Denied, ActiveRecord::RecordNotFound, ArgumentError,
         AuthAdmissionBinding::InvalidTransition
    render_invalid_binding!
  end

  def create
    apply_base_browser_continuation_headers!
    binding = load_ceremony_binding!
    BaseAuthAdmissionCoordinator.with_admission_binding_lock!(binding) do |locked_binding|
      token = validate_binding_base_context!(locked_binding)
      locked_binding.confirm_base!(
        base_token: token,
        browser_digest: base_admission_browser_digest(locked_binding.entry_ref),
      )
    end
    redirect_to(auth_binding_entry_url(binding), status: :see_other, allow_other_host: true)
  rescue BaseAuthAdmissionCoordinator::Denied, ActiveRecord::RecordNotFound, ArgumentError,
         AuthAdmissionBinding::InvalidTransition
    render_invalid_binding!
  end

  private

  def load_ceremony_binding!
    raise ArgumentError if duplicate_admission_reference?("binding_ref")

    raise ArgumentError if BaseAuthAdmissionCoordinator.client_supplied_binding_proof?(params)

    reference = params[:binding_ref]
    raise ArgumentError unless reference.is_a?(String) &&
      reference.match?(BaseAuthAdmissionCoordinator::ADMISSION_REFERENCE_PATTERN)

    BaseAuthAdmissionCoordinator.find_admission_binding_by_confirmation!(
      surface: self.class.base_admission_surface_name, reference: reference,
    )
  end

  def validate_binding_base_context!(binding)
    raise BaseAuthAdmissionCoordinator::Denied.new("binding is unavailable", code: "invalid_admission") unless
      binding.live? && base_admission_browser_nonce.present? && auth_binding_session_active?(binding)

    unless ActiveSupport::SecurityUtils.secure_compare(
      binding.base_browser_digest, base_admission_browser_digest(binding.entry_ref),
    )
      raise BaseAuthAdmissionCoordinator::Denied.new(
        "Base browser does not match binding", code: "session_binding_mismatch",
      )
    end

    token = current_session_token
    if binding.base_token_id.present?
      unless token && token.id == binding.base_token_id && token.currently_usable?(token.class.database_now)
        raise BaseAuthAdmissionCoordinator::Denied.new(
          "Base session does not match binding",
          code: "session_binding_mismatch",
        )
      end

      validate_binding_parent_actor!(binding, token)
      token
    else
      if token.present? || binding.purpose == "step_up_handoff"
        raise BaseAuthAdmissionCoordinator::Denied.new("unexpected Base session", code: "session_binding_mismatch")
      end

      validate_binding_parent_actor!(binding, nil)
      nil
    end
  end

  def validate_binding_parent_actor!(binding, token)
    case binding.parent_kind
    when :step_up_ceremony_transaction
      transaction = binding.step_up_ceremony_transaction
      actor = Actor.subject
      unless actor.is_a?(ApplicationRecord) && transaction.actor_ref == actor.public_id &&
          transaction.session_ref == token.public_id &&
          %w(pending
             verified).include?(transaction.status) && !transaction.expired?(now: transaction.class.database_now)
        raise BaseAuthAdmissionCoordinator::Denied.new(
          "Base actor does not match binding",
          code: "session_binding_mismatch",
        )
      end
    when :authorization_transaction
      transaction = binding.authorization_transaction
      now = transaction.class.database_now
      raise BaseAuthAdmissionCoordinator::Denied.new("authorization is unavailable", code: "invalid_admission") if
        transaction.expired?(now: now) || transaction.login_challenge_expired?(now: now) || transaction.consumed?
    when :sign_in_flow
      flow = binding.sign_in_flow
      raise BaseAuthAdmissionCoordinator::Denied.new("local entry is unavailable", code: "invalid_admission") unless
        flow.sign_in_primary_pending? && !flow.expired?(flow.class.database_now) && flow.principal_id.nil?
    else
      raise BaseAuthAdmissionCoordinator::Denied.new("binding parent is unavailable", code: "invalid_admission")
    end
  end

  def auth_binding_session_active?(binding)
    session = binding.auth_ceremony_session
    session.present? && session.active?(now: binding.class.database_now)
  end

  def auth_binding_entry_url(binding)
    query = { entry_ref: binding.entry_ref, ri: params[:ri] }.compact
    case self.class.base_admission_surface_name
    when "app"
      app_auth_binding_entry_url(binding, **query, host: ENV.fetch("PUBLIC_AUTH_SERVICE_URL"), protocol: "https")
    when "com"
      com_auth_binding_entry_url(binding, **query, host: ENV.fetch("PUBLIC_AUTH_CORPORATE_URL"), protocol: "https")
    when "org"
      org_auth_binding_entry_url(binding, **query, host: ENV.fetch("PUBLIC_AUTH_STAFF_URL"), protocol: "https")
    else
      raise ArgumentError, "unsupported Base surface"
    end
  end

  def app_auth_binding_entry_url(binding, **query)
    case binding.purpose
    when "authentication_handoff", "local_sign_in", "local_sign_up"
      signup_binding?(binding) ? auth_app_sign_up_url(**query) : auth_app_sign_in_url(**query)
    when "bootstrap_handoff"
      new_auth_app_verification_setup_url(**query)
    when "credential_registration_handoff"
      if binding.step_up_ceremony_transaction&.allowed_methods_array == ["totp"]
        return new_auth_app_settings_totp_url(**query)
      end

      require_passkey_registration_binding!(binding)
      new_auth_app_verification_registration_passkey_url(**query)
    when "step_up_handoff", "reauthentication_handoff", "credential_change_handoff"
      auth_app_verification_url(**query)
    else
      raise ArgumentError, "unsupported app admission purpose"
    end
  end

  def com_auth_binding_entry_url(binding, **query)
    case binding.purpose
    when "authentication_handoff", "local_sign_in", "local_sign_up"
      signup_binding?(binding) ? auth_com_sign_up_url(**query) : auth_com_sign_in_url(**query)
    when "bootstrap_handoff"
      new_auth_com_verification_setup_url(**query)
    when "credential_registration_handoff"
      require_passkey_registration_binding!(binding)
      new_auth_com_verification_registration_passkey_url(**query)
    when "step_up_handoff", "reauthentication_handoff", "credential_change_handoff"
      auth_com_verification_url(**query)
    else
      raise ArgumentError, "unsupported com admission purpose"
    end
  end

  def org_auth_binding_entry_url(binding, **query)
    case binding.purpose
    when "authentication_handoff", "local_sign_in"
      raise ArgumentError, "operator signup is unavailable" if signup_binding?(binding)

      auth_org_sign_in_url(**query)
    when "bootstrap_handoff"
      new_auth_org_verification_setup_url(**query)
    when "credential_registration_handoff"
      require_passkey_registration_binding!(binding)
      new_auth_org_verification_registration_passkey_url(**query)
    when "step_up_handoff", "reauthentication_handoff", "credential_change_handoff"
      auth_org_verification_url(**query)
    else
      raise ArgumentError, "unsupported org admission purpose"
    end
  end

  def signup_binding?(binding)
    binding.purpose == "local_sign_up" || binding.authorization_transaction&.intent == "sign_up"
  end

  def require_passkey_registration_binding!(binding)
    return if binding.step_up_ceremony_transaction&.allowed_methods_array == ["passkey"]

    raise ArgumentError, "unsupported credential registration method"
  end

  def render_invalid_binding!
    apply_base_browser_continuation_headers!
    render plain: I18n.t("errors.messages.invalid_request"), status: :bad_request,
           content_type: "text/plain"
  end
end
