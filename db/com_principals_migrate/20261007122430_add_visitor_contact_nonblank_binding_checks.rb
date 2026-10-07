# frozen_string_literal: true

class AddVisitorContactNonblankBindingChecks < ActiveRecord::Migration[8.2]
  public

  def change
    add_check_constraint(
      :visitor_emails,
      "binding_finalized_at IS NULL OR (address_digest IS NOT NULL AND address_digest ~ '[^[:space:]]')",
      name: "visitor_emails_binding_digest_nonblank", validate: false,
    )
    add_check_constraint(
      :visitor_telephones,
      "binding_finalized_at IS NULL OR (number_digest IS NOT NULL AND number_digest ~ '[^[:space:]]')",
      name: "visitor_telephones_binding_digest_nonblank", validate: false,
    )
  end
end
