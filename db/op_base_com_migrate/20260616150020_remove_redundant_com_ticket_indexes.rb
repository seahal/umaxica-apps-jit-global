# frozen_string_literal: true

class RemoveRedundantComTicketIndexes < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def up
    remove_index(:visitor_oidc_connections, name: "index_visitor_oidc_connections_on_visitor_id", algorithm: :concurrently) if
      index_exists?(:visitor_oidc_connections, name: "index_visitor_oidc_connections_on_visitor_id")
    remove_index(:visitor_sign_up_flows, name: "index_visitor_sign_up_flows_on_status_id", algorithm: :concurrently) if
      index_exists?(:visitor_sign_up_flows, name: "index_visitor_sign_up_flows_on_status_id")
  end

  def down
    add_index(:visitor_oidc_connections, :visitor_id, name: "index_visitor_oidc_connections_on_visitor_id", algorithm: :concurrently) unless
      index_exists?(:visitor_oidc_connections, name: "index_visitor_oidc_connections_on_visitor_id")
    add_index(:visitor_sign_up_flows, :status_id, name: "index_visitor_sign_up_flows_on_status_id", algorithm: :concurrently) unless
      index_exists?(:visitor_sign_up_flows, name: "index_visitor_sign_up_flows_on_status_id")
  end
end
