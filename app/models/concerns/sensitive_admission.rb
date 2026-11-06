# frozen_string_literal: true

# The endpoints and transitions are intentionally absent until the complete browser handoff is wired.
module SensitiveAdmission
  extend ActiveSupport::Concern

  STATUSES = %w(issued attached confirmed redeemed cancelled).freeze
  DIGEST_PATTERN = /\A[0-9a-f]{64}\z/
  PUBLIC_REFERENCE_PATTERN = /\A[A-Za-z0-9_-]{21}\z/

  private

  def valid_sensitive_admission_deadline
    return if issued_at && expires_at && expires_at > issued_at

    errors.add(:expires_at, :invalid)
  end
end
