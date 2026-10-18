# typed: false
# frozen_string_literal: true

class ValidateAuthenticationEvidenceConstraints < ActiveRecord::Migration[8.2]
  def change
    validate_check_constraint(
      :client_auth_ceremony_sessions,
      name: "client_auth_ceremony_sessions_authentication_method",
    )
    validate_check_constraint(
      :client_auth_ceremony_sessions,
      name: "client_auth_ceremony_sessions_authentication_evidence_pair",
    )
  end
end
