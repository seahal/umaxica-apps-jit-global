# typed: false
# frozen_string_literal: true

module RpSession
  extend ActiveSupport::Concern
  include PublicId
  include RefreshTokenShared

  LOGOUT_STATUSES = %w(success no_session unsupported failed).freeze

  class IssuanceRejected < StandardError; end

  public

  def active?
    revoked_at.blank? &&
      root_token_active? &&
      (refresh_token_expires_at.blank? || refresh_token_expires_at > Time.current)
  end

  # A revoked RP Session cannot be replaced until every Access JWT issued by it
  # is outside the verifier's configured clock-skew window. A nil value on an
  # old row is deliberately conservative: the application cannot prove when a
  # JWT was issued, so it must not treat that row as already retired.
  def retirement_pending?(now = Time.current)
    return true if revoked_at.blank?
    return true unless has_attribute?(:oidc_access_token_max_expires_at)

    max_expires_at = self[:oidc_access_token_max_expires_at]
    return true if max_expires_at.blank?

    now < max_expires_at + SecurityTokenLifetimes::OIDC_ACCESS_JWT_CLOCK_LEEWAY_SECONDS
  end

  def access_token_retirement_deadline
    return nil unless has_attribute?(:oidc_access_token_max_expires_at)

    max_expires_at = self[:oidc_access_token_max_expires_at]
    return nil if max_expires_at.blank?

    max_expires_at + SecurityTokenLifetimes::OIDC_ACCESS_JWT_CLOCK_LEEWAY_SECONDS
  end

  # Persist the maximum Access JWT exp before the token response leaves the
  # application. The value is monotonic so an older/shorter issuance cannot
  # shorten the retirement window established by a longer-lived JWT.
  def record_access_token_expiry!(expires_at)
    raise ArgumentError, "expires_at must be a time" unless expires_at.respond_to?(:to_time)

    unless has_attribute?(:oidc_access_token_max_expires_at)
      raise ActiveRecord::StatementInvalid,
            "RP Session schema is missing oidc_access_token_max_expires_at"
    end

    candidate = expires_at.to_time
    with_parent_and_self_lock do
      raise IssuanceRejected, "RP Session is no longer active" unless active?

      current = self[:oidc_access_token_max_expires_at]
      next if current.present? && current >= candidate

      update!(oidc_access_token_max_expires_at: candidate)
    end

    self[:oidc_access_token_max_expires_at]
  end

  def revoked?
    revoked_at.present?
  end

  def parent_token
    public_send(parent_association_name)
  end

  def parent_token_active?
    token = parent_token
    return false unless token
    return false unless token.respond_to?(:currently_usable?)

    token.currently_usable?
  end

  def issue_refresh_token!(expires_at: refresh_token_expires_at || default_refresh_token_expires_at)
    with_parent_and_self_lock do
      raise IssuanceRejected, "RP Session is no longer active" unless active?

      expires_at = SessionAbsoluteExpiryValue.cap(
        proposed_expiry: expires_at,
        absolute_expiry: parent_token&.discarded_at,
      )
      raw_refresh_token, verifier = generate_refresh_token(public_id: public_id)
      update!(
        refresh_token_digest: encoded_refresh_token_digest(verifier),
        refresh_token_expires_at: expires_at,
        refresh_token_rotated_at: nil,
        previous_refresh_token_digest: nil,
        last_used_at: Time.current,
      )
      raw_refresh_token
    end
  end

  def rotate_refresh_token!(expires_at: refresh_token_expires_at || default_refresh_token_expires_at)
    with_parent_and_self_lock do
      raise ActiveRecord::RecordInvalid.new(self) unless active?

      expires_at = SessionAbsoluteExpiryValue.cap(
        proposed_expiry: expires_at,
        absolute_expiry: parent_token&.discarded_at,
      )

      previous_digest = refresh_token_digest
      raw_refresh_token, verifier = generate_refresh_token(public_id: public_id)
      update!(
        previous_refresh_token_digest: previous_digest,
        refresh_token_digest: encoded_refresh_token_digest(verifier),
        refresh_token_expires_at: expires_at,
        refresh_token_rotated_at: Time.current,
        last_used_at: Time.current,
      )
      raw_refresh_token
    end
  end

  def authenticate_refresh_token(verifier)
    return false unless active?
    return false if verifier.blank? || refresh_token_digest.blank?

    refresh_token_digest_matches?(verifier)
  end

  def refresh_token_digest_matches?(verifier)
    candidate = encoded_refresh_token_digest(verifier)
    secure_compare?(refresh_token_digest, candidate)
  end

  # A verifier that matches the digest superseded by the last rotation is a
  # replay of an already-rotated refresh token. Per RFC 9700 section 4.14.2 that
  # is compromise evidence, not a routine authentication failure: either the
  # client kept a stale token or an attacker captured one.
  def previous_refresh_token_digest_matches?(verifier)
    return false if previous_refresh_token_digest.blank?

    candidate = encoded_refresh_token_digest(verifier)
    secure_compare?(previous_refresh_token_digest, candidate)
  end

  def revoke!(status: "failed", now: Time.current)
    with_parent_and_self_lock do
      update!(
        revoked_at: now,
        last_logout_status: status,
        last_logout_attempted_at: now,
        logged_out_at: now,
      )
    end
  end

  def mark_logout_status!(status:, now: Time.current)
    with_parent_and_self_lock do
      update!(
        last_logout_status: status,
        last_logout_attempted_at: now,
        logged_out_at: ((status == "success") ? now : logged_out_at),
        revoked_at: ((status == "success") ? now : revoked_at),
      )
    end
  end

  private

  def ensure_public_id
    self.public_id ||= Nanoid.generate(size: 21)
  end

  def default_refresh_token_expires_at
    SessionAbsoluteExpiryValue.cap(
      proposed_expiry: Time.current + RefreshTokenable::REFRESH_TTL,
      absolute_expiry: parent_token&.discarded_at,
    )
  end

  def encoded_refresh_token_digest(verifier)
    digest_refresh_token(verifier).unpack1("H*")
  end

  def root_token_active?
    parent_token_active?
  end

  def parent_association_name
    raise NotImplementedError
  end

  def with_parent_and_self_lock
    parent = parent_token
    return with_lock { yield } unless parent

    parent.with_lock do
      with_lock { yield }
    end
  end
end
