# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"
require Rails.root.join("app/subscribers/jwt_anomaly_subscriber")

class JwtAnomalySubscriberCoverageTest < ActiveSupport::TestCase
  fixtures :jwt_occurrences

  class MockEvent
    attr_reader :name, :payload, :time

    def initialize(name:, payload:, time: nil)
      @name = name
      @payload = payload
      @time = time
    end
  end

  test "emit creates anomaly event without unallowlisted metadata" do
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
      time: Time.current.change(usec: 0),
    )

    assert_difference "JwtAnomalyEvent.count", 1 do
      JwtAnomalySubscriber.new.emit(mock_event)
    end

    event = JwtAnomalyEvent.order(:id).last

    assert_equal jwt_occurrences(:auth_user_malformed_token), event.jwt_occurrence
    assert_equal({}, event.metadata)
  end

  test "emit ignores unrelated events and logs creation failures" do
    assert_no_difference "JwtAnomalyEvent.count" do
      JwtAnomalySubscriber.new.emit(MockEvent.new(name: "other.event", payload: { code: "AUTH_USER_MALFORMED_TOKEN" }))
    end

    logged_message = nil
    Rails.logger.stub(:error, proc { |message = nil| logged_message = message if message }) do
      JwtAnomalyEvent.stub(:create!, ->(**) { raise ActiveRecord::ActiveRecordError, "explode" }) do
        JwtAnomalySubscriber.new.emit(
          MockEvent.new(
            name: "jwt.anomaly.detected",
            payload: { code: "AUTH_USER_MALFORMED_TOKEN" },
          ),
        )
      end
    end

    assert_includes logged_message, "jwt.anomaly.subscriber_failed"
  end

  test "emit ignores blank codes and events without a name" do
    assert_no_difference "JwtAnomalyEvent.count" do
      JwtAnomalySubscriber.new.emit(MockEvent.new(name: "jwt.anomaly.detected", payload: {}))
      JwtAnomalySubscriber.new.emit(MockEvent.new(name: nil, payload: { code: "AUTH_USER_MALFORMED_TOKEN" }))
    end
  end

  test "emit accepts string keyed payloads and defaults occurred_at to current time" do
    travel_to Time.zone.parse("2026-06-15 21:00:00") do
      assert_difference "JwtAnomalyEvent.count", 1 do
        JwtAnomalySubscriber.new.emit(
          MockEvent.new(
            name: "jwt.anomaly.detected",
            payload: { "code" => "AUTH_USER_MALFORMED_TOKEN", "extra" => "kept" },
          ),
        )
      end
    end

    event = JwtAnomalyEvent.order(:id).last

    assert_equal({}, event.metadata)
    assert_equal Time.zone.parse("2026-06-15 21:00:00"), event.occurred_at
  end

  test "build_metadata excludes unallowlisted fields" do
    subscriber = JwtAnomalySubscriber.new
    payload = {
      code: "TEST_CODE",
      request_host: "host",
      kid: "kid",
      alg: "alg",
      typ: "typ",
      iss: "iss",
      jti: "jti",
      error_class: "Error",
      error_message: "msg",
      extra_field1: "extra1",
      extra_field2: "extra2",
    }

    metadata = subscriber.send(:build_metadata, payload)

    assert_equal({}, metadata)
  end
end
