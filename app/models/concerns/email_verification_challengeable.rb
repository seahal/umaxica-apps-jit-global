# typed: false
# frozen_string_literal: true

# Adds durable, single-use Email Verification Protocol challenge state to the
# existing per-surface email ceremony transaction models. This concern does
# not parse or verify EVT packages and never changes an email credential.
module EmailVerificationChallengeable
  extend ActiveSupport::Concern

  CHALLENGE_TTL = 10.minutes
  OUTCOME_PENDING = "pending"
  OUTCOME_VERIFIED = "verified"
  OUTCOME_FALLBACK = "fallback"
  OUTCOME_REJECTED = "rejected"
  OUTCOMES = [OUTCOME_PENDING, OUTCOME_VERIFIED, OUTCOME_FALLBACK, OUTCOME_REJECTED].freeze
  TERMINAL_OUTCOMES = [OUTCOME_VERIFIED, OUTCOME_FALLBACK, OUTCOME_REJECTED].freeze
  FAILURE_REASONS = %w(
    missing_token
    feature_disabled
    unsupported_profile
    malformed_token
    email_mismatch
    nonce_mismatch
    origin_mismatch
    expired_token
    dns_failure
    metadata_failure
    jwks_failure
    signature_failure
    network_timeout
    replay_detected
  ).freeze
  OPTIONAL_METADATA_ATTRIBUTES = %i(
    evp_nonce_digest
    evp_token_digest
    evp_failure_reason
    evp_issuer
    evp_issued_at
    evp_verified_at
    evp_consumed_at
  ).freeze

  IssuedChallenge = Data.define(:transaction, :nonce)
  Error = Class.new(StandardError)
  StateError = Class.new(Error)
  ExpiredError = Class.new(Error)
  ReplayError = Class.new(Error)

  # FIXME: Violates Umaxica/NoConcernInclusionHooks; move the declarations in this block into each class that includes this concern.
  included do
    validates :evp_outcome, inclusion: { in: OUTCOMES }, allow_nil: true
    validates :evp_failure_reason, inclusion: { in: FAILURE_REASONS }, allow_nil: true
    validates :evp_attempt_count, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
    validate :evp_challenge_metadata_is_consistent
  end

  class_methods do
    def issue_evp_challenge!(actor_ref:, session_ref:, operation:, email_candidate_ref: nil,
                             normalized_email_digest: nil, now: Time.current)
      nonce = SecureRandom.urlsafe_base64(32)
      transaction = create_transaction!(
        actor_ref: actor_ref,
        session_ref: session_ref,
        operation: operation,
        email_candidate_ref: email_candidate_ref,
        normalized_email_digest: normalized_email_digest,
        expires_at: now + CHALLENGE_TTL,
        now: now,
        evp_nonce_digest: digest_evp_secret(nonce),
        evp_outcome: OUTCOME_PENDING,
      )

      IssuedChallenge.new(transaction: transaction, nonce: nonce)
    end

    def digest_evp_secret(value)
      OpenSSL::HMAC.hexdigest("SHA256", evp_digest_key, value.to_s)
    end

    private

    def evp_digest_key
      Rails.application.key_generator.generate_key("email-verification-protocol/challenge", 32)
    end
  end

  def evp_challenge_pending?(now: Time.current)
    evp_outcome == OUTCOME_PENDING && !evp_challenge_expired?(now: now)
  end

  def evp_challenge_expired?(now: Time.current)
    expires_at.blank? || expires_at <= now
  end

  def evp_nonce_matches?(nonce)
    return false if nonce.blank? || evp_nonce_digest.blank?

    ActiveSupport::SecurityUtils.secure_compare(
      evp_nonce_digest,
      self.class.digest_evp_secret(nonce),
    )
  end

  def record_evp_verified!(token:, issuer:, issued_at:, now: Time.current)
    raise ArgumentError, "EVP token is required" if token.blank?
    raise ArgumentError, "EVP issuer is required" if issuer.blank?
    raise ArgumentError, "EVP issued_at is required" if issued_at.blank?

    transition_evp_challenge!(
      outcome: OUTCOME_VERIFIED,
      token: token,
      issuer: issuer,
      issued_at: issued_at,
      verified_at: now,
      now: now,
    )
  end

  def record_evp_fallback!(failure_reason:, token: nil, now: Time.current)
    transition_evp_challenge!(
      outcome: OUTCOME_FALLBACK,
      token: token,
      failure_reason: failure_reason,
      now: now,
    )
  end

  def record_evp_rejected!(token:, failure_reason:, now: Time.current)
    raise ArgumentError, "EVP token is required" if token.blank?

    transition_evp_challenge!(
      outcome: OUTCOME_REJECTED,
      token: token,
      failure_reason: failure_reason,
      now: now,
    )
  end

  private

  def transition_evp_challenge!(outcome:, token:, now:, failure_reason: nil, issuer: nil, issued_at: nil,
                                verified_at: nil)
    with_lock do
      raise StateError, "EVP challenge is not pending" unless evp_outcome == OUTCOME_PENDING
      raise ExpiredError, "EVP challenge is expired" if evp_challenge_expired?(now: now)

      update!(
        evp_outcome: outcome,
        evp_token_digest: token.present? ? self.class.digest_evp_secret(token) : nil,
        evp_failure_reason: failure_reason,
        evp_issuer: issuer,
        evp_issued_at: issued_at,
        evp_verified_at: verified_at,
        evp_consumed_at: now,
        evp_attempt_count: evp_attempt_count.to_i + (token.present? ? 1 : 0),
      )
    end
    reload
  rescue ActiveRecord::RecordNotUnique => e
    raise ReplayError, "EVP token has already been consumed", cause: e
  end

  def evp_challenge_metadata_is_consistent
    return evp_validate_blank_outcome if evp_outcome.nil?

    errors.add(:evp_nonce_digest, "must be present") if evp_nonce_digest.blank?
    return evp_validate_pending_outcome if evp_outcome == OUTCOME_PENDING

    errors.add(:evp_consumed_at, "must be present") if evp_consumed_at.blank?
    evp_validate_terminal_outcome
  end

  def evp_validate_blank_outcome
    if OPTIONAL_METADATA_ATTRIBUTES.any? { |attribute| public_send(attribute).present? } ||
        evp_attempt_count.to_i.positive?
      errors.add(:evp_outcome, :blank)
    end
  end

  def evp_validate_pending_outcome
    errors.add(:evp_consumed_at, "must be blank") if evp_consumed_at.present?
  end

  def evp_validate_terminal_outcome
    case evp_outcome
    when OUTCOME_VERIFIED
      evp_validate_verified_outcome
    when OUTCOME_FALLBACK, OUTCOME_REJECTED
      evp_validate_failed_outcome
    else
      errors.add(:evp_outcome, "is unsupported")
    end
  end

  def evp_validate_verified_outcome
    errors.add(:evp_token_digest, "must be present") if evp_token_digest.blank?
    errors.add(:evp_issuer, "must be present") if evp_issuer.blank?
    errors.add(:evp_issued_at, "must be present") if evp_issued_at.blank?
    errors.add(:evp_verified_at, "must be present") if evp_verified_at.blank?
    if evp_issued_at.present? && evp_verified_at.present? && evp_issued_at > evp_verified_at
      errors.add(:evp_issued_at, "must not be after verification")
    end
    errors.add(:evp_failure_reason, "must be blank") if evp_failure_reason.present?
  end

  def evp_validate_failed_outcome
    errors.add(:evp_failure_reason, "must be present") if evp_failure_reason.blank?
    errors.add(:evp_token_digest, "must be present") if evp_outcome == OUTCOME_REJECTED && evp_token_digest.blank?
    errors.add(:evp_issuer, "must be blank") if evp_issuer.present?
    errors.add(:evp_issued_at, "must be blank") if evp_issued_at.present?
    errors.add(:evp_verified_at, "must be blank") if evp_verified_at.present?
  end
end
