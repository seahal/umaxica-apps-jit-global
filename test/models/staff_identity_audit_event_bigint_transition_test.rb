# frozen_string_literal: true

require "test_helper"

class StaffIdentityAuditEventBigintTransitionTest < ActiveSupport::TestCase
  setup do
    @legacy_code = "CUTOVER_TEST_#{SecureRandom.hex(6).upcase}"
  end

  teardown do
    connection = Operator.connection_pool.lease_connection
    connection.execute(
      "DELETE FROM staff_identity_audits WHERE legacy_event_id = #{connection.quote(@legacy_code)}",
    ) if connection.column_exists?(:staff_identity_audits, :legacy_event_id)
    connection.execute(
      "DELETE FROM staff_identity_audit_events WHERE legacy_id = #{connection.quote(@legacy_code)}",
    ) if connection.column_exists?(:staff_identity_audit_events, :legacy_id)
  end

  test "cut over catalog keeps legacy codes while using bigint primary and foreign keys" do
    event_columns = Operator.connection_pool.lease_connection.columns(:staff_identity_audit_events)
    audit_columns = Operator.connection_pool.lease_connection.columns(:staff_identity_audits)

    event_id = event_columns.find { |column| column.name == "id" }
    legacy_id = event_columns.find { |column| column.name == "legacy_id" }
    legacy_event_id = audit_columns.find { |column| column.name == "legacy_event_id" }
    audit_event_id = audit_columns.find { |column| column.name == "event_id" }

    assert event_id, "staff_identity_audit_events.id is required"
    assert legacy_id, "staff_identity_audit_events.legacy_id is required"
    assert legacy_event_id, "staff_identity_audits.legacy_event_id is required"
    assert audit_event_id, "staff_identity_audits.event_id is required"
    assert_equal :integer, event_id.type
    assert_equal 8, event_id.limit
    assert_equal :string, legacy_id.type
    assert_equal :string, legacy_event_id.type
    assert_equal :integer, audit_event_id.type
    assert_equal 8, audit_event_id.limit
    assert_not event_columns.any? { |column| column.name == "id_bigint" }
    assert_not audit_columns.any? { |column| column.name == "event_id_bigint" }

    assert_not legacy_id.null, "the preserved event code must remain required"
    assert_not legacy_event_id.null, "the preserved audit event code must remain required"
    assert_not audit_event_id.null, "the bigint audit reference must remain required"

    connection = Operator.connection_pool.lease_connection

    assert_equal "id", connection.primary_key(:staff_identity_audit_events)
    event_foreign_key =
      connection.foreign_keys(:staff_identity_audits).find do |foreign_key|
        foreign_key.column == "event_id" && foreign_key.to_table == "staff_identity_audit_events"
      end

    assert event_foreign_key, "the bigint event reference must be enforced by a foreign key"
    assert_equal "staff_identity_audit_events", event_foreign_key.to_table
    assert_equal "id", event_foreign_key.primary_key
  end

  test "final bigint keys preserve the legacy event code and audit reference" do
    connection = Operator.connection_pool.lease_connection
    operator_id = connection.select_value("SELECT id FROM operators ORDER BY id LIMIT 1")

    assert_not_nil operator_id, "the isolated ORG catalog must provide an operator for an audit row"
    event_id = connection.select_value("SELECT COALESCE(MAX(id), 0) + 1 FROM staff_identity_audit_events").to_i
    now = connection.quote(Time.current)

    connection.execute(<<~SQL.squish)
      INSERT INTO staff_identity_audit_events (id, legacy_id)
      VALUES (#{event_id}, #{connection.quote(@legacy_code)})
    SQL
    connection.execute(<<~SQL.squish)
      INSERT INTO staff_identity_audits
        (staff_id, event_id, legacy_event_id, created_at, updated_at)
      VALUES
        (#{Integer(operator_id)}, #{event_id}, #{connection.quote(@legacy_code)}, #{now}, #{now})
    SQL

    event = connection.select_one(
      "SELECT id, legacy_id FROM staff_identity_audit_events WHERE id = #{event_id}",
    )
    audit = connection.select_one(
      "SELECT event_id, legacy_event_id FROM staff_identity_audits WHERE legacy_event_id = " \
      "#{connection.quote(@legacy_code)}",
    )

    assert_equal event_id, event.fetch("id").to_i
    assert_equal @legacy_code, event.fetch("legacy_id")
    assert_equal event_id, audit.fetch("event_id").to_i
    assert_equal @legacy_code, audit.fetch("legacy_event_id")
  end
end
