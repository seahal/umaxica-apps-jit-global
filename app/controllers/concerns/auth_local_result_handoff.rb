# frozen_string_literal: true

# Concrete controllers provide the local handoff path, Base completion URL and layout. They
# authenticate the admitted flow's actor and authorize its issuance policy before these actions.
module AuthLocalResultHandoff
  public

  def show
    render(
      "auth/shared/oidc_authorization_handoff", layout: local_result_layout,
                                                locals: { completion_url: local_result_create_path, ri: params[:ri] },
    )
  end

  def create
    flow = auth_ceremony_local_sign_in_flow
    ceremony = admitted_auth_ceremony_session
    unless flow && ceremony&.authentication_evidence_recorded?
      return reject_invalid_sign_in_sequence!
    end

    code = LocalAuthenticationResultCoordinator.issue!(flow: flow, ceremony_session_ref: ceremony.id.to_s)
    render "auth/shared/oidc_authorization_result", layout: local_result_layout,
                                                    locals: { completion_url: local_result_completion_url,
                                                              result_token: code,
                                                              transaction_ref: flow.public_id,
                                                              ri: params[:ri], }
  rescue AuthCeremonySession::InvalidTransition, BaseAuthAdmissionCoordinator::Denied
    reject_invalid_sign_in_sequence!
  rescue Umaxica::Valkey::Unavailable, Umaxica::Valkey::OperationError
    render plain: I18n.t("errors.rate_limit.backend_unavailable"), status: :service_unavailable
  end
end
