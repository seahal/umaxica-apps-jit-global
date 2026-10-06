# frozen_string_literal: true

class AddRefreshDeliveryReceiptToOperatorRpSessions < ActiveRecord::Migration[8.2]
  def up
    safety_assured do
      add_column :operator_rp_sessions, :refresh_generation, :bigint, null: false, default: 0, if_not_exists: true
      add_column :operator_rp_sessions, :refresh_delivery_ciphertext, :text, if_not_exists: true
      add_column :operator_rp_sessions, :refresh_delivery_predecessor_digest, :string, if_not_exists: true
      add_column :operator_rp_sessions, :refresh_delivery_expires_at, :datetime, if_not_exists: true
    end

    unless check_constraint_exists?(:operator_rp_sessions, name: "chk_operator_rp_sessions_refresh_delivery_all_or_none")
      add_check_constraint(
        :operator_rp_sessions,
        <<~SQL.squish,
          (refresh_delivery_ciphertext IS NULL AND refresh_delivery_predecessor_digest IS NULL AND
            refresh_delivery_expires_at IS NULL) OR
          (refresh_delivery_ciphertext IS NOT NULL AND refresh_delivery_predecessor_digest IS NOT NULL AND
            refresh_delivery_expires_at IS NOT NULL)
        SQL
        name: "chk_operator_rp_sessions_refresh_delivery_all_or_none",
        validate: false,
      )
    end
  end

  def down
    remove_check_constraint :operator_rp_sessions, name: "chk_operator_rp_sessions_refresh_delivery_all_or_none"
    remove_column :operator_rp_sessions, :refresh_delivery_expires_at
    remove_column :operator_rp_sessions, :refresh_delivery_predecessor_digest
    remove_column :operator_rp_sessions, :refresh_delivery_ciphertext
    remove_column :operator_rp_sessions, :refresh_generation
  end
end
