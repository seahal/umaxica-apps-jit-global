# typed: false
# frozen_string_literal: true

# Keeps the Auth -> Base OIDC result out of URLs. The GET action only renders a
# same-origin CSRF-protected continuation form; the POST action issues the
# one-shot result and renders the cross-surface form that posts it to Base.
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

    issuance = BaseAuthAdmissionCoordinator.register_result_and_issue!(
      surface: oidc_result_handoff_surface,
      login_challenge: challenge,
      actor: current_resource,
      session_ref: current_session_public_id,
      auth_method: Array(Actor.authn.access_claims&.dig("amr")).first || "unknown",
      acr: Actor.authn.access_claims&.dig("acr"),
      authentication_event_at: current_authentication_event_at,
    )
    complete_auth_ceremony_session!

    render "auth/shared/oidc_authorization_result",
           layout: oidc_result_handoff_layout,
           locals: {
             completion_url: public_send(
               oidc_result_base_completion_helper,
               host: oidc_base_authority_host,
               protocol: "https",
             ),
             result_token: issuance.code,
             ri: params[:ri],
           }
  rescue BaseAuthAdmissionCoordinator::Denied, ActiveRecord::RecordNotFound, ArgumentError
    reject_oidc_result_handoff!
  end

  private

  def reject_oidc_result_handoff!
    render plain: I18n.t("errors.messages.invalid_request"), status: :bad_request
  end

  def oidc_result_handoff_layout
    "auth/#{oidc_result_handoff_surface}/application"
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
