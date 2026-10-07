# frozen_string_literal: true

class AddClientContactNonblankBindingChecks < ActiveRecord::Migration[8.2]
  public

  def change
    add_check_constraint(
      :client_emails,
      "binding_finalized_at IS NULL OR (address_digest IS NOT NULL AND address_digest ~ '[^[:space:]]')",
      name: "client_emails_binding_digest_nonblank", validate: false,
    )
    add_check_constraint(
      :client_telephones,
      "binding_finalized_at IS NULL OR (number_digest IS NOT NULL AND number_digest ~ '[^[:space:]]')",
      name: "client_telephones_binding_digest_nonblank", validate: false,
    )
  end
end
