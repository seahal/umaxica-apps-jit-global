# frozen_string_literal: true

class CutOverStaffIdentityAuditEventBigintKeys < ActiveRecord::Migration[8.2]
  NEW_FOREIGN_KEY = "fk_staff_identity_audits_event_id_bigint"
  OLD_FOREIGN_KEY = "fk_rails_ce4872192d"
  EVENT_PRIMARY_KEY = "staff_identity_audit_events_pkey"
  MAPPED_ID_INDEX = "index_staff_identity_audit_events_on_id"
  EVENT_LEGACY_ID_NOT_NULL = "staff_identity_audit_events_legacy_id_not_null"
  EVENT_BIGINT_ID_NOT_NULL = "staff_identity_audit_events_id_bigint_not_null"
  AUDIT_BIGINT_EVENT_ID_NOT_NULL = "staff_identity_audits_event_id_bigint_not_null"

  def up
    assert_additive_schema!
    assert_complete_mapping!
    install_staged_constraints!
    promote_bigint_primary_key!
    attach_final_foreign_key!
    remove_legacy_source_column!
  end

  def down
    assert_cutover_schema!
    remove_final_constraints!
    restore_string_reference_columns!
    restore_string_primary_key!
    restore_string_foreign_key!
  end

  private

  def install_staged_constraints!
    add_foreign_key(
      :staff_identity_audits,
      :staff_identity_audit_events,
      column: :event_id_bigint,
      primary_key: :id_bigint,
      validate: false,
      name: NEW_FOREIGN_KEY,
    )
    remove_foreign_key(:staff_identity_audits, column: :event_id)

    add_check_constraint(
      :staff_identity_audit_events,
      "legacy_id IS NOT NULL",
      name: EVENT_LEGACY_ID_NOT_NULL,
      validate: false,
    )
    add_check_constraint(
      :staff_identity_audit_events,
      "id_bigint IS NOT NULL",
      name: EVENT_BIGINT_ID_NOT_NULL,
      validate: false,
    )
    add_check_constraint(
      :staff_identity_audits,
      "event_id_bigint IS NOT NULL",
      name: AUDIT_BIGINT_EVENT_ID_NOT_NULL,
      validate: false,
    )
  end

  def promote_bigint_primary_key!
    drop_primary_key!(:staff_identity_audit_events)
    # The consumer inventory found no application writer or reader for these model-less tables;
    # staff_identity_audits is the sole persisted reference and is switched above before the
    # rename. This is the reviewed cutover boundary, not a general-purpose column rename.
    safety_assured do
      rename_column(:staff_identity_audit_events, :id, :legacy_id_source)
      rename_column(:staff_identity_audit_events, :id_bigint, :id)
      rename_column(:staff_identity_audits, :event_id, :legacy_event_id)
      rename_column(:staff_identity_audits, :event_id_bigint, :event_id)
    end

    # The new bigint column is already unique and non-null under the staged checks; Rails has no
    # primary-key promotion API for this column swap, so keep this DDL inside the reviewed narrow
    # safety boundary.
    safety_assured do
      execute(<<~SQL.squish)
        ALTER TABLE staff_identity_audit_events
        ADD CONSTRAINT #{EVENT_PRIMARY_KEY} PRIMARY KEY (id)
      SQL
    end
    # The pre-cutover FK used the temporary unique id_bigint index. Reattach it to the new
    # primary key before removing that now-redundant index.
    remove_foreign_key(:staff_identity_audits, name: NEW_FOREIGN_KEY)
    remove_index(:staff_identity_audit_events, name: MAPPED_ID_INDEX)
  end

  def attach_final_foreign_key!
    add_foreign_key(
      :staff_identity_audits,
      :staff_identity_audit_events,
      column: :event_id,
      primary_key: :id,
      validate: false,
      name: NEW_FOREIGN_KEY,
    )
  end

  def remove_legacy_source_column!
    # The mapping assertion proves legacy_id_source == legacy_id for every row before this
    # temporary source column is removed. The retained legacy_id is the reversible correspondence
    # value used by the down migration; no issued event code is discarded.
    safety_assured { remove_column(:staff_identity_audit_events, :legacy_id_source) }
  end

  def remove_final_constraints!
    remove_foreign_key(:staff_identity_audits, name: NEW_FOREIGN_KEY)
    remove_check_constraint(:staff_identity_audit_events, name: EVENT_LEGACY_ID_NOT_NULL)
    remove_check_constraint(:staff_identity_audit_events, name: EVENT_BIGINT_ID_NOT_NULL)
    remove_check_constraint(:staff_identity_audits, name: AUDIT_BIGINT_EVENT_ID_NOT_NULL)
  end

  def restore_string_reference_columns!
    safety_assured do
      rename_column(:staff_identity_audits, :event_id, :event_id_bigint)
      rename_column(:staff_identity_audits, :legacy_event_id, :event_id)
    end
  end

  def restore_string_primary_key!
    drop_primary_key!(:staff_identity_audit_events)
    safety_assured { rename_column(:staff_identity_audit_events, :id, :id_bigint) }
    add_column(:staff_identity_audit_events, :id, :string)
    safety_assured do
      execute(<<~SQL.squish)
        UPDATE staff_identity_audit_events
        SET id = legacy_id
        WHERE id IS NULL
      SQL
      change_column_null(:staff_identity_audit_events, :id, false)
    end
    change_column_null(:staff_identity_audit_events, :legacy_id, true)
    change_column_null(:staff_identity_audit_events, :id_bigint, true)
    change_column_null(:staff_identity_audits, :event_id_bigint, true)

    safety_assured do
      execute(<<~SQL.squish)
        ALTER TABLE staff_identity_audit_events
        ADD CONSTRAINT #{EVENT_PRIMARY_KEY} PRIMARY KEY (id)
      SQL
    end
    # Rollback is run inside Rails' migration transaction. Recreating this small correspondence
    # index cannot use CREATE INDEX CONCURRENTLY there; the mapping is already validated and this
    # explicit rollback-only lock is preferable to leaving the old schema without its uniqueness.
    safety_assured do
      add_index(
        :staff_identity_audit_events,
        :id_bigint,
        unique: true,
        name: "index_staff_identity_audit_events_on_id_bigint",
      )
    end
  end

  def restore_string_foreign_key!
    add_foreign_key(
      :staff_identity_audits,
      :staff_identity_audit_events,
      column: :event_id,
      name: OLD_FOREIGN_KEY,
    )
  end

  def assert_additive_schema!
    required = {
      staff_identity_audit_events: %w(id legacy_id id_bigint),
      staff_identity_audits: %w(id event_id event_id_bigint),
    }
    assert_columns!(required)
    return unless column_exists?(:staff_identity_audit_events, :legacy_id_source)

    raise ActiveRecord::MigrationError, "staff identity audit-event bigint cutover has already run"
  end

  def assert_cutover_schema!
    required = {
      staff_identity_audit_events: %w(id legacy_id),
      staff_identity_audits: %w(id event_id legacy_event_id),
    }
    assert_columns!(required)
    return unless column_exists?(:staff_identity_audit_events, :id_bigint) ||
      column_exists?(:staff_identity_audits, :event_id_bigint)

    raise ActiveRecord::MigrationError, "staff identity audit-event bigint cutover is not active"
  end

  def assert_columns!(required)
    required.each do |table, columns|
      actual = connection.columns(table).map(&:name)
      missing = columns - actual
      next if missing.empty?

      message = [
        "staff identity audit-event cutover schema is incomplete for #{table}:",
        missing.join(", "),
      ].join(" ")
      raise ActiveRecord::MigrationError, message
    end
  end

  def assert_complete_mapping!
    event_conflicts = connection.select_value(<<~SQL.squish).to_i
      SELECT count(*)
      FROM staff_identity_audit_events
      WHERE legacy_id IS NULL OR id_bigint IS NULL OR legacy_id <> id
    SQL
    unless event_conflicts.zero?
      raise ActiveRecord::MigrationError, "staff identity audit-event bigint mapping is incomplete or inconsistent"
    end

    audit_conflicts = connection.select_value(<<~SQL.squish).to_i
      SELECT count(*)
      FROM staff_identity_audits audits
      LEFT JOIN staff_identity_audit_events events ON events.legacy_id = audits.event_id
      WHERE audits.event_id_bigint IS NULL
         OR events.id_bigint IS NULL
         OR audits.event_id_bigint <> events.id_bigint
    SQL
    return if audit_conflicts.zero?

    raise ActiveRecord::MigrationError, "staff identity audit reference bigint mapping is incomplete or inconsistent"
  end

  def drop_primary_key!(table)
    constraint_name = connection.select_value(<<~SQL.squish)
      SELECT constraint_name
      FROM information_schema.table_constraints
      WHERE table_schema = 'public'
        AND table_name = #{connection.quote(table.to_s)}
        AND constraint_type = 'PRIMARY KEY'
    SQL
    raise ActiveRecord::MigrationError, "#{table} primary key is missing" if constraint_name.nil?
    unless constraint_name == EVENT_PRIMARY_KEY
      raise ActiveRecord::MigrationError, "#{table} primary key is unexpected: #{constraint_name}"
    end

    # Rails has no portable primary-key swap operation. The old string FK is removed and the new
    # mapping FK is installed before this narrow PostgreSQL constraint replacement.
    safety_assured do
      execute("ALTER TABLE #{connection.quote_table_name(table)} DROP CONSTRAINT #{connection.quote_column_name(constraint_name)}")
    end
  end
end
