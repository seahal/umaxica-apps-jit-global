# typed: false
# frozen_string_literal: true

# Signed, one-shot logout-request token issued by the IdP to the RP and
# presented back at `GET /oidc/logout`. Two layered protections:
#
#   1. `verifier.generate / verified` ensures the token is signed and
#      not expired (TTL = 2 minutes).
#   2. A unique `jti` claim is consumed on first successful `verify`.
#      Re-presenting the same token returns nil so the controller can
#      respond with `invalid_request`. This blocks GET-replay vectors
#      where the same logout link is followed twice (browser history,
#      copy-pasted URL, link prefetcher) and incidentally raises the
#      bar against CSRF-style attempts to trick a user into clicking
#      a stolen-but-still-fresh logout link.
module OidcLogoutRequest
  PURPOSE = "oidc_logout_request"
  TTL = 2.minutes
  JTI_BYTES = 16
  # Track consumed jtis slightly longer than the token TTL so a token
  # that expires in-flight cannot be replayed against a process whose
  # clock skew gives it a few extra seconds.
  REPLAY_TRACKING_TTL = TTL + 30.seconds

  class << self
    def issue(client_id:, ri:)
      verifier.generate(
        {
          "client_id" => client_id.to_s,
          "ri" => normalize_ri(ri),
          "jti" => SecureRandom.hex(JTI_BYTES),
        },
        purpose: PURPOSE,
        expires_in: TTL,
      )
    end

    # Returns the parsed payload on the first successful verification
    # and `nil` thereafter for the same token. A `nil` return means
    # either a signature/TTL failure or a replay.
    def verify(token)
      payload = verifier.verified(token.to_s, purpose: PURPOSE)
      return unless payload.is_a?(Hash)

      client_id = payload["client_id"].to_s
      return if client_id.blank?

      jti = payload["jti"].to_s
      return if jti.blank?
      return unless consume_jti!(issuer: client_id, jti: jti)

      {
        client_id: client_id,
        ri: normalize_ri(payload["ri"]),
        jti: jti,
      }
    rescue ActiveSupport::MessageVerifier::InvalidSignature, JSON::ParserError
      nil
    end

    private

    def normalize_ri(value)
      RequestContextContract.normalize_region(value)
    end

    def verifier
      Rails.application.message_verifier(:oidc_logout_request)
    end

    def consume_jti!(issuer:, jti:)
      SecurityConsumedJti.consume!(
        purpose: SecurityConsumedJti::PURPOSES.fetch(:oidc_logout_request),
        issuer: issuer,
        jti: jti,
        expires_at: REPLAY_TRACKING_TTL.from_now,
      )
    rescue ActiveRecord::ActiveRecordError => e
      Rails.logger.info(
        JitLogEvent.format(
          "oidc.logout_request.replay_record_unavailable",
          error_class: e.class.name,
          error_message: e.message,
        ),
      )
      false
    end
  end
end
