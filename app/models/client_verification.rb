# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: client_verifications
# Database name: app_ticket
#
#  id            :bigint           not null, primary key
#  discard_at  :datetime         default(Infinity), not null
#  last_used_at  :datetime
#  purge_eligible_at     :datetime         default(Infinity), not null
#  token_digest  :string           not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  user_token_id :bigint           not null
#
# Indexes
#
#  index_client_verifications_on_token_digest   (token_digest) UNIQUE
#  index_client_verifications_on_user_token_id  (user_token_id)
#
# Foreign Keys
#
#  fk_rails_...  (user_token_id => client_tokens.id) ON DELETE => cascade
#
class ClientVerification < AppTicketRecord
  include Retainable
  include RefreshTokenShared
  include VerificationCookieable

  TTL = 15.minutes

  belongs_to :user_token, class_name: "ClientToken", inverse_of: :client_verifications

  validates :token_digest, presence: true, uniqueness: true
  validates :discard_at, presence: true

  scope :active, -> { where(arel_table[:discard_at].gt(Time.current)) }

  def active?
    discard_at.present? && discard_at > Time.current
  end

  def self.digest_token(raw_token)
    digest_refresh_token(raw_token.to_s).unpack1("H*")
  end

  def self.issue_for_token!(token:, discard_at: TTL.from_now)
    now = Time.current
    raw_token = SecureRandom.urlsafe_base64(32)
    digest = digest_token(raw_token)

    verification =
      transaction do
        where(user_token_id: token.id).active.find_each do |verification_record|
          verification_record.update!(discard_at: now, updated_at: now)
        end

        create!(
          user_token: token,
          token_digest: digest,
          discard_at: discard_at,
          last_used_at: now,
        )
      end

    [verification, raw_token]
  end
end
