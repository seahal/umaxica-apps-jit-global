# typed: false
# frozen_string_literal: true

# A root login is established once, in the same app_tickets transaction that creates its browser
# session token. The login cooldown reads this column instead of the unclassified token created_at,
# so RP sessions, refresh rotations, and pending or failed attempts never move the cooldown anchor.
# The unique flow binding keeps one sign-in flow from establishing more than one root login.
# See adr/root-login-establishment-boundary.md.
class AddRootLoginEstablishedAtToClientTokens < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def change
    add_column(:client_tokens, :root_login_established_at, :timestamptz)
    add_index(
      :client_tokens, [:user_id, :root_login_established_at],
      where: "root_login_established_at IS NOT NULL",
      name: "index_client_tokens_on_user_id_root_login_established_at",
      algorithm: :concurrently,
    )
    add_index(
      :client_sign_in_flows, :token_id,
      unique: true,
      where: "token_id IS NOT NULL",
      name: "index_client_sign_in_flows_on_token_id_unique",
      algorithm: :concurrently,
    )
  end
end
