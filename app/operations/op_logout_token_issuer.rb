# typed: false
# frozen_string_literal: true

# Signs one OpenID Connect Back-Channel Logout Token for a single participant (R5-WU10, one.md 6.3).
#
# Signed by the realm OP issuer key, short-lived, addressed to exactly the participant's client and
# sid, carrying the back-channel logout event and never a nonce. Each delivery attempt gets a fresh
# JTI; deduplication across retries rests on the RP receipt and the outbox's stable event identity.
class OpLogoutTokenIssuer
  TOKEN_TYPE = "logout+jwt"
  EVENT = "http://schemas.openid.net/event/backchannel-logout"
  LIFETIME = 2.minutes
  RESOURCE_TYPES = { "app" => "client", "com" => "visitor", "org" => "operator" }.freeze

  class << self
    public

    # realm - "app", "com" or "org"; read from the participant's realm stop class when omitted.
    def call(participant:, realm: nil, now: Time.current)
      realm ||= participant.class.name.delete_prefix("Op")[0, 3].downcase
      resource_type = RESOURCE_TYPES.fetch(realm.to_s)
      payload = {
        "iss" => participant.issuer,
        "aud" => [participant.client_id],
        "iat" => now.to_i,
        "exp" => (now + LIFETIME).to_i,
        "jti" => SecureRandom.uuid,
        "sid" => participant.sid,
        "events" => { EVENT => {} },
      }
      JitSecurityJwtKeyring.encode(
        payload, typ: TOKEN_TYPE, issuer_id: OidcIssuer.jwt_issuer_id_for_resource_type(resource_type),
      )
    end
  end
end
