# APP social signup completion and ceremony navigation

Status: implementing

## Purpose and authorization

The owner authorized completing APP Apple/Google signup and subsequent sign-in securely, and
unifying the existing Back navigation on five APP ceremony method screens and the ORG emergency
Passkey screen. Existing uncommitted work must remain intact.

## Scope and constraints

Keep issuer, realm, provider, state, nonce, admission, signed phase, expiry, CSRF and account
ownership checks. Use real public-flow tests with external-provider fixtures only at the provider
boundary. Do not manufacture successful authentication or bypass finalization to make tests pass.
Preserve signup versus sign-in intent and existing cancellation. No production/Neon/external writes,
destructive persistence, schema application or unapproved persistent completion shape is authorized.

APP navigation covers Sign In Email/Passkey/Secret and Sign Up Email/Telephone; ORG covers emergency
Passkey. The method-selection entry pages get no new Back link. Use the existing Page header
navigation and localized actions.back; the arrow is supplied by Page.

## Acceptance

- AC-1: New Apple and Google signup reach durable registration, canonical sign-in, Visa result and
  the original RP's authenticated response without changing surface authority.
- AC-2: Existing registered Apple/Google subjects can sign in; signup does not relink another
  account or bypass policy.
- AC-3: Invalid/stale/cross-browser callback and signup evidence are refused without acquiring
  authority. Completion, cancellation and retry preserve committed registration facts. Any
  unresolved persistent recovery requirement remains explicitly open.
- AC-4: The six specified method screens render exactly one top Back navigation, showing the
  localized Back label with Page's decorative arrow. Their destinations remain server-supplied and
  cancellation remains a separate protected action.
- AC-5: Entry method-selection pages retain their current navigation contract. Related tests and
  scoped lint pass; blocked checks are recorded honestly.

## Execution

1. Reproduce social completion and fix obsolete pre-callback Flow assumptions in tests.
2. Follow both signup and sign-in through the real public boundaries and correct demonstrated
   in-scope failures.
3. Assess failure/retry against accepted finalization ADRs; prepare a concrete shape review if
   persistent recovery cannot be implemented under the existing contract.
4. Apply the six-screen header navigation change with focused UI and HTTP checks.
5. Record actual evidence, remaining gates and durable checklist updates.

## Current disposition

Normal signup/sign-in and six-screen navigation acceptance is locally verified by the focused checks
recorded in
[the execution evidence](../../evidence/2026-11-02-app-social-completion-and-back-navigation-T9K4.md).
AC-1, AC-2 and AC-4 have passing public-boundary checks. AC-3's existing
negative/replay/cancellation checks pass, but Source completion/Ticket failure recovery and
cross-tab generation persistence remain open; this spec is not closed and no production-readiness
claim is made. AC-5's focused tests pass; pre-existing lint findings in unchanged methods and the
legacy test helper are reported rather than suppressed. The final combined Ruby run and its
single-worker retry were blocked by test database setup; the earlier successful 37-test and 20-test
runs are recorded separately, not as a combined pass.

The normal journey needed no weakening of application security and no social issuance change. The
demonstrated failures were obsolete pre-callback test assumptions and a transport fixture that
required Authorization on a public JWKS request and required a cached GET to occur. The modern
public HTTP cases now check both providers through actual RP cookies and Dashboard without a
UserInfo success stub. External providers remain mocked at their test boundary.

Persistent recovery is not silently approximated with a verified actor status or audit row. The
existing `plans/2026-11-01-wua2-registration-completion-receipt-shape-review.md` and
`plans/2026-11-01-wua2-social-callback-generation-shape-review.md` explicitly require owner shape
approval. Their tables/writers and migrations were not introduced or applied by this change.
