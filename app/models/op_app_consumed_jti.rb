# typed: false
# frozen_string_literal: true

class OpAppConsumedJti < OpBaseAppRecord
  self.table_name = "op_consumed_jtis"

  REALM = "app"

  class << self
    public

    def consume!(purpose:, issuer:, client_id:, jti:, expires_at:, consumed_at: Time.current)
      return false if [purpose, issuer, client_id, jti, expires_at].any?(&:blank?)

      connection_class_for_self.connected_to(role: :writing) do
        create!(
          purpose: purpose.to_s,
          issuer: issuer.to_s,
          realm: REALM,
          client_id: client_id.to_s,
          jti_digest: digest_jti(jti),
          expires_at: expires_at,
          consumed_at: consumed_at,
        )
      end
      true
    rescue ActiveRecord::RecordNotUnique
      false
    end

    def digest_jti(jti)
      Digest::SHA256.hexdigest(jti.to_s)
    end
  end

  validates :realm, inclusion: { in: [REALM] }, presence: true
  validates :purpose, :issuer, :client_id, :jti_digest, :expires_at, :consumed_at, presence: true
  validates :realm, length: { maximum: 3 }
  validates :client_id, :jti_digest, :purpose, length: { maximum: 64 }
  validates :issuer, length: { maximum: 255 }
end
