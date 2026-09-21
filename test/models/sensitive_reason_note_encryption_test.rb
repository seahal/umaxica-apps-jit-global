# frozen_string_literal: true

require "test_helper"

class SensitiveReasonNoteEncryptionTest < ActiveSupport::TestCase
  test "approved account and enforcement notes are encrypted at rest" do
    marker = "sensitive-note-#{SecureRandom.hex(8)}"
    operator = operators(:one)

    client = clients(:one)
    client.update!(
      access_state: AdministrativeAccessLockable::ACCESS_STATE_ADMIN_LOCKED,
      admin_locked_at: Time.current,
      admin_locked_by_operator_id: operator.id,
      admin_locked_reason_code: "security_incident",
      admin_locked_reason_note: marker,
    )

    visitor = visitors(:reserved_visitor)
    visitor.update!(
      access_state: AdministrativeAccessLockable::ACCESS_STATE_ADMIN_LOCKED,
      admin_locked_at: Time.current,
      admin_locked_by_operator_id: operator.id,
      admin_locked_reason_code: "security_incident",
      admin_locked_reason_note: marker,
    )

    target_operator = operators(:two)
    target_operator.update!(
      access_state: AdministrativeAccessLockable::ACCESS_STATE_ADMIN_LOCKED,
      admin_locked_at: Time.current,
      admin_locked_by_operator_id: operator.id,
      admin_locked_reason_code: "security_incident",
      admin_locked_reason_note: marker,
    )

    access_event = AccountAccessEvent.create!(
      account_type: "Client",
      account_id: client.id,
      event_type: AccountAccessEvent::EVENT_TYPE_ADMIN_LOCK,
      previous_access_state: "enabled",
      next_access_state: "admin_locked",
      operator_id: operator.id,
      reason_code: "security_incident",
      reason_note: marker,
      occurred_at: Time.current,
      metadata: {},
    )

    app_case = create_enforcement_case(AppEnforcementCase, client.public_id, operator.public_id, marker)
    com_case = create_enforcement_case(ComEnforcementCase, visitor.public_id, operator.public_id, marker)
    org_case = create_enforcement_case(OrgEnforcementCase, target_operator.public_id, operator.public_id, marker)

    [
      [client, "clients", :admin_locked_reason_note],
      [visitor, "visitors", :admin_locked_reason_note],
      [target_operator, "operators", :admin_locked_reason_note],
      [access_event, "account_access_events", :reason_note],
      [app_case, "app_enforcement_cases", :reason_note],
      [com_case, "com_enforcement_cases", :reason_note],
      [org_case, "org_enforcement_cases", :reason_note],
    ].each do |record, table_name, column_name|
      assert_equal marker, record.reload.public_send(column_name)
      raw_value = raw_column_value(record, table_name, column_name)

      assert_not_equal marker, raw_value
      assert_not_includes raw_value.to_s, marker
    end
  end

  private

  def create_enforcement_case(klass, principal_public_id, applied_by_operator_public_id, reason_note)
    klass.create!(
      kind: "cooldown",
      duration_mode: "timed",
      visibility: "visible",
      release_mode: "automatic",
      effective_at: Time.current,
      expires_at: 1.day.from_now,
      reason_code: "abuse",
      reason_note: reason_note,
      principal_public_id: principal_public_id,
      applied_by_operator_public_id: applied_by_operator_public_id,
    )
  end

  def raw_column_value(record, table_name, column_name)
    connection = record.class.lease_connection
    quoted_table = connection.quote_table_name(table_name)
    quoted_column = connection.quote_column_name(column_name)
    quoted_id = connection.quote(record.id)
    connection.select_value("SELECT #{quoted_column} FROM #{quoted_table} WHERE id = #{quoted_id}")
  end
end
