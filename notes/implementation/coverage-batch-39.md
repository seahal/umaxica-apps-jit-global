# Coverage Batch 39 Implementation Notes

## Context

- Original plan/spec: continue raising `bin/rails test` line coverage toward 97% and keep
  failures/errors at zero.
- Related decisions/docs/plans: `notes/implementation/coverage-batch-38.md`,
  `docs/operations/development-credential-provisioning.md`.
- Implementation date: 2026-08-31.

Batch 38 concluded that the remaining uncovered lines were an almost uniform spray of one- and
two-line branch fragments, and that writing more ceremony tests had collapsed to roughly six covered
lines per test file. That conclusion was right about the fragments and wrong about the cause. This
batch found a second population hiding inside the same numbers: **code no route can reach**. A
controller action with no route is uncovered for a reason no test can fix, and batch 38's "uncovered
fragment" census counted those lines as if a test could reach them.

## Coverage

Measured before merging origin/main, on this branch alone:

- Starting Rails line coverage: 51,411 / 53,783 (95.5896%).
- Ending Rails line coverage: 51,267 / 53,134 (96.48%).
- Starting branch coverage: 12,094 / 15,885 (76.13%). Ending 12,191 / 15,693 (77.68%).

Those figures are no longer the branch's figures. Roughly 1,100 deleted lines were restored during
the merge (see below), and the merge also brought in upstream's own coverage work, so the number has
to be re-measured on the merged tree before it means anything. The requested target was 97%; this
branch did not reach it on its own, and the census below of what stands between the two is the part
worth keeping.

## What this batch kept, after merging origin/main

This branch was written before PR #857 landed. That PR contains an independent coverage effort over
the same files, and merging the two produced eighteen conflicts. The reconciliation rule was: where
upstream had built tests around code, upstream wins.

That reversed most of this batch's original programme. Three scans (comparing each uncovered `def`
against the method the lookup actually resolves; subtracting every `controller#action` the router
can produce; listing definitions whose name appears nowhere else) had identified a large amount of
code as unreachable, and roughly 1,100 lines were deleted on that basis. Upstream had since written
tests for much of it -- the `SignAuthorityRedirect` host table, `SignSocialAuthenticationEndpoint`'s
provider guard and link step-up, `SignVerificationTotpActions`,
`AuthenticationVisitor#sign_in_url_with_pt`, `Auth::Com::Verification::BaseController`'s private
block, `advance_cycle_to_checkpoint_after_active_session!` -- so 45 files were restored to the
upstream version and the deletions dropped.

Two of those reversals were not merely deferential. `WithdrawalLifecycle`'s
`revoke_sessions(except_public_id:)` and `exclude_fresh_withdrawal_step_up_sessions` were described
by a since-removed withdrawal audit plan as the current design for keeping the requesting session
alive through withdrawal; deleting them as unreferenced would have removed a capability an accepted
plan depends on. Resolved 2026-09-13: the confirmed specification revokes every session, including
the requesting one, and continues withdrawal through the withdrawal ceremony. The code already does
this, and the unused `except_public_id:` exclusion and its tests were removed the same day.

The scans themselves were still worth running -- they are what surfaced the defects below -- but "no
caller in the tree" turned out to be a weak signal in a repository with parallel work in flight, and
the shadowing scan in particular missed includers that are test doubles rather than controllers.

## What survived

- The four defects below, none of which upstream had fixed.
- The three enforcement-case migrations and the locale additions.
- `show?` on the three token policies.
- The new tests: the concern-harness unit tests (AuthenticationBase's per-surface tables, the OIDC
  promotion gate, verification pt/model helpers, the cookie-backed verification record,
  PreferenceCore/PreferenceAdoption/PreferenceBase mappings), the OIDC refresh and revocation
  surface tests, the com verification setup redirect, the removal-endpoint compatibility tests, and
  the nine per-surface identity test files, which carry more cases than their upstream counterparts.
- A narrower set of removals that upstream had not built tests around: the `#resend` actions left
  behind by the redelivery split, and `#options`/`#verification` on the settings passkey
  controllers, both superseded by their own RESTful resources.

## Defects fixed

- **`sign.withdrawal.errors.*` translations were missing.** `Sign::InvalidWithdrawalStateError`,
  `Sign::WithdrawalDeletionError` and `Sign::WithdrawalRecoveryNotAvailableError` all pass an i18n
  key to `ApplicationError#initialize`, which calls `I18n.t`. None of the three keys existed.
  Raising any of them raised `I18n::MissingTranslationData` instead, in place of the error the
  caller asked for; the existing tests hid this by stubbing `I18n.t`. Added
  `errors.deletion_failed`, `errors.invalid_state` and `errors.recovery_not_available` under
  `sign.withdrawal` in `ja.yml` and `en.yml`.

