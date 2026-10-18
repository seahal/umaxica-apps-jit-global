# frozen_string_literal: true

# Rollback requires completing or canceling verified registration ceremonies first.
class SeparateOperatorRegistrationEvidenceFromStepUpCredential < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  public

  def change
    old_evidence = "status <> 'verified' OR " \
                   "(verified_credential_ref IS NOT NULL AND length(verified_credential_ref) > 0)"
    new_evidence = "status <> 'verified' OR (" \
                   "purpose IN ('bootstrap','credential_registration') AND " \
                   "verified_credential_ref IS NULL AND aal = 'none' AND required_aal = 'none' AND " \
                   "phishing_resistant IS FALSE AND phishing_resistant_required IS FALSE AND " \
                   "method IN ('passkey','totp')) OR (" \
                   "purpose NOT IN ('bootstrap','credential_registration') AND " \
                   "verified_credential_ref IS NOT NULL AND length(verified_credential_ref) > 0)"
    remove_check_constraint(
      :operator_step_up_ceremony_transactions, old_evidence,
      name: "operator_step_up_verified_credential_present",
    )
    add_check_constraint(
      :operator_step_up_ceremony_transactions, new_evidence,
      name: "operator_step_up_verified_credential_present", validate: false,
    )
    validate_check_constraint(
      :operator_step_up_ceremony_transactions,
      name: "operator_step_up_verified_credential_present",
    )
  end
end
