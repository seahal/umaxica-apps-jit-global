# frozen_string_literal: true

class ValidateClientContactNonblankBindingChecks < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  public

  def up
    validate_check_constraint(:client_emails, name: "client_emails_binding_digest_nonblank")
    validate_check_constraint(:client_telephones, name: "client_telephones_binding_digest_nonblank")
  end

  def down
    # Validation retains the same write contract; reversing the preceding migration removes the checks.
  end
end
