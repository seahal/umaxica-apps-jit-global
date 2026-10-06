# typed: false
# frozen_string_literal: true

class ClientAuthAdmissionBinding < AppTicketRecord
  include AuthAdmissionBinding

  configure_auth_admission_binding(
    surface: "app",
    sign_in_flow: ClientSignInFlow,
    authorization_transaction: ClientOidcAuthorizationTransaction,
    step_up_ceremony_transaction: ClientStepUpCeremonyTransaction,
    base_token: ClientToken,
    auth_session: ClientAuthCeremonySession,
  )

  belongs_to :sign_in_flow, class_name: "ClientSignInFlow", optional: true
  belongs_to :authorization_transaction, class_name: "ClientOidcAuthorizationTransaction", optional: true
  belongs_to :step_up_ceremony_transaction, class_name: "ClientStepUpCeremonyTransaction", optional: true
  belongs_to :base_token, class_name: "ClientToken", optional: true
  belongs_to :auth_ceremony_session, class_name: "ClientAuthCeremonySession", optional: true
  belongs_to :admitted_auth_ceremony_session, class_name: "ClientAuthCeremonySession", optional: true
end
