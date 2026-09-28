# typed: false
# frozen_string_literal: true

# Proof, committed with the ClientToken it names, that an Emergency Secret Credential sign-in
# operation created its app session. adr/emergency-secret-credential-commit-acknowledgement.md
class ClientEmergencySignInOperation < AppTicketRecord
  belongs_to :client_token

  validates :operation_id, presence: true
  validates :credential_public_id, presence: true, length: { maximum: 21 }
end
