# typed: false
# frozen_string_literal: true

# Keeps the Auth -> Visa OIDC result out of URLs. The GET action is a Design D
# continuation: it issues the short-lived transaction-bound result and redirects
# the browser to Visa's dedicated result resource.
module AuthOidcResultHandoff
  extend ActiveSupport::Concern

  public

  def show
    apply_oidc_result_handoff_headers!
    return reject_oidc_result_handoff! unless oidc_continuation_navigation_request?

    complete_oidc_result_handoff!
  rescue BaseAuthAdmissionCoordinator::Denied, ActiveRecord::RecordNotFound,
         AuthCeremonySession::InvalidTransition, ArgumentError, KeyError
    reject_oidc_result_handoff!
  end

  private

  def complete_oidc_result_handoff!
    challenge = oidc_authorization_login_challenge
    return reject_oidc_result_handoff! if challenge.blank?

    evidence = oidc_result_authentication_evidence
    return reject_oidc_result_handoff! if evidence.nil? || current_resource.nil?

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
    response.headers["Content-Security-Policy"] = "frame-ancestors 'none'"
  end

  def oidc_continuation_navigation_request?
    request.get? && !request.head? &&
      request.headers["Sec-Fetch-Mode"].to_s == "navigate" &&
      request.headers["Sec-Fetch-Dest"].to_s == "document"
  end

  def reject_oidc_result_handoff!
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
