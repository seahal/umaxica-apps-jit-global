# frozen_string_literal: true

class ValidateSecretOutboxAuthoritySnapshots < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def change
    validate_check_constraint :client_secret_audit_outboxes,
                              name: "client_secret_issuance_purge_authority_snapshot"
  end
end
