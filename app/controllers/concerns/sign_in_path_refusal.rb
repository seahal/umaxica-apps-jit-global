# typed: false
# frozen_string_literal: true

# WU-07 (D-73, T19): one responder for Sign-in path refusals. It writes exactly one reason-coded event
# without references, tokens, codes or contact values, clears only this requester's continuity state
# for ownership/definitive refusals, and answers with the class's single response.
module SignInPathRefusal
  private

  def refuse_sign_in_path!(reason, body: nil, status: nil)
    refusal = record_sign_in_path_refusal!(reason)
    return refusal if performed?

    render plain: body || refusal_body(refusal),
           content_type: "text/plain",
           status: status || refusal_response_status(refusal)
  end

  def record_sign_in_path_refusal!(reason)
    refusal = SignInPathRefusalValue.for(reason)
    return refusal if @sign_in_path_refusal_logged

    Rails.logger.info(
      JitLogEvent.format(
        "sign.refused",
        refusal_class: refusal.refusal_class.to_s,
        reason_code: refusal.reason,
        surface: sign_in_refusal_surface,
      ),
    )
    @sign_in_path_refusal_logged = true
    clear_sign_in_path_continuity! if refusal.clears_continuity?
    refusal
  end

  def refusal_body(refusal)
    return I18n.t("errors.rate_limit.backend_unavailable") if refusal.refusal_class == :dependency

    I18n.t("errors.messages.invalid_request")
  end

  def refusal_response_status(refusal)
    return :service_unavailable if refusal.retryable?
    return :internal_server_error if refusal.refusal_class == :internal

    refusal.status
  end

  def clear_sign_in_path_continuity!
    surface = sign_in_refusal_surface.to_sym
    SignInCycleLocator.new(session, surface: surface).clear!
    SignUpSessionState.for(session, surface: surface).clear_all! if %i(app com).include?(surface)
    session.delete(SessionLimitGate::GATE_SESSION_KEY)
    session.delete(:pending_mfa)
    session.delete(:mfa_user_id)
    session.delete(:external_authentication_ceremony_reference)
    session.delete(:sign_up_email_flow_state)
    session.delete(:email_registration_transaction_ref)

    clear_social_auth_intent! if respond_to?(:clear_social_auth_intent!, true)
    cookies.delete(auth_ceremony_sid_cookie_name, path: "/") if respond_to?(:auth_ceremony_sid_cookie_name, true)
  rescue ArgumentError
    # A non-Auth caller can still use the responder for a protocol boundary; it has no
    # surface-specific continuity store to clear.
    nil
  end

  def sign_in_refusal_surface
    return auth_ceremony_surface.to_s if respond_to?(:auth_ceremony_surface, true)

    request.path.to_s.split("/").fetch(2, "unknown")
  end
end
