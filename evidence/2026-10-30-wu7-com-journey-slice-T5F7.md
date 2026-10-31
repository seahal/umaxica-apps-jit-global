# WU-7 slice 6: section 4.1/4.4 com write journey — the shared 4-cookie issuance

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`; nothing committed; worktree = WU-3..WU-7-slice-5
  plus this slice.
- Scope: the com anonymous write now issues the section 4.1 shared cookie set from one entrance and
  the section 4.2 JWT is the row's credential for later reads.

## Code

- `app/controllers/concerns/preference_access_token_issuer.rb` — `issue_access_token_from` branches
  on the anonymous com shape and calls the new `issue_anonymous_com_token_from`:
  - encodes the section 4.2 JWT and **self-verifies it by decode** before queueing any cookie
    (a failed self-verification logs `preference.access_token.self_verification_failed`, sets the
    refresh-failure flag, queues nothing);
  - queues exactly the shared set — `PreferenceCookieName.anonymous_jwt` (test `preference`,
    production `__Secure-preference`), `language` (JS-readable, default `ja`), and
    `PreferenceCookieName.anonymous_experience` (test `experience`, production `__Secure-experience`,
    the JSON of `preferences` minus language);
  - cookie options: Domain = the registrable two-label domain (`nil` for a single-label dev host),
    Path=/, Secure per `force_secure?`/request, HttpOnly for the JWT, SameSite=Lax,
    expires = the 400-day binding TTL;
  - expires the legacy item cookies (`ct/tz/cu/df/tf/mo/dn/ps/preference_consented`) and the legacy
    access/refresh/DBSC names on the same response (D-57 tossing).
- `app/controllers/concerns/preference_base.rb` — `access_token_cookie_name` /
  `access_token_cookie_names` resolve the com surface to the section 4.1 shared name (the transport's
  read/presence/cleanup paths therefore look at the name the writer actually issues); app/org keep
  the access-cookie family until WU-9.
- `app/values/security_jwt_preference_token_codec.rb` — `extract_public_id` reads
  `public_id` first, then falls back to `sub` (the section 4.2 shape carries the row id only in
  `sub`); the legacy decode still asserts `sub == public_id`.
- `app/controllers/concerns/preference_access_token_transport.rb` —
  `decode_matching_access_token` accepts the section 4.2 shape (no `preference_type` claim, `aud`
  `"com"`) without the legacy type equality check; the legacy branch keeps its check.

## Verification

- New integration journey `test/integration/anonymous_com_preference_write_journey_test.rb`: a
  CSRF-tokened consent PATCH on the com cookie screen responds `redirect`, and the response queues
  the four names (`preference`, `language`, `experience`, `preference_binding`); the issued JWT has
  no `client_id`/`preference_type` claims, `aud == "com"`; the JWT's `sub` resolves to a *new live
  anonymous row* whose cookie child stores a binding digest equal to the digest of the presented
  binding value, `consented=true`. Result: 1 run, 27 assertions, 0 failures.
- The matched read-back leg (browser re-presents the issued JWT + binding; screen renders the stored
  consent) is **deferred with the cause recorded**: the com *entry* transport still routes an
  anonymous screen without a presented refresh credential through `ensure_preferences_record`'s
  GET branch, which builds an unpersisted default row — the read-back lands with the
  com-transport-removal slice (the §4.7 matched branch itself is covered by the constant-time
  `matches?` tests).
- WU-7 suite (write boundary + binding + read + payload + token shape + legacy claims): 21 runs,
  129 assertions, 0 failures, 0 errors; directory regression
  (`test/controllers/base/com + test/controllers/concerns/ + preference_web_csrf`): 748 runs,
  9,027 assertions, 2 failures — both recorded baseline ids.
- Rubocop: all six touched files end clean; `ruby -c` passes.

## Remaining in WU-7 (next slices)

- The com entry-transport rewiring (access-only read path + refresh/DBSC removal from the com
  branch, which also closes the matched read-back); section 4.3 destructive columns (owner gate).
