# frozen_string_literal: true
class AddCleanupAttemptsCountToClientSignUpCycles < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  # ArtifactCleanup retries failed cleanups indefinitely if nothing tracks
  # attempt counts. A permanent failure (e.g. dependent rows in an unexpected
  # state) keeps the row in `cleanup_status = "failed"` forever, hot-looping
  # the worker. Cap retries here; the worker excludes rows that have hit the
  # ceiling and an operator alert can pick them up.

  def up
    add_column :client_sign_up_cycles, :cleanup_attempts_count, :integer,
               default: 0, null: false unless
      column_exists?(:client_sign_up_cycles, :cleanup_attempts_count)
  end

  def down
    remove_column :client_sign_up_cycles, :cleanup_attempts_count if
      column_exists?(:client_sign_up_cycles, :cleanup_attempts_count)
  end
end
