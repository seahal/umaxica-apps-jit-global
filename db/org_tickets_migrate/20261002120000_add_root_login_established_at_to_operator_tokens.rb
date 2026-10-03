# typed: false
# frozen_string_literal: true

# A root login is established once, in the same org_tickets transaction that creates its browser
# session token. The login cooldown reads this column instead of the unclassified token created_at,
# so RP sessions, refresh rotations, and pending or failed attempts never move the cooldown anchor.
# The unique flow binding keeps one sign-in flow from establishing more than one root login.
# See adr/root-login-establishment-boundary.md.
class AddRootLoginEstablishedAtToOperatorTokens < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def change
    add_column(:operator_tokens, :root_login_established_at, :timestamptz)
    add_index(
      :operator_tokens, [:staff_id, :root_login_established_at],
      where: "root_login_established_at IS NOT NULL",
      name: "index_operator_tokens_on_staff_id_root_login_established_at",
      algorithm: :concurrently,
    )
    add_index(
      :operator_sign_in_flows, :token_id,
      unique: true,
      where: "token_id IS NOT NULL",
      name: "index_operator_sign_in_flows_on_token_id_unique",
      algorithm: :concurrently,
    )
  end
end
