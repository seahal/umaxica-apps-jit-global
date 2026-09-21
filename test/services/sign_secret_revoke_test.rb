# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class SignSecretRevokeTest < ActiveSupport::TestCase
  test "sets revoked and discarded timestamps and records the event" do
    now = Time.zone.parse("2026-06-14 12:00:00 UTC")
    saved = []
    credential = Class.new do
      attr_accessor :revoked_at, :discard_at
      attr_reader :reloads

      def initialize(saved)
        @saved = saved
        @reloads = 0
      end

      def with_lock
        yield
      end

      def reload
        @reloads += 1
      end

      def save!
        @saved << [revoked_at, discard_at]
      end
    end.new(saved)

    captured = nil
    SignSecretRecordEvent.stub(:call, ->(**kwargs) { captured = kwargs }) do
      result = SignSecretRevoke.call(secret_credential: credential, now: now)

      assert_same credential, result.secret_credential
    end

    assert_equal 1, credential.reloads
    assert_equal [[now, now]], saved
    assert_equal "secret.revoked", captured.fetch(:event_name)
    assert_same credential, captured.fetch(:secret_credential)
  end
end
