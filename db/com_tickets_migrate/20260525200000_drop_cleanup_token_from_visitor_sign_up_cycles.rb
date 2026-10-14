# frozen_string_literal: true
class DropCleanupTokenFromVisitorSignUpCycles < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  # Mirror of DropCleanupTokenFromClientSignUpCycles. cleanup_token was never
  # consulted by any service; the populating callback + validator are removed
  # and the column + index are dropped here. See
  # plans/backlog/retention-vocabulary-drift-cleanup.md.

  def up
    remove_index :visitor_sign_up_cycles,
                 name: "index_visitor_sign_up_cycles_on_cleanup_token",
                 algorithm: :concurrently,
                 if_exists: true

    safety_assured do
      remove_column :visitor_sign_up_cycles, :cleanup_token if
        column_exists?(:visitor_sign_up_cycles, :cleanup_token)
    end
  end

  def down
    safety_assured do
      add_column :visitor_sign_up_cycles, :cleanup_token, :string, default: "", null: false unless
        column_exists?(:visitor_sign_up_cycles, :cleanup_token)
    end

    add_index :visitor_sign_up_cycles, :cleanup_token,
              name: "index_visitor_sign_up_cycles_on_cleanup_token",
              algorithm: :concurrently,
              if_not_exists: true
  end
end
