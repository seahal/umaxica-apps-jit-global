# WU-43: RP OIDC `state` as an ES384 JWS, `target_link_uri`, `/sign/interruption`

- Date: 2026-10-23. Base commit `6e4d70d0b0799a4ef9bd9fc4cea2c21d4b3eca72`; change uncommitted.
- Decisions: D-149 … D-155, D-160, D-162. ADR: `adr/rp-oidc-state-and-return-target.md`.

## Change

- `OidcStateJwt` (new value): ES384 JWS with the RP's `oidc_client:<namespace>` key, header `typ`
  `umaxica-oidc-state+jwt`, claims `iss`, `aud` (`<client_id>#oidc-state`), `jti`, `iat`,
  `exp = iat + 30 min`, `v`, optional `target_link_uri`; verification pins ES384, the RP's own key
  set, `iss`/`aud`, no `exp` leeway, 30 s leeway for a future `iat`.
- `RpTargetLinkUri` (new value): relative path only — no query, fragment, dot segment, `%`, `//`,
  nothing under `/sign` or `/oidc`; anything else is ignored.
- `OidcSsoInitiator`: mints the JWS `state`; the session holds exactly one pending entry keyed by
  its `jti` (`OIDC_PENDING_FLOW_LIMIT = 1`, D-155, with the reason at the constant); the RP `pt` is
  gone from the pending entry. The protected-page redirect builds `/sign?target_link_uri=<path>`.
- `OidcRpSignEntry`: `GET /sign` keeps the target as a hidden field; `POST /sign` validates it again.
- `OidcCallback`: verifies the JWS first, then this browser's entry for its `jti` (absent, replaced or
  expired → refused), restores the verified target once; `login_required` → `/sign` (new interactive
  start, D-80/D-110); `access_denied` and every other expected failure → 303 `GET /sign/interruption`
  after cleanup (D-152, D-153); dependency failures stay 503. Pending TTL = 30 min (D-150).
- `GET /sign/interruption` on all 12 RPs (`resource :interruption, only: :show, module: :sign`,
  `OidcRpSignInterruption` concern, one shared template, `no-store`, `no-referrer`, no redirect,
  fixed text in `oidc_rp.interruption.*`, D-160 (4)); added to the runtime-role ownership table and
  the reviewed `set_region` skip list.

## Verification

- New: `test/values/oidc_state_jwt_test.rb` (A43-1 … A43-6, client assertion confusion A43-5;
  29:59 / 30:00 / 30:01), `test/values/rp_target_link_uri_test.rb` (A43-13),
  `test/integration/rp_sign_interruption_test.rb` (A43-17, 12 hosts). 9 runs, 0 failures.
- Updated to the new contract (each test name or comment says so): callback tests (labels become
  the JWS `jti`; 422 plain text → 303 interruption; 10 → 30 min TTL; target path only), initiator
  tests (one pending entry; `/oidc` paths never a target; query not carried), Tech/Palm/Edit/Core
  callback and dashboard tests, neutral entry contract.
- 135 RP sign-in test files: 1240 runs, 39 failures, 5 errors — all in the G-1 baseline list; no new
  failure. Static guards (`test/security`, `test/unit/security`, `test/lib`, route naming): only the
  reviewed allow-list update.
- **Effective window:** 30 minutes holds on the RP side only; until WU-06 the OP's authorization
  transaction (15 min) and `login_challenge` (10 min) end the flow earlier (fail closed).

## Not done / Not run

- D-162 (3) rename of the RP `sign_in_url_with_pt`: **not done.** The name is the abstract contract
  of `AuthenticationBase`, which Auth also implements for its signed `pt` lane; renaming it would
  touch the Auth lane that D-162 forbids touching. The RP implementation now emits `target_link_uri`.
- Not run: A43-9 as a two-tab request test (the replacement is covered by the initiator test),
  A43-9d, A43-9e, A43-11 (CSRF enabled inside the test), A43-18, A43-19 (log assertion), A43-20,
  A43-21 (Auth `pt` lane suite not re-run), A43-15 end to end (needs WU-13).
- Base RPs (`base-*-ww`): the shared concern applies to them too; their pending entry is still lost
  at the OP's sign-in `reset_session` on the shared host until WU-02 (TR G1, D-154).
