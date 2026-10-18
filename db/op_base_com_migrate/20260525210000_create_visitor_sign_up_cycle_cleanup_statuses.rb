# frozen_string_literal: true
class CreateVisitorSignUpCycleCleanupStatuses < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  # Mirror of CreateClientSignUpCycleCleanupStatuses for the visitor surface.
  # See that file for the status ID table and rationale.

  STATUS_IDS = [
    [0,  "NOTHING"],
    [10, "IDLE"],
    [20, "PENDING"],
    [30, "COMPLETED"],
    [40, "FAILED"],
  ].freeze

  STRING_TO_ID = { "idle" => 10, "pending" => 20, "completed" => 30, "failed" => 40 }.freeze

  def up
    unless table_exists?(:visitor_sign_up_cycle_cleanup_statuses)
      create_table :visitor_sign_up_cycle_cleanup_statuses, id: :bigint, force: false
      safety_assured do
        execute(<<~SQL.squish)
          INSERT INTO visitor_sign_up_cycle_cleanup_statuses (id)
          VALUES #{STATUS_IDS.map { |id, _| "(#{id})" }.join(", ")}
          ON CONFLICT DO NOTHING
        SQL
      end
    end

    unless column_exists?(:visitor_sign_up_cycles, :cleanup_status_id)
      add_column :visitor_sign_up_cycles, :cleanup_status_id, :bigint, default: 10, null: false
    end

    STRING_TO_ID.each do |string, id|
      safety_assured do
        execute(<<~SQL.squish)
          UPDATE visitor_sign_up_cycles
          SET cleanup_status_id = #{id}
          WHERE cleanup_status = '#{string}' AND cleanup_status_id = 10
        SQL
      end
    end

    unless foreign_key_exists?(:visitor_sign_up_cycles, :visitor_sign_up_cycle_cleanup_statuses)
      add_foreign_key :visitor_sign_up_cycles, :visitor_sign_up_cycle_cleanup_statuses,
                      column: :cleanup_status_id, validate: false
    end

    add_index :visitor_sign_up_cycles, [:cleanup_status_id, :purged_at],
              name: "index_visitor_sign_up_cycles_on_cleanup_status_id_and_purged_at",
              algorithm: :concurrently,
              if_not_exists: true

    remove_index :visitor_sign_up_cycles,
                 name: "index_visitor_sign_up_cycles_on_cleanup_status_and_purged_at",
                 algorithm: :concurrently,
                 if_exists: true

    safety_assured do
      remove_column :visitor_sign_up_cycles, :cleanup_status if
        column_exists?(:visitor_sign_up_cycles, :cleanup_status)
    end
  end

  def down
    safety_assured do
      add_column :visitor_sign_up_cycles, :cleanup_status, :string, default: "idle", null: false unless
        column_exists?(:visitor_sign_up_cycles, :cleanup_status)
    end

    STRING_TO_ID.each do |string, id|
      safety_assured do
        execute(<<~SQL.squish)
          UPDATE visitor_sign_up_cycles
          SET cleanup_status = '#{string}'
          WHERE cleanup_status_id = #{id}
        SQL
      end
    end

    add_index :visitor_sign_up_cycles, [:cleanup_status, :purged_at],
              name: "index_visitor_sign_up_cycles_on_cleanup_status_and_purged_at",
              algorithm: :concurrently,
              if_not_exists: true

    remove_index :visitor_sign_up_cycles,
                 name: "index_visitor_sign_up_cycles_on_cleanup_status_id_and_purged_at",
                 algorithm: :concurrently,
                 if_exists: true

    if foreign_key_exists?(:visitor_sign_up_cycles, :visitor_sign_up_cycle_cleanup_statuses)
      remove_foreign_key :visitor_sign_up_cycles, :visitor_sign_up_cycle_cleanup_statuses
    end

    remove_column :visitor_sign_up_cycles, :cleanup_status_id if
      column_exists?(:visitor_sign_up_cycles, :cleanup_status_id)

    drop_table :visitor_sign_up_cycle_cleanup_statuses if
      table_exists?(:visitor_sign_up_cycle_cleanup_statuses)
  end
end
