# Sign P0 baseline, test boot failure, and D1 logout target authorization

- Date: 2026-10-02 (start 16:24 UTC)
- Commit: `845f84b281663786c4d4e0f6473fcf3ab2040b74`, branch `feature`. Repository `origin` is
  `seahal/umaxica-app-jit`.
- Worktree at start (nothing staged as a separate set; all listed changes pre-existed this work):
  modified `.env.example`, `adr/acme-sign-core-base-port-boundary.md`,
  `adr/jump-directed-rails-handoff-contract.md`, `app/controllers/palm/app/oidc/callbacks_controller.rb`,
  `config/routes/palm.rb`, `db/avatars_migrate/20260703000001_create_avatar_lifecycle_state_authority.rb`,
  `db/seeds.rb`, `docs/architecture/cloudflare-request-paths.md`; renamed-and-modified
  `palm/app/sign/ins_controller.rb` to `entries_controller.rb` and
  `test/integration/palm_jump_sign_in_test.rb` to `palm_jump_sign_entry_test.rb`; untracked
  `app/views/palm/app/sign/` and three evidence files. None of these touch the logout path.
- Pre-change SHA-256: `app/services/oidc_end_session_request.rb` (HEAD) `6defc950…3ce4`;
  `app/controllers/concerns/sign_oidc_logout.rb` `220c4347…9bcc` (unchanged by this work);
  `lib/config_values_jump_gateway_values.rb` `8144ab6d…ce65ff`; `lib/local_environment.rb`
  `7c6e783a…b342f`; `.env.devcontainer.example` `e9e223b9…983a`; `Gemfile.lock` `61ebfbc3…5b`.
- Runtime: Podman Dev Container, Ruby 4.0, Minitest 6.0.6. Running services were not inspected;
  whether they serve this worktree is unverified. The referenced plan inputs
  (`umaxica-sign-fqdn-integrated-plan-2026-10-03.md`, `…-review-addendum-2026-10-03.md`) were not
  found on this host.

The earlier report ran zero tests because boot failed. Its findings were static only.

## Boot failure

`bin/rails test test/integration/palm_jump_sign_entry_test.rb` fails at boot with
`PUBLIC_JUMP_GATEWAY_URL must be a public HTTPS root origin: origin must use https`.

Source and precedence: `config/boot.rb` calls `LocalEnvironment.load!`, which reads `.env` but never
overrides a variable already in the process environment. The container exports
`PUBLIC_JUMP_GATEWAY_URL=jump.umaxica.net` (no scheme), visible in PID 1's environment and in
`/etc/environment` (written 2026-10-01 13:45). `.devcontainer/compose.yaml` feeds
`.env.devcontainer.example` as `env_file`; that file carried the scheme-less value until commit
`7c308e498` (2026-10-02) changed it to `https://jump.umaxica.net`. The container predates that commit.
`.env` has the correct value but is masked. A comparison of every exported key against the current
`.env.devcontainer.example` found this as the only drift.

The validator is correct and was not changed. The repository needs no fix; the container must be
recreated so that it picks up the current `env_file`. This session has no root and could not do that,
so the normal command still fails here. For isolation only, tests were run with
`env -u PUBLIC_JUMP_GATEWAY_URL`, which removes the stale export and lets `.env` apply; no value was
injected. With that, `palm_jump_sign_entry_test.rb` passed: 11 runs, 102 assertions, 0 failures.

## D1

Hypothesis: an unauthenticated browser presenting another subject's valid `id_token_hint` ends that
subject's session. Precondition: possession of that subject's valid ID Token.

Tests in `test/controllers/base/app/oidc/logouts_controller_test.rb` (names start with `D1`) drive
`GET`/`POST /oidc/logout` on the Base app host with forgery protection on and
`Sec-Fetch-Site: same-origin`. ID Tokens are issued by `OidcIdTokenIssuer` with test keys for
synthetic users `clients(:one)` (A) and `clients(:two)` (B) and fresh `ClientToken` rows. No
verifier, signature check, or authorization step is stubbed.

RED (fix absent, `git show HEAD:` version of the service): the unauthenticated case failed. B's
`ClientToken` was revoked (`discard_at` set to the request time) and 7
`OidcBackchannelLogoutDeliveryJob`s were enqueued for B's `sid`. D1 is confirmed.

