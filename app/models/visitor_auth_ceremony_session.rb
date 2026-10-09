# typed: false
# frozen_string_literal: true

class VisitorAuthCeremonySession < ComTicketRecord
  include AuthCeremonySession
  include AuthEmailOtpChallenge

  validates :sid_digest, presence: true, uniqueness: true, length: { is: 64 }
  validates :expires_at, presence: true

  before_validation :normalize_blank_previous_digest

  private

  def normalize_blank_previous_digest
    self.previous_sid_digest = previous_sid_digest.presence
  end
end
