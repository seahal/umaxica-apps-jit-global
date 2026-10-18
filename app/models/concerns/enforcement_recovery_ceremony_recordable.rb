# typed: false
# frozen_string_literal: true

# A recovery ceremony proves control of an already verified identity without
# creating a normal authenticated session. Each realm supplies its own model
# and subject association, preserving principal-database isolation.
module EnforcementRecoveryCeremonyRecordable
  extend ActiveSupport::Concern

  TOKEN_BYTES = 32
  TTL = 30.minutes
  ACTIVE = 1
  CONSUMED = 2
  REVOKED = 3

  # FIXME: Violates Umaxica/NoConcernInclusionHooks; move the declarations in this block into each class that includes this concern.
  included do
    include ::PublicId

    attr_reader :plaintext_token

    before_validation :assign_token, on: :create
    before_validation :assign_expiry, on: :create
    validates :status_id, inclusion: { in: [ACTIVE, CONSUMED, REVOKED] }
    validates :token_digest, presence: true, uniqueness: true
    validates :expires_at, presence: true
  end

  class_methods do
    def issue!(subject:, request:)
      create!(
        subject_association_name => subject,
        :ip_digest => digest_optional(request.remote_ip),
        :user_agent_digest => digest_optional(request.user_agent),
      )
    end

    def authenticate(public_id:, token:)
      return nil if public_id.blank? || token.blank?

      ceremony = find_by(public_id: public_id)
      return nil unless ceremony&.active?
      return nil unless ceremony.token_matches?(token)

      ceremony
    end

    def digest(value) = OpenSSL::Digest::SHA256.digest(value.to_s)

    def digest_optional(value) = value.present? ? digest(value) : nil
  end

  def active?
    status_id == ACTIVE && consumed_at.blank? && revoked_at.blank? && expires_at > Time.current
  end

  def consume! = update!(status_id: CONSUMED, consumed_at: Time.current)

  def revoke! = update!(status_id: REVOKED, revoked_at: Time.current)

  def token_matches?(token)
    candidate = self.class.digest(token)
    token_digest.bytesize == candidate.bytesize && ActiveSupport::SecurityUtils.secure_compare(token_digest, candidate)
  end

  private

  def assign_token
    return if token_digest.present?

    @plaintext_token = SecureRandom.urlsafe_base64(TOKEN_BYTES)
    self.token_digest = self.class.digest(plaintext_token)
  end

  def assign_expiry
    self.expires_at ||= TTL.from_now
  end
end
