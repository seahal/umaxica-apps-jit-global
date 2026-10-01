# typed: false
# frozen_string_literal: true

# Redeems Base-issued opaque admission, rotates ceremony-local __Host-auth_sid,
# and refuses to start a protected ceremony without that admission.
module AuthCeremonyAdmission
  extend ActiveSupport::Concern

  include AuthCeremonySidCookie
  include AuthCeremonyContext

  public

  def create
    apply_admission_transport_headers!
    redeem_admission_reference_and_redirect!(expected_intent: auth_ceremony_entry_intent)
  end

  private

  def admit_or_render_sign_ceremony!(expected_intent:)
    apply_admission_transport_headers!

    return render_invalid_admission_request! if params[:admission].present?
    return render_invalid_admission_request! if multiple_admission_references?
    if request.get? && admission_reference_param.present?
      return render_admission_continuation!
    end

    if logged_in? && admission_reference_param.blank? && !admitted_ceremony_present?(expected_intent: expected_intent)
      return handle_logged_in_direct_entry!
    end

    if ceremony_admission_present?
      if auth_ceremony_matches_intent?(expected_intent)
        @oidc_authorization_intent = auth_ceremony_authorization_transaction&.intent
        return yield
      end

      return render plain: I18n.t("errors.messages.invalid_request"), status: :bad_request
    end

    bridge_to_base_admission!
  end

  def redeem_admission_reference_and_redirect!(expected_intent:)
    return render_invalid_admission_request! if multiple_admission_references?

    payload = BaseAuthAdmissionCoordinator.consume_entry_reference!(
      reference: admission_reference_param,
      surface: auth_ceremony_surface,
      expected_intent: expected_intent,
    )
    if BaseAuthAdmissionCoordinator.local_entry_purpose?(payload: payload, intent: expected_intent)
      rotate_auth_ceremony_session!
      return redirect_to(auth_ceremony_clean_url(expected_intent: expected_intent), status: :see_other)
    end

    transaction = OidcAuthorizationTransactionCoordinator.find_by_transaction_id!(
      surface: auth_ceremony_surface,
      transaction_id: payload.fetch("subject_ref"),
    )
    decision_time = transaction.class.database_now
    if transaction.login_challenge_expired?(now: decision_time) || transaction.expired?(now: decision_time)
      raise BaseAuthAdmissionCoordinator::Denied, "authorization transaction expired"
    end

    if transaction.consumed?
      raise BaseAuthAdmissionCoordinator::Denied, "authorization transaction already consumed"
    end

    unless auth_ceremony_intent_matches?(transaction.intent, expected_intent)
      raise BaseAuthAdmissionCoordinator::Denied, "authorization transaction intent mismatch"
    end

    rotate_auth_ceremony_session!(authorization_transaction_ref: transaction.transaction_id)
    redirect_to(auth_ceremony_clean_url(expected_intent: expected_intent), status: :see_other)
  rescue BaseAuthAdmissionCoordinator::Denied, ActiveRecord::RecordNotFound, ArgumentError,
         AuthCeremonySession::InvalidTransition
    render_invalid_admission_request!
  end

  def rotate_auth_ceremony_session!(authorization_transaction_ref: nil)
    model = BaseAuthAdmissionCoordinator.ceremony_session_class(auth_ceremony_surface)
    record, sid = model.rotate_and_admit!(
      previous_raw_sid: read_auth_ceremony_sid_cookie,
      authorization_transaction_ref: authorization_transaction_ref,
    )
    write_auth_ceremony_sid_cookie!(sid)
    record
  end

  def ceremony_admission_present?
    # Ceremony cookie is continuity only and cannot start a protected flow.
    auth_ceremony_admission_present?
  end

  def admitted_ceremony_present?(expected_intent:)
    auth_ceremony_admission_present? && auth_ceremony_matches_intent?(expected_intent)
  end

  def bridge_to_base_admission!
    redirect_to_jump_url(
      URI::Generic.build(
        scheme: "https",
        host: base_authority_host,
        path: "/",
        query: params[:ri].present? ? { ri: params[:ri] }.to_query : nil,
      ).to_s,
      status: :see_other,
    )
  end

  def apply_admission_transport_headers!
    response.headers["Cache-Control"] = "private, no-store"
    response.headers["Referrer-Policy"] = "no-referrer"
  end

  def render_admission_continuation!
    render "auth/shared/admission_continuation",
           layout: false,
           locals: {
             action_url: request.path,
             reference_param: admission_reference_param_name,
             reference: admission_reference_param,
             ri: params[:ri],
             pt: params[:pt],
           }
  end

  def render_invalid_admission_request!
    render plain: I18n.t("errors.messages.invalid_request"), status: :bad_request
  end

  def admission_reference_param
    refs = {
      "transaction_ref" => params[:transaction_ref].to_s.presence,
      "entry_ref" => params[:entry_ref].to_s.presence,
    }.compact
    refs.values.first
  end

  def multiple_admission_references?
    params[:transaction_ref].to_s.present? && params[:entry_ref].to_s.present?
  end

  def admission_reference_param_name
    return "transaction_ref" if params[:transaction_ref].to_s.present?
    return "entry_ref" if params[:entry_ref].to_s.present?

    raise ArgumentError, "admission reference is missing"
  end

  def auth_ceremony_clean_url(expected_intent:)
    ri = params[:ri]
    path = (expected_intent.to_s == "sign_up") ? "sign_up" : "sign_in"
    case auth_ceremony_surface
    when "app"
      (path == "sign_up") ? auth_app_sign_up_path(ri: ri) : auth_app_sign_in_path(ri: ri)
    when "com"
      (path == "sign_up") ? auth_com_sign_up_path(ri: ri) : auth_com_sign_in_path(ri: ri)
    else
      (path == "sign_up") ? auth_org_sign_up_path(ri: ri) : auth_org_sign_in_path(ri: ri)
    end
  end

  def auth_ceremony_intent_matches?(actual, expected)
    actual.to_s == expected.to_s ||
      (actual.to_s == "authentication" && %w(sign_in sign_up).include?(expected.to_s))
  end
end
