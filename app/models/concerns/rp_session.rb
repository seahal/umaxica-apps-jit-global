# typed: false
# frozen_string_literal: true

module RpSession
  extend ActiveSupport::Concern
  include PublicId
  include RefreshTokenShared

  LOGOUT_STATUSES = %w(success no_session unsupported failed).freeze

  class IssuanceRejected < StandardError; end

  public

  def active?(now = nil)
    now ||= self.class.database_now
    revoked_at.blank? &&
      root_token_active?(now) &&
      (refresh_token_expires_at.blank? || refresh_token_expires_at > now)
  end

  # A revoked RP Session cannot be replaced until every Access JWT issued by it
  # is outside the verifier's configured clock-skew window. A nil value on an
  # old row is deliberately conservative: the application cannot prove when a
  # JWT was issued, so it must not treat that row as already retired.
  def retirement_pending?(now = nil)
    now ||= self.class.database_now
    return true if revoked_at.blank?
    return true unless has_attribute?(:oidc_access_token_max_expires_at)

    max_expires_at = self[:oidc_access_token_max_expires_at]
    return true if max_expires_at.blank?

    now < max_expires_at + SecurityTokenLifetimes::OIDC_ACCESS_JWT_CLOCK_LEEWAY_SECONDS
  end

  # Persist the maximum Access JWT exp before the token response leaves the
  # application. The value is monotonic so an older/shorter issuance cannot
  # shorten the retirement window established by a longer-lived JWT.
  def record_access_token_expiry!(expires_at, now: nil)
    raise ArgumentError, "expires_at must be a time" unless expires_at.respond_to?(:to_time)

    unless has_attribute?(:oidc_access_token_max_expires_at)
      raise ActiveRecord::StatementInvalid,
            "RP Session schema is missing oidc_access_token_max_expires_at"
    end

    candidate = expires_at.to_time
    with_parent_and_self_lock do
      decision_time = now || self.class.database_now
      raise IssuanceRejected, "RP Session is no longer active" unless active?(decision_time)

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
    parent_device_session&.current_refresh_token
  end

  def parent_token_active?(now = nil)
    device_session = parent_device_session
    return false unless device_session&.usable?

    token = device_session.current_refresh_token
    return false unless token

    token.currently_usable?(now || self.class.database_now)
  end

  def issue_refresh_token!(expires_at: nil, now: nil)
    with_parent_and_self_lock do
      decision_time = now || self.class.database_now
      raise IssuanceRejected, "RP Session is no longer active" unless active?(decision_time)

      expires_at ||= default_refresh_token_expires_at(now: decision_time)

      expires_at = SessionAbsoluteExpiryValue.cap(
        proposed_expiry: expires_at,
        absolute_expiry: parent_token&.discard_at,
      )
      raw_refresh_token, verifier = generate_refresh_token(public_id: public_id)
      update!(
        refresh_token_digest: encoded_refresh_token_digest(verifier),
        refresh_token_expires_at: expires_at,
        refresh_token_rotated_at: nil,
        previous_refresh_token_digest: nil,
        refresh_delivery_ciphertext: nil,
        refresh_delivery_predecessor_digest: nil,
        refresh_delivery_expires_at: nil,
        last_used_at: decision_time,
      )
      raw_refresh_token
    end
  end

  def rotate_refresh_token!(expires_at: nil, now: nil)
    with_parent_and_self_lock do
      decision_time = now || self.class.database_now
      raise ActiveRecord::RecordInvalid.new(self) unless active?(decision_time)

      expires_at ||= default_refresh_token_expires_at(now: decision_time)

      expires_at = SessionAbsoluteExpiryValue.cap(
        proposed_expiry: expires_at,
        absolute_expiry: parent_token&.discard_at,
      )

      previous_digest = refresh_token_digest
      raw_refresh_token, verifier = generate_refresh_token(public_id: public_id)
      update!(
        previous_refresh_token_digest: previous_digest,
        refresh_token_digest: encoded_refresh_token_digest(verifier),
        refresh_token_expires_at: expires_at,
        refresh_token_rotated_at: decision_time,
        refresh_generation: refresh_generation + 1,
        refresh_delivery_ciphertext: nil,
        refresh_delivery_predecessor_digest: nil,
        refresh_delivery_expires_at: nil,
        last_used_at: decision_time,
      )
      raw_refresh_token
    end
  end

  def store_refresh_delivery_receipt!(ciphertext:, predecessor_digest:, expires_at:)
    raise ArgumentError, "refresh delivery ciphertext is required" if ciphertext.blank?
    raise ArgumentError, "refresh delivery predecessor digest is required" if predecessor_digest.blank?
    raise ArgumentError, "refresh delivery expiry is required" unless expires_at.respond_to?(:to_time)

    update!(
      refresh_delivery_ciphertext: ciphertext,
      refresh_delivery_predecessor_digest: predecessor_digest,
      refresh_delivery_expires_at: expires_at,
    )
  end

  def refresh_delivery_receipt_present?
    refresh_delivery_ciphertext.present? || refresh_delivery_predecessor_digest.present? ||
      refresh_delivery_expires_at.present?
  end

  def clear_refresh_delivery_receipt!
    update!(
      refresh_delivery_ciphertext: nil,
      refresh_delivery_predecessor_digest: nil,
      refresh_delivery_expires_at: nil,
    )
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

  def revoke!(status: "failed", now: nil)
    with_parent_and_self_lock do
      decision_time = now || self.class.database_now
      assign_attributes(
        revoked_at: decision_time,
        last_logout_status: status,
        last_logout_attempted_at: decision_time,
        logged_out_at: decision_time,
      )
      save!(touch: false)
    end
  end

  private

  def ensure_public_id
    self.public_id ||= Nanoid.generate(size: 21)
  end

  def default_refresh_token_expires_at(now: nil)
    SessionAbsoluteExpiryValue.cap(
      proposed_expiry: (now || self.class.database_now) + RefreshTokenable::REFRESH_TTL,
      absolute_expiry: parent_token&.discard_at,
    )
  end

  def encoded_refresh_token_digest(verifier)
    digest_refresh_token(verifier).unpack1("H*")
  end

  def root_token_active?(now = nil)
    parent_token_active?(now)
  end

  def with_parent_and_self_lock
    device_session = parent_device_session
    raise IssuanceRejected, "RP Session device session is missing" unless device_session

    device_session.with_lock do
      parent = device_session.current_refresh_token
      raise IssuanceRejected, "RP Session current root token is missing" unless parent

      parent.with_lock do
        with_lock { yield }
      end
    end
  end

  def parent_device_session
    case self
    when ClientRpSession then ClientDeviceSession.find_by(id: self[:device_session_id])
    when VisitorRpSession then VisitorDeviceSession.find_by(id: self[:device_session_id])
    when OperatorRpSession then OperatorDeviceSession.find_by(id: self[:device_session_id])
    else
      raise IssuanceRejected, "unsupported RP Session class"
    end
  end

  public :parent_device_session, :with_parent_and_self_lock
end
