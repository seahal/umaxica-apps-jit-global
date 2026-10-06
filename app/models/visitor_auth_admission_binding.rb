# typed: false
# frozen_string_literal: true

class VisitorAuthAdmissionBinding < ComTicketRecord
  include AuthAdmissionBinding

  configure_auth_admission_binding(
    surface: "com",
    sign_in_flow: VisitorSignInFlow,
    authorization_transaction: VisitorOidcAuthorizationTransaction,
    step_up_ceremony_transaction: VisitorStepUpCeremonyTransaction,
    base_token: VisitorToken,
    auth_session: VisitorAuthCeremonySession,
  )

  belongs_to :sign_in_flow, class_name: "VisitorSignInFlow", optional: true
  belongs_to :authorization_transaction, class_name: "VisitorOidcAuthorizationTransaction", optional: true
  belongs_to :step_up_ceremony_transaction, class_name: "VisitorStepUpCeremonyTransaction", optional: true
  belongs_to :base_token, class_name: "VisitorToken", optional: true
  belongs_to :auth_ceremony_session, class_name: "VisitorAuthCeremonySession", optional: true
  belongs_to :admitted_auth_ceremony_session, class_name: "VisitorAuthCeremonySession", optional: true
end
