# typed: false
# frozen_string_literal: true

# Keeps the Auth -> Visa OIDC result out of URLs. The GET action is a Design D
# continuation: it issues the short-lived transaction-bound result and redirects
# the browser to Visa's dedicated result resource.
module AuthOidcResultHandoff
  extend ActiveSupport::Concern

  include FrameDenyingContentSecurityPolicy
  include BrowserNavigationRequest

  public

  def show
    apply_oidc_result_handoff_headers!
    return reject_oidc_result_handoff!("not_navigation") unless browser_navigation_request?

    complete_oidc_result_handoff!
  rescue BaseAuthAdmissionCoordinator::Denied, ActiveRecord::RecordNotFound,
         AuthCeremonySession::InvalidTransition, ArgumentError, KeyError => e
    reject_oidc_result_handoff!("raised", error: e)
  end

  private

  def complete_oidc_result_handoff!
    challenge = oidc_authorization_login_challenge
    return reject_oidc_result_handoff!("login_challenge_missing") if challenge.blank?

    evidence = oidc_result_authentication_evidence
    return reject_oidc_result_handoff!("evidence_missing") if evidence.nil?
    return reject_oidc_result_handoff!("actor_missing") if current_resource.nil?

    issuance = BaseAuthAdmissionCoordinator.register_result_and_issue!(
      surface: oidc_result_handoff_surface,
      login_challenge: challenge,
      actor: current_resource,
      session_ref: nil,
      auth_method: evidence.fetch(:auth_method),
      acr: nil,
      authentication_event_at: evidence.fetch(:authentication_event_at),
    )
    complete_auth_ceremony_session!

    redirect_to(
      oidc_result_base_completion_url(
        result_ref: issuance.reference,
        transaction_ref: issuance.transaction.transaction_id,
        ri: params[:ri],
        host: visa_authority_host,
        protocol: "https",
      ), allow_other_host: true, status: :see_other,
    )
  end

  def apply_oidc_result_handoff_headers!
    response.headers["Cache-Control"] = "private, no-store"
    response.headers["Referrer-Policy"] = "no-referrer"
    deny_framing!
  end

  # `check` names the failed condition for the log only; people see the same refusal for all.
  def reject_oidc_result_handoff!(check = "cycle_not_ready", error: nil)
    Rails.logger.info(
      JitLogEvent.format(
        "auth.oidc_result_handoff.refused",
        surface: oidc_result_handoff_surface,
        check: check,
        error_class: error&.class&.name,
        denied_code: error.respond_to?(:code) ? error.code : nil,
        request_method: request.request_method,
        sec_fetch_mode: request.headers["Sec-Fetch-Mode"],
        sec_fetch_dest: request.headers["Sec-Fetch-Dest"],
        sec_fetch_site: request.headers["Sec-Fetch-Site"],
        sec_purpose: request.headers["Sec-Purpose"],
      ),
    )
    render plain: I18n.t("errors.messages.invalid_request"), status: :bad_request
  end

  def oidc_result_authentication_evidence
    ceremony = current_auth_ceremony_session
    return unless ceremony&.authentication_evidence_recorded?

    method = ceremony.authentication_method.to_s
    amr = AuthenticationBase::ESTABLISHED_AUTHENTICATION_METHOD_AMR_MAP.fetch(method)
    event_at = ceremony.authentication_event_at
    return if event_at.blank?

    { auth_method: amr.first, authentication_event_at: event_at }
  rescue KeyError
    nil
  end

  def oidc_result_handoff_surface
    raise NotImplementedError, "#{self.class} must define #oidc_result_handoff_surface"
  end

  def oidc_result_base_completion_url(**)
    raise NotImplementedError, "#{self.class} must define #oidc_result_base_completion_url"
  end
end
