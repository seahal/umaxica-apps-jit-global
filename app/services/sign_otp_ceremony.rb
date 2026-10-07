# typed: false
# frozen_string_literal: true

class SignOtpCeremony
  Result = Struct.new(:success?, :status, :record, :code, :error, keyword_init: true)

  OTP_EXPIRATION = CommonOtpPolicy::SIGN_UP_CONFIRMATION_TTL

  def self.issue!(...)
    new(...).issue!
  end

  def self.verify!(...)
    new(...).verify!
  end

  def initialize(purpose:, surface:, channel:, subject:, destination: nil, code: nil,
                 session_nonce: nil, request_context: nil)
    @purpose = purpose.to_sym
    @surface = surface.to_sym
    @channel = channel.to_sym
    @subject = subject
    @destination = destination
    @code = code
    @session_nonce = session_nonce
    @request_context = request_context
  end

  def issue!
    validate_scope!
    return session_mismatch_result unless session_nonce_matches_subject?

    subject.with_lock do
      return result(false, :inactive_flow, error: :inactive_flow) unless active_flow?

      with_candidate_owner_lock { issue_for_active_flow! }
    end
  end

  def verify!
    validate_scope!
    return session_mismatch_result unless session_nonce_matches_subject?

    subject.with_lock do
      return result(false, :inactive_flow, error: :inactive_flow) unless active_flow?

      with_candidate_owner_lock { verify_for_active_flow! }
    end
  end

  private

  attr_reader :purpose, :surface, :channel, :subject, :destination, :code, :session_nonce, :request_context

  def active_flow?
    return false if subject.sign_up_terminal?

    decision_time = subject.class.database_now
    if subject.expired?(decision_time)
      SignUpTermination.call(cycle: subject, event: :expire)
      return false
    end

    !subject.lapsed?(decision_time)
  end

  def issue_for_active_flow!
    record = bound_record
    return result(false, :missing_destination, error: :missing_destination) unless record

    validate_candidate_owner!(record)
    return result(false, :inactive_candidate, record: record, error: :inactive_candidate) if record.binding_released?
    unless destination_matches?(record)
      return result(false, :destination_mismatch, record: record, error: :destination_mismatch)
    end
    return result(false, :rate_limited, record: record, error: :rate_limited) if cooldown_active?(record)
    return result(false, :locked, record: record, error: :locked) if record.locked?

    otp_code = nil
    record.with_lock do
      return result(false, :inactive_flow, error: :inactive_flow) unless active_flow?

      validate_candidate_owner!(record)
      return result(false, :inactive_candidate, record: record, error: :inactive_candidate) if record.binding_released?
      return result(false, :locked, record: record, error: :locked) if record.locked?
      return result(false, :rate_limited, record: record, error: :rate_limited) if cooldown_active?(record)
      if record.sign_up_otp_context&.fetch("verified_at")
        return result(false, :already_verified, record: record, error: :already_verified)
      end

      otp_code = generate_and_store_otp!(record)
      unless SignUpOtpChallengeRecorder.call(flow: subject, record: record, channel: channel, code: otp_code)
        return result(false, :inactive_candidate, record: record, error: :inactive_candidate)
      end
    end
    deliver!(record, otp_code)
    result(true, :issued, record: record, code: otp_code)
  end

  def verify_for_active_flow!
    record = bound_record
    return result(false, :missing_destination, error: :missing_destination) unless record

    validate_candidate_owner!(record)
    return result(false, :inactive_candidate, record: record, error: :inactive_candidate) if record.binding_released?
    unless destination_matches?(record)
      return result(false, :destination_mismatch, record: record, error: :destination_mismatch)
    end
    return result(false, :blank_code, record: record, error: :blank_code) if code.blank?

    record.with_lock do
      return result(false, :inactive_flow, error: :inactive_flow) unless active_flow?

      validate_candidate_owner!(record)
      return result(false, :inactive_candidate, record: record, error: :inactive_candidate) if record.binding_released?

      context = record.sign_up_otp_context
      return result(false, :missing_challenge, record: record, error: :missing_challenge) unless context
      unless signup_context_current?(context, record)
        return result(false, :binding_mismatch, record: record, error: :binding_mismatch)
      end
      return result(
        false, :invalid_code, record: record,
                              error: :invalid_code,
      ) unless code.is_a?(String) && code.match?(/\A[0-9]{6}\z/)

      now = record.class.database_now
      return verify_committed_signup_proof(record, context, now) if context.fetch("verified_at")

      verify_issued_signup_challenge(record, context, now)
    end
  end

  def verify_committed_signup_proof(record, context, now)
    if Time.iso8601(context.fetch("result_expires_at")) <= now
      return result(false, :result_expired, record: record, error: :result_expired)
    end

    valid_retry = signup_context_code_matches?(context)
    retry_budget = OtpVerificationFailureBudget.new.verify!(
      surface: surface, purpose: purpose, channel: channel,
      destination_digest: destination_digest(record), valid: valid_retry,
    )
    record.increment_attempts! unless valid_retry
    return result(false, :locked, record: record, error: :locked) if retry_budget == :locked || record.locked?

    result(valid_retry, valid_retry ? :verified : :invalid_code, record: record)
  end

  def verify_issued_signup_challenge(record, context, now)
    otp_data = record.get_otp
    return result(false, :missing_otp, record: record, error: :missing_otp) unless otp_data

    hotp = ROTP::HOTP.new(otp_data[:otp_private_key])
    expected_code = hotp.at(otp_data[:otp_counter]).to_s
    valid = otp_code_matches?(expected_code, code) && signup_context_code_matches?(context)
    budget_status = OtpVerificationFailureBudget.new.verify!(
      surface: surface, purpose: purpose, channel: channel,
      destination_digest: destination_digest(record), valid: valid,
    )
    if budget_status == :verified
      record.clear_otp
      record.update!(
        sign_up_otp_context: context.merge(
          "verified_at" => now.utc.iso8601(6),
          "result_expires_at" => [now + 60.seconds, subject.expires_at].min.utc.iso8601(6),
        ),
      )
      return result(true, :verified, record: record)
    end

    record.increment_attempts! unless valid
    return result(false, :locked, record: record, error: :locked) if budget_status == :locked
    return result(false, :locked, record: record, error: :locked) if record.locked?

    result(false, :invalid_code, record: record, error: :invalid_code)
  end

  def with_candidate_owner_lock
    record = bound_record
    return result(false, :missing_destination, error: :missing_destination) unless record

    validate_candidate_owner!(record)
    owner_model = (surface == :app) ? Client : Visitor
    owner = owner_model.find_by(id: subject.principal_id)
    return result(false, :inactive_candidate, error: :inactive_candidate) unless owner

    owner.with_lock do
      pending_status = (surface == :app) ? ClientStatus::UNVERIFIED_WITH_SIGN_UP : VisitorStatus::ACTIVE
      unless owner.status_id == pending_status && owner.active? && owner.access_enabled? &&
          owner.accessible?(owner.class.database_now)
        return result(false, :inactive_candidate, error: :inactive_candidate)
      end

      yield
    end
  end

  def signup_context_current?(context, record)
    owner = (surface == :app) ? record.user : record.visitor
    context.fetch("version") == 1 && context.fetch("surface") == surface.to_s &&
      context.fetch("purpose") == "sign_up" && context.fetch("flow_ref") == subject.public_id &&
      context.fetch("nonce_digest") == subject.nonce_digest && context.fetch("owner_ref") == owner.public_id &&
      context.fetch("contact_ref") == record.public_id &&
      context.fetch("destination_digest") == destination_digest(record) &&
      !record.binding_finalized_at && record.accessible?(record.class.database_now) &&
      (context.fetch("verified_at") || context.fetch("counter") == record.otp_counter.to_s)
  end

  def signup_context_code_matches?(context)
    expected = context.fetch("code_digest")
    submitted = SignUpOtpCodeDigest.for(context: context, channel: channel, code: code)
    expected.bytesize == submitted.bytesize && ActiveSupport::SecurityUtils.secure_compare(expected, submitted)
  end

  def validate_scope!
    raise ArgumentError, "unsupported OTP purpose" unless purpose == :sign_up
    raise ArgumentError, "unsupported OTP surface" unless %i(app com).include?(surface)
    raise ArgumentError, "unsupported OTP channel" unless %i(email telephone).include?(channel)
    raise ArgumentError, "OTP subject does not match surface" unless subject_matches_surface?
    return if subject.pending_contact_type == channel.to_s

    raise ArgumentError, "OTP channel does not match sign-up ticket"
  end

  def subject_matches_surface?
    case surface
    when :app then subject.is_a?(ClientSignUpFlow)
    when :com then subject.is_a?(VisitorSignUpFlow)
    else false
    end
  end

  def bound_record
    return if subject.pending_contact_id.blank?

    expected_record_class.find_by(id: subject.pending_contact_id)
  end

  def expected_record_class
    case [surface, channel]
    when [:app, :email] then ClientEmail
    when [:app, :telephone] then ClientTelephone
    when [:com, :email] then VisitorEmail
    when [:com, :telephone] then VisitorTelephone
    else raise ArgumentError, "unsupported OTP record scope"
    end
  end

  def validate_candidate_owner!(record)
    owner_id =
      case surface
      when :app then record.user_id
      when :com then record.visitor_id
      else raise ArgumentError, "unsupported OTP owner scope"
      end
    return if subject.principal_id.present? && owner_id == subject.principal_id

    raise ArgumentError, "signup OTP candidate does not belong to Ticket Identity"
  end

  def destination_matches?(record)
    expected_digest = destination_digest(record)
    return true if destination.blank? || expected_digest.blank?

    normalized_digest(destination) == expected_digest
  end

  def destination_digest(record)
    case channel
    when :email then record.address_digest
    when :telephone then record.number_digest
    end
  end

  def normalized_digest(value)
    case channel
    when :email then IdentifierBlindIndex.bidx_for_email(value)
    when :telephone then IdentifierBlindIndex.bidx_for_telephone(value)
    end
  end

  def cooldown_active?(record)
    return record.otp_cooldown_active? if record.respond_to?(:otp_cooldown_active?)

    decision_time = record.class.database_now
    return false unless record.respond_to?(:otp_last_sent_at)
    return false if record.otp_last_sent_at.blank?
    return false if record.otp_last_sent_at == -Float::INFINITY

    record.otp_last_sent_at > decision_time - CommonOtpPolicy::SEND_COOLDOWN
  end

  def generate_and_store_otp!(record)
    otp_private_key = ROTP::Base32.random_base32
    otp_counter = SecureRandom.random_number(1 << 64)
    otp_code = ROTP::HOTP.new(otp_private_key).at(otp_counter).to_s
    decision_time = record.class.database_now
    record.store_otp(
      otp_private_key,
      otp_counter,
      (decision_time + OTP_EXPIRATION).to_i,
      now: decision_time,
    )
    otp_code
  end

  def otp_code_matches?(expected, submitted)
    expected_value = expected.to_s
    submitted_value = submitted.to_s
    return false unless submitted_value.match?(/\A\d{#{expected_value.length}}\z/)

    ActiveSupport::SecurityUtils.secure_compare(expected_value, submitted_value)
  end

  def deliver!(record, otp_code)
    OtpAdapter
      .for(surface: surface, channel: channel)
      .deliver(
        record: record, otp_code: otp_code, purpose: purpose, public_id: record.public_id,
        sign_up_flow_ref: subject.public_id, sign_up_otp_counter: record.otp_counter.to_s,
      )
  end

  def result(success, status, record: nil, code: nil, error: nil)
    Result.new(success?: success, status: status, record: record, code: code, error: error)
  end

  def session_mismatch_result
    result(false, :session_mismatch, error: :session_mismatch)
  end

  def session_nonce_matches_subject?
    return false unless subject.respond_to?(:public_id)

    expected = subject.public_id.to_s
    supplied = session_nonce.to_s
    return false if expected.blank? || supplied.blank? || expected.bytesize != supplied.bytesize

    ActiveSupport::SecurityUtils.secure_compare(expected, supplied)
  end
end
