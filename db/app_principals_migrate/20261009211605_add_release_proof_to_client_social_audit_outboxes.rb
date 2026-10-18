# frozen_string_literal: true

class AddReleaseProofToClientSocialAuditOutboxes < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def change
    add_index(
      :client_social_audit_outboxes, %i(provider provider_subject_digest released_at),
      where: "event_name = 'unlinked'", name: "client_social_audit_release_lookup",
      algorithm: :concurrently,
    )
    add_check_constraint(
      :client_social_audit_outboxes, "provider_subject_digest ~ '^[0-9a-f]{64}$'",
      name: "client_social_audit_digest", validate: false,
    )
    release_rule = "(event_name = 'linked' AND released_at IS NULL) OR " \
                   "(event_name = 'unlinked' AND released_at IS NOT NULL)"
    add_check_constraint(
      :client_social_audit_outboxes, release_rule,
      name: "client_social_audit_release", validate: false,
    )
  end
end
