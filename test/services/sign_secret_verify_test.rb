# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class SignSecretVerifyTest < ActiveSupport::TestCase
  setup do
    @now = Time.zone.parse("2026-06-24 12:00:00 UTC")
  end

  test "verifies a matching multi-use secret credential, updates usage, and records the event" do
    credential = build_credential(usage_policy: "multi_use")
    event = nil

    SignSecretLookupDigest.stub(:digest, ->(_raw) { credential.lookup_digest }) do
      SignSecretRecordEvent.stub(:call, ->(**kwargs) { event = kwargs }) do
        result = SignSecretVerify.call(secret_credential: credential, raw_secret_credential: "raw-1", now: @now)

        assert_equal :success, result.reason
        assert_same credential, result.secret_credential
        assert_equal credential.id, result.details[:secret_credential_id]
      end
    end

    assert_equal 1, credential.reloads
    assert_equal @now, credential.last_used_at
    assert_equal 1, credential.use_count
    assert_nil credential.consumed_at
    assert_equal 1, credential.saved
    assert_equal "secret.verified", event.fetch(:event_name)
    assert_same credential, event.fetch(:secret_credential)
  end

  test "verifies a single-use credential and marks it consumed and used" do
    credential = build_credential(usage_policy: "single_use")

    SignSecretLookupDigest.stub(:digest, ->(_raw) { credential.lookup_digest }) do
      SignSecretRecordEvent.stub(:call, ->(**kwargs) { }) do
        result = SignSecretVerify.call(secret_credential: credential, raw_secret_credential: "raw-1", now: @now)

        assert_equal :success, result.reason
      end
    end

    assert_equal @now, credential.consumed_at
    assert_equal "USED", credential.columns[:status_id]
    assert_equal 1, credential.saved
  end

  test "treats an unset usage policy with no max uses as multi-use" do
    credential = build_credential(usage_policy: nil, max_uses: nil)

    SignSecretLookupDigest.stub(:digest, ->(_raw) { credential.lookup_digest }) do
      SignSecretRecordEvent.stub(:call, ->(**kwargs) { }) do
        result = SignSecretVerify.call(secret_credential: credential, raw_secret_credential: "raw-1", now: @now)

        assert_equal :success, result.reason
      end
    end

    assert_nil credential.consumed_at
  end

  test "treats an unset usage policy with a max uses of one as single-use" do
    credential = build_credential(usage_policy: nil, max_uses: 1)

    SignSecretLookupDigest.stub(:digest, ->(_raw) { credential.lookup_digest }) do
      SignSecretRecordEvent.stub(:call, ->(**kwargs) { }) do
        result = SignSecretVerify.call(secret_credential: credential, raw_secret_credential: "raw-1", now: @now)

        assert_equal :success, result.reason
      end
    end

    assert_equal @now, credential.consumed_at
    assert_equal "USED", credential.columns[:status_id]
  end

  test "fails with mismatch when the credential is blank" do
    result = SignSecretVerify.call(secret_credential: nil, raw_secret_credential: "raw-1", now: @now)

    assert_equal :secret_credential_mismatch, result.reason
    assert_nil result.secret_credential
  end

  test "fails with mismatch when the raw secret is blank and increments failure count" do
    credential = build_credential

    result = SignSecretVerify.call(secret_credential: credential, raw_secret_credential: "", now: @now)

    assert_equal :secret_credential_mismatch, result.reason
    assert_equal 1, credential.failure_count
    assert_equal @now, credential.last_failed_at
    assert_equal 1, credential.saved
  end

  test "fails with consumed when a single-use credential is already consumed" do
    credential = build_credential(usage_policy: "single_use", consumed_at: @now - 1.minute)

    result = SignSecretVerify.call(secret_credential: credential, raw_secret_credential: "raw-1", now: @now)

    assert_equal :secret_credential_consumed, result.reason
  end

  test "fails with revoked when revoked_at is present" do
    credential = build_credential(revoked_at: @now - 1.minute)

    result = SignSecretVerify.call(secret_credential: credential, raw_secret_credential: "raw-1", now: @now)

    assert_equal :secret_credential_revoked, result.reason
  end

  test "fails with revoked when the credential is not active" do
    credential = build_credential(active_value: false)

    result = SignSecretVerify.call(secret_credential: credential, raw_secret_credential: "raw-1", now: @now)

    assert_equal :secret_credential_revoked, result.reason
  end

  test "fails with expired when discard_at has lapsed" do
    credential = build_credential(discard_at: @now - 1.minute)

    result = SignSecretVerify.call(secret_credential: credential, raw_secret_credential: "raw-1", now: @now)

    assert_equal :secret_credential_expired, result.reason
  end

  test "fails with not_before when not_before_at is in the future" do
    credential = build_credential(not_before_at: @now + 1.minute)

    result = SignSecretVerify.call(secret_credential: credential, raw_secret_credential: "raw-1", now: @now)

    assert_equal :secret_credential_not_before, result.reason
  end

  test "fails with locked when locked_at is in the past" do
    credential = build_credential(locked_at: @now - 1.minute)

    result = SignSecretVerify.call(secret_credential: credential, raw_secret_credential: "raw-1", now: @now)

    assert_equal :secret_credential_locked, result.reason
  end

  test "fails with consumed when max uses is exceeded" do
    credential = build_credential(max_uses: 1, use_count: 1)

    result = SignSecretVerify.call(secret_credential: credential, raw_secret_credential: "raw-1", now: @now)

    assert_equal :secret_credential_consumed, result.reason
  end

  test "fails with locked when usage policy is limited_session" do
    credential = build_credential(usage_policy: "limited_session")

    result = SignSecretVerify.call(secret_credential: credential, raw_secret_credential: "raw-1", now: @now)

    assert_equal :secret_credential_locked, result.reason
  end

  test "fails with mismatch when the stored lookup digest is blank" do
    credential = build_credential(lookup_digest: "")

    result = SignSecretVerify.call(secret_credential: credential, raw_secret_credential: "raw-1", now: @now)

    assert_equal :secret_credential_mismatch, result.reason
  end

  test "fails with mismatch when digest lengths differ" do
    credential = build_credential(lookup_digest: "dddddddd")

    SignSecretLookupDigest.stub(:digest, ->(_raw) { "x" * 9 }) do
      result = SignSecretVerify.call(secret_credential: credential, raw_secret_credential: "raw-1", now: @now)

      assert_equal :secret_credential_mismatch, result.reason
    end
  end

  test "fails with mismatch when the digest comparison fails" do
    credential = build_credential(lookup_digest: "AAAAAAAA")

    SignSecretLookupDigest.stub(:digest, ->(_raw) { "BBBBBBBB" }) do
      result = SignSecretVerify.call(secret_credential: credential, raw_secret_credential: "raw-1", now: @now)

      assert_equal :secret_credential_mismatch, result.reason
    end
  end

  test "fails with mismatch when authenticate rejects the raw secret" do
    credential = build_credential(authenticate_result: false)

    SignSecretLookupDigest.stub(:digest, ->(_raw) { credential.lookup_digest }) do
      result = SignSecretVerify.call(secret_credential: credential, raw_secret_credential: "raw-1", now: @now)

      assert_equal :secret_credential_mismatch, result.reason
    end
  end

  test "locks the credential when a mismatch pushes failure count over the max" do
    credential = build_credential(max_failures: 3, failure_count: 2)

    result = SignSecretVerify.call(secret_credential: credential, raw_secret_credential: "raw-1", now: @now)

    assert_equal :secret_credential_mismatch, result.reason
    assert_equal 3, credential.failure_count
    assert_equal @now, credential.locked_at
    assert_equal "REVOKED", credential.columns[:status_id]
    assert_equal 1, credential.saved
  end

  test "rescues internal errors into a failure result" do
    credential = build_credential
    credential.raise_on_authenticate = true

    SignSecretLookupDigest.stub(:digest, ->(_raw) { credential.lookup_digest }) do
      result = SignSecretVerify.call(secret_credential: credential, raw_secret_credential: "raw-1", now: @now)

      assert_equal :internal_error, result.reason
      assert_equal "StandardError", result.details[:error_class]
    end
  end

  private

  def build_credential(**overrides)
    credential = FakeCredential.new
    overrides.each { |key, value| credential.public_send("#{key}=", value) }
    credential
  end

  class FakeCredential
    attr_accessor :id, :lookup_digest, :usage_policy, :revoked_at, :discard_at, :not_before_at,
                  :max_uses, :max_failures, :secret_kind, :active_value, :authenticate_result,
                  :raise_on_authenticate
    attr_reader :reloads, :saved, :columns, :locked_at, :consumed_at, :last_used_at, :last_failed_at,
                :use_count, :failure_count

    def initialize
      @id = 42
      @reloads = 0
      @saved = 0
      @columns = {}
      @use_count = 0
      @failure_count = 0
      @authenticate_result = true
      @active_value = true
      @usage_policy = "multi_use"
      @lookup_digest = "digest-abcdef"
      @secret_kind = "api_key"
      @changed = false
    end

    def self.status_id_for(status)
      status.to_s.upcase
    end

    def self.identity_secret_credential_status_id_column
      :status_id
    end

    def blank?
      false
    end

    def present?
      true
    end

    def with_lock
      yield
    end

    def reload
      @reloads += 1
      self
    end

    def save!
      @saved += 1
      true
    end

    def changed?
      @changed
    end

    def active?
      @active_value
    end

    def authenticate(_raw)
      raise StandardError, "boom" if @raise_on_authenticate

      @authenticate_result
    end

    delegate :[]=, to: :@columns

    def locked_at=(value)
      @changed = true
      @locked_at = value
    end

    def consumed_at=(value)
      @changed = true
      @consumed_at = value
    end

    def last_used_at=(value)
      @changed = true
      @last_used_at = value
    end

    def last_failed_at=(value)
      @changed = true
      @last_failed_at = value
    end

    def use_count=(value)
      @changed = true
      @use_count = value
    end

    def failure_count=(value)
      @changed = true
      @failure_count = value
    end
  end
end
