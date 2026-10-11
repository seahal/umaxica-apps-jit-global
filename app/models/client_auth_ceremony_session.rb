# typed: false
# frozen_string_literal: true

class ClientAuthCeremonySession < AppTicketRecord
  include AuthCeremonySession

  before_validation :normalize_blank_previous_digest

  validates :sid_digest, presence: true, uniqueness: true, length: { is: 64 }
  validates :expires_at, presence: true

  private

  def normalize_blank_previous_digest
    self.previous_sid_digest = previous_sid_digest.presence
  end
end
