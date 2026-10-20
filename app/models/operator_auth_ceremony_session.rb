# typed: false
# frozen_string_literal: true

class OperatorAuthCeremonySession < OpBaseOrgRecord
  include AuthCeremonySession

  validates :sid_digest, presence: true, uniqueness: true, length: { is: 64 }
  validates :expires_at, presence: true
  validates :previous_sid_digest, length: { maximum: 64 }

  before_validation :normalize_blank_previous_digest

  private

  def normalize_blank_previous_digest
    self.previous_sid_digest = previous_sid_digest.presence
  end
end
