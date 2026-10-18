# frozen_string_literal: true

# Owns only telephone destination failures; the other channel has an independent policy.
class TelephoneOtpVerificationFailureBudget
  FAILURE_LIMIT = 5
  WINDOW_SECONDS = 900

  VERIFICATION_SCRIPT = <<~LUA.freeze
    local raw = redis.call('GET', KEYS[1])
    local count = 0
    if raw then
      if not string.match(raw, '^[1-5]$') or redis.call('PTTL', KEYS[1]) < 0 then
        return 'corrupt'
      end
      count = tonumber(raw)
    end
    if count >= tonumber(ARGV[1]) then return 'locked' end
    if ARGV[3] == 'valid' then return 'verified' end
    if raw then
      count = redis.call('INCR', KEYS[1])
    else
      redis.call('SET', KEYS[1], '1', 'EX', ARGV[2])
      count = 1
    end
    if count >= tonumber(ARGV[1]) then return 'locked' end
    return 'invalid_code'
  LUA

  public

  def initialize(connection: nil)
    @owns_connection = connection.nil?
    @connection = connection || Umaxica::Valkey::Connection.new(
      namespace: Umaxica::Valkey::Namespaces.otp_verification(**Umaxica::Valkey::Namespaces.runtime_scope),
    )
  end

  def verify!(surface:, purpose:, channel:, destination_digest:, valid:)
    raise ArgumentError, "unsupported OTP surface" unless %i(app com org).include?(surface)
    unless %i(sign_up authentication credential_registration enforcement_recovery withdrawal_reentry).include?(purpose)
      raise ArgumentError, "unsupported OTP purpose"
    end
    raise ArgumentError, "unsupported telephone OTP channel" unless channel == :telephone
    unless destination_digest.is_a?(String) && destination_digest.match?(/\A[0-9a-f]{64}\z/)
      raise ArgumentError, "invalid OTP destination digest"
    end
    raise ArgumentError, "OTP comparison result must be boolean" unless [true, false].include?(valid)

    key = @connection.key("#{surface}:#{purpose}:#{channel}:#{destination_digest}")
    status = @connection.call(
      "EVAL", VERIFICATION_SCRIPT, 1, key, FAILURE_LIMIT, WINDOW_SECONDS, valid ? "valid" : "invalid",
    )
    return status.to_sym if %w(verified invalid_code locked).include?(status)

    raise Umaxica::Valkey::SerializationError, "invalid OTP verification budget state"
  ensure
    @connection.close if @owns_connection
  end
end
