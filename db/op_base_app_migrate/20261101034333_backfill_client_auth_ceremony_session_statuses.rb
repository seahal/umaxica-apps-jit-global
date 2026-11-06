# frozen_string_literal: true

class BackfillClientAuthCeremonySessionStatuses < ActiveRecord::Migration[8.2]
  ISSUED = 10
  ADMITTED = 20
  EVIDENCE_RECORDED = 30
  REPLACED = 40
  REVOKED = 90
  COMPLETED = 91
  CANCELLED_BEFORE_PROGRESS = 92
  CANCELLED_AFTER_PROGRESS = 93
  STATUS_IDS = [ISSUED, ADMITTED, EVIDENCE_RECORDED, REPLACED, REVOKED,
                COMPLETED, CANCELLED_BEFORE_PROGRESS, CANCELLED_AFTER_PROGRESS,].freeze

  def up
    assert_existing_facts_are_consistent!
    safety_assured do
      execute(<<~SQL.squish)
        UPDATE client_auth_ceremony_sessions AS ceremony
        SET status_id = CASE
          WHEN ceremony.completed_at IS NOT NULL THEN #{COMPLETED}
          WHEN ceremony.cancelled_at IS NOT NULL AND ceremony.authentication_method IS NOT NULL
            THEN #{CANCELLED_AFTER_PROGRESS}
          WHEN ceremony.cancelled_at IS NOT NULL THEN #{CANCELLED_BEFORE_PROGRESS}
          WHEN ceremony.revoked_at IS NOT NULL AND EXISTS (
            SELECT 1 FROM client_auth_ceremony_sessions AS successor
            WHERE successor.previous_sid_digest = ceremony.sid_digest
          ) THEN #{REPLACED}
          WHEN ceremony.revoked_at IS NOT NULL THEN #{REVOKED}
          WHEN ceremony.authentication_method IS NOT NULL THEN #{EVIDENCE_RECORDED}
          WHEN ceremony.admitted_at IS NOT NULL THEN #{ADMITTED}
          ELSE #{ISSUED}
        END
      SQL
    end
    assert_backfill_complete!
  end

  def down
    safety_assured { execute("UPDATE client_auth_ceremony_sessions SET status_id = NULL") }
  end

  private

  def assert_existing_facts_are_consistent!
    violations = select_value(<<~SQL.squish).to_i
      SELECT COUNT(*) FROM client_auth_ceremony_sessions
      WHERE num_nonnulls(revoked_at, completed_at, cancelled_at) > 1
         OR ((authentication_method IS NULL) <> (authentication_event_at IS NULL))
         OR ((completed_at IS NOT NULL OR cancelled_at IS NOT NULL) AND admitted_at IS NULL)
         OR (authentication_method IS NOT NULL AND admitted_at IS NULL)
    SQL
    return if violations.zero?

    raise ActiveRecord::MigrationError,
          "client Auth ceremony session facts are inconsistent (rows=#{violations})"
  end

  def assert_backfill_complete!
    invalid = select_value(<<~SQL.squish).to_i
      SELECT COUNT(*) FROM client_auth_ceremony_sessions
      WHERE status_id IS NULL OR status_id NOT IN (#{STATUS_IDS.join(", ")})
    SQL
    return if invalid.zero?

    raise ActiveRecord::MigrationError,
          "client Auth ceremony session status backfill is incomplete (rows=#{invalid})"
  end
end