## Defects fixed (continued)

- **The three `.../removal` compatibility endpoints raised on every authenticated request.**
  `Auth::{App,Com,Org}::Settings::RemovalsController#create` is declared
  `AUTHENTICATION_MODE = :private` but never called `authorize!`, so
  `verify_private_action_authorized!` raised `ActionPolicy::UnauthorizedAction`.
  `ActionPolicyUsageTest` allowlists these three actions as "protected by ceremony state rather than
  a durable domain record policy", but that allowlist only silences the static scan -- the runtime
  `verify_authorized` check is unconditional for a private action. Each now authorizes its own actor
  with `show?`, which all three actor policies define as `owner?`. Pinned by
  `test/controllers/auth/settings_removal_compatibility_test.rb`.
- **A failed Turnstile challenge on secret-credential creation returned 500, not 422.**
  `SignSettingsSecretCredentialTurnstileGuard` answered with `render :new`, but both including
  controllers are Inertia-only and have no `app/views/base/{com,org}/identity/secret_credentials`
  directory, so it raised `ActionView::MissingTemplate` (confirmed by temporarily restoring the old
  line and re-running). The guard now delegates the re-render to the surface. Its `update`,
  `destroy` and `else` branches were dead -- both controllers guard `create` only -- and went with
  the fix, along with the now-unused `secret_credential_turnstile_failure_redirect_path`.
- **`SignAuthorityRedirect` matched namespaces that no longer exist.** `sign_authority_host` and
  `base_authority_host` selected a host by matching the controller against `Sign::` / `Acme::`.
  Those namespaces were renamed to `Auth::` / `Base::`, so no branch ever matched and every call
  fell through to `request.host`. The sibling `SignAcmeAuthorityRedirect` had been updated for the
  rename; this one had not. Every remaining caller is a removals controller redirecting within its
  own surface, which is `request.host`, so the selection is now written out directly instead of
  being kept as branches that cannot be taken. `redirect_to_base_authority!`, `base_authority_host`,
  `redirect_to_acme_authority!` and `acme_authority_host` were dead here (the live copies are in
  `SignAcmeAuthorityRedirect`) and were removed, together with two `include ::SignAuthorityRedirect`
  lines in controllers that call nothing from it.

## Pre-existing violations found but not fixed

- `SignEmailOtpRedeliveryEndpoint#resend_email_otp_redelivery` and
  `require_email_nonce_for_redelivery!` pass `alert:` / `notice:` to `redirect_to`, which sets Rails
  flash. `AGENTS.md` forbids flash. Fixing it means replacing the redelivery feedback mechanism,
  which is a UX contract change rather than a coverage change.
- `Auth::{App,Com,Org}::RootsController#index` and their `root_landing_props` are unreachable:
  `redirect_root_to_sign_in` canonicalizes an allowlisted `ri` and `PreferenceGlobal#set_region`
  normalizes anything else, so both GET paths redirect before the action body runs. The action
  cannot simply be deleted -- the route names it -- so it stays as a fallback.

## Tests added

Service-level, no HTTP setup required:

- `test/services/oidc_refresh_token_issuer_surface_test.rb` -- staff and visitor refresh-token
  rotation and replay. `OidcRefreshTokenIssuer` dispatches on the parent token class in three places
  (usage lookup, risk-event actor key, connection touch) and only the client surface was pinned.
- `test/services/oidc_token_revoker_surface_lookup_test.rb` -- the same for revocation, including
  the assertion that a revocation authenticated as a visitor client cannot reach a staff usage row,
  and the sid fallback that revokes an access token bound to a browser session. The existing
  `OidcTokenRevokerCoverageTest` stubs those lookups away.
- `WithdrawalLifecycle`: every actor-class dispatch names the actor class it cannot serve.
- `SignOtpCeremony`: `verify!` refuses a destination the ticket is not bound to without consuming
  the real OTP; `issue!` refuses a channel the ticket is not waiting on.
- `RecoveryPasscodeTopUp`: a credential class with no recovery kind tops up nothing (this is the
  staff case -- `OperatorSecretCredentialKind` has no `RECOVERY`), and an unknown credential class
  is refused by name.

Controller-level:

- `BaseOauthAuthorizationSurfacesTest` gained the OIDC `login_challenge` resume path for com and
  org: resumed exactly once, refused when no sign-in has completed, refused when expired. Both
  `resume_authorization!` methods were entirely unexecuted before this.
