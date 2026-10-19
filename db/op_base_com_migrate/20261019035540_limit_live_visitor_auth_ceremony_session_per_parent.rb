# frozen_string_literal: true

# D06 Switch: a parent authorization may get a new Auth ceremony after its earlier ceremony was
# cancelled by the Switch. Uniqueness therefore covers only ceremonies that are not cancelled, which
# still keeps one live ceremony per parent.
class LimitLiveVisitorAuthCeremonySessionPerParent < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  public

  def up
    add_index(
      :visitor_auth_ceremony_sessions, :authorization_transaction_ref,
      unique: true, name: "idx_auth_ceremony_sessions_on_live_tx_ref", algorithm: :concurrently,
      where: "authorization_transaction_ref IS NOT NULL AND cancelled_at IS NULL",
    )
    remove_index(:visitor_auth_ceremony_sessions, name: "idx_auth_ceremony_sessions_on_tx_ref", algorithm: :concurrently)
  end

  def down
    add_index(
      :visitor_auth_ceremony_sessions, :authorization_transaction_ref,
      unique: true, name: "idx_auth_ceremony_sessions_on_tx_ref", algorithm: :concurrently,
      where: "authorization_transaction_ref IS NOT NULL",
    )
    remove_index(:visitor_auth_ceremony_sessions, name: "idx_auth_ceremony_sessions_on_live_tx_ref", algorithm: :concurrently)
  end
end
