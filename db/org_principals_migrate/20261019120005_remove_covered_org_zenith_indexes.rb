# frozen_string_literal: true

class RemoveCoveredOrgZenithIndexes < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def change
    remove_index(:agents, :operator_identity_id, name: "index_agents_on_operator_identity_id", algorithm: :concurrently)
    remove_index(:operator_oidc_identity_bindings, :operator_identity_id, name: "index_operator_oidc_identity_bindings_on_operator_identity_id", algorithm: :concurrently)
  end
end
