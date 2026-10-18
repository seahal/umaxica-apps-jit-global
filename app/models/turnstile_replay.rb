# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: turnstile_replays
# Database name: op_base_app
#
#  id           :bigint           not null, primary key
#  action       :string
#  cdata        :string
#  ceremony_id  :string           not null
#  consumed_at  :datetime
#  expires_at   :datetime         not null
#  hostname     :string
#  token_digest :string           not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#
# Indexes
#
#  index_turnstile_replays_on_expires_at    (expires_at)
#  index_turnstile_replays_on_token_digest  (token_digest) UNIQUE
#
class TurnstileReplay < OpBaseAppRecord
  validates :ceremony_id, :token_digest, :expires_at, presence: true

  def self.digest_token(token)
    Digest::SHA256.hexdigest(token.to_s)
  end

  def expired?
    expires_at.present? && expires_at <= Time.current
  end
end
