# Sign-up failure investigation (app surface)

Read-only log/code investigation. No code changes made.

## Symptom

User report: sign-in succeeds, sign-up fails. Reproduced in `log/development.log` — every sign-up
attempt observed in the log (4 occurrences, e.g. lines 2793-2829, 2913-2932/3149ish, 3225/3240,
3561-3586) ends in `400 Bad Request` before the registration form ever renders. Sign-in, using the
same shared code path, completes with `200 OK` (e.g. lines 2692-2729).

## Reproduction trace (sign-up, `log/development.log:2793-2829`)

1. `Base::App::RootsController#create` (`intent=sign_up`) issues a local admission code
   (`BaseAuthAdmissionCoordinator.issue_local_entry!`) and redirects to `jump.umaxica.net`
   (`app/controllers/base/app/roots_controller.rb:26-33`).
2. Jump service redirects back to `Auth::App::Sign::UpsController#show` with `admission` + `rt`
   params. The `rt` param is verified and stripped
   (`app/controllers/concerns/jump_rt_return_verification.rb:37`), redirecting to the same URL
   without `rt`.
3. `#show` runs again with only `admission` + `ri`.
   `AuthCeremonyAdmission#redeem_admission_and_redirect!`
   (`app/controllers/concerns/auth_ceremony_admission.rb:38-80`) consumes the admission code, sets
   `session[:auth_ceremony_admitted_intent] = "sign_up"` (or, on the handoff branch,
   `session[:oidc_authorization_intent] = transaction.intent`), and redirects (303) to the "clean"
   URL `/sign/up?ri=us` (no admission param). This step succeeds — no error.
4. `#show` runs a third time with only `ri=us`. `ceremony_admission_present?` is true, but the
   intent-match check fails:
   ```ruby
   (stored.blank? || stored == expected_intent) && (local_intent.blank? || local_intent == expected_intent)
   ```
   (`auth_ceremony_admission.rb:27`), so it falls through to
   `render plain: I18n.t("errors.messages.invalid_request"), status: :bad_request`
   (`auth_ceremony_admission.rb:32`). This matches the logged `Rendering text template` /
   `Completed 400 Bad Request` at `log/development.log:2827-2829`. The registration entry page
   (`render_sign_up_entry_page!`) is never reached.

## Comparison against the working sign-in flow

`Auth::App::Sign::InsController#show` runs through the **identical** shared concern
(`AuthCeremonyAdmission`, `expected_intent: "sign_in"`) via the identical `RootsController#create` →
jump → admission-redeem → clean-URL redirect sequence (`log/development.log:2692-2729`). For
sign-in, step 4's final request completes with `200 OK` and renders the real page. This rules out,
as blanket causes, several early hypotheses:

- **Session cookie not surviving the redirect chain** — ruled out. If the `session` cookie itself
  weren't round-tripping across this exact redirect chain, sign-in would fail too, since it uses the
  same cookie, same domain (`.umaxica.app` apex, `secure: false`, `same_site: :lax` in this
  non-`force_secure` dev environment — see `lib/jit_session_cookie_config.rb`), and the same
  controller concern.
- **Valkey/Redis outage** — the log is full of
  `{"event":"valkey.store.unavailable", ..., "store":"rails_performance", ...}` entries, but those
  are from the unrelated `rails_performance` gem's own Redis client (degrades by design, "record
  dropped"), not from `Valkey::AuthState::OpaqueAdmissionStore`
  (`app/services/valkey/auth_state/opaque_admission_store.rb`), which backs admission codes. If that
  store were down, `consume_local_entry!`/`consume_handoff!` would raise
  `Umaxica::Valkey::Unavailable`, which is **not** rescued in `redeem_admission_and_redirect!` —
  that would surface as a 500, not the clean 303 we see in step 3, so the admission store itself is
  reachable and working for both intents.
- `SignUpSuspensionGuard#reject_suspended_sign_up!` — ruled out by content: a suspended sign-up
  renders the entry-page component at `503`, not the plain-text `invalid_request` body at `400` that
  the log shows.
- `AppSignUpEntryPage` concern — read-only prop builder, touches no session state.

## Unresolved: why does step 4's intent check fail only for sign-up?

The code that writes the session value in step 3 and the code that reads it in step 4 are part of
the same shared concern, parameterized only by the string `"sign_up"` vs `"sign_in"`, and
`redeem_admission_and_redirect!` unconditionally assigns (not merges)
`session[:auth_ceremony_admitted_intent] = expected_intent` immediately before redirecting.
Structurally, that assignment cannot itself produce a mismatch on the very next request for the same
`expected_intent`. Two details are worth flagging for closer, **live** (not log-based) inspection,
since they could not be confirmed from static analysis alone:

1. **Query-count asymmetry.** The sign-up redeem (step 3) reports `ActiveRecord: 3.0ms (6 queries)`
   vs. sign-in's `5.2ms (2 queries)` (`log/development.log:2718` vs `:2821`). This is consistent
   with sign-up's redeem taking the **handoff** branch (`consume_handoff!` →
   `OidcAuthorizationTransactionCoordinator.find_by_transaction_id!` →
   `rotate_auth_ceremony_session!`) rather than the cheaper **local** branch that sign-in appears to
   take. If sign-up is consistently falling through to the handoff branch (i.e.
   `consume_local_entry!` reports "local admission missing" every time), the two flows are not
   actually exercising the same code path in practice, despite sharing the same source.
   `Valkey::AuthState::OpaqueAdmissionStore::CODE_TTL` is **60 seconds**
   (`app/services/valkey/auth_state/opaque_admission_store.rb:13`) — worth checking whether the
   local admission code is expiring before it's consumed for sign-up specifically (e.g. a slower
   jump/Turnstile round-trip on the sign-up entry point), and, if the handoff branch is taken,
   whether a matching `sign_up_handoff` transaction was ever issued for this request at all (it does
   not appear to be — `RootsController#create` only ever calls `issue_local_entry!`, never
   `issue_handoff!`).
2. Given (1), the most productive next step is **not** more log reading but a live reproduction with
   either `redis-cli` inspection of the `admission:local_sign_up:*` / `admission:sign_up_handoff:*`
   keys during the flow, or temporary `Rails.logger.debug` around `redeem_admission_and_redirect!`
   to print which branch executes and the resulting `session[:auth_ceremony_admitted_intent]` /
   `session[:oidc_authorization_intent]` values, to confirm whether the write itself is wrong or
   whether it's genuinely not surviving into the next request.

## Scope note

This was a read-only investigation per the request; no code was changed.
