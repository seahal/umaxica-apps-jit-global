# typed: false
# frozen_string_literal: true

class IdentityTotpCeremonyCandidate < AppTicketRecord
  include IdentityCeremonyCandidateRecord

  encrypts :private_key

  validates :private_key, presence: true
  validates :last_otp_at, presence: true, if: :unbound_candidate?
  validates :surface, inclusion: { in: IdentityTotpCeremonyContract::SURFACES }

  private

  def unbound_candidate? = step_up_ceremony_transaction_ref.nil?
end
