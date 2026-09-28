# Auth ceremony continuations: TOTP enrolment, sign-up cancel, Step-Up, org MFA, public errors

Commit: 310745dc291913c5b9baaae76738442c4ec9ff1d (HEAD moved during the session; unrelated work was
committed concurrently). The worktree carried uncommitted concurrent work (preference credential
recovery, org administration, dashboards, `authentication_base.rb`); this change edits none of those
lines.

## A. TOTP enrolment

Before:

    GET /settings/totps/new --(session[:private_key] ||= new secret)--> QR shown
    "Cancel" = GET link to /settings/totps  (secret stays in session)
    GET new again --(||= reuses the old secret)--> same QR
    POST /settings/totps (code) --(verify against session[:private_key])--> credential

After:

    GET  /settings/totps/new            display only; no enrolment -> offers "start"
    POST /settings/totps/enrollment     start: session[:totp_enrollment] = {id, secret, expires_at +10m}
    GET  /settings/totps/new            active enrolment -> QR from its secret, form carries its id
    DELETE /settings/totps/enrollment   cancel: removes totp_enrollment, legacy :private_key, :totp_ceremony
    POST /settings/totps (code, id)     id must match the active enrolment, else 409 plain text;
                                        success persists the credential and ends the enrolment

Refresh keeps the same secret (same enrolment id). Start after cancel issues a new secret. A stale
page (earlier enrolment id) or a post after cancel is refused without creating a credential. The
routes exist only on the app host.

## B. Sign-up cancellation

The OTP pages linked "return" to GET /sign/up while the ticket stayed in the session; the next
sign-up in that session answered 422 `invalid_transition` (reproduced by test). The link is replaced
by the existing DELETE /sign/up/check/{email,telephone}/otp (app, com): `SignUpCancellation` marks
the ticket CANCELLED, `sign_up_session_state.clear_all!` clears the session state, 303 to /sign/up.
The cancelled ticket's code no longer advances; a new sign-up proceeds. The decoy flow for an
existing address answers the same 303.

## C. Step-Up continuations

| Continuation | Destination | Authority |
| --- | --- | --- |
| Success | signed `pt` (internal path; purpose, flow, surface, session nonce, 15 min) | server-issued token, unchanged |
| Back | Step-Up method selection (`/verification`) from each method page; none on setup | fixed route |
| Cancel, Base-initiated | Base `POST /verification/cancellation`, then that surface's Base root | server: acme completion state in session; Base resolves its root |
| Cancel, Auth-initiated | Auth settings path of the surface | server: fixed per surface |

Base no longer reads `params[:return_to]`; Auth no longer sends it. Setup has no Back (no earlier
Step-Up state exists); its Cancel works for an actor with no method (cancellations skip
`enforce_step_up_prereqs!`, allowlisted). `setup_pt_path` and `decode_pt_path` were removed. `pt`
remains reusable within its lifetime (not changed here).

## D. Org MFA

Every `log_in` caller passes `require_totp_check: false`. Org sessions are established only by
`sign_org_normal_passkey_ceremony` and `sign_org_emergency_passkey_ceremony`, both with
`auth_method: "passkey"`, which `mfa_bypassed_for_auth_method?` exempts; Entra's second stage is the
normal passkey ceremony; `sign_up_sequence_controller_support` serves app and com only. No org state
reaches MFA_PENDING. Removed: org challenge routes, both controllers, both pages, their tests and
`sign.org.in.mfa.*` locale keys. The emergency passkey ceremony stays routed.

## E. Public error mapping

| Internal condition | Public response/code | Format | User-actionable | Internal only |
| --- | --- | --- | --- | --- |
| Sign-up transition rejected (`invalid_transition`, `failed`, ...) | 422 `errors.messages.invalid_request` | text/plain | no | status logged |
| Sign-up transition `blocked`/`unauthorized` | 403 `errors.messages.not_authorized` | text/plain | no | status logged |
| Sign-up transition `expired` | 410 `errors.messages.invalid_request` | text/plain | no | status logged |
| Sign-up transition succeeded but not finalized | raises (invariant: birthdate is last) | - | - | yes |
| Birthdate `birthdate_format` / `too_long` | 422 `sign.shared.birthdate.errors.format` | text/plain | yes | - |
| Birthdate `birthdate_before_today` | 422 `sign.shared.birthdate.errors.not_before_today` | text/plain | yes | - |
| Birthdate, other validation | 422 `errors.messages.invalid_request` | text/plain | no | attributes logged |
| Passkey record `:too_many` | 422 `errors.webauthn.passkey_limit_reached` | JSON `{error}` | yes | - |
| Passkey record, other validation | 422 `errors.webauthn.verification_failed` | JSON `{error}` | no | attributes logged |
| `stale_checkpoint` | 409 `stale_checkpoint` | text/plain, JSON | reload | existing contract, kept |
| TOTP enrolment id mismatch/absent | 409 `errors.messages.invalid_request` | text/plain | no | - |

The app passkey verification override returning plain text was drift: the one consumer
(`PasskeyRegistrationPanel`) parses JSON only.

## F. Tests

Failing first (observed red before the implementation):

- TOTP: `GET new` left `session[:private_key]`; the old cancel link left the secret; enrolment
  start/cancel/stale-page tests failed on the missing routes.
- Sign-up: OTP page had `return_link` and no `cancel`; birthdate public-key tests (missing keys).
- Step-Up: Base app/com/org redirected to the posted `return_to`; the Auth handoff rendered
  `return_to=/settings/emails?ri=jp`; setup Back pointed at the success continuation
  (`/settings?ri=jp`).
- Org MFA: the four org challenge routes were recognized.
- Passkey limit: app answered `text/plain`.

Added after the implementation (regression): TOTP GET-unroutable and com/org absence (passed
before), enrolment start refused at the slot limit, sign-up decoy-flow cancellation, com/org setup
cancellation, Vitest page tests for the TOTP start/cancel, OTP cancel and setup cancel.

Results:

- Focused suites (TOTP, sign-up, verification, Base Step-Up, org, route contract, burst rate
  limit, passkeys): all green.
- `bin/rails test` (all files except the untracked `preference_credential_recovery_matrix_test.rb`):
  11967 runs, 2 failures, both caused by this change (i18n cleanup key list, skip allowlist) and
  fixed; the two tests then pass. Final `bin/rails test` (every file, the preference matrix test
  now loading): 12006 runs, 0 failures, 0 errors, 2 skips.
- `bun run test`: 1059 passed. `bun run typecheck`: two errors, in
  `spec/features/dashboards/base_dashboard_identity.test.tsx` and
  `src/pages/base/org/avatars/show.tsx`, both files under concurrent edit and not touched here.
- `oxfmt --check` on touched frontend files: clean. `knip`: no findings. RuboCop on touched Ruby
  files: clean except a pre-existing line in `passkeys_controller_test.rb:274`. Architecture
  baseline: entries removed for the deleted org controller; no entry added.
- A clean-worktree run was not possible: this session's edits share files with uncommitted
  concurrent work (locales, routes, baseline files, concerns), so the patch cannot be isolated.
