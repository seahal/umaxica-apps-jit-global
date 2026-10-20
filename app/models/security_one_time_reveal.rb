# typed: false
# frozen_string_literal: true

class SecurityOneTimeReveal < OpBaseAppRecord
  class << self
    def consume(jti_digest:, actor_type:, actor_id:, session_nonce_digest:, purpose:, now: Time.current)
      transaction do
        record = lock.find_by(
          jti_digest: jti_digest,
          actor_type: actor_type,
          actor_id: actor_id,
          session_nonce_digest: session_nonce_digest,
          purpose: purpose,
          consumed_at: nil,
        )
        return if record.nil? || record.expires_at <= now

        record.update!(consumed_at: now)
        record.encrypted_payload
      end
    end
  end

  validates :actor_id, :actor_type, :encrypted_payload, :expires_at, :jti_digest, :purpose,
            :session_nonce_digest, exclusion: { in: [nil] }
end
