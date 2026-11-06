# frozen_string_literal: true

# The owner approved the `security` retention class at 365 days on 2026-11-03 in `zero.md`.
class InsertSecurityChronicleRetentionPolicy < ActiveRecord::Migration[8.2]
  def up
    safety_assured do
      execute(<<~SQL.squish)
        INSERT INTO chronicle_retention_policies (code, name, duration_days, permanent, created_at, updated_at)
        VALUES ('security', 'Security', 365, false, now(), now())
        ON CONFLICT (code) DO NOTHING
      SQL
    end
  end

  def down
    # No-op: audit rows reference this policy and must not lose it.
  end
end
