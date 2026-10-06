# typed: false
# frozen_string_literal: true

class OperatorAuthAdmissionBinding < OrgTicketRecord
  include AuthAdmissionBinding

  configure_auth_admission_binding(
    surface: "org",
    sign_in_flow: OperatorSignInFlow,
    authorization_transaction: OperatorOidcAuthorizationTransaction,
    step_up_ceremony_transaction: OperatorStepUpCeremonyTransaction,
    base_token: OperatorToken,
    auth_session: OperatorAuthCeremonySession,
  )

  belongs_to :sign_in_flow, class_name: "OperatorSignInFlow", optional: true
  belongs_to :authorization_transaction, class_name: "OperatorOidcAuthorizationTransaction", optional: true
  belongs_to :step_up_ceremony_transaction, class_name: "OperatorStepUpCeremonyTransaction", optional: true
  belongs_to :base_token, class_name: "OperatorToken", optional: true
  belongs_to :auth_ceremony_session, class_name: "OperatorAuthCeremonySession", optional: true
  belongs_to :admitted_auth_ceremony_session, class_name: "OperatorAuthCeremonySession", optional: true
end
