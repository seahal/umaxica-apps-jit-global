# typed: false
# frozen_string_literal: true

module OidcTokenUsage
  extend ActiveSupport::Concern
  include PublicId
  include RefreshTokenShared

  LOGOUT_STATUSES = %w(success no_session unsupported failed).freeze

  included do
    before_validation :ensure_public_id, on: :create

    scope :currently_usable_at,
          ->(now = Time.current) do
            where(revoked_at: nil)
              .where(arel_table[:refresh_token_expires_at].eq(nil).or(arel_table[:refresh_token_expires_at].gt(now)))
          end

    validates :public_id, presence: true, uniqueness: true, length: { maximum: 21 }
    validates :oidc_client_id, presence: true, length: { maximum: 64 }
    validates :last_logout_status, inclusion: { in: LOGOUT_STATUSES }, allow_nil: true
    validates :refresh_token_digest, uniqueness: true, allow_nil: true
  end

  def active?
    revoked_at.blank? &&
      root_token_active? &&
      (refresh_token_expires_at.blank? || refresh_token_expires_at > Time.current)
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

  def rotate_refresh_token!(expires_at: refresh_token_expires_at || default_refresh_token_expires_at)
    with_lock do
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
    update!(
      revoked_at: now,
      last_logout_status: status,
      last_logout_attempted_at: now,
      logged_out_at: now,
    )
  end

  def mark_logout_status!(status:, now: Time.current)
    update!(
      last_logout_status: status,
      last_logout_attempted_at: now,
      logged_out_at: ((status == "success") ? now : logged_out_at),
      revoked_at: ((status == "success") ? now : revoked_at),
    )
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
end
