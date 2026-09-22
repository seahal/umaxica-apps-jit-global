# typed: false
# frozen_string_literal: true

# Keeps the Auth -> Base OIDC result out of URLs. The GET action only renders a
# same-origin CSRF-protected continuation form; the POST action issues the
# short-lived transaction-bound result and renders the cross-surface form that
# posts it to Base.
module AuthOidcResultHandoff
  extend ActiveSupport::Concern

  public

  def show
    return reject_oidc_result_handoff! if oidc_authorization_login_challenge.blank?

    render(
      "auth/shared/oidc_authorization_handoff",
      layout: oidc_result_handoff_layout,
      locals: {
        completion_url: public_send(oidc_result_handoff_create_helper, ri: params[:ri]),
        ri: params[:ri],
      },
    )
  end

  def create
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

    render "auth/shared/oidc_authorization_result",
           layout: oidc_result_handoff_layout,
           locals: {
             completion_url: public_send(
               oidc_result_base_completion_helper,
               host: base_authority_host,
               protocol: "https",
             ),
             result_token: issuance.code,
             transaction_ref: issuance.transaction.transaction_id,
             ri: params[:ri],
           }
  rescue BaseAuthAdmissionCoordinator::Denied, ActiveRecord::RecordNotFound,
         AuthCeremonySession::InvalidTransition, ArgumentError, KeyError
    reject_oidc_result_handoff!
  end

  private

  def reject_oidc_result_handoff!
    render plain: I18n.t("errors.messages.invalid_request"), status: :bad_request
  end

  def oidc_result_handoff_layout
    "auth/#{oidc_result_handoff_surface}/application"
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

  def oidc_result_handoff_create_helper
    raise NotImplementedError, "#{self.class} must define #oidc_result_handoff_create_helper"
  end

  def oidc_result_base_completion_helper
    raise NotImplementedError, "#{self.class} must define #oidc_result_base_completion_helper"
  end
end
