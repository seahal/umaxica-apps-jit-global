# typed: false
# frozen_string_literal: true

class SignSecretVerify
  Result = Struct.new(:secret_credential, :reason, :details, keyword_init: true)

  def self.call(secret_credential:, raw_secret_credential:, now: Time.current)
    new(secret_credential: secret_credential, raw_secret_credential: raw_secret_credential, now: now).call
  end

  def initialize(secret_credential:, raw_secret_credential:, now:)
    @secret_credential = secret_credential
    @raw_secret_credential = raw_secret_credential.to_s
    @now = now
  end

  def call
    return failure(:secret_credential_mismatch) if @secret_credential.blank?
    return failure(:secret_credential_mismatch) if @raw_secret_credential.blank?

    @secret_credential.with_lock do
      @secret_credential.reload

      return failure(:secret_credential_consumed) if consumed? && single_use?
      return failure(:secret_credential_revoked) if revoked?
      return failure(:secret_credential_revoked) if
        @secret_credential.respond_to?(:active?) && !@secret_credential.active?
      return failure(:secret_credential_expired) if lapsed?
      return failure(:secret_credential_not_before) if not_before?
      return failure(:secret_credential_locked) if locked?
      return failure(:secret_credential_consumed) if max_uses_exceeded?
      return failure(:secret_credential_locked) if @secret_credential.usage_policy.to_s == "limited_session"

      expected_lookup_digest = SignSecretLookupDigest.digest(@raw_secret_credential)
      stored_lookup_digest = @secret_credential.lookup_digest.to_s
      return failure(:secret_credential_mismatch) if stored_lookup_digest.blank?
      return failure(:secret_credential_mismatch) unless
        expected_lookup_digest.length == stored_lookup_digest.length
      return failure(:secret_credential_mismatch) unless secure_compare(
        expected_lookup_digest,
        stored_lookup_digest,
      )
      return failure(:secret_credential_mismatch) unless @secret_credential.authenticate(@raw_secret_credential)

      consume_success!
      @secret_credential.save!
    end

    SignSecretRecordEvent.call(event_name: "secret.verified", secret_credential: @secret_credential)
    success
  rescue StandardError => e
    failure(:internal_error, error_class: e.class.name)
  end

  private

  def consume_success!
    @secret_credential.last_used_at = @now if @secret_credential.respond_to?(:last_used_at=)
    @secret_credential.use_count = @secret_credential.use_count.to_i + 1 if
      @secret_credential.respond_to?(:use_count=)
    return unless single_use? || max_uses_exceeded?

    @secret_credential.consumed_at = @now
    mark_status!(:used)

  end

  def failure(reason, details = {})
    if @secret_credential.present? && @secret_credential.respond_to?(:failure_count=) &&
        reason == :secret_credential_mismatch
      @secret_credential.failure_count = @secret_credential.failure_count.to_i + 1
      @secret_credential.last_failed_at = @now if @secret_credential.respond_to?(:last_failed_at=)
      if max_failures_exceeded?
        @secret_credential.locked_at = @now if @secret_credential.respond_to?(:locked_at=)
        mark_status!(:revoked)
      end
      @secret_credential.save! if @secret_credential.changed?
    end

    Result.new(secret_credential: nil, reason: reason, details: details)
  end

  def success
    Result.new(
      secret_credential: @secret_credential, reason: :success,
      details: { secret_credential_id: @secret_credential.id },
    )
  end

  def single_use?
    return true if @secret_credential.usage_policy.to_s == "single_use"
    return false if @secret_credential.usage_policy.to_s == "multi_use"

    max_uses = @secret_credential.max_uses
    return false if max_uses.blank?

    max_uses.to_i <= 1
  end

  def max_uses_exceeded?
    max_uses = @secret_credential.max_uses
    return false if max_uses.blank?

    @secret_credential.use_count.to_i >= max_uses.to_i
  end

  def max_failures_exceeded?
    max_failures = @secret_credential.max_failures
    return false if max_failures.blank?

    @secret_credential.failure_count.to_i >= max_failures.to_i
  end

  def lapsed?
    return false if @secret_credential.discard_at.blank?
    return false if @secret_credential.discard_at.respond_to?(:infinite?) &&
      @secret_credential.discard_at.infinite?

    @now >= @secret_credential.discard_at
  end

  def revoked?
    return true if @secret_credential.respond_to?(:revoked_at) && @secret_credential.revoked_at.present?
    return true unless @secret_credential.respond_to?(:secret_kind)

    false
  end

  def not_before?
    return false if @secret_credential.not_before_at.blank?

    @now < @secret_credential.not_before_at
  end

  def locked?
    return false if @secret_credential.locked_at.blank?

    @secret_credential.locked_at <= @now
  end

  def consumed?
    @secret_credential.consumed_at.present?
  end

  def mark_status!(status)
    return unless @secret_credential.class.respond_to?(:status_id_for)
    return unless @secret_credential.class.respond_to?(:identity_secret_credential_status_id_column)

    @secret_credential[@secret_credential.class.identity_secret_credential_status_id_column] =
      @secret_credential.class.status_id_for(status)
  end

  def secure_compare(left, right)
    ActiveSupport::SecurityUtils.secure_compare(left, right)
  end
end
