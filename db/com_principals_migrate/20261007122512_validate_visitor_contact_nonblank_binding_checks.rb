# frozen_string_literal: true

class ValidateVisitorContactNonblankBindingChecks < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  public

  def up
    validate_check_constraint(:visitor_emails, name: "visitor_emails_binding_digest_nonblank")
    validate_check_constraint(:visitor_telephones, name: "visitor_telephones_binding_digest_nonblank")
  end

  def down
    # Validation retains the same write contract; reversing the preceding migration removes the checks.
  end
end
