# typed: false
# frozen_string_literal: true

class ExtendVisitorAuthCeremonySessionLifecycle < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def change
    add_column(:visitor_auth_ceremony_sessions, :authorization_transaction_ref, :string, if_not_exists: true)
    add_column(:visitor_auth_ceremony_sessions, :admitted_at, :datetime, if_not_exists: true)
    add_column(:visitor_auth_ceremony_sessions, :completed_at, :datetime, if_not_exists: true)
    add_column(:visitor_auth_ceremony_sessions, :cancelled_at, :datetime, if_not_exists: true)

    add_index(
      :visitor_auth_ceremony_sessions, :authorization_transaction_ref,
      unique: true,
      where: "authorization_transaction_ref IS NOT NULL",
      name: "idx_auth_ceremony_sessions_on_tx_ref",
      algorithm: :concurrently,
      if_not_exists: true,
    )
    add_check_constraint(
      :visitor_auth_ceremony_sessions,
      "num_nonnulls(revoked_at, completed_at, cancelled_at) <= 1",
      name: "visitor_auth_ceremony_sessions_one_terminal_timestamp",
      validate: false,
    )
    add_check_constraint(
      :visitor_auth_ceremony_sessions,
      "authorization_transaction_ref IS NULL OR admitted_at IS NOT NULL",
      name: "visitor_auth_ceremony_sessions_admission_binding",
      validate: false,
    )
  end
end
