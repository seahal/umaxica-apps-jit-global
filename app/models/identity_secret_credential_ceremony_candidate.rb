# typed: false
# frozen_string_literal: true

class IdentitySecretCredentialCeremonyCandidate < OpBaseAppRecord
  include IdentityCeremonyCandidateRecord

  encrypts :password_digest

  validates :transaction_id, :operation, :password_digest, presence: true
  validates :enabled, inclusion: { in: [true, false] }
  validates :surface, inclusion: { in: IdentitySecretCredentialCeremonyContract::SURFACES }
  validates :operation, inclusion: { in: IdentitySecretCredentialCeremonyContract::OPERATIONS }
end
