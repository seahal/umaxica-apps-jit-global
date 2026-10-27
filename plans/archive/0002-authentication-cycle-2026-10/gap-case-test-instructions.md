# eight.md — Codex instructions: acceptance tests for the Gap cases

> Archived 2026-10-27 from the working file `eight.md` (cycle archive 0002; frozen, not maintained).

Working document (gitignored). Hand this whole file to Codex. Source of the case list:
`seven.md` stage 2 (2026-10-26). Case definitions: `three.md` §2. Decisions: `one.md`.

## Goal

Write request/unit tests for every acceptance case that stage 2 classified as **Gap**, so that each
case is asserted by a named test. The goal is evidence, not green: a test that exposes a defect is
a valid result.

## Read first

- `AGENTS.md`, then the rules it selects for: Minitest (`generic/testing.mdc`,
  `generic/no-test-only-code.mdc`, `project/static-invariant-guards.mdc`), routing and
  authentication (`project/surfaces.mdc`, `generic/routing.mdc`,
  `generic/authentication-boundaries.mdc`, `project/browser-rp-contract.mdc`,
  `docs/architecture/controller-lifecycle.md`), sign-in and sessions (`project/session-issuance.mdc`).
- `seven.md` (stage 2) and `three.md` §2 for each case; the decisions cited by a case in `one.md`.
- Test helpers: `test/support/auth_ceremony_entry_helper.rb` (`admit_auth_ceremony_entry!`),
  `test/support/oidc_auth_admission_test_helper.rb`, `test/support/webauthn_fake_client_helper.rb`,
  existing `test/concurrency/*` for separate-connection tests.

## Hard constraints

1. **Tests only.** Do not change `app/`, `config/`, `db/`, `lib/`.
2. **A defect is reported, not fixed.** If a correct test fails because the implementation
   violates the case: keep the test failing, record the observed behavior, move to the next case.
   Never weaken an assertion, skip, or mark a test pending to get green.
3. Never run `git reset/clean/restore/checkout/stash`; never commit or stage; never reset or
   rebuild a database.
4. Preserve every unrelated change in the worktree. Do not touch logout / sign-out /
   authority-stop code or tests (withdrawn from the cycle), `config/locales/*`,
   `config/initializers/locale.rb`, `.github/workflows/ci.yml`.
5. Do not delete or weaken existing tests. No test-only production code; no `send`, reflection or
   visibility changes to reach private methods.
6. Boundaries (AGENTS.md): test just below, at and just above every limit; cover missing, empty and
   malformed inputs where the case takes input.
7. **"to confirm" cases:** first search for an existing test that already asserts the case under
   another name. If one exists and asserts the full expected outcome, cite it and write nothing.
8. Name every new test with its case ID first, e.g. `test "A12-3: a relay hop repeated at 10 s is refused"`.
   Prefer one file per unit, e.g. `test/integration/acceptance_wu12_relays_test.rb`.
9. Use per-host browser sessions (`open_session`) wherever hosts matter (Base `www`, Auth, Visa).

## Cases, in priority order

### 1. WU-02 — Visa OP / Base RP (security boundary)

- **A02-5** A token carrying the old `www` issuer, and a client assertion with the old audience →
  refused. Cover ID Token / Access JWT verification and the token endpoint client assertion, per
  realm.
- **A02-6** Visa JWKS vs Base JWKS → disjoint key sets (`VISA_*` vs `BASE_*`), per realm, by `kid`
  and key material.
- **A02-9** Ceremony binding confirmation purpose ↔ host → Visa accepts only Sign-in path purposes,
  `www` only Re-verification; the other is refused **before any state change** (assert binding,
  ceremony and transaction rows unchanged). Check `test/controllers/auth/ceremony_admission_boundary_test.rb`
  first (rule 7).
- **A02-12** No Base page reads OP-written Rails-session state → a static guard in the repository's
  invariant-test style (no Base controller/view reads Visa/Auth session keys), plus `/welcome` and
  `/selector` request tests that pass with RP state only.

### 2. WU-29 — Sign entry Sentry (flags BLOCKED)

- **A29-4** While BLOCKED: direct admitted-entry GET, `POST /sign/in`, one continuation POST per
  sign-in method, one Google and one Entra provider callback → refused; no evidence, Flow or
  registration. (`POST /ceremony_bindings` no longer exists, D-179 (1): assert it is not routable
  instead.)
