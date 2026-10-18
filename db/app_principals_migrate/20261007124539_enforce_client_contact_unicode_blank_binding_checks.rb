# frozen_string_literal: true

class EnforceClientContactUnicodeBlankBindingChecks < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  public

  def up
    # PostgreSQL POSIX space depends on database locale and omits NBSP in the current fleet.
    # Explicit Unicode White_Space additions keep this check aligned with application blank values.
    add_check_constraint(
      :client_emails,
      "binding_finalized_at IS NULL OR (address_digest IS NOT NULL AND " \
      "address_digest ~ '[^[:space:]\u0085\u00a0\u1680\u2000-\u200a\u2028\u2029\u202f\u205f\u3000]')",
      name: "client_emails_binding_digest_unicode_nonblank", validate: false,
    )
    add_check_constraint(
      :client_telephones,
      "binding_finalized_at IS NULL OR (number_digest IS NOT NULL AND " \
      "number_digest ~ '[^[:space:]\u0085\u00a0\u1680\u2000-\u200a\u2028\u2029\u202f\u205f\u3000]')",
      name: "client_telephones_binding_digest_unicode_nonblank", validate: false,
    )
    validate_check_constraint(:client_emails, name: "client_emails_binding_digest_unicode_nonblank")
    validate_check_constraint(:client_telephones, name: "client_telephones_binding_digest_unicode_nonblank")
  end

  def down
    remove_check_constraint(:client_telephones, name: "client_telephones_binding_digest_unicode_nonblank")
    remove_check_constraint(:client_emails, name: "client_emails_binding_digest_unicode_nonblank")
  end
end
