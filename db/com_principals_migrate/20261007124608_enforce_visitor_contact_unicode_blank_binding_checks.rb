# frozen_string_literal: true

class EnforceVisitorContactUnicodeBlankBindingChecks < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  public

  def up
    # PostgreSQL POSIX space depends on database locale and omits NBSP in the current fleet.
    # Explicit Unicode White_Space additions keep this check aligned with application blank values.
    add_check_constraint(
      :visitor_emails,
      "binding_finalized_at IS NULL OR (address_digest IS NOT NULL AND " \
      "address_digest ~ '[^[:space:]\u0085\u00a0\u1680\u2000-\u200a\u2028\u2029\u202f\u205f\u3000]')",
      name: "visitor_emails_binding_digest_unicode_nonblank", validate: false,
    )
    add_check_constraint(
      :visitor_telephones,
      "binding_finalized_at IS NULL OR (number_digest IS NOT NULL AND " \
      "number_digest ~ '[^[:space:]\u0085\u00a0\u1680\u2000-\u200a\u2028\u2029\u202f\u205f\u3000]')",
      name: "visitor_telephones_binding_digest_unicode_nonblank", validate: false,
    )
    validate_check_constraint(:visitor_emails, name: "visitor_emails_binding_digest_unicode_nonblank")
    validate_check_constraint(:visitor_telephones, name: "visitor_telephones_binding_digest_unicode_nonblank")
  end

  def down
    remove_check_constraint(:visitor_telephones, name: "visitor_telephones_binding_digest_unicode_nonblank")
    remove_check_constraint(:visitor_emails, name: "visitor_emails_binding_digest_unicode_nonblank")
  end
end
