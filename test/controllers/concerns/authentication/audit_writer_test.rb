# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

module Authentication
  class AuditWriterTest < ActiveSupport::TestCase
    self.fixture_table_names = []

    setup do
      @user = Client.create!(
        security_mode_id: SecurityModeConfigurable::NORMAL,
        public_id: PublicId.generate,
        status_id: ClientStatus::ACTIVE,
        visibility_id: ClientVisibility::USER,
      )

      # Ensure audit master data exists
      ClientChronicleEvent.ensure_defaults! if ClientChronicleEvent.respond_to?(:ensure_defaults!)
      ClientChronicleLevel.ensure_defaults! if ClientChronicleLevel.respond_to?(:ensure_defaults!)
    end

    test "write! creates audit record successfully" do
      audit = AuthenticationAuditWriter.write!(
        ClientChronicle,
        ClientChronicleEvent::LOGGED_IN,
        resource: @user,
        actor: @user,
        ip_address: "127.0.0.1",
      )

      assert_predicate audit, :persisted?
      assert_equal ClientChronicleEvent::LOGGED_IN, audit.event_id
      assert_equal @user.id.to_s, audit.subject_id
      assert_equal "Client", audit.subject_type
      assert_equal IPAddr.new("127.0.0.1"), audit.ip_address
    end

    test "write! raises exception on validation failure" do
      # Create invalid event_id that doesn't exist in master data
      invalid_event_id = "INVALID_EVENT_#{SecureRandom.hex(4)}"

      assert_raises(AuthenticationAuditWriter::AuditWriteError) do
        AuthenticationAuditWriter.write!(
          ClientChronicle,
          invalid_event_id,
          resource: @user,
          actor: @user,
          ip_address: "127.0.0.1",
        )
      end
    end

    test "write returns true on success" do
      result = AuthenticationAuditWriter.write(
        ClientChronicle,
        ClientChronicleEvent::LOGGED_IN,
        resource: @user,
        actor: @user,
        ip_address: "127.0.0.1",
      )

      assert result
      assert ClientChronicle.exists?(event_id: ClientChronicleEvent::LOGGED_IN, subject_id: @user.id)
    end

    test "write recreates missing user chronicle event and level references" do
      ChronicleRecord.connected_to(role: :writing) do
        ClientChronicle.where(event_id: ClientChronicleEvent::LOGGED_IN).or(
          ClientChronicle.where(level_id: ClientChronicleLevel::NOTHING),
        ).delete_all
        ClientChronicleEvent.where(id: ClientChronicleEvent::LOGGED_IN).delete_all
        ClientChronicleLevel.where(id: ClientChronicleLevel::NOTHING).delete_all
      end

      result = AuthenticationAuditWriter.write(
        ClientChronicle,
        "LOGGED_IN",
        resource: @user,
        actor: @user,
        ip_address: "127.0.0.1",
      )

      assert result
      assert ClientChronicleEvent.exists?(id: ClientChronicleEvent::LOGGED_IN)
      assert ClientChronicleLevel.exists?(id: ClientChronicleLevel::NOTHING)
      assert ClientChronicle.exists?(event_id: ClientChronicleEvent::LOGGED_IN, subject_id: @user.id)
    end

    test "write returns false on failure" do
      # Create invalid event_id that is guaranteed not to exist
      invalid_event_id = "NONEXISTENT_#{SecureRandom.hex(16).upcase}"

      # Ensure this event doesn't exist in the database
      ChronicleRecord.connected_to(role: :writing) do
        ClientChronicleEvent.where(id: invalid_event_id).delete_all
      end

      result = AuthenticationAuditWriter.write(
        ClientChronicle,
        invalid_event_id,
        resource: @user,
        actor: @user,
        ip_address: "127.0.0.1",
      )

      assert_not result, "write should return false when audit save fails"

      # Verify audit was not saved
      assert_not ClientChronicle.exists?(event_id: invalid_event_id, subject_id: @user.id),
                 "Failed audit should not be saved to database"
    end

    test "write logs failure for observability" do
      # Create invalid event_id
      invalid_event_id = "NONEXISTENT_#{SecureRandom.hex(16).upcase}"

      # Ensure event doesn't exist
      ChronicleRecord.connected_to(role: :writing) do
        ClientChronicleEvent.where(id: invalid_event_id).delete_all
      end

      logged = []

      Rails.logger.stub(:info, ->(message) { logged << JSON.parse(message, symbolize_names: true) }) do
        result = AuthenticationAuditWriter.write(
          ClientChronicle,
          invalid_event_id,
          resource: @user,
          actor: @user,
          ip_address: "127.0.0.1",
        )

        assert_not result, "write should return false to indicate failure (observable)"
      end

      notification = logged.find { |entry| entry[:event] == AuthenticationAuditWriter::WRITE_FAILED_EVENT }
      payload = notification&.fetch(:data)

      assert notification, "write should log authentication audit failure event"
      assert_equal invalid_event_id, payload.fetch(:event_id)
      assert_equal "Client", payload.fetch(:actor_type)
      assert_equal @user.public_id, payload.fetch(:actor_id)
      assert_equal "Client", payload.fetch(:resource_type)
      assert_equal @user.public_id, payload.fetch(:resource_id)
      assert_predicate payload.fetch(:ip_address_digest), :present?
      assert_not_includes notification[:data].keys, :error_message
    end

    test "write does not raise exception on failure" do
      invalid_event_id = "INVALID_EVENT_#{SecureRandom.hex(4)}"

      assert_nothing_raised do
        result = AuthenticationAuditWriter.write(
          ClientChronicle,
          invalid_event_id,
          resource: @user,
          actor: @user,
          ip_address: "127.0.0.1",
        )

        assert_not result
      end
    end

    test "build_audit creates audit record without saving" do
      audit = AuthenticationAuditWriter.build_audit(
        ClientChronicle,
        ClientChronicleEvent::LOGGED_IN,
        resource: @user,
        actor: @user,
        ip_address: "127.0.0.1",
      )

      assert_not audit.persisted?
      assert_equal ClientChronicleEvent::LOGGED_IN, audit.event_id
      assert_equal @user.id.to_s, audit.subject_id
      assert_equal "Client", audit.subject_type
    end

    # Regression for S-4: when the primary audit write fails, a
    # ChronicleOutboxEntry must be created so the missed event can be
    # replayed later. Previously the failure was only an application log
    # with no durable record.
    test "write persists a ChronicleOutboxEntry on audit failure" do
      invalid_event_id = "NONEXISTENT_OUTBOX_#{SecureRandom.hex(8).upcase}"
      ChronicleRecord.connected_to(role: :writing) do
        ClientChronicleEvent.where(id: invalid_event_id).delete_all
      end

      AuthenticationAuditWriter.stub(
        :write!, ->(*) {
                   raise AuthenticationAuditWriter::AuditWriteError, "forced"
                 },
      ) do
        assert_difference -> {
          ChronicleRecord.connected_to(role: :reading) { ChronicleOutboxEntry.count }
        }, 1 do
          AuthenticationAuditWriter.write(
            ClientChronicle,
            invalid_event_id,
            resource: @user,
            actor: @user,
            ip_address: "127.0.0.1",
          )
        end
      end

      entry =
        ChronicleRecord.connected_to(role: :reading) do
          ChronicleOutboxEntry.order(created_at: :desc).first
        end

      assert_equal AuthenticationAuditWriter::OUTBOX_EVENT, entry.event
      assert_equal AuthenticationAuditWriter::OUTBOX_STATUS_PENDING, entry.status
      assert_equal "ClientChronicle", entry.payload["audit_class"]
      assert_equal invalid_event_id, entry.payload["event_id"]
      assert_equal "Client", entry.payload["resource_type"]
      assert_equal @user.public_id, entry.payload["resource_id"]
      assert_equal @user.public_id, entry.payload["actor_id"]
      assert_equal "127.0.0.1", entry.payload["ip_address"]
      assert_not entry.payload.key?("ip_address_digest")
      assert_not entry.payload.key?("error_message")
      assert_predicate entry.payload["error_class"], :present?
    end

    # Regression for S-4: outbox payloads land in the chronicle DB and
    # must not embed secret_credentials. Context goes through
    # ChronicleRecordPolicy.sanitize, which filters forbidden keys.
    test "write sanitizes secret_credentials out of the outbox payload context" do
      invalid_event_id = "NONEXISTENT_SECRET_#{SecureRandom.hex(8).upcase}"
      ChronicleRecord.connected_to(role: :writing) do
        ClientChronicleEvent.where(id: invalid_event_id).delete_all
      end

      AuthenticationAuditWriter.stub(
        :write!, ->(*) {
                   raise AuthenticationAuditWriter::AuditWriteError, "forced"
                 },
      ) do
        AuthenticationAuditWriter.write(
          ClientChronicle,
          invalid_event_id,
          resource: @user,
          actor: @user,
          ip_address: "127.0.0.1",
          context: {
            auth_method: "secret_credential",
            raw_secret_credential: "should-not-survive",
            password: "nope",
            token: "token-should-not-survive",
            otp: "123456",
            session_id: "session-should-not-survive",
            raw_email: "person@example.test",
            raw_ip: "203.0.113.10",
          },
        )
      end

      entry =
        ChronicleRecord.connected_to(role: :reading) do
          ChronicleOutboxEntry.order(created_at: :desc).first
        end
      sanitized_context = entry.payload["context"] || {}

      assert_equal "secret_credential", sanitized_context["auth_method"]
      assert_not sanitized_context.key?("raw_secret_credential"),
                 "raw_secret_credential must be stripped from outbox payload"
      assert_not sanitized_context.key?("password"),
                 "password must be stripped from outbox payload"
      assert_not sanitized_context.key?("token"),
                 "token must be stripped from outbox payload"
      assert_not sanitized_context.key?("otp"),
                 "otp must be stripped from outbox payload"
      assert_not sanitized_context.key?("session_id"),
                 "session_id must be stripped from outbox payload"
      assert_not sanitized_context.key?("raw_email"),
                 "raw_email must be stripped from outbox payload"
      assert_not sanitized_context.key?("raw_ip"),
                 "raw_ip must be stripped from outbox payload"
    end

    test "write sanitizes secret_credentials out of the application log payload" do
      invalid_event_id = "NONEXISTENT_EVENT_SECRET_#{SecureRandom.hex(8).upcase}"
      logged = []

      Rails.logger.stub(:info, ->(message) { logged << JSON.parse(message, symbolize_names: true) }) do
        AuthenticationAuditWriter.write(
          ClientChronicle,
          invalid_event_id,
          resource: @user,
          actor: @user,
          ip_address: "203.0.113.10",
          context: {
            auth_method: "passkey",
            token: "token-should-not-survive",
            otp: "123456",
            session_id: "session-should-not-survive",
            raw_secret_credential: "raw-secret_credential-should-not-survive",
            raw_email: "person@example.test",
            raw_ip: "203.0.113.10",
          },
        )
      end

      payload = logged.find { |entry| entry[:event] == AuthenticationAuditWriter::WRITE_FAILED_EVENT }.fetch(:data)
      payload_json = payload.to_json

      assert_includes payload_json, "passkey"
      assert_not_includes payload_json, "token-should-not-survive"
      assert_not_includes payload_json, "123456"
      assert_not_includes payload_json, "session-should-not-survive"
      assert_not_includes payload_json, "raw-secret_credential-should-not-survive"
      assert_not_includes payload_json, "person@example.test"
      assert_not_includes payload_json, "203.0.113.10"
      assert_not_includes payload.keys, :error_message
    end

    test "write calls fallback recorder on audit failure" do
      invalid_event_id = "NONEXISTENT_FALLBACK_#{SecureRandom.hex(8).upcase}"
      fallback_calls = []

      ChronicleFallbackRecorder.stub(:call, ->(**payload) { fallback_calls << payload }) do
        AuthenticationAuditWriter.write(
          ClientChronicle,
          invalid_event_id,
          resource: @user,
          actor: @user,
          ip_address: "127.0.0.1",
        )
      end

      fallback = fallback_calls.find { |payload| payload[:event] == AuthenticationAuditWriter::FALLBACK_EVENT }

      assert fallback, "write should emit a structured fallback record"
      assert_equal invalid_event_id, fallback.fetch(:action)
      assert_equal @user, fallback.fetch(:actor)
      assert_equal @user, fallback.fetch(:subject)
      assert fallback.fetch(:manual_recovery_required)
    end

    test "write does not call Rails logger error directly" do
      invalid_event_id = "NONEXISTENT_NO_DIRECT_LOG_#{SecureRandom.hex(8).upcase}"
      logger_error_calls = []

      ChronicleFallbackRecorder.stub(:call, true) do
        Rails.logger.stub(:error, ->(message = nil, &block) { logger_error_calls << (message || block&.call) }) do
          AuthenticationAuditWriter.write(
            ClientChronicle,
            invalid_event_id,
            resource: @user,
            actor: @user,
            ip_address: "127.0.0.1",
          )
        end
      end

      assert_empty logger_error_calls
    end

    test "log event formats authentication events as JSON" do
      log_io = StringIO.new
      logger = ActiveSupport::Logger.new(log_io)
      logger.formatter = ->(_severity, _datetime, _progname, message) { "#{message}\n" }

      Rails.stub(:logger, logger) do
        Rails.logger.info(
          JitLogEvent.format(
            AuthenticationAuditWriter::WRITE_FAILED_EVENT,
            event_uuid: SecureRandom.uuid,
            audit_class: "ClientChronicle",
            event_id: "LOGGED_IN",
            actor_type: "Client",
            actor_id: @user.public_id,
          ),
        )
      end

      event_log = log_io.string.lines.find { |line| line.include?(AuthenticationAuditWriter::WRITE_FAILED_EVENT) }

      assert event_log, "authentication event should be written to Rails.logger"
      parsed = JSON.parse(event_log)

      assert_equal AuthenticationAuditWriter::WRITE_FAILED_EVENT, parsed.fetch("event")
      assert parsed.fetch("data").key?("actor_id")
    end

    test "write uses writing role for audit database" do
      # Verify that ChronicleRecord.connected_to is called with role: :writing
      # This ensures audit writes go to the primary database, not replica
      original_method = ChronicleRecord.method(:connected_to)

      connection_calls = []
      ChronicleRecord.define_singleton_method(:connected_to) do |**options, &block|
        connection_calls << options
        original_method.call(**options, &block)
      end

      AuthenticationAuditWriter.write(
        ClientChronicle,
        "LOGGED_IN",
        resource: @user,
        actor: @user,
        ip_address: "127.0.0.1",
      )

      assert connection_calls.any? { |opts| opts[:role] == :writing }
    ensure
      # Restore original method
      ChronicleRecord.define_singleton_method(:connected_to, original_method)
    end
  end
end
