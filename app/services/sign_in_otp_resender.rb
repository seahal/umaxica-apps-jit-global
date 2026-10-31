# typed: false
# frozen_string_literal: true

# Resends a sign-in OTP. Email is the only supported channel: SMS OTP is not an
# accepted sign-in proof, so no telephone branch exists to be re-enabled.
class SignInOtpResender
  include EmailOtpResponseTiming

  class InvalidHistory < StandardError; end

  class OpenTransaction < StandardError; end

  KIND = "email"
  SURFACES = SignInOtpResendState::SURFACES.map(&:to_sym).freeze
  EMAIL_MODELS = { app: ClientEmail }.freeze
  BASE_SECONDS = 30
  EMAIL_CAP_SECONDS = 15.minutes.to_i
  INVALID_RETRY_AFTER = 30
  MAX_HISTORY = 30

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
    return if @ceremony.is_a?(ClientAuthCeremonySession) && @ceremony.sid_digest == @browser_binding

    raise ArgumentError, "sign-in resend ceremony does not match surface and browser"

  end

  def call
    parsed = SignInOtpResendState.parse(@state, browser_binding: @browser_binding)
    return invalid_response unless parsed && parsed[:kind] == @kind && parsed[:surface] == @surface.to_s

    normalized_target = IdentifierBlindIndex.normalize_email(parsed[:target])
    return invalid_response if normalized_target.blank?

    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    if ClientAuthCeremonySession.lease_connection.transaction_open? ||
        EmailOccurrence.lease_connection.transaction_open?
      raise OpenTransaction, "sign-in OTP resend requires ownership of Auth and occurrence transactions"
    end

    response, delivery = issue_and_record!(normalized_target, parsed)
    return response if response

    deliver!(delivery) if delivery
    Response.new(status: :ok, resendable: true, retry_after: 0)
  rescue OpenTransaction, ActiveJob::EnqueueError, ActiveRecord::ConnectionNotEstablished, ActiveRecord::ConnectionFailed,
         ActiveRecord::ConnectionTimeoutError, ActiveRecord::LockWaitTimeout, ActiveRecord::Deadlocked,
         PG::ConnectionBad => e
    Rails.error.report(e, handled: true, context: { service: "otp_resend", kind: @kind })
    Response.new(status: :service_unavailable, resendable: false, retry_after: 0)
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

  # Serialize the decision even when no occurrence exists. The OTP commit must
  # precede the occurrence write, and delivery must follow the occurrence commit.
  def issue_and_record!(normalized_target, parsed)
    body = occurrence_hmac(normalized_target)
    EmailOccurrence.transaction do
      key = Digest::SHA256.digest("sign_in:email_otp_resend:#{body}").unpack1("q>")
      EmailOccurrence.lease_connection.execute("SELECT pg_advisory_xact_lock(#{key.to_i})")
      occurrence = EmailOccurrence.find_by(body: body)
      decision_time = EmailOccurrence.database_now
      issued_timestamps = parse_issued_history(occurrence&.memo)
      policy = SignInOtpResendPolicy.new(base_seconds: BASE_SECONDS, cap_seconds: EMAIL_CAP_SECONDS)
      decision = policy.evaluate(issued_timestamps: issued_timestamps, now: decision_time)

      unless decision.resendable
        log_blocked!(
          occurrence: occurrence, issued_timestamps: issued_timestamps,
          retry_after: decision.retry_after,
        )
        next [Response.new(
          status: :too_many_requests, resendable: false,
          retry_after: decision.retry_after,
        ), nil,]
      end

      issued = issue!(normalized_target, parsed)
      next [invalid_response, nil] unless issued

      occurrence ||= find_or_create_occurrence!(body)
      updated_history = (issued_timestamps + [EmailOccurrence.database_now]).last(MAX_HISTORY)
      log_issued!(occurrence: occurrence, issued_timestamps: updated_history)
      [nil, issued.fetch(:delivery)]
    end
  end

  def parse_issued_history(memo)
    return [] if memo.nil?
    return [] if memo.empty?

    match = /\Apurpose=in issued=([1-9][0-9]*(?:,[1-9][0-9]*)*)(?: retry_after=[0-9]+)?\z/.match(memo)
    raise InvalidHistory, "invalid sign-in resend history" unless match

    match[1].split(",").map { |value| Time.zone.at(Integer(value, 10)) }
  end

  def issue!(normalized_target, parsed)
    if parsed.fetch(:contact_mode) == "fake"
      return false unless @ceremony.email_otp_challenge_current?(contact: nil)

      generation = @ceremony.email_otp_context.fetch("generation")
      result = @ceremony.issue_email_otp!(
        contact: nil, destination: normalized_target, expected_generation: generation,
      )
      return false if result == false

      return { delivery: nil }
    end
    return false unless parsed.fetch(:contact_mode) == "real"

    target = EMAIL_MODELS.fetch(@surface).find_by(public_id: parsed.fetch(:contact_ref))
    return false unless target

    return false unless @ceremony.email_otp_challenge_current?(contact: target)

    owner_id = target.user_id
    return false unless owner_id.to_s.rjust(20, "0") == parsed.fetch(:owner_ref) &&
      target.binding_finalized_at.utc.iso8601(6) == parsed.fetch(:binding_fact) &&
      target.address_digest == IdentifierBlindIndex.bidx_for_email(normalized_target, realm: @surface)

    generation = @ceremony.email_otp_context.fetch("generation")
    otp_code = @ceremony.issue_email_otp!(
      contact: target, destination: normalized_target, expected_generation: generation,
    )
    return false if otp_code == false
    return { delivery: nil } if otp_code.nil?

    { delivery: { target: target, otp_code: otp_code, generation: @ceremony.email_otp_context.fetch("generation") } }
  end

  def deliver!(delivery)
    OtpAdapter
      .for(surface: @surface, channel: :email)
      .deliver(
        record: delivery.fetch(:target), otp_code: delivery.fetch(:otp_code), purpose: :sign_in,
        auth_ceremony_session_ref: @ceremony.id.to_s,
        auth_email_otp_generation: delivery.fetch(:generation),
      )
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
      EmailOccurrenceStatus.find_or_create_by!(id: EmailOccurrenceStatus::ACTIVE).id
    end

    def email_blocked_status_id
      EmailOccurrenceStatus.find_or_create_by!(id: EmailOccurrenceStatus::NOTHING).id
    end
  end
end
