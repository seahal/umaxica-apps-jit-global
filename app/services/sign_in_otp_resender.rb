# typed: false
# frozen_string_literal: true

# Resends a sign-in OTP. Email is the only supported channel: SMS OTP is not an
# accepted sign-in proof, so no telephone branch exists to be re-enabled.
class SignInOtpResender
  include EmailOtpResponseTiming

  KIND = "email"
  SURFACES = SignInOtpResendState::SURFACES.map(&:to_sym).freeze
  EMAIL_MODELS = { app: ClientEmail, com: VisitorEmail }.freeze
  BASE_SECONDS = 30
  EMAIL_CAP_SECONDS = 15.minutes.to_i
  INVALID_RETRY_AFTER = 30
  MAX_HISTORY = 30
  STATUS_ID_CACHE = Concurrent::Map.new

  Response = Struct.new(:status, :resendable, :retry_after, keyword_init: true)

  def initialize(kind:, state:, surface:, browser_binding:, ceremony:)
    @kind = kind.to_s
    raise ArgumentError, "unsupported sign-in OTP resend kind: #{@kind}" unless @kind == KIND

    @surface = surface.to_s.to_sym
    unless SURFACES.include?(@surface)
      raise ArgumentError, "unsupported sign-in OTP resend surface: #{@surface}"
    end

    @state = state
    @browser_binding = browser_binding
    @ceremony = ceremony
    expected = (@surface == :app) ? ClientAuthCeremonySession : VisitorAuthCeremonySession
    return if @ceremony.is_a?(expected) && @ceremony.sid_digest == @browser_binding

    raise ArgumentError, "sign-in resend ceremony does not match surface and browser"

  end

  def call
    parsed = SignInOtpResendState.parse(@state, browser_binding: @browser_binding)
    return invalid_response unless parsed && parsed[:kind] == @kind && parsed[:surface] == @surface.to_s

    normalized_target = IdentifierBlindIndex.normalize_email(parsed[:target])
    return invalid_response if normalized_target.blank?

    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    occurrence = find_or_create_occurrence!(occurrence_hmac(normalized_target))
    blocked_response = reserve_resend!(occurrence)
    return blocked_response if blocked_response.present?

    return invalid_response unless issue_and_send!(normalized_target, parsed)

    Response.new(status: :ok, resendable: true, retry_after: 0)
  rescue StandardError => e
    Rails.error.report(e, handled: false, context: { service: "otp_resend", kind: @kind })
    raise
  ensure
    ensure_min_elapsed(started, EmailOtpPolicy::EMAIL_AUTH_RESPONSE_MINIMUM_SECONDS) if started
  end

  private

  def invalid_response
    Response.new(status: :bad_request, resendable: false, retry_after: INVALID_RETRY_AFTER)
  end

  # EmailOccurrence validates body uniqueness, so create_or_find_by! raises
  # RecordInvalid (not RecordNotUnique) for an existing row. Look the row up
  # first and fall back to it when a concurrent request wins the insert.
  def find_or_create_occurrence!(body)
    EmailOccurrence.find_by(body: body) || EmailOccurrence.create!(body: body)
  rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid
    EmailOccurrence.find_by!(body: body)
  end

  def occurrence_hmac(normalized_target)
    OccurrenceHmac.digest(kind: @kind, body: normalized_target)
  end

  # Reserve the resend slot before provider I/O. The unique body index makes the
  # first row creation race-safe; the row lock serializes subsequent evaluations.
  # A failed provider call therefore cannot be used by concurrent requests to
  # bypass the cooldown, while the external provider is never called under the
  # occurrence database lock.
  def reserve_resend!(occurrence)
    occurrence.with_lock do
      decision_time = occurrence.class.database_now
      issued_timestamps = parse_issued_history(occurrence.memo)
      policy = SignInOtpResendPolicy.new(base_seconds: BASE_SECONDS, cap_seconds: EMAIL_CAP_SECONDS)
      decision = policy.evaluate(issued_timestamps: issued_timestamps, now: decision_time)

      if decision.resendable
        updated_history = (issued_timestamps + [decision_time]).last(MAX_HISTORY)
        log_issued!(occurrence: occurrence, issued_timestamps: updated_history)
        nil
      else
        log_blocked!(
          occurrence: occurrence, issued_timestamps: issued_timestamps,
          retry_after: decision.retry_after,
        )
        Response.new(
          status: :too_many_requests, resendable: false,
          retry_after: decision.retry_after,
        )
      end
    end
  end

  def parse_issued_history(memo)
    return [] if memo.blank?

    raw = memo.to_s[/issued=([0-9,]+)/, 1]
    return [] if raw.blank?

    raw.split(",").filter_map do |value|
      seconds = Integer(value.to_s, 10)
      Time.zone.at(seconds) if seconds.positive?
    end
  end

  def issue_and_send!(normalized_target, parsed)
    if parsed.fetch(:contact_mode) == "fake"
      return false unless @ceremony.email_otp_challenge_current?(contact: nil)

      @ceremony.issue_email_otp!(contact: nil, destination: normalized_target)
      return true
    end
    return false unless parsed.fetch(:contact_mode) == "real"

    target = EMAIL_MODELS.fetch(@surface).find_by(public_id: parsed.fetch(:contact_ref))
    return false unless target

    return false unless @ceremony.email_otp_challenge_current?(contact: target)

    owner_id = (@surface == :app) ? target.user_id : target.visitor_id
    return false unless owner_id.to_s.rjust(20, "0") == parsed.fetch(:owner_ref) &&
      target.binding_finalized_at.utc.iso8601(6) == parsed.fetch(:binding_fact) &&
      target.address_digest == IdentifierBlindIndex.bidx_for_email(normalized_target, realm: @surface)

    otp_code = @ceremony.issue_email_otp!(contact: target, destination: normalized_target)
    return true if otp_code.nil?

    OtpAdapter
      .for(surface: @surface, channel: :email)
      .deliver(
        record: target, otp_code: otp_code, purpose: :sign_in,
        auth_ceremony_session_ref: @ceremony.id.to_s,
        auth_email_otp_generation: @ceremony.email_otp_context.fetch("generation"),
      )
    true
  end

  def log_issued!(occurrence:, issued_timestamps:)
    occurrence.status_id = self.class.email_issued_status_id
    occurrence.memo = build_memo(issued_timestamps: issued_timestamps)
    occurrence.save!
  end

  def log_blocked!(occurrence:, issued_timestamps:, retry_after:)
    occurrence.status_id = self.class.email_blocked_status_id
    occurrence.memo = build_memo(issued_timestamps: issued_timestamps, retry_after: retry_after)
    occurrence.save!
  end

  def build_memo(issued_timestamps:, retry_after: nil)
    values = issued_timestamps.last(MAX_HISTORY).map { |i| epoch_seconds(i) }.join(",")
    memo = "purpose=in issued=#{values}"
    memo += " retry_after=#{Integer(retry_after.to_s, 10)}" if retry_after
    memo[0, 1000]
  end

  def epoch_seconds(value)
    return value.to_i if value.respond_to?(:to_i)

    Integer(value.to_s, 10)
  end

  class << self
    def email_issued_status_id
      status_id_for(EmailOccurrenceStatus, :ACTIVE)
    end

    def email_blocked_status_id
      status_id_for(EmailOccurrenceStatus, :NOTHING)
    end

    private

    def status_id_for(status_class, key)
      STATUS_ID_CACHE.compute_if_absent(status_class) { Concurrent::Map.new }
        .compute_if_absent(key) do
          status_id =
            case status_class.name
            when "EmailOccurrenceStatus"
              { ACTIVE: EmailOccurrenceStatus::ACTIVE, NOTHING: EmailOccurrenceStatus::NOTHING }.fetch(key)
            else
              raise KeyError, "Unsupported occurrence status class: #{status_class.name}"
            end
          status_class.find_or_create_by!(id: status_id).id
        end
    end
  end
end
