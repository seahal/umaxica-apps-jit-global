# typed: false
# frozen_string_literal: true

# Redeems Base-issued opaque admission, rotates ceremony-local __Host-auth_sid,
# and refuses to start a protected ceremony without that admission.
module AuthCeremonyAdmission
  extend ActiveSupport::Concern

  include AuthCeremonySidCookie

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
      stored = session[:oidc_authorization_intent].to_s
      local_intent = session[:auth_ceremony_admitted_intent].to_s
      if (stored.blank? || stored == expected_intent) && (local_intent.blank? || local_intent == expected_intent)
        @oidc_authorization_intent = session[:oidc_authorization_intent]
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
      session[:auth_ceremony_admitted_intent] = expected_intent
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

    unless transaction.intent == expected_intent
      raise BaseAuthAdmissionCoordinator::Denied, "authorization transaction intent mismatch"
    end

    rotate_auth_ceremony_session!
    session.delete(:auth_ceremony_admitted_intent)
    session[:oidc_authorization_login_challenge] = transaction.login_challenge
    session[:oidc_authorization_intent] = transaction.intent
    redirect_to(auth_ceremony_clean_url, status: :see_other)
  rescue BaseAuthAdmissionCoordinator::Denied, ActiveRecord::RecordNotFound, ArgumentError
    render plain: I18n.t("errors.messages.invalid_request"), status: :bad_request
  end

  def rotate_auth_ceremony_session!
    model = BaseAuthAdmissionCoordinator.ceremony_session_class(auth_ceremony_surface)
    raw = read_auth_ceremony_sid_cookie
    if raw.present?
      existing = model.find_active_by_raw_sid(raw)
      existing&.revoke!
    end
    _record, sid = model.issue!
    write_auth_ceremony_sid_cookie!(sid)
  end

  def ceremony_admission_present?
    # Ceremony cookie is continuity only and cannot start a protected flow.
    session[:oidc_authorization_login_challenge].present? || session[:auth_ceremony_admitted_intent].present?
  end

  def admitted_ceremony_present?(expected_intent:)
    session[:oidc_authorization_login_challenge].present? ||
      session[:auth_ceremony_admitted_intent].to_s == expected_intent.to_s
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

  def auth_ceremony_surface
    case self.class.name
    when /::App::/ then "app"
    when /::Com::/ then "com"
    when /::Org::/ then "org"
    else
      raise ArgumentError, "unsupported auth ceremony surface"
    end
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
end
