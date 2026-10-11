# typed: false
# frozen_string_literal: true

class ClientRpSession < AppTicketRecord
  include RpSession

  belongs_to :client_token, inverse_of: :client_rp_sessions

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

  delegate :user, to: :client_token

  private

  def parent_association_name
    :client_token
  end
end
