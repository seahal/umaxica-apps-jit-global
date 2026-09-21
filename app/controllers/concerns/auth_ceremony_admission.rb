# typed: false
# frozen_string_literal: true

# Redeems Base-issued opaque admission, rotates ceremony-local __Host-auth_sid,
# and refuses to start a protected ceremony without that admission.
module AuthCeremonyAdmission
  extend ActiveSupport::Concern

  include AuthCeremonySidCookie
  include AuthCeremonyContext

  private

  def admit_or_render_sign_ceremony!(expected_intent:)
    apply_admission_transport_headers!

    if logged_in? && params[:admission].blank? && !admitted_ceremony_present?(expected_intent: expected_intent)
      return handle_logged_in_direct_entry!
    end

    if params[:admission].present?
      return redeem_admission_and_redirect!(expected_intent: expected_intent)
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

  def redeem_admission_and_redirect!(expected_intent:)
    begin
      BaseAuthAdmissionCoordinator.consume_local_entry!(
        raw_code: params[:admission].to_s,
        surface: auth_ceremony_surface,
        expected_intent: expected_intent,
      )
      rotate_auth_ceremony_session!
      return redirect_to(auth_ceremony_clean_url, status: :see_other)
    rescue BaseAuthAdmissionCoordinator::Denied => e
      raise unless e.message == "local admission missing"
    end

    payload = BaseAuthAdmissionCoordinator.consume_handoff!(
      raw_code: params[:admission].to_s,
      surface: auth_ceremony_surface,
      expected_intent: expected_intent,
    )
    transaction = OidcAuthorizationTransactionCoordinator.find_by_transaction_id!(
      surface: auth_ceremony_surface,
      transaction_id: payload.fetch("subject_ref"),
    )
    if transaction.login_challenge_expired?
      raise BaseAuthAdmissionCoordinator::Denied, "authorization transaction expired"
    end

    if transaction.consumed?
      raise BaseAuthAdmissionCoordinator::Denied, "authorization transaction already consumed"
    end

    unless auth_ceremony_intent_matches?(transaction.intent, expected_intent)
      raise BaseAuthAdmissionCoordinator::Denied, "authorization transaction intent mismatch"
    end

    rotate_auth_ceremony_session!(authorization_transaction_ref: transaction.transaction_id)
    redirect_to(auth_ceremony_clean_url, status: :see_other)
  rescue BaseAuthAdmissionCoordinator::Denied, ActiveRecord::RecordNotFound, ArgumentError
    render plain: I18n.t("errors.messages.invalid_request"), status: :bad_request
  end

  def rotate_auth_ceremony_session!(authorization_transaction_ref: nil)
    model = BaseAuthAdmissionCoordinator.ceremony_session_class(auth_ceremony_surface)
    raw = read_auth_ceremony_sid_cookie
    if raw.present?
      existing = model.find_active_by_raw_sid(raw)
      existing&.revoke!
    end
    record, sid = model.issue!
    record.admit!(authorization_transaction_ref: authorization_transaction_ref)
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
    redirect_to(
      URI::Generic.build(
        scheme: request.scheme,
        host: base_authority_host,
        path: "/",
        query: params[:ri].present? ? { ri: params[:ri] }.to_query : nil,
      ).to_s,
      allow_other_host: cross_host_redirect_allowed?,
      status: :see_other,
    )
  end

  def apply_admission_transport_headers!
    response.headers["Cache-Control"] = "private, no-store"
    response.headers["Referrer-Policy"] = "no-referrer"
  end

  def auth_ceremony_clean_url
    ri = params[:ri]
    case auth_ceremony_surface
    when "app"
      expected_sign_up? ? auth_app_sign_up_path(ri: ri) : auth_app_sign_in_path(ri: ri)
    when "com"
      expected_sign_up? ? auth_com_sign_up_path(ri: ri) : auth_com_sign_in_path(ri: ri)
    else
      expected_sign_up? ? auth_org_sign_up_path(ri: ri) : auth_org_sign_in_path(ri: ri)
    end
  end

  def expected_sign_up?
    action_name == "show" && controller_path.end_with?("/sign/ups")
  end

  def auth_ceremony_intent_matches?(actual, expected)
    actual.to_s == expected.to_s ||
      (actual.to_s == "authentication" && %w(sign_in sign_up).include?(expected.to_s))
  end
end
