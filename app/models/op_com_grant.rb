# typed: false
# frozen_string_literal: true

class OpComGrant < OpBaseComRecord
  include RpSession

  belongs_to :visitor_device_session, class_name: "VisitorDeviceSession", foreign_key: :device_session_id,
                                      inverse_of: :op_com_grants
  # FIXME: The checker requests a token FK deliberately removed for stable device-session
  # ownership; D3 preserves historical grants and requires a new decision before adding an FK.
  belongs_to :visitor_token, inverse_of: :op_com_grants

  validates :public_id, presence: true, uniqueness: true, length: { maximum: 21 }
  # WU-17: written at issuance from the actor (roots) or the root (grants); never defaulted.
  validates :authentication_epoch, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :oidc_client_id, presence: true, length: { maximum: 64 }
  validates :last_logout_status, inclusion: { in: RpSession::LOGOUT_STATUSES }, allow_nil: true
  validates :refresh_token_digest, uniqueness: true, allow_nil: true

  before_validation :bind_device_session_from_parent_token, on: :create

  before_validation :ensure_public_id, on: :create

  delegate :visitor, to: :visitor_device_session

  scope :currently_usable_at,
        ->(now = Time.current) do
          where(revoked_at: nil)
            .where(arel_table[:refresh_token_expires_at].eq(nil).or(arel_table[:refresh_token_expires_at].gt(now)))
        end

  private

  def bind_device_session_from_parent_token
    return if device_session_id.present?

    token = VisitorToken.find_by(id: visitor_token_id)
    self.device_session_id = token&.device_session_id
  end

  def parent_association_name
    :visitor_device_session
  end
end