- **A29-5** Root-login commit while Sign In BLOCKED → refusal status; no token, cookie or login
  audit; the flow is not HALTED.
- **A29-6** Sign Up completes while Sign In BLOCKED → the identity persists; no session.
- **A29-7** Flag flipped between two requests of one flow → the second request observes the new
  state (both directions).
- **A29-8** While BLOCKED: authenticated page, Refresh, Sign Out, Step-Up ticket, `prompt=none`,
  SSO code → unaffected. (Sign Out: assert only that the Sentry does not block it; do not test
  sign-out internals.)
- **A29-9** ORG Emergency while `sign_in_available_org=false` → works; ORG invitation while
  `sign_up_available_org=false` → refused.

### 3. WU-12 — Automatic relays (Design D, D-100/D-101/D-104)

- **A12-1** Happy path RP `POST /sign` → … → RP `/oidc/callback` on app, com and org → no Continue
  page rendered; only 303/GET between user steps (assert the response sequence and count).
- **A12-3** The same bound browser repeats a relay hop (attach, confirm, redeem) at 9 s / 10 s / 11 s
  after issuance → same next redirect / refused / refused; no second effect. Not the final result
  GET.
- **A12-4** A repeat whose stored next-hop reference is consumed or expired → refused, never
  re-minted (assert no new reference row).
- **A12-6** The final result GET repeated after the Root Session exists → error; no second Root
  Session.

### 4. WU-07 — Refusal classes (D-73)

- **A07-1c** Retryable (Turnstile) → same page, new challenge, Flow kept, OTP not consumed.
- **A07-1e** Internal inconsistency → 5xx and an auditable record.
- **A07-2** After a refusal, per class: definitive → social intent, Flow locators and ceremony
  continuity removed from the Rails session; retryable → kept; ownership mismatch → nothing of the
  victim's touched; dependency failure → nothing needlessly consumed.
- **A07-3** Log event per refusal → exactly one event with the reason code; no reference, token,
  code or contact value.

### 5. WU-27 — Post-containment journey (D-104, D-130, D-155)

- **A27-1b** Lost response before the auth cookies arrived → the browser is not signed in; a new
  sign-in succeeds; the orphan Root Session is not reused and is removable through session-limit
  remediation.
- **A27-2** Then RP "continue" → SSO code from the existing Root Session; no new Root Session.
- **A27-3** Two tabs started in one browser → OP: each completes or errors on its own bindings, at
  most one Root Session; RP: only the last-started tab completes.

### 6. WU-06 — Curfew

- **A06-4** OP-side parents (ceremony, flows, OIDC transaction, `login_challenge`) → none ends the
  window before the curfew; the OIDC transaction row still exists at 30:01.
- **A06-6b** Finalization whose principal commit and Sign-in handoff land at or after 30:00 (lock
  wait injected through a real separate transaction) → registration kept; the handoff is refused as
  a curfew consumer (no Root Session, Grant or RP session); a later ordinary sign-in succeeds.

### 7. WU-13 — Cancel and Switch

- **A13-4** `/oauth/authorize` with `cancellation_ref` / `switch_handoff` → treated as an ordinary
  authorization request parameter set (no Cancel/Switch job, no state change).

### 8. WU-34 — Unfinished registrations refused (D-106, D-131)

- **A34-2** Each method (OTP, Passkey, Secret, social, TOTP) for a pre-Finalization Client/Visitor →
  refused (request tests, APP and COM where the method exists).
- **A34-5** Failure after the principal's registered commit (graph or OP Flow completion fails) →
  registered: Sign In admits; graph completed at the next sign-in; not deleted by cleanup.

## Verification

- Run each new test file on its own; then `bundle exec rubocop` on the new files.
- Do not run the full suite unless asked; if you do, report it separately from the case results.

## Records

1. `evidence/2026-10-26-acceptance-gap-tests-XXXX.md` (`XXXX` = 4 chars `[0-9A-Z]`):
   - full `git rev-parse HEAD`; note that the worktree is dirty and affects results;
   - a table: case → test file and test name → result (pass / **fail: observed behavior** /
     existing test cited);
   - every implementation defect found, with the case, the request and the observed response or
     state.
2. `seven.md` stage 2: update the Class column of each handled case (`Gap → Mapped`, or
   `Gap → Failing: <one-line defect>`).

## Final report

List per unit: tests added, cases passing, cases failing with the defect, cases resolved by citing
an existing test, and anything skipped with the reason.
