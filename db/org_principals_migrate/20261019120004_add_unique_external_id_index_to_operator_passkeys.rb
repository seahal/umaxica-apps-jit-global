# frozen_string_literal: true

# REQ-P06: one Passkey per external_id within this principal database. Built concurrently so the
# index never blocks Passkey writes; existing duplicate external_ids make this migration fail. The
# unique index replaces the plain lookup index on the same column.
class AddUniqueExternalIdIndexToOperatorPasskeys < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def change
    add_index(
      :operator_passkeys, :external_id,
      unique: true, name: "index_operator_passkeys_on_external_id_unique", algorithm: :concurrently,
    )
    remove_index(
      :operator_passkeys, :external_id,
      name: "index_operator_passkeys_on_external_id", algorithm: :concurrently,
    )
  end
end
