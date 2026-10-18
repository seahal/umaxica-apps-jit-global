# Preference JWT redundant decode (per-request)

## Summary

`PreferenceAccessTokenTransport#load_access_token_payload` verified the same preference access-token
JWT 6 times on every authenticated HTML request. The decoded payload is already memoized in
`@preference_payload`, so the extra verifications were pure CPU waste. Reduced to 1 verification per
request.

## Evidence (measured)

Profiled one fully authenticated `Sign::Com` GET through the ~16-callback controller lifecycle
(temporary integration harness, since removed). Findings:

- `PreferenceToken.decode` called **6x** per request, every call from
  `preference_access_token_transport.rb` `decode_matching_access_token`, all on the **identical**
  token string. JWT signature verification (`JWT::Claims:: DecodeVerifier.verify!`) showed up in the
  stackprof wall profile.
- `set_preferences_cookie` was the single most expensive before_action (~1.23ms/call); the decode
  work lived inside it.

Two root causes:

1. `load_access_token_payload` decoded the matched token a **second** time:
   `matching_access_token_value` already decodes the matched cookie and assigns
   `@preference_payload`, then the method re-ran `decode_matching_access_token` on the same token.
2. `load_access_token_payload` had no memo guard, so its 3 per-request call sites
   (`set_preferences_cookie`, `resolved_current_token` in `ActorSupport`,
   `load_access_token_preference_record!`) each re-scanned cookies and re-verified: 3 sites x 2
   decodes = 6.

## Fix

`load_access_token_payload` now (a) returns early when `@preference_payload` is already a Hash, and
(b) reuses the payload that `matching_access_token_value` assigns instead of re-decoding the
returned token. `@preference_payload` is the canonical per-request memo and is reset to `nil` when
invalidated (`keep_loaded_access_token_payload?`, `preference_core` reset), so the guard is
consistent with existing invalidation. Result: 6 -> 1 decode/request; `set_preferences_cookie` ~38%
faster (1.23ms -> 0.77ms/call locally).

Verified: sessions controller, preference security/booster/global/localization, preference token
service, authentication flow, auth/preference booster, step-up, verification sessions suites — all
green (227+ runs).

## Not done / follow-up

- The **auth** access-token decode path (`SecurityJwtAuthAccessTokenCodec`) WAS measured with a real
  cookie-based login (set `auth_refresh` -> transparent refresh mints `auth_access` -> second
  request decodes it). Result: exactly **1 decode per steady-state request** -- no redundant
  verification. The sibling does NOT have the preference path's bug; resource resolution is memoized
  via `@current_resource`. No change needed.
- The `current_resource`-loaded-17x-per-request signal seen in profiling is a **test-harness
  artifact** (the test override re-runs `find_by` each call). In production `actor_current_resource`
  reads the in-memory `Actor` after `set_current_actor`, so there is no repeated SQL. Not a real
  issue.
