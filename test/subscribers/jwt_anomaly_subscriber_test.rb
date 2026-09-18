# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class JwtAnomalySubscriberTest < ActiveSupport::TestCase
  fixtures :jwt_occurrences

  class MockEvent
    attr_reader :name, :payload, :time

    def initialize(name:, payload:, time: nil)
      @name = name
      @payload = payload
      @time = time
    end
  end

  test "emit does nothing when event name does not match" do
    mock_event = MockEvent.new(
      name: "other.event",
      payload: { code: "MALFORMED_TOKEN" },
    )

    subscriber = JwtAnomalySubscriber.new
    assert_no_difference "JwtAnomalyEvent.count" do
      subscriber.emit(mock_event)
    end
  end

  test "emit does nothing when event does not respond to name" do
    payload = { code: "MALFORMED_TOKEN" }
    subscriber = JwtAnomalySubscriber.new

    assert_no_difference "JwtAnomalyEvent.count" do
      subscriber.emit(payload)
    end
  end

  test "emit does nothing when code is blank" do
    mock_event = MockEvent.new(
      name: "jwt.anomaly.detected",
      payload: { code: "" },
    )

    subscriber = JwtAnomalySubscriber.new
    assert_no_difference "JwtAnomalyEvent.count" do
      subscriber.emit(mock_event)
    end
  end

  test "emit handles missing payload gracefully" do
    mock_event = MockEvent.new(
      name: "jwt.anomaly.detected",
      payload: nil,
    )

    subscriber = JwtAnomalySubscriber.new
    assert_no_difference "JwtAnomalyEvent.count" do
      subscriber.emit(mock_event)
    end
  end

  test "emit handles a non-hash payload gracefully" do
    mock_event = MockEvent.new(
      name: "jwt.anomaly.detected",
      payload: %w(not a payload),
    )

    assert_no_difference "JwtAnomalyEvent.count" do
      assert_nothing_raised { JwtAnomalySubscriber.new.emit(mock_event) }
    end
  end

  def setup_anomaly_event_test
    occurred_at = Time.current.change(usec: 0)
    mock_event = MockEvent.new(
      name: "jwt.anomaly.detected",
      payload: {
        code: "AUTH_USER_MALFORMED_TOKEN",
        request_host: "id.app.localhost",
        kid: "kid-1",
        alg: "ES384",
        typ: "JWT",
        iss: "jit",
        jti: "jti-123",
        error_class: "JWT::DecodeError",
        error_message: "invalid token",
        extra: "kept",
      },
      time: occurred_at,
    )

    subscriber = JwtAnomalySubscriber.new

    assert_difference "JwtAnomalyEvent.count", 1 do
      subscriber.emit(mock_event)
    end

    [JwtAnomalyEvent.order(:id).last, occurred_at]
  end

  test "emit creates anomaly event linked to occurrence" do
    event, _occurred_at = setup_anomaly_event_test

    assert_equal jwt_occurrences(:auth_user_malformed_token), event.jwt_occurrence
    assert_equal "AUTH_USER_MALFORMED_TOKEN", event.code
  end

  test "emit resolves each current authentication context catalog" do
    codes = %w(AUTH_CLIENT_CLAIM_INVALID AUTH_OPERATOR_DECODE_FAILED AUTH_VISITOR_UNKNOWN_KID)
    codes.each_with_index do |code, index|
      JwtOccurrence.create!(
        body: code,
        memo: "current reference row",
        public_id: format("jwt_current_%09d", index + 1),
        status_id: JwtOccurrenceStatus::ACTIVE,
      )

      assert_difference "JwtAnomalyEvent.count", 1 do
        JwtAnomalySubscriber.new.emit(
          MockEvent.new(name: "jwt.anomaly.detected", payload: { code: code }),
        )
      end

      event = JwtAnomalyEvent.order(:id).last

      assert_equal code, event.code
      assert_equal code, event.jwt_occurrence.body
    end
  end

  test "the registered notification subscriber persists an anomaly event" do
    assert_difference "JwtAnomalyEvent.count", 1 do
      ActiveSupport::Notifications.instrument(
        "jwt.anomaly.detected",
        code: "AUTH_USER_MALFORMED_TOKEN",
        request_host: "id.app.localhost",
      )
    end

    assert_equal "AUTH_USER_MALFORMED_TOKEN", JwtAnomalyEvent.order(:id).last.code
  end

  test "emit stores jwt header fields correctly" do
    event, _occurred_at = setup_anomaly_event_test

    assert_equal "kid-1", event.kid
    assert_equal "ES384", event.alg
    assert_equal "JWT", event.typ
  end

  test "emit stores jwt claim fields correctly" do
    event, _occurred_at = setup_anomaly_event_test

    assert_equal "jit", event.issuer
    assert_equal "jti-123", event.jti
  end

  test "emit stores error information correctly" do
    event, _occurred_at = setup_anomaly_event_test

    assert_equal "JWT::DecodeError", event.error_class
    assert_equal "invalid token", event.error_message
    assert_equal({}, event.metadata)
  end

  test "emit does not persist a raw JWT-shaped error message" do
    raw_jwt = "eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiJzZWNyZXQifQ.signature-value"
    mock_event = MockEvent.new(
      name: "jwt.anomaly.detected",
      payload: {
        code: "AUTH_USER_MALFORMED_TOKEN",
        error_message: "invalid token #{raw_jwt}",
      },
    )

    assert_difference "JwtAnomalyEvent.count", 1 do
      JwtAnomalySubscriber.new.emit(mock_event)
    end

    event = JwtAnomalyEvent.order(:id).last

    assert_not_includes event.error_message, raw_jwt
    assert_includes event.error_message, "[FILTERED]"
  end

  test "emit sanitizes diagnostic fields at the persistence boundary" do
    raw_jwt = "eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiJzZWNyZXQifQ.signature-value"
    mock_event = MockEvent.new(
      name: "jwt.anomaly.detected",
      payload: {
        code: "AUTH_USER_MALFORMED_TOKEN",
        request_host: raw_jwt,
        kid: raw_jwt,
        alg: raw_jwt,
        typ: raw_jwt,
        iss: raw_jwt,
        jti: raw_jwt,
        error_class: raw_jwt,
      },
    )

    assert_difference "JwtAnomalyEvent.count", 1 do
      JwtAnomalySubscriber.new.emit(mock_event)
    end

    event = JwtAnomalyEvent.order(:id).last
    persisted_values = event.attributes.values_at(
      "request_host", "kid", "alg", "typ", "issuer", "jti", "error_class",
    )

    persisted_values.each do |value|
      assert_not_includes value, raw_jwt
      assert_includes value, "[FILTERED]"
    end
  end

  test "emit stores request host and timestamp correctly" do
    event, occurred_at = setup_anomaly_event_test

    assert_equal "id.app.localhost", event.request_host
    assert_equal occurred_at, event.occurred_at
  end

  test "emit records a catalog miss when occurrence is not found" do
    mock_event = MockEvent.new(
      name: "jwt.anomaly.detected",
      payload: { code: "UNKNOWN_CODE" },
    )

    subscriber = JwtAnomalySubscriber.new

    logged_message = nil

    Rails.logger.stub(:error, ->(message) { logged_message = message }) do
      assert_no_difference "JwtAnomalyEvent.count" do
        subscriber.emit(mock_event)
      end
    end

    payload = JSON.parse(logged_message)

    assert_equal "jwt.anomaly.catalog_miss", payload.fetch("event")
    assert_equal "UNKNOWN_CODE", payload.dig("data", "reason_code")
  end

  test "emit does not log malformed catalog codes" do
    secret = "token=not-for-logs"
    mock_event = MockEvent.new(
      name: "jwt.anomaly.detected",
      payload: { code: secret },
    )

    logged_message = nil

    Rails.logger.stub(:error, ->(message) { logged_message = message }) do
      assert_no_difference "JwtAnomalyEvent.count" do
        JwtAnomalySubscriber.new.emit(mock_event)
      end
    end

    payload = JSON.parse(logged_message)

    assert_equal "INVALID", payload.dig("data", "reason_code")
    assert_equal secret.bytesize, payload.dig("data", "reason_code_length")
    assert_not_includes logged_message, secret
  end

  test "build_metadata does not retain unallowlisted event fields" do
    subscriber = JwtAnomalySubscriber.new

    metadata = subscriber.send(
      :build_metadata,
      {
        :code => "AUTH_USER_MALFORMED_TOKEN",
        "request_host" => "id.app.localhost",
        :kid => "kid-1",
        :alg => "ES384",
        :typ => "JWT",
        :iss => "jit",
        :jti => "jti-123",
        :error_class => "JWT::DecodeError",
        :error_message => "invalid token",
        :extra => "kept",
        "another" => "kept-too",
      },
    )

    assert_equal({}, metadata)
  end

  test "emit logs and swallows persistence errors from event creation" do
    logged_message = nil
    mock_event = MockEvent.new(
      name: "jwt.anomaly.detected",
      payload: { code: "AUTH_USER_MALFORMED_TOKEN" },
    )

    JwtAnomalyEvent.stub(:create!, ->(**) { raise ActiveRecord::ActiveRecordError, "explode" }) do
      Rails.logger.stub(:error, ->(message) { logged_message = message }) do
        JwtAnomalySubscriber.new.emit(mock_event)
      end
    end

    payload = JSON.parse(logged_message)

    assert_equal "jwt.anomaly.subscriber_failed", payload.fetch("event")
    assert_equal "ActiveRecord::ActiveRecordError", payload.dig("data", "error_class")
    assert_equal "explode", payload.dig("data", "message")
  end

  test "emit sanitizes persistence error messages before logging" do
    raw_jwt = "eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiJzZWNyZXQifQ.signature-value"
    logged_message = nil
    mock_event = MockEvent.new(
      name: "jwt.anomaly.detected",
      payload: { code: "AUTH_USER_MALFORMED_TOKEN" },
    )

    JwtAnomalyEvent.stub(
      :create!,
      ->(**) { raise ActiveRecord::ActiveRecordError, "database rejected #{raw_jwt}" },
    ) do
      Rails.logger.stub(:error, ->(message) { logged_message = message }) do
        JwtAnomalySubscriber.new.emit(mock_event)
      end
    end

    payload = JSON.parse(logged_message)

    assert_not_includes logged_message, raw_jwt
    assert_includes payload.dig("data", "message"), "[FILTERED]"
  end
end