- Turnstile failure on the com and org settings-passkey options endpoints, in both the JSON and the
  document shape.

## Not done

- The 18 universally shadowed concern methods (65 lines). Each is small and several read as
  intentional template-method defaults; removing them is a readability judgement, not a correctness
  one.
- `Auth::{App,Com,Org}::Sign::In::Session::CancellationsController` are unroutable, but
  `test/controllers/auth/in/session_cancellations_controller_test.rb` instantiates them directly.
  Deleting them means deleting that test. Left for a decision rather than taken unilaterally.
- A second opinion supplied a list of services referenced only from tests (`OutageService`,
  `TokenEmergencyService`, `AnalyticsConsentGuard`, `AvatarLifecycle::Transition`,
  `OidcJwksService`, `AppleClientSecretProvider`). All six check out as production-unreferenced in
  this worktree, but each has a dedicated test, so deleting them removes mostly-covered lines and is
  a product decision rather than a coverage one. Several other entries on that list --
  `AdministrativeAccessLock`, `DpopJtiReplayGuard`, `ExternalAuthenticationSignupUseCase`,
  `AccountStanding`, `SocialAuthSignupFinalizer`, `Publishing::ArchivedTaxonomyAssignmentError`,
  `ChronicleApplicationService`, `OidcClientStoresStaticClientStore`,
  `StepUpRequirement#aal_supported?` and `#method_allowed?` -- are live here and must not be
  removed.

## Verification

On the merged tree (`git merge origin/main`, eighteen conflicts resolved):

- `bin/rails test test/`: 11,095 runs, 60,984 assertions, 6 failures, 1 error, 1 skip.
- All seven failures/errors are the credential-blocked file described below. Restoring
  `WEBAUTHN_APP_RP_ID` / `WEBAUTHN_APP_ORIGIN` makes all 27 tests in that file pass, which is how
  they were confirmed environmental rather than a code defect.
- The one skip is pre-existing and tracked in issue #846.
- Two of this batch's own test files needed updating for upstream's refactor: PR #857 moved
  `EnforcementCase#apply!` into `EnforcementCaseApplyOperation`, and the standing and recovery page
  tests called the old method.

## Where the remaining 1,915 lines are

A census of the uncovered lines grouped into contiguous runs:

| run length |  runs | lines |
| ---------: | ----: | ----: |
|     1 line | 1,309 | 1,309 |
|    2 lines |   209 |   418 |
|    3 lines |    42 |   126 |
|    4 lines |    16 |    64 |
|   5+ lines |     4 |    27 |

Two thirds of what is left is isolated single lines, and the whole codebase holds only twenty runs
of four lines or more. Covering every multi-line run in the application -- roughly sixty scenarios
-- yields about 200 lines and still leaves the target short; the balance has to come from the 1,309
single lines at approximately one scenario each. Reaching 97% is therefore on the order of 200
further test scenarios, which is a separate programme of work rather than a continuation of this
one.

Counting by method instead: 489 methods are entirely unexecuted, holding 718 lines, spread over 259
files at an average of 2.8 lines per file. The largest single file holds 20.

Two levers that would move the figure are not available in this sandbox. The seven
credential-blocked tests cover the app settings-passkey registration ceremony and pass in CI, where
`test.key` exists. The skipped test in `test/integration/oidc_rp_browser_flow_test.rb` is blocked on
the Sign-side session issuance removal tracked in issue #846.

Three probes during this batch cost effort and returned nothing, because the targets turned out to
be unreachable rather than untested, and they are recorded here so they are not retried: the OIDC
session-limit handoff branch in `AuthenticationSequenceGate` is bypassed by the current design;
`Auth::*::RootsController#index` cannot run because `redirect_root_to_sign_in` and
`PreferenceGlobal#set_region` both redirect first; and the social-completion sign-up path redirects
to sign-in before reaching `complete_social_signup!`.

A fourth lever was tried and reverted: the `respond_to?(:sign_app_..._path)` chains in
`AuthenticationBase`, `AuthenticationRedirects` and `SocialAuth` look like dead per-surface
dispatch, because the first branch is true on the controllers that were sampled. It is not dead --
`respond_to?` differs per controller and the chain fires for the com sign-up checkpoint controllers.
Simplifying it broke sixteen tests. `SocialAuth#social_auth_observability_surface` looks the same
and is also live, because the concern is included by test doubles that a runtime scan over
`ActionController::Base.descendants` does not see.

## Review Notes

