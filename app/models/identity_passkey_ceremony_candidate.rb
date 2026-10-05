# typed: false
# frozen_string_literal: true

# A Passkey that Auth verified for one registration permission and Base has not yet turned into a
# credential. The material is public, but its integrity decides which key is trusted, so the digest
# is recomputed when Base consumes the row.
class IdentityPasskeyCeremonyCandidate < AppTicketRecord
  include IdentityCeremonyCandidateRecord

  validates :step_up_ceremony_transaction_ref, :webauthn_id, :public_key, :description, presence: true
  validates :step_up_ceremony_transaction_ref, uniqueness: true
  validates :surface, inclusion: { in: IdentityPasskeyCeremonyContract::SURFACES }
  validates :sign_count, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  class << self
    public

    def digest_for(webauthn_id:, public_key:, sign_count:, description:, transports:, metadata:)
      Digest::SHA256.hexdigest(
        JSON.generate(
          [webauthn_id, public_key, Integer(sign_count), description, Array(transports), metadata.to_h.sort],
        ),
      )
    end
  end

  public

  def material_digest
    self.class.digest_for(
      webauthn_id: webauthn_id, public_key: public_key, sign_count: sign_count, description: description,
      transports: transports, metadata: metadata,
    )
  end

  def material_intact?
    ActiveSupport::SecurityUtils.secure_compare(digest, material_digest)
  end
end
