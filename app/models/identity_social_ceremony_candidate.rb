# typed: false
# frozen_string_literal: true

class IdentitySocialCeremonyCandidate < OpBaseAppRecord
  include IdentityCeremonyCandidateRecord

  NANOID_REFERENCE_PATTERN = /\A[A-Za-z0-9_-]{21}\z/.freeze
  LEGACY_UUID_REFERENCE_PATTERN =
    /\A[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\z/i.freeze

  class << self
    public

    def valid_reference?(value)
      value.is_a?(String) &&
        (NANOID_REFERENCE_PATTERN.match?(value) || LEGACY_UUID_REFERENCE_PATTERN.match?(value))
    end
  end

  encrypts :auth_hash

  serialize :auth_hash, coder: JSON

  validates :transaction_id, :operation, :provider, :auth_hash, presence: true
  validates :surface, inclusion: { in: IdentitySocialCeremonyContract::SURFACES }
  validates :operation, inclusion: { in: IdentitySocialCeremonyContract::OPERATIONS }
  validates :provider, inclusion: { in: IdentitySocialCeremonyContract::PROVIDERS }
  validate :auth_hash_shape

  private

  def auth_hash_shape
    principal = auth_hash["principal"] if auth_hash.is_a?(Hash)
    return if principal.is_a?(Hash) &&
      principal.values_at(
        "provider",
        "subject",
        "issuer",
        "audience",
        "verified_at",
        "verification_authority",
      ).all?(&:present?)

    errors.add(:auth_hash, "is invalid")
  end
end