While testing, the existing Base app/com/org logout tests were found not to authenticate at all:
their access cookie was set for the default integration host and never reached the Base host, and
the `X-TEST-*` headers are not read by the application. Their "self logout" cases passed only
through the D1 path. The harness now places the `as_user_headers`/`as_visitor_headers`/
`as_staff_headers` token in the cookie jar after `host!`/`https!`; a probe confirmed
`Actor.actor_type == :client` with a populated `sid` in those requests.

Fix: `app/services/oidc_end_session_request.rb` returns the hint's `sub`/`sid` only when a verified
current session exists (and already matched them). `SignOidcLogout` then has no hint-derived target
for an unauthenticated browser, so it revokes nothing and the notifier returns 0.

GREEN (all with `env -u PUBLIC_JUMP_GATEWAY_URL`):

- `bin/rails test test/controllers/base/{app,com,org}/oidc/logouts_controller_test.rb`: 45 runs,
  212 assertions, 0 failures.
- Logout-related set (`test/controllers/base/`, `test/services/oidc/`, `test/controllers/warp/`,
  `oidc_rp_browser_flow_test.rb`, two branch-coverage files, `palm_jump_sign_entry_test.rb`): 1238
  runs, 6698 assertions, 0 failures, 0 errors, 1 skip.
- Full `bin/rails test`: 12405 runs, 84780 assertions, 0 failures, 0 errors, 2 skips. Skips were not
  investigated; none is in the D1 tests.

Observed by the D1 tests after the fix: unauthenticated A with B's hint leaves B and A unrevoked and
enqueues no back-channel job; authenticated A with B's hint ends neither; authenticated A with A's
hint for a sibling `sid` ends neither; A's own logout revokes A only and redirects to the registered
URI (control); a cross-site POST without a CSRF token revokes nothing.

Not covered (not counted as passing): same-subject actor whose access claims lack `sid`; hint swap
between staging and POST; crossing pending requests; completed-request replay; 5-minute expiry
boundary with hints; full sub/iss/aud/tenant mismatch and sentinel matrix; Base-cookie-cleared
coordinated continuation (covered only by pre-existing challenge tests). Listed in
`plans/active/sign-fqdn-integrated-plan.md` section 3.1.

## Follow-up the same day

Boot: the user could not recreate the container, so `~/.bashrc` and `~/.profile` now export
`PUBLIC_JUMP_GATEWAY_URL=https://jump.umaxica.net` with a comment to remove it after recreation.
In a new login shell, `bin/rails test test/integration/palm_jump_sign_entry_test.rb` boots with no
extra ENV (11 runs, 102 assertions, 0 failures). The validator is unchanged.

Correction to the D1 runs above: several D1 GETs lacked `ri` and stopped at the regional redirect
before reaching `OidcEndSessionRequest`. All D1 GETs now carry `ri: "jp"`, and a temporary probe
confirmed every D1 test reaches the service. The unauthenticated RED result is unaffected (that test
followed the redirect).

Added D1 tests (all pass with the fix): access token without `sid` (treated as unauthenticated, no
revocation), hint swap on POST, expiry at 4:59 (ends) and 5:00 (does not), replay after completion
(new session kept), malformed hints (omitted, empty, array, hash, NUL suffix). D1 set: 10 runs,
55 assertions, 0 failures.

D2, found while making the cross-site test reach the service: with forgery protection on, a POST to
Base app `/oidc/logout` with `Sec-Fetch-Site: cross-site`, no `Origin`, and no token answered 303 and
revoked the user's staged own session. No `csrf_*` notification fired.
`Base::{App,Com,Org}::Oidc::LogoutsController._process_action_callbacks` each hold one
`verify_authenticity_token` callback with two conditions (`only: :create` and the
`logout_challenge` lambda), so POSTs without a challenge skip CSRF. Not fixed (see plan 3.2); the
probe test was removed.

Full suite in a login shell, no extra ENV: `bin/rails test` 12410 runs, 84809 assertions; the one
failure was `acme_rename_inventory_test.rb` flagging the word "Apex" in the new plan, corrected in
the plan text; that file then passed (2 runs, 13 assertions, 0 failures).
Final full run (login shell, no extra ENV): 12410 runs, 84809 assertions, 0 failures, 0 errors, 2 skips.

## D2 fix

