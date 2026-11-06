# typed: false
# frozen_string_literal: true

class ClientAuthCeremonySession < OpBaseAppRecord
  include AuthCeremonySession
  include AuthEmailOtpChallenge

  belongs_to :status,
             class_name: "ClientAuthCeremonySessionStatus",
             inverse_of: :client_auth_ceremony_sessions

  validates :sid_digest, presence: true, uniqueness: true, length: { is: 64 }
  validates :expires_at, presence: true
  validates :status_id, inclusion: { in: AuthCeremonySession::STATUS_IDS }
  validates :previous_sid_digest, length: { maximum: 64 }

  before_validation :normalize_blank_previous_digest

  public

  def cancelled_before_authentication_progress?
    super && email_otp_context.blank?
  end

  private

  def normalize_blank_previous_digest
    self.previous_sid_digest = previous_sid_digest.presence
  end
end