- Known failing: the same seven tests in
  `test/controllers/auth/app/settings/passkeys_controller_test.rb` as batch 38. That file deletes
  `WEBAUTHN_APP_RP_ID` / `WEBAUTHN_APP_ORIGIN` in `setup`, so the values must come from
  `config/credentials/test.yml.enc`, which needs the `test.key` issued out of band. Environmental,
  not a code defect.
- Known skipped: one test in `test/integration/oidc_rp_browser_flow_test.rb`, pre-existing and tied
  to issue #846.
- `ControllerInheritanceInvariantTest` failed after the deletions because two `KNOWN_VIOLATIONS`
  entries pointed at deleted files; the test says to remove them, and they were removed.

## Resuming toward 98%

Measured on the merged tree at 97.20% (52,254 / 53,758). 98% needs 429 more covered lines.

What works, in order of observed yield:

1. **Construct the real signed tokens and post the endpoint directly.** Issuing a grant and a result
   through `IdentitySocialCeremonyGrantIssuer` / `IdentitySocialCeremonyResultIssuer` and posting
   them to the completion endpoint reached the largest uncovered file in three tests, about six
   lines each. Driving the same branch through the OmniAuth flow never reached it. The same shape
   should work for the OIDC logout challenge (`AcmeLogoutTransactionCoordinator`) and the step-up
   ceremony grants.
2. **Error branches on paired surfaces.** Each refusal on a ceremony endpoint tends to be three or
   four lines, and the app/com/org copies are near-identical, so one investigation pays three times.
   The MFA passkey refusals went that way.
3. **Concern harnesses for declared seams.** Cheap and safe, but the seams are one-liners, so the
   yield is one to three lines per test. This is what the last few batches were, at roughly 1.2 to
   1.5 lines per test.

What does not work, checked and discarded:

- The 63 routed-but-never-executed actions total only 93 lines; most are `render json: {}` stubs.
- `Roots#index` on every surface is unreachable: `RegionalRootRedirect` has a configured URL for
  both allowed regions, so the callback always redirects first.
- Deleting the 23 still-unrouted controllers moves the figure by +0.06 (they are 207 covered lines
  against 33 missed) and re-opens the merge disagreement.
- Sweeping every surface controller for its declared seams added 3 lines: the seams were already
  reached. It is still worth keeping as a contract, but not as coverage.

The top forty files hold 467 of the remaining 1,504 lines; `/tmp` is not durable, so the ranked list
is regenerated with:

```
ruby -rjson -e 'cov=JSON.parse(File.read("coverage/.resultset.json"))["Rails Tests"]["coverage"]
root=Dir.pwd+"/"
cov.select{|k,_| k.start_with?(root+"app/")||k.start_with?(root+"lib/")}
   .map{|k,v| [v["lines"].count{|x| x==0}, k.sub(root,"")]}
   .select{|r| r[0]>0}.sort_by{|r| -r[0]}.first(40).each{|n,f| puts "%4d  %s" % [n,f]}'
```

Note the resultset now holds two entries, `Unit Tests` (stale) and `Rails Tests` (current). Reading
`.values.first` picks the stale one and gives numbers that do not match the report.

## Two rate-limit arms that cannot fire as declared

Found while covering the limiter refusal handlers; both are shadowed by a rule declared before them
that resolves to the same cache key with a lower limit. Neither is a coverage problem — they are
rules that do not run.

`app/controllers/auth/app/sign/in/secrets_controller.rb`, `secret_credential_create_identifier`
(`to: 10`, keyed by `AuthenticationRateLimitKey.for(surface: :app, identifier:)`) sits after
`secret_credential_create_account` (`to: 10`, keyed by `pending_mfa[:user_id]` or, absent one,
`"unbound:#{request.remote_ip}"`). With no pending MFA both count every request and the account rule
answers first; with a pending MFA the identifier rule is skipped by its own
`unless: -> { pending_mfa_valid? }`. So the per-identifier bound never applies. The org copy of the
same controller has no account rule, which is why its identifier rule does fire and is covered.

`app/controllers/auth/app/sign/in/challenge/totps_controller.rb`, `mfa_totp_create_ip_sustained`
(`to: 20`, keyed by remote IP) sits before `mfa_totp_create_account` (`to: 10`), which falls back to
`"unbound:#{request.remote_ip}"` when no MFA is pending — the same key, at half the limit. The
account rule therefore answers first and the sustained IP rule is unreachable for the
unauthenticated case. It would still fire for requests carrying distinct pending-MFA actors from one
source.

Deciding what the intended bound is belongs to whoever owns the sign-in limiter policy; the tests
pin current behaviour and do not assert the shadowed arms.
