# frozen_string_literal: true

class RemoveRedundantAppTicketIndexes < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def up
    remove_index(:client_oidc_connections, name: "index_client_oidc_connections_on_user_id", algorithm: :concurrently) if
      index_exists?(:client_oidc_connections, name: "index_client_oidc_connections_on_user_id")
    remove_index(:client_sign_up_flows, name: "index_client_sign_up_flows_on_status_id", algorithm: :concurrently) if
      index_exists?(:client_sign_up_flows, name: "index_client_sign_up_flows_on_status_id")
  end

  def down
    add_index(:client_oidc_connections, :user_id, name: "index_client_oidc_connections_on_user_id", algorithm: :concurrently) unless
      index_exists?(:client_oidc_connections, name: "index_client_oidc_connections_on_user_id")
    add_index(:client_sign_up_flows, :status_id, name: "index_client_sign_up_flows_on_status_id", algorithm: :concurrently) unless
      index_exists?(:client_sign_up_flows, name: "index_client_sign_up_flows_on_status_id")
  end
end
