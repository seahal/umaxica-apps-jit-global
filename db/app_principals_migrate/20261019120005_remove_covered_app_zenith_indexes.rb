# frozen_string_literal: true

class RemoveCoveredAppZenithIndexes < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def change
    remove_index(:personas, :client_identity_id, name: "index_personas_on_client_identity_id", algorithm: :concurrently)
    remove_index(:client_oidc_identity_bindings, :client_identity_id, name: "index_client_oidc_identity_bindings_on_client_identity_id", algorithm: :concurrently)
    remove_index(:client_withdrawal_ceremonies, :client_id, name: "index_client_withdrawal_ceremonies_on_client_id", algorithm: :concurrently)
    remove_index(:client_processor_erasure_notification_attempts, :client_processor_erasure_notification_id, name: "idx_on_client_processor_erasure_notification_id_2c59431eb8", algorithm: :concurrently)
    remove_index(:client_enforcement_recovery_ceremonies, :client_id, name: "index_client_enforcement_recovery_ceremonies_on_client_id", algorithm: :concurrently)
    remove_index(:client_retention_holds, :client_id, name: "index_client_retention_holds_on_client_id", algorithm: :concurrently)
    remove_index(:client_privacy_requests, :client_id, name: "index_client_privacy_requests_on_client_id", algorithm: :concurrently)
    remove_index(:client_processor_erasure_notifications, :client_privacy_request_id, name: "idx_on_client_privacy_request_id_019e8d95c9", algorithm: :concurrently)
  end
end
