# frozen_string_literal: true

class AddPublicIdToOperatorTelephones < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def change
    # Existing rows require an independently controlled backfill before NOT NULL cutover.
    add_column(:operator_telephones, :public_id, :string, limit: 25)
    add_index(:operator_telephones, :public_id, unique: true, algorithm: :concurrently)
    add_check_constraint(
      :operator_telephones,
      "public_id IS NULL OR public_id !~ '^[[:space:]]*$'",
      name: "operator_telephones_public_id_nonblank", validate: false,
    )
  end
end
