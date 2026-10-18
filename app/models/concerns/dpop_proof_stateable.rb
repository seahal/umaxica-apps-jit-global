# typed: false
# frozen_string_literal: true

module DpopProofStateable
  extend ActiveSupport::Concern

  TTL_SECONDS = 300

  # FIXME: Violates Umaxica/NoConcernInclusionHooks; move the declarations in this block into each class that includes this concern.
  included do
    scope :active_at, ->(time) { where(arel_table[:expires_at].gt(time)) }
    validates :expires_at, presence: true
    validates :seen_at, presence: true
    validates :jti, uniqueness: true, allow_nil: true
    validates :nonce, uniqueness: true, allow_nil: true
  end

  class_methods do
    def record_jti!(jti:, jkt:, htm:, htu:, now: Time.current)
      return false if jti.blank?

      ActiveRecord::Base.connected_to(role: :writing) do
        create!(
          jti: jti,
          jkt: jkt,
          htm: htm,
          htu: htu,
          seen_at: now,
          expires_at: now + TTL_SECONDS.seconds,
        )
      end
      true
    rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid
      false
    end

    def issue_nonce!(now: Time.current)
      nonce = SecureRandom.urlsafe_base64(32)
      ActiveRecord::Base.connected_to(role: :writing) do
        create!(nonce: nonce, seen_at: now, expires_at: now + TTL_SECONDS.seconds)
      end
      nonce
    end

    def consume_nonce!(nonce, now: Time.current)
      return false if nonce.blank?

      state =
        ActiveRecord::Base.connected_to(role: :writing) do
          active_at(now).lock.find_by(nonce: nonce, nonce_used_at: nil)
        end
      return false unless state

      ActiveRecord::Base.connected_to(role: :writing) do
        state.update!(nonce_used_at: now)
      end
      true
    end
  end
end
