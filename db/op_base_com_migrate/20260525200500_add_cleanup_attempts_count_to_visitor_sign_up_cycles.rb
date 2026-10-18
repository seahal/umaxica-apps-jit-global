# frozen_string_literal: true
class AddCleanupAttemptsCountToVisitorSignUpCycles < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  # Mirror of AddCleanupAttemptsCountToClientSignUpCycles. Used by
  # ArtifactCleanup#cleanup_pending_for to cap retry attempts on persistently
  # failing rows.

  def up
    add_column :visitor_sign_up_cycles, :cleanup_attempts_count, :integer,
               default: 0, null: false unless
      column_exists?(:visitor_sign_up_cycles, :cleanup_attempts_count)
  end

  def down
    remove_column :visitor_sign_up_cycles, :cleanup_attempts_count if
      column_exists?(:visitor_sign_up_cycles, :cleanup_attempts_count)
  end
end
