# frozen_string_literal: true

class RemoveRedundantOrgTicketIndexes < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def up
    remove_index(:operator_oidc_connections, name: "index_operator_oidc_connections_on_staff_id", algorithm: :concurrently) if
      index_exists?(:operator_oidc_connections, name: "index_operator_oidc_connections_on_staff_id")
  end

  def down
    add_index(:operator_oidc_connections, :staff_id, name: "index_operator_oidc_connections_on_staff_id", algorithm: :concurrently) unless
      index_exists?(:operator_oidc_connections, name: "index_operator_oidc_connections_on_staff_id")
  end
end
