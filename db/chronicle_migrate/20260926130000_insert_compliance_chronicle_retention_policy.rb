# frozen_string_literal: true

# OQ-AUD-004 (docs/vendor/identity/15_audit-log-integrity-requirement.md): the owner set the
# `compliance` retention class to one year on 2026-09-26, noting it may change later. A later change
# is its own migration that updates this row; this insert never overwrites an existing row.
class InsertComplianceChronicleRetentionPolicy < ActiveRecord::Migration[8.2]
  def up
    safety_assured do
      execute(<<~SQL.squish)
        INSERT INTO chronicle_retention_policies (code, name, duration_days, permanent, created_at, updated_at)
        VALUES ('compliance', 'Compliance', 365, false, now(), now())
        ON CONFLICT (code) DO NOTHING
      SQL
    end
  end

  def down
    # No-op: audit rows reference this policy and must not lose it.
  end
end
