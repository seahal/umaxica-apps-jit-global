# typed: false
# frozen_string_literal: true

class VisitorRpSession < ComTicketRecord
  include RpSession

  belongs_to :visitor_device_session, class_name: "VisitorDeviceSession", foreign_key: :device_session_id,
                                      inverse_of: :visitor_rp_sessions
  belongs_to :visitor_token, inverse_of: :visitor_rp_sessions

  before_validation :bind_device_session_from_parent_token, on: :create

  before_validation :ensure_public_id, on: :create

  scope :currently_usable_at,
        ->(now = Time.current) do
          where(revoked_at: nil)
            .where(arel_table[:refresh_token_expires_at].eq(nil).or(arel_table[:refresh_token_expires_at].gt(now)))
        end

  validates :public_id, presence: true, uniqueness: true, length: { maximum: 21 }
  validates :oidc_client_id, presence: true, length: { maximum: 64 }
  validates :last_logout_status, inclusion: { in: RpSession::LOGOUT_STATUSES }, allow_nil: true
  validates :refresh_token_digest, uniqueness: true, allow_nil: true

  delegate :visitor, to: :visitor_device_session

  private

  def bind_device_session_from_parent_token
    self.visitor_device_session ||= visitor_token&.device_session
  end

  def parent_association_name
    :visitor_device_session
  end
end
