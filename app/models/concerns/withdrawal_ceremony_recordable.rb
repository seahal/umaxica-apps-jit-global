# typed: false
# frozen_string_literal: true

module WithdrawalCeremonyRecordable
  extend ActiveSupport::Concern

  TOKEN_BYTES = 32
  TTL = 30.minutes
  PURPOSES = %w(status recovery termination).freeze
  STATUS_ACTIVE = 1
  STATUS_CONSUMED = 2
  STATUS_REVOKED = 3
  STATUS_EXPIRED = 4
  STATUS_IDS = [STATUS_ACTIVE, STATUS_CONSUMED, STATUS_REVOKED, STATUS_EXPIRED].freeze

  # FIXME: Violates Umaxica/NoConcernInclusionHooks; move the declarations in this block into each class that includes this concern.
  included do
    include ::PublicId

    attr_reader :plaintext_token

    before_validation :ensure_purpose, on: :create
    before_validation :ensure_expires_at, on: :create
    before_validation :ensure_token_digest, on: :create

    validates :purpose, inclusion: { in: PURPOSES }
    validates :status_id, inclusion: { in: STATUS_IDS }
    validates :token_digest, presence: true, uniqueness: true
    validates :expires_at, presence: true
  end

  class_methods do
    def issue!(subject:, purpose: "status", request: nil)
      create!(
        subject_association_name => subject,
        :purpose => purpose,
        :ip_digest => digest_optional(request&.remote_ip),
        :user_agent_digest => digest_optional(request&.user_agent),
      )
    end

    def authenticate(public_id:, token:)
      return nil if public_id.blank? || token.blank?

      ceremony = find_by(public_id: public_id)
      return nil unless ceremony&.active?
      return nil unless ceremony.token_matches?(token)
      return nil unless ceremony.subject_withdrawal_restricted?

      ceremony
    end

    def digest_token(token)
      OpenSSL::Digest::SHA256.digest(token.to_s)
    end

    def digest_optional(value)
      return nil if value.blank?

      digest_token(value)
    end
  end

  def active?
    !expired? && !consumed? && !revoked? && status_id == STATUS_ACTIVE
  end

  def expired?
    return true if status_id == STATUS_EXPIRED

    expires_at.present? && expires_at <= Time.current
  end

  def consumed?
    consumed_at.present? || status_id == STATUS_CONSUMED
  end

  def revoked?
    revoked_at.present? || status_id == STATUS_REVOKED
  end

  def consume!
    update!(status_id: STATUS_CONSUMED, consumed_at: Time.current)
  end

  def revoke!
    update!(status_id: STATUS_REVOKED, revoked_at: Time.current)
  end

  def token_matches?(token)
    return false if token_digest.blank? || token.blank?

    candidate = self.class.digest_token(token)
    return false unless token_digest.bytesize == candidate.bytesize

    ActiveSupport::SecurityUtils.secure_compare(token_digest, candidate)
  end

  def subject_withdrawal_restricted?
    subject.respond_to?(:withdrawal_in_progress?) && (subject.withdrawal_in_progress? || subject.terminated?)
  end

  private

  def ensure_purpose
    self.purpose = "status" if purpose.blank?
  end

  def ensure_expires_at
    self.expires_at ||= self.class::TTL.from_now
  end

  def ensure_token_digest
    return if token_digest.present?

    @plaintext_token = SecureRandom.urlsafe_base64(TOKEN_BYTES)
    self.token_digest = self.class.digest_token(@plaintext_token)
  end
end
