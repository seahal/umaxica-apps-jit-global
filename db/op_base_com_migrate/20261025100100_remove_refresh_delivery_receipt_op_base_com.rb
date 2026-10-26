# frozen_string_literal: true

# WU-10 (D-25): refresh follows RFC 6749 section 6 without a delivery receipt, so the grant no
# longer stores an encrypted replay of its last token response. Authorized by D-168 / D-159.
class RemoveRefreshDeliveryReceiptOpBaseCom < ActiveRecord::Migration[8.2]
  def up
    remove_check_constraint(:op_com_grants, name: "chk_op_com_grants_refresh_delivery_all_or_none")
    safety_assured do
      remove_column(:op_com_grants, :refresh_delivery_ciphertext)
      remove_column(:op_com_grants, :refresh_delivery_predecessor_digest)
      remove_column(:op_com_grants, :refresh_delivery_expires_at)
    end
  end

  def down
    add_column(:op_com_grants, :refresh_delivery_ciphertext, :text)
    add_column(:op_com_grants, :refresh_delivery_predecessor_digest, :string)
    add_column(:op_com_grants, :refresh_delivery_expires_at, :datetime)
    add_check_constraint(
      :op_com_grants,
      "(refresh_delivery_ciphertext IS NULL AND refresh_delivery_predecessor_digest IS NULL AND " \
      "refresh_delivery_expires_at IS NULL) OR (refresh_delivery_ciphertext IS NOT NULL AND " \
      "refresh_delivery_predecessor_digest IS NOT NULL AND refresh_delivery_expires_at IS NOT NULL)",
      name: "chk_op_com_grants_refresh_delivery_all_or_none",
    )
  end
end
