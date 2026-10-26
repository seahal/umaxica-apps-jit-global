# typed: false
# frozen_string_literal: true

# Redeems Base-issued opaque admission, rotates ceremony-local __Host-auth_sid,
# and refuses to start a protected ceremony without that admission.
module AuthCeremonyAdmission
  extend ActiveSupport::Concern

  include AuthCeremonySidCookie
  include AuthCeremonyContext
  include StepUpCeremonyLogging
  include AdmissionReferenceParameters

  public

  private

  def admit_or_render_sign_ceremony!(expected_intent:)
    apply_admission_transport_headers!

    return render_invalid_admission_request! if params[:admission].present?
    return render_invalid_admission_request! if multiple_admission_references? || invalid_admission_reference_params?

    if request.get? && admission_reference_param.present?
      return render_admission_reference!(expected_intent:)
    end

    if logged_in? && admission_reference_param.blank? && !admitted_ceremony_present?(expected_intent: expected_intent)
      return render_sign_in_unavailable_while_authenticated
    end

    if ceremony_admission_present?
      if auth_ceremony_matches_intent?(expected_intent)
        @oidc_authorization_intent = auth_ceremony_authorization_transaction&.intent
        return yield
      end

      log_ticket_ceremony_entry_refusal(expected_intent)
      return render plain: I18n.t("errors.messages.invalid_request"), status: :bad_request
    end

    # Auth starts only from a Base-issued admission or a verified continuation; a context-free
    # request is refused rather than bridged to Base (adr/sign-neutral-entry-and-logout-target-authorization.md).
    log_ticket_ceremony_entry_refusal(expected_intent)
    render_invalid_admission_request!
  rescue BaseAuthAdmissionCoordinator::Denied, ActiveRecord::RecordNotFound, ArgumentError
    log_ticket_ceremony_entry_refusal(expected_intent)
    render_invalid_admission_request!
  end

  def render_admission_reference!(expected_intent:)
    binding = admission_binding_for_reference
    return render_invalid_admission_request! unless binding

    authorization_parent = AuthAdmissionBinding::PARENT_PURPOSES.fetch(:authorization_transaction)
    unless authorization_parent.include?(binding.purpose)
      BaseAuthAdmissionCoordinator.validate_admission_continuation!(
        binding:, surface: auth_ceremony_surface, expected_intent:,
      )
    end
    return redeem_admission_reference_and_redirect!(expected_intent:) if binding.attached? && binding.confirmed?

    redirect_to(
      auth_ceremony_admission_action_url(
        entry_ref: admission_reference_param,
        ri: params[:ri],
        lx: normalized_locale(params[:lx]),
      ),
      status: :see_other,
    )
  end

  # Sign-in admissions share this entry; only ticket ceremonies belong in the Step-Up log.
  def log_ticket_ceremony_entry_refusal(expected_intent)
    return unless BaseAuthAdmissionCoordinator::TICKET_CEREMONY_PURPOSES.include?(expected_intent.to_s)

    log_step_up_ceremony(
      "refused", outcome: "refused", stage: "auth_ceremony_entry", **auth_ceremony_ticket_refusal,
    )
  end

  def redeem_admission_reference_and_redirect!(expected_intent:)
    return render_invalid_admission_request! if multiple_admission_references? || invalid_admission_reference_params?

    binding = BaseAuthAdmissionCoordinator.find_admission_binding!(
      surface: auth_ceremony_surface, reference: admission_reference_param,
    )
    raw_auth_sid = read_auth_ceremony_sid_cookie
    replacement_sid =
      BaseAuthAdmissionCoordinator.with_admission_binding_lock!(binding) do |locked_binding|
        if redeemed_binding_matches_cookie?(
          locked_binding,
          raw_auth_sid,
        ) && auth_ceremony_matches_intent?(expected_intent)
          nil
        else
          _record, sid = admit_confirmed_binding!(locked_binding, raw_auth_sid:, expected_intent:)
          sid
        end
      end
    write_auth_ceremony_sid_cookie!(replacement_sid) if replacement_sid
    redirect_to(auth_ceremony_clean_url(expected_intent: expected_intent), status: :see_other)
  rescue BaseAuthAdmissionCoordinator::Denied, ActiveRecord::RecordNotFound, ArgumentError,
         AuthCeremonySession::InvalidTransition => e
    if BaseAuthAdmissionCoordinator::TICKET_CEREMONY_PURPOSES.include?(expected_intent.to_s)
      log_step_up_refusal(e, stage: "auth_admission", admission_intent: expected_intent.to_s)
    end
    render_invalid_admission_request!
  rescue Umaxica::Valkey::Unavailable, Umaxica::Valkey::OperationError
    render_admission_backend_unavailable!
  end

  def admit_confirmed_binding!(binding, raw_auth_sid:, expected_intent:)
    payload = BaseAuthAdmissionCoordinator.consume_entry_reference!(
      reference: admission_reference_param,
      surface: auth_ceremony_surface,
      expected_intent: expected_intent,
      binding: binding,
      raw_auth_sid: raw_auth_sid,
    )
    if BaseAuthAdmissionCoordinator::TICKET_CEREMONY_PURPOSES.include?(expected_intent.to_s)
      transaction = BaseAuthAdmissionCoordinator.resolve_step_up_admission!(
        payload: payload, surface: auth_ceremony_surface, expected_intent: expected_intent,
      )
      replacement = rotate_auth_ceremony_session!(
        admission_purpose: payload.fetch("purpose"),
        step_up_ceremony_transaction_ref: transaction.transaction_id,
        admission_binding: binding,
      )
      log_step_up_ceremony(
        "ceremony_accepted", transaction: transaction, outcome: "accepted", stage: "auth_admission",
                             state_before: transaction.status,
      )
      replacement
    else
      admit_oidc_payload!(payload, expected_intent: expected_intent, binding: binding)
    end
  end

  def render_admission_backend_unavailable!
    render plain: I18n.t("errors.rate_limit.backend_unavailable"), status: :service_unavailable
  end

  def redeemed_binding_matches_cookie?(binding, raw_auth_sid)
    return false unless binding.redeemed? && raw_auth_sid.present?

    model = BaseAuthAdmissionCoordinator.ceremony_session_class(auth_ceremony_surface)
    current_session = model.find_active_by_raw_sid(raw_auth_sid)
    current_session&.admitted? && current_session.id == binding.admitted_auth_ceremony_session_id
  end

  def admit_oidc_payload!(payload, expected_intent:, binding:)
    transaction = OidcAuthorizationTransactionCoordinator.find_by_transaction_id!(
      surface: auth_ceremony_surface,
      transaction_id: payload.fetch("subject_ref"),
    )
    decision_time = transaction.class.database_now
    if transaction.login_challenge_expired?(now: decision_time) || transaction.expired?(now: decision_time)
      raise BaseAuthAdmissionCoordinator::Denied.new("authorization transaction expired", code: "expired_admission")
    end

    if transaction.consumed?
      raise BaseAuthAdmissionCoordinator::Denied.new(
        "authorization transaction already consumed",
        code: "admission_replay",
      )
    end

    actual_intent =
      if binding.purpose == "authentication_handoff"
        AuthEntryIntentResolver.call(prompt: transaction.oidc_prompt, entry_intent: binding.entry_intent)
      else
        transaction.intent
      end
    unless actual_intent == expected_intent.to_s
      raise BaseAuthAdmissionCoordinator::Denied.new(
        "authorization transaction intent mismatch",
        code: "invalid_admission",
      )
    end

    rotate_auth_ceremony_session!(
      admission_purpose: payload.fetch("purpose"),
      authorization_transaction_ref: transaction.transaction_id,
      admission_binding: binding,
    )
  end

  def rotate_auth_ceremony_session!(admission_purpose:, authorization_transaction_ref: nil,
                                    step_up_ceremony_transaction_ref: nil, admission_binding:)
    model = BaseAuthAdmissionCoordinator.ceremony_session_class(auth_ceremony_surface)
    raw_sid = read_auth_ceremony_sid_cookie
    record, sid =
      admission_binding.class.connection_owner.connected_to(role: :writing) do
      admission_binding.class.transaction do
        locked_binding = admission_binding.class.lock.find(admission_binding.id)
        attached_session = model.lock.find(locked_binding.auth_ceremony_session_id)
        unless raw_sid.present? && model.find_active_by_raw_sid(raw_sid)&.id == attached_session.id
          raise AuthCeremonySession::InvalidTransition, "Auth ceremony session does not match binding"
        end

        now = model.database_now
        admitted, admitted_sid = model.rotate_and_admit!(
          admission_purpose: admission_purpose,
          previous_raw_sid: raw_sid,
          authorization_transaction_ref: authorization_transaction_ref,
          step_up_ceremony_transaction_ref: step_up_ceremony_transaction_ref,
          ttl: auth_ceremony_ttl_for_binding(admission_binding, now, model), now:,
        )
        locked_binding.redeem!(auth_session: attached_session, admitted_auth_session: admitted)
        [admitted, admitted_sid]
      end
    end
    [record, sid]
  end

  def ceremony_admission_present?
    # Ceremony cookie is continuity only and cannot start a protected flow.
    auth_ceremony_admission_present?
  end

  def auth_ceremony_ttl_for_binding(binding, now, model)
    return model::DEFAULT_TTL unless binding.purpose == "authentication_handoff"

    remaining = binding.curfew_at - now
    raise BaseAuthAdmissionCoordinator::Denied.new(
      "sign-in path curfew has passed", code: "expired_admission",
    ) unless remaining.positive?

    [model::DEFAULT_TTL, remaining].min
  end

  def admission_binding_for_reference
    BaseAuthAdmissionCoordinator.find_admission_binding!(
      surface: auth_ceremony_surface, reference: admission_reference_param,
    )
  rescue BaseAuthAdmissionCoordinator::Denied, ActiveRecord::RecordNotFound, ArgumentError
    nil
  end

  def admitted_ceremony_present?(expected_intent:)
    auth_ceremony_admission_present? && auth_ceremony_matches_intent?(expected_intent)
  end

  def apply_admission_transport_headers!
    response.headers["Cache-Control"] = "private, no-store"
    response.headers["Referrer-Policy"] = "no-referrer"
    response.headers["Content-Security-Policy"] = "frame-ancestors 'none'"
  end

  def render_invalid_admission_request!
    render plain: I18n.t("errors.messages.invalid_request"), status: :bad_request
  end

  def auth_ceremony_admission_action_url(**query)
    case auth_ceremony_surface
    when "app" then auth_app_ceremony_bindings_path(**query)
    when "com" then auth_com_ceremony_bindings_path(**query)
    when "org" then auth_org_ceremony_bindings_path(**query)
    else raise ArgumentError, "unsupported Auth ceremony surface"
    end
  end

  def admission_reference_param
    params[:entry_ref].to_s.presence
  end

  def multiple_admission_references?
    params[:transaction_ref].present?
  end

  def invalid_admission_reference_params?
    duplicate_admission_reference?("entry_ref") ||
      BaseAuthAdmissionCoordinator.client_supplied_binding_proof?(params) ||
      (params[:entry_ref].present? && !params[:entry_ref].is_a?(String))
  end

  def admission_reference_param_name
    return "entry_ref" if params[:entry_ref].to_s.present?

    raise ArgumentError, "admission reference is missing"
  end

  def auth_ceremony_clean_url(expected_intent:)
    return auth_step_up_ceremony_clean_url if BaseAuthAdmissionCoordinator::TICKET_CEREMONY_PURPOSES.include?(expected_intent.to_s)

    query = { ri: params[:ri], lx: normalized_locale(params[:lx]) }.compact
    path = (expected_intent.to_s == "sign_up") ? "sign_up" : "sign_in"
    case auth_ceremony_surface
    when "app"
      (path == "sign_up") ? auth_app_sign_up_path(**query) : auth_app_sign_in_path(**query)
    when "com"
      (path == "sign_up") ? auth_com_sign_up_path(**query) : auth_com_sign_in_path(**query)
    else
      (path == "sign_up") ? auth_org_sign_up_path(**query) : auth_org_sign_in_path(**query)
    end
  end

  def auth_step_up_ceremony_clean_url
    raise NotImplementedError, "#{self.class} must define #auth_step_up_ceremony_clean_url"
  end
end
