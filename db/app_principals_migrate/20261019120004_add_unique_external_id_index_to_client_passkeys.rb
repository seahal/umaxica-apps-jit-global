# frozen_string_literal: true

# REQ-P06: one Passkey per external_id within this principal database. Built concurrently so the
# index never blocks Passkey writes; existing duplicate external_ids make this migration fail.
class AddUniqueExternalIdIndexToClientPasskeys < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def change
    add_index(:client_passkeys, :external_id, unique: true, name: "index_client_passkeys_on_external_id", algorithm: :concurrently)
  end
end
