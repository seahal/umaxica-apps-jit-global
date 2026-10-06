# frozen_string_literal: true

class AddSecretOutboxAuthoritySnapshots < ActiveRecord::Migration[8.2]
  def change
    add_column :client_secret_audit_outboxes, :issuance_origin, :string
    add_column :client_secret_audit_outboxes, :issuance_browser_session_ref, :string
    add_column :client_secret_audit_outboxes, :issuance_sign_up_flow_ref, :string
    add_check_constraint :client_secret_audit_outboxes,
                         "event_name <> 'secret.issuance_purged' OR " \
                         "((issuance_origin IS NULL AND issuance_browser_session_ref IS NULL AND " \
                         "issuance_sign_up_flow_ref IS NULL) OR " \
                         "(issuance_origin IN ('manual', 'passkey_registration') AND " \
                         "((issuance_browser_session_ref IS NULL) <> (issuance_sign_up_flow_ref IS NULL))))",
                         name: "client_secret_issuance_purge_authority_snapshot", validate: false
  end
end
