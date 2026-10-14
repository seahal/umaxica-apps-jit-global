# frozen_string_literal: true
class DropCleanupTokenFromClientSignUpCycles < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  # cleanup_token was added as an "cleanup ownership marker" intended to bind
  # the cleanup actor to the cycle, but no service ever consulted it. The
  # callback that populated it and the validation are removed; the column +
  # index are dropped here. See plans/backlog/retention-vocabulary-drift-cleanup.md.

  def up
    remove_index :client_sign_up_cycles,
                 name: "index_client_sign_up_cycles_on_cleanup_token",
                 algorithm: :concurrently,
                 if_exists: true

    safety_assured do
      remove_column :client_sign_up_cycles, :cleanup_token if
        column_exists?(:client_sign_up_cycles, :cleanup_token)
    end
  end

  def down
    safety_assured do
      add_column :client_sign_up_cycles, :cleanup_token, :string, default: "", null: false unless
        column_exists?(:client_sign_up_cycles, :cleanup_token)
    end

    add_index :client_sign_up_cycles, :cleanup_token,
              name: "index_client_sign_up_cycles_on_cleanup_token",
              algorithm: :concurrently,
              if_not_exists: true
  end
end
