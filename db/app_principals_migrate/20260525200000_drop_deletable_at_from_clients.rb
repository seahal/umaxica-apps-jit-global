# frozen_string_literal: true
class DropDeletableAtFromClients < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  # `clients.deletable_at` is a legacy alias of `purged_at`. The 2026-05-08
  # `consolidate_retention_on_*` migrations renamed `deletable_at` →
  # `purged_at` on every other table but never reached `clients`. Live readers:
  # none — RetentionPurgeJob, Withdrawal::PersonalDataAnonymizer, and the
  # SignUp services all consult `purged_at`. See
  # adr/retention-lifecycle-column-boundary.md and
  # plans/backlog/retention-vocabulary-drift-cleanup.md.
  #
  # `clients` is a large table; index removal must run CONCURRENTLY. The
  # `remove_column` itself is a metadata-only operation on Postgres 11+ and
  # does not rewrite the table.

  def up
    remove_index :clients,
                 name: "index_clients_on_deletable_at",
                 algorithm: :concurrently,
                 if_exists: true

    safety_assured do
      remove_column :clients, :deletable_at if column_exists?(:clients, :deletable_at)
    end
  end

  def down
    safety_assured do
      add_column :clients, :deletable_at, :datetime,
                 default: ::Float::INFINITY, null: false unless
        column_exists?(:clients, :deletable_at)
    end

    # `deletable_at` was always intended to mirror `purged_at` on this table;
    # restore the value pairing on rollback so the column is not blanket-set
    # to Infinity for rows that already had a real purge time scheduled.
    execute(<<~SQL.squish)
      UPDATE clients SET deletable_at = purged_at
    SQL

    add_index :clients, :deletable_at,
              name: "index_clients_on_deletable_at",
              algorithm: :concurrently,
              if_not_exists: true
  end
end
