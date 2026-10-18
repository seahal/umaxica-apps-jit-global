# typed: false
# frozen_string_literal: true

# Verifies a TOTP code against exactly one actor-owned active credential. The selected credential
# row is locked before verification, replay checking, and failure/success persistence so one
# authenticator cannot be revoked by guesses intended for another one.
class TotpWindowConsumer
  Result =
    Data.define(:status, :credential, :otp_at) do
      def initialize(status:, credential: nil, otp_at: nil)
        super
      end

      def accepted? = status == :accepted

      def replay? = status == :replay

      def revoked? = status == :revoked

      def credential_required? = status == :credential_required
    end

  def self.call(credentials:, token:, credential_public_id: nil, now: nil)
    new(credentials:, token:, credential_public_id:, now:).call
  end

  def initialize(credentials:, token:, credential_public_id:, now:)
    @credentials = credentials
    @token = token.to_s
    @credential_public_id = credential_public_id.to_s.presence
    @now = now
  end

  def call
    candidate = select_credential
    return Result.new(status: candidate) if candidate.is_a?(Symbol)
    return Result.new(status: :mismatch) unless candidate

    credentials.klass.transaction do
      credential = credentials.where(id: candidate.id).lock.first
      # The relation is ACTIVE-scoped, but the state is checked again after the row lock. A
      # concurrent revocation must not be bypassed by a stale pre-lock relation result.
      next Result.new(status: :mismatch) unless credential&.active?

      verify(credential)
    end
  end

  private

  attr_reader :credentials, :token, :credential_public_id, :now

  def select_credential
    if credential_public_id
      credentials.find_by(public_id: credential_public_id)
    else
      candidates = credentials.limit(2).to_a
      return :mismatch if candidates.empty?
      return :credential_required if candidates.length > 1

      candidates.first
    end
  end

  def verify(credential)
    decision_time = now || credential.class.database_now
    otp_at = ROTP::TOTP.new(credential.private_key).verify(token, at: decision_time.to_i)
    return fail_attempt(credential, status: :mismatch) unless otp_at

    return fail_attempt(credential, status: :replay, otp_at:) if replayed?(credential, otp_at)

    accept(credential, otp_at)
  end

  def replayed?(credential, otp_at)
    stored = credential.last_otp_at
    stored_finite = stored.present? && !(stored.respond_to?(:infinite?) && stored.infinite?)
    stored_finite && stored.to_i >= otp_at.to_i
  end

  def accept(credential, otp_at)
    return Result.new(status: :revoked, credential:) unless credential.record_totp_success!(otp_at:)

    Result.new(status: :accepted, credential:, otp_at:)
  end

  def fail_attempt(credential, status:, otp_at: nil)
    transition = credential.record_totp_failure!
    result_status = (transition == :revoked) ? :revoked : status
    Result.new(status: result_status, credential:, otp_at:)
  end
end
