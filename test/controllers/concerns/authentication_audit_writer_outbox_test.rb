# typed: false
# frozen_string_literal: true

require "test_helper"

# When an audit row cannot be written directly it is queued on the chronicle
# outbox instead, so the event is not lost. If the outbox itself is unreachable
# the writer has to report that it did not persist the event, and record the
# fallback that names it for manual recovery -- reporting success there would
# lose an audit event silently.
class AuthenticationAuditWriterOutboxTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "an audit row is written against the association the audit class exposes" do
    client = Client.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE,
      visibility_id: ClientVisibility::USER,
    )

    assert_difference -> { ClientChronicle.count }, 1 do
      AuthenticationAuditWriter.write!(
        ClientChronicle,
        ClientChronicleEvent::LOGGED_IN,
        resource: client,
        ip_address: "203.0.113.5",
      )
    end

    assert_equal client.id.to_s, ClientChronicle.order(:created_at).last.user_id.to_s
  end
end