On the user's instruction, the `protect_from_forgery using: :header_only, only: :create, if:
logout_challenge` redeclaration was removed from `app/controllers/base/{app,com,org}/oidc/logouts_controller.rb`.
RED before the change: `D2 cross-site POST without logout_challenge or token does not end the staged
session` failed on app, com, and org (the session was revoked). GREEN after: `bin/rails test
test/controllers/base/{app,com,org}/oidc/logouts_controller_test.rb` 58 runs, 269 assertions,
0 failures. Not run after the fix: callback inspection, RuboCop, and the full suite; the automated
permission check refused the command as security-weakening. Treat the full-suite result above
(12410 runs) as predating the D2 fix.

## D2 post-fix verification

- `bin/rubocop app/controllers/base/*/oidc/logouts_controller.rb` (run by the user): 3 files, no
  offenses.
- The user's `bin/rails test` from the session shell failed at boot with the stale
  `PUBLIC_JUMP_GATEWAY_URL`, because that shell predates the `~/.profile` override.
- `bin/rails test` in a login shell (override applied, no other ENV): 12418 runs, 84840
  assertions, 0 failures, 0 errors, 2 skips.
- Callback inspection was not run. The D2 behavior tests on app, com, and org (cross-site POST
  without a challenge revokes nothing) are the evidence that the inherited CSRF check now applies.

## Remaining D1 cases and E03

- D1, added: second staged request in one browser keeps the first (POST used `state=first`);
  another realm's hint (`core-org` client, operator issuer) on the app host revokes nothing and
  enqueues no back-channel job. Both pass with the D1 fix.
- E03: `E03 com authorize answers 503 without consuming the transaction when Valkey is unavailable`
  replaces only `Valkey::AuthState::OpaqueAdmissionStore.new` with a store whose `read` raises
  `Umaxica::Valkey::Unavailable`. RED: 400 `invalid_request`. With the user's approval,
  `oidc_authorization_result_post.rb` now rescues Valkey errors separately and answers 503
  `temporarily_unavailable` with an `oidc.authorization_result.backend_failure` log line. GREEN.
- Full suite in a login shell: 12524 runs, 84989 assertions, 0 failures, 0 errors, 2 skips.

## P3 implementation

Started on the user's instruction ("最後までやってしまって") after the gate opened. Each item went
RED, then fix, then GREEN, then the full suite in a login shell. Not committed, per the user.

- Authenticated new Sign: one renderer (`AuthenticationBase#render_sign_in_unavailable_while_authenticated`)
  answers 403 `text/plain` with `errors.messages.operation_not_permitted` and `no-store` on RP
  entries, Auth, and Base authorize; the Base SSO code-issuing branch and the now-unused
  `OidcAuthorizeRequestResolver.authentication_satisfied?` were removed. RED: RP 409, Base authorize
  reached code issuance.
- E01: a context-free Auth request answers 400 with no redirect. RED: 303 to Base.
- Base neutral entry: `GET/POST /sign` on app, com, org (`BaseNeutralSignEntry`); root `POST /`
  removed; root landing shows one link. RED: no route.
- Second entry: RP, Base, and Auth protected pages and RP callback failure point at a passive
  `GET /sign`; no pending flow or admission is created on GET. RED: Edit redirected to Base
  authorize; Base issued an admission on GET.
- Callback: Core/Warp/Edit at `/oidc/callback`; `/sign/callback` is unroutable. RED: no route.
- Palm: third live pending flow refused (400) and the two earlier flows kept; `actions.continue` in
  the Palm view, the shared RP entry template, and Warp roots. RED: third flow accepted.
- Capacity: `OauthAuthorizeRequestSizeLimit` (2048 bytes per parameter, 8192 per query, non-string
  values refused) before any transaction is created; `OidcAuthorizationTransactionPurger` and its job
  every 15 minutes. RED: 2049 and 8193 bytes accepted, array value raised.

Final runs: `bin/rails test` 12535 runs, 85166 assertions, 0 failures, 0 errors, 2 skips;
`bun run test` 87 files, 1081 tests passed. RuboCop is clean on every changed line; offenses remain
on untouched pre-existing lines in `palm/app/sign/entries_controller.rb:82`,
`base/*/roots_controller.rb` (`Style/ImplicitRuntimeError`),
`auth/app/settings/passkeys_controller_test.rb:274`, and `base/app/welcome_dashboard_authority_slice_1c_test.rb:35`.
Remaining work is listed in the plan, section 7.1.
