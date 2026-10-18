# frozen_string_literal: true

# nine.md P3d: retire identifier-owned proof only after its ceremony consumers have moved.
# Reversal recreates the old schema shape; it cannot recover discarded proof values.
# Apply only within the approved disposable rehearsal or a separately approved data cutover.
class RetireClientIdentifierHotpFields < ActiveRecord::Migration[8.2]
  def change
    # Six model declarations ignore these fields before removal. The approved undeployed
    # disposable rehearsal uses this code snapshot; retained-data deployment needs that order.
    safety_assured do
      remove_column(:client_emails, :otp_private_key, :string, null: false, default: "")
      remove_column(:client_emails, :otp_counter, :text, null: false, default: "")
      remove_column(:client_emails, :otp_expires_at, :datetime, null: false, default: -Float::INFINITY)
      remove_column(:client_telephones, :otp_private_key, :string, null: false, default: "")
      remove_column(:client_telephones, :otp_counter, :text, null: false, default: "")
      remove_column(:client_telephones, :otp_expires_at, :datetime, null: false, default: -Float::INFINITY)
    end
  end
end
