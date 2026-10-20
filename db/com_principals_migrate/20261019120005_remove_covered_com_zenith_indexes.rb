# frozen_string_literal: true

class RemoveCoveredComZenithIndexes < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def change
    remove_index(:individuals, :visitor_identity_id, name: "index_individuals_on_visitor_identity_id", algorithm: :concurrently)
    remove_index(:visitor_oidc_identity_bindings, :visitor_identity_id, name: "index_visitor_oidc_identity_bindings_on_visitor_identity_id", algorithm: :concurrently)
    remove_index(:visitor_withdrawal_ceremonies, :visitor_id, name: "index_visitor_withdrawal_ceremonies_on_visitor_id", algorithm: :concurrently)
    remove_index(:visitor_processor_erasure_notification_attempts, :visitor_processor_erasure_notification_id, name: "idx_on_visitor_processor_erasure_notification_id_da29c17a62", algorithm: :concurrently)
    remove_index(:visitor_enforcement_recovery_ceremonies, :visitor_id, name: "index_visitor_enforcement_recovery_ceremonies_on_visitor_id", algorithm: :concurrently)
    remove_index(:visitor_retention_holds, :visitor_id, name: "index_visitor_retention_holds_on_visitor_id", algorithm: :concurrently)
    remove_index(:visitor_privacy_requests, :visitor_id, name: "index_visitor_privacy_requests_on_visitor_id", algorithm: :concurrently)
    remove_index(:visitor_processor_erasure_notifications, :visitor_privacy_request_id, name: "idx_on_visitor_privacy_request_id_4225260194", algorithm: :concurrently)
  end
end
