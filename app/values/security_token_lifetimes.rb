# typed: false
# frozen_string_literal: true

# Application-level token lifetime and key-rotation policy.
#
# Keep family-specific values out of Jit::Security::Jwt so the low-level
# JWT/JWS/JWK/JWKS layer does not know about Auth, Preference, OIDC, or
# JumpRT token families.
module SecurityTokenLifetimes
  AUTH_ACCESS_JWT_TTL = 5.minutes
  PREFERENCE_JWT_TTL = 7.days
  OIDC_ID_TOKEN_TTL = 5.minutes
  JUMP_RT_TTL = 30.seconds

  JWKS_ROTATION_LEEWAY = 1.hour
  CDN_STALE_LEEWAY = 1.hour

  # Idle (inactivity) timeout per surface. A session with no activity for
  # longer than this can no longer authenticate or refresh, independent of the
  # absolute token lifetime. Operator/org sessions use a much tighter window
  # because of their elevated privilege. These are idle windows only; the
  # absolute token lifetimes above are unchanged.
  CLIENT_IDLE_TTL = 8.hours
  OPERATOR_IDLE_TTL = 30.minutes
  VISITOR_IDLE_TTL = 8.hours

  CLIENT_REFRESH_TOKEN_TTL = 30.days
  OPERATOR_REFRESH_TOKEN_TTL = 8.hours
  VISITOR_REFRESH_TOKEN_TTL = 30.days

  # Minimum gap between per-request last_used_at writes. Activity tracking is
  # throttled so an authenticated request does not write to the session row on
  # every hit (see AuthenticationCurrentResourceResolver#touch_session_activity!).
  ACTIVITY_TOUCH_THROTTLE = 60.seconds

  module_function

  def old_kid_verification_window(ttl)
    ttl + JWKS_ROTATION_LEEWAY + CDN_STALE_LEEWAY
  end

  # Idle timeout window for the given surface ("operator", "visitor", or the
  # client default). Unknown surfaces fall back to the client window.
  def idle_ttl_for(resource_type)
    case resource_type.to_s
    when "operator" then OPERATOR_IDLE_TTL
    when "visitor" then VISITOR_IDLE_TTL
    else CLIENT_IDLE_TTL
    end
  end
end
