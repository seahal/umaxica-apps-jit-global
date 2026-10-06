# typed: false
# frozen_string_literal: true

# Base-side receiver for the Auth attachment handoff. GET is a representation
# only; the CSRF-protected POST is the sole operation that records
# base_confirmed_at and returns the browser to Auth.
module BaseCeremonyBindingConfirmation
  extend ActiveSupport::Concern

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
    token = validate_binding_base_context!(binding)
    binding.confirm_base!(
      base_token: token,
      browser_digest: base_admission_browser_digest(binding.entry_ref),
    )
    redirect_to(auth_binding_entry_url(binding), status: :see_other, allow_other_host: true)
  rescue BaseAuthAdmissionCoordinator::Denied, ActiveRecord::RecordNotFound, ArgumentError,
         AuthAdmissionBinding::InvalidTransition
    render_invalid_binding!
  end

  private

  def load_ceremony_binding!
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

      nil
    end
  end

  def validate_binding_parent_actor!(binding, token)
    case binding.parent_kind
    when :step_up_ceremony_transaction
      transaction = binding.step_up_ceremony_transaction
      actor = Actor.subject
      unless actor.respond_to?(:public_id) && transaction.actor_ref == actor.public_id &&
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
      raise BaseAuthAdmissionCoordinator::Denied.new("authorization is unavailable", code: "invalid_admission") if
        transaction.expired?(now: transaction.class.database_now)
    when :sign_in_flow
      raise BaseAuthAdmissionCoordinator::Denied.new("local entry is unavailable", code: "invalid_admission") unless
        binding.sign_in_flow.sign_in_primary_pending?
    else
      raise BaseAuthAdmissionCoordinator::Denied.new("binding parent is unavailable", code: "invalid_admission")
    end
  end

  def auth_binding_session_active?(binding)
    session = binding.auth_ceremony_session
    session.present? && session.active?(now: binding.class.database_now) && !session.admitted?
  end

  def auth_binding_entry_url(binding)
    query = { entry_ref: binding.entry_ref, ri: params[:ri] }.compact
    case self.class.base_admission_surface_name
    when "app"
      auth_host_url = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
      case binding.purpose
      when "authentication_handoff", "local_sign_in", "local_sign_up"
        intent = binding.authorization_transaction&.intent.to_s
        path_helper = (intent == "sign_up" || binding.purpose == "local_sign_up") ? :auth_app_sign_up_url : :auth_app_sign_in_url
      when "bootstrap_handoff"
        path_helper = :new_auth_app_verification_setup_url
      when "credential_registration_handoff"
        unless binding.step_up_ceremony_transaction&.allowed_methods_array == ["passkey"]
          raise ArgumentError, "unsupported credential registration method"
        end

        path_helper = :new_auth_app_verification_registration_passkey_url
      else
        path_helper = :auth_app_verification_url
      end
      public_send(path_helper, **query, host: auth_host_url, protocol: "https")
    when "com"
      auth_host_url = ENV.fetch("PUBLIC_AUTH_CORPORATE_URL")
      path_helper =
        %w(authentication_handoff local_sign_in local_sign_up).include?(binding.purpose) ?
               ((binding.purpose == "local_sign_up") ? :auth_com_sign_up_url : :auth_com_sign_in_url) : :auth_com_verification_url
      if binding.purpose == "credential_registration_handoff"
        unless binding.step_up_ceremony_transaction&.allowed_methods_array == ["passkey"]
          raise ArgumentError, "unsupported credential registration method"
        end

        path_helper = :new_auth_com_verification_registration_passkey_url
      end
      public_send(path_helper, **query, host: auth_host_url, protocol: "https")
    when "org"
      auth_host_url = ENV.fetch("PUBLIC_AUTH_STAFF_URL")
      path_helper =
        %w(authentication_handoff local_sign_in local_sign_up).include?(binding.purpose) ?
               ((binding.purpose == "local_sign_up") ? :auth_org_sign_up_url : :auth_org_sign_in_url) : :auth_org_verification_url
      if binding.purpose == "credential_registration_handoff"
        unless binding.step_up_ceremony_transaction&.allowed_methods_array == ["passkey"]
          raise ArgumentError, "unsupported credential registration method"
        end

        path_helper = :new_auth_org_verification_registration_passkey_url
      end
      public_send(path_helper, **query, host: auth_host_url, protocol: "https")
    else
      raise ArgumentError, "unsupported Base surface"
    end
  end

  def render_invalid_binding!
    apply_base_browser_continuation_headers!
    render plain: I18n.t("errors.messages.invalid_request"), status: :bad_request,
           content_type: "text/plain"
  end
end
