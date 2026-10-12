# frozen_string_literal: true

# Populates the additive mapping columns for the org identity-audit reference tables.
#
# The operation is deliberately separate from schema migrations. It preserves every existing
# string code, is restartable, and does not change the primary key or foreign-key contract until a
# later reviewed cutover has verified all mappings.
class StaffIdentityAuditEventBigintBackfillOperation
  BATCH_SIZE_RANGE = 1..1000
  MAX_BIGINT = 9_223_372_036_854_775_807

  class BackfillError < StandardError; end

  class << self
    public

    def call(dry_run:, batch_size:)
      validate_arguments!(dry_run:, batch_size:)

      Operator.connection_pool.with_connection do |connection|
        schema = verify_schema!(connection)
        return result_for_cutover(dry_run:) if schema == :cutover

        reject_inconsistent_mappings!(connection)

        return result_for(connection, dry_run:) if dry_run

        events_assigned = assign_event_mappings!(connection, batch_size:)
        audit_references_assigned = assign_audit_references!(connection, batch_size:)
        result_for(
          connection,
          dry_run: false,
          events_assigned: events_assigned,
          audit_references_assigned: audit_references_assigned,
        )
      end
    end

    private

    def validate_arguments!(dry_run:, batch_size:)
      return if [true, false].include?(dry_run) && batch_size.is_a?(Integer) &&
        BATCH_SIZE_RANGE.cover?(batch_size)

      raise ArgumentError, "audit-event bigint backfill requires an explicit mode and bounded batch size"
    end

    def verify_schema!(connection)
      final_columns = {
        staff_identity_audit_events: %w(id legacy_id),
        staff_identity_audits: %w(id event_id legacy_event_id),
      }
      return :cutover if final_columns.all? do |table, columns|
        actual = connection.columns(table).map(&:name)
        excluded_column =
          if table == :staff_identity_audit_events
            "id_bigint"
          else
            "event_id_bigint"
          end

        (columns - actual).empty? &&
          actual.exclude?(excluded_column)
      end

      additive_columns = {
        staff_identity_audit_events: %w(id legacy_id id_bigint),
        staff_identity_audits: %w(id event_id event_id_bigint),
      }

      additive_columns.each do |table, columns|
        actual = connection.columns(table).map(&:name)
        missing = columns - actual
        next if missing.empty?

        raise BackfillError, "audit-event bigint backfill schema is incomplete for #{table}"
      end
      :additive
    end

    def reject_inconsistent_mappings!(connection)
      event_conflicts = connection.select_value(<<~SQL.squish).to_i
        SELECT count(*)
        FROM staff_identity_audit_events
        WHERE legacy_id IS NOT NULL AND legacy_id <> id
      SQL
      raise BackfillError, "audit-event legacy mapping conflict" unless event_conflicts.zero?

      audit_conflicts = connection.select_value(<<~SQL.squish).to_i
        SELECT count(*)
        FROM staff_identity_audits audits
        LEFT JOIN staff_identity_audit_events events ON events.legacy_id = audits.event_id
        WHERE audits.event_id_bigint IS NOT NULL
          AND (events.id_bigint IS NULL OR audits.event_id_bigint <> events.id_bigint)
      SQL
      raise BackfillError, "audit reference mapping conflict" unless audit_conflicts.zero?
    end

    def result_for(connection, dry_run:, events_assigned: 0, audit_references_assigned: 0)
      {
        dry_run: dry_run,
        cutover: false,
        events_assigned: events_assigned,
        audit_references_assigned: audit_references_assigned,
        events_missing: connection.select_value(<<~SQL.squish).to_i,
          SELECT count(*)
          FROM staff_identity_audit_events
          WHERE legacy_id IS NULL OR id_bigint IS NULL
        SQL
        audit_references_missing: connection.select_value(<<~SQL.squish).to_i,
          SELECT count(*)
          FROM staff_identity_audits
          WHERE event_id_bigint IS NULL
        SQL
        unresolved_audit_references: connection.select_value(<<~SQL.squish).to_i,
          SELECT count(*)
          FROM staff_identity_audits audits
          WHERE audits.event_id_bigint IS NULL
            AND NOT EXISTS (
              SELECT 1
              FROM staff_identity_audit_events events
              WHERE events.legacy_id = audits.event_id
            )
        SQL
      }.freeze
    end

    def result_for_cutover(dry_run:)
      {
        dry_run: dry_run,
        cutover: true,
        events_assigned: 0,
        audit_references_assigned: 0,
        events_missing: 0,
        audit_references_missing: 0,
        unresolved_audit_references: 0,
      }.freeze
    end

    def assign_event_mappings!(connection, batch_size:)
      assign_in_batches(connection, batch_size:, table: :staff_identity_audit_events) do |rows|
        next_id = connection.select_value(
          "SELECT COALESCE(MAX(id_bigint), 0) FROM staff_identity_audit_events",
        ).to_i
        rows.each_with_index do |row, index|
          assigned_id = next_id + index + 1
          raise BackfillError, "audit-event bigint space exhausted" if assigned_id > MAX_BIGINT

          old_id = connection.quote(row.fetch("id"))
          connection.execute(<<~SQL.squish)
            UPDATE staff_identity_audit_events
            SET legacy_id = COALESCE(legacy_id, id), id_bigint = COALESCE(id_bigint, #{assigned_id})
            WHERE id = #{old_id}
          SQL
        end
      end
    end

    def assign_audit_references!(connection, batch_size:)
      assigned = 0
      loop do
        count =
          connection.transaction(requires_new: true) do
            connection.execute("LOCK TABLE staff_identity_audit_events IN SHARE MODE")
            rows = connection.exec_query(<<~SQL.squish).to_a
              SELECT id, event_id
              FROM staff_identity_audits
              WHERE event_id_bigint IS NULL
              ORDER BY id
              LIMIT #{Integer(batch_size)}
              FOR UPDATE
            SQL
            rows.each do |row|
              event_id = connection.select_value(
                "SELECT id_bigint FROM staff_identity_audit_events WHERE legacy_id = " \
                "#{connection.quote(row.fetch("event_id"))}",
              )
              raise BackfillError, "audit reference has no matching event mapping" if event_id.nil?

              connection.execute(<<~SQL.squish)
                UPDATE staff_identity_audits
                SET event_id_bigint = #{Integer(event_id)}
                WHERE id = #{Integer(row.fetch("id"))}
              SQL
            end
            rows.length
          end
        assigned += count
        break if count.zero?
      end
      assigned
    end

    def assign_in_batches(connection, batch_size:, table:)
      assigned = 0
      loop do
        count =
          connection.transaction(requires_new: true) do
            connection.execute("LOCK TABLE #{table} IN SHARE ROW EXCLUSIVE MODE")
            rows = connection.exec_query(<<~SQL.squish).to_a
              SELECT id, legacy_id, id_bigint
              FROM #{table}
              WHERE legacy_id IS NULL OR id_bigint IS NULL
              ORDER BY id
              LIMIT #{Integer(batch_size)}
              FOR UPDATE
            SQL
            yield rows unless rows.empty?
            rows.length
          end
        assigned += count
        break if count.zero?
      end
      assigned
    end
  end
end
