# typed: false
# frozen_string_literal: true

# Verifies a TOTP code against an account's active credentials and owns the retry protection
# around that verification.
#
# Every attempt runs in one transaction that locks all of the account's active credential rows
# (in primary-key order, so concurrent attempts cannot deadlock). The lock check, the code
# check, the replay check, and the failure-count update therefore see one consistent state, and
# concurrent attempts against one account are serialized: none of them can read a stale count
# and lose an increment, and a success cannot interleave with a failure's update.
#
# The failure state lives in PostgreSQL (ClientTotpCredential#record_totp_failure!), not in the
# rate-limit store, so a Valkey outage or flush does not lift the lockout.
class TotpWindowConsumer
  Result =
    Data.define(:status, :credential, :otp_at, :locked_until) do
      def initialize(status:, credential: nil, otp_at: nil, locked_until: nil)
        super
      end

      def accepted? = status == :accepted

      def replay? = status == :replay

      def locked? = status == :locked
    end

  def self.call(credentials:, token:, now: Time.current)
    new(credentials:, token:, now:).call
  end

  def initialize(credentials:, token:, now:)
    @credentials = credentials
    @token = token.to_s
    @now = now
  end

  def call
    credentials.klass.transaction do
      locked_rows = credentials.reorder(:id).lock.to_a
      next Result.new(status: :mismatch) if locked_rows.empty?

      locked_until = locked_rows.filter_map { |credential| credential.totp_locked_until(now) }.max
      next Result.new(status: :locked, locked_until: locked_until) if locked_until

      verify(locked_rows)
    end
  end

  private

  attr_reader :credentials, :token, :now

  def verify(locked_rows)
    verification_order(locked_rows).each do |credential|
      otp_at = ROTP::TOTP.new(credential.private_key).verify(token, at: now.to_i)
      next unless otp_at

      return accept(locked_rows, credential, otp_at) unless replayed?(credential, otp_at)

      return fail_attempt(locked_rows, status: :replay, credential: credential, otp_at: otp_at)
    end

    fail_attempt(locked_rows, status: :mismatch)
  end

  # Newest credential first, matching the order callers pass in.
  def verification_order(locked_rows)
    locked_rows.sort_by { |credential| [-credential.created_at.to_f, -credential.id] }
  end

  def replayed?(credential, otp_at)
    stored = credential.last_otp_at
    stored_finite = stored.present? && !(stored.respond_to?(:infinite?) && stored.infinite?)
    stored_finite && stored.to_i >= otp_at.to_i
  end

  def accept(locked_rows, credential, otp_at)
    credential.update!(last_otp_at: Time.zone.at(otp_at))
    locked_rows.each(&:reset_totp_attempts!)
    Result.new(status: :accepted, credential: credential, otp_at: otp_at)
  end

  def fail_attempt(locked_rows, status:, credential: nil, otp_at: nil)
    locked_rows.each { |row| row.record_totp_failure!(now) }
    Result.new(status: status, credential: credential, otp_at: otp_at)
  end
end
