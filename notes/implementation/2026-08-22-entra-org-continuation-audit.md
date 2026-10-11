# Org Entra ID Continuation Audit

## Context

- Task: reconstruct how far the Org Microsoft Entra ID sign-in implementation had progressed, decide
  what is complete, partial, obsolete, or conflicting, and finish the remaining repository-side
  work.
- Audit date: 2026-08-22.
- Related decisions: `adr/org-entra-id-sign-in-boundary.md`,
  `adr/org-entra-omniauth-strategy-migration.md`,
  `adr/org-entra-single-tenant-credential-configuration.md`,
  `docs/operations/entra-org-login-runbook.md`.

## Branch divergence found first

The audit was started from a worktree branched off `main` (`e6e7ebc95`). On that base the Entra
implementation still read tenant, client id, and client secret from `organization_entra_connections`
rows, served `/sign/in/entra/callback`, blocked all `/social/*` on the org host, and carried a
second, fully duplicated verification stack (`EntraIdTokenVerifier`, top-level `EntraJwksCache`,
`OrgEntraIdentityResolver`, and two value objects) that no production code referenced.

None of that reflects the current repository. `main` is not an ancestor of `develop`; `develop` was
47 commits ahead and already contained the single-tenant credential architecture, the OmniAuth
strategy migration, the provider x surface allowlist, the duplicate-stack consolidation, and the
operations runbook. The `main`-based rework was discarded rather than completed.

**Handoff consequence:** an Entra audit that reads only the checked-out branch will reconstruct a
superseded architecture. Compare against `develop` before concluding anything about Entra state.

## Findings on `develop`

Everything the task specified as required behaviour was already implemented and green: pinned single
tenant with Discovery disabled, PKCE S256, state, nonce, RS256-only JWKS with rotation handling,
`iss`/`aud`/`tid`/`oid`/`acct` validation, `tid + oid` as the only lookup key, no UserInfo/Graph
call, no raw token in the AuthHash, deny-by-default provider x host matrix, no JIT provisioning, and
credentials read from Rails credentials with a boot-time failure when absent.

Three defects remained.

- Decision: stub the token exchange in `test "callback rejects a replayed state"`.
  - Why: the unstubbed path posted the real client id and secret to `login.microsoftonline.com` on
    every run and depended on Microsoft returning `invalid_grant` for a fabricated code. A fresh
    Entra Trace ID appeared in the log on each run, confirming a live round trip. The suite has no
    outbound-network guard (no WebMock/VCR), so nothing else caught it.
  - Also strengthened the assertion: both callbacks return 422, so status alone could not
    distinguish "state consumed, failed later" from "rejected at the state check". The test now
    asserts the failure reason carried on the redirect (`invalid_grant` then `csrf_detected`), which
    is what actually proves single use.
  - Verified with outbound HTTP(S) blocked: 111 Entra/OmniAuth tests pass with no network.

- Decision: make `Auth::Org::Settings::EntrasController` single-tenant.
  - Why: it was the last caller still wired to the superseded per-organization model. `#create`
    required `entra[connection_public_id]` and `find_by!`-ed an ACTIVE
    `OrganizationEntraConnection`, then redirected with `?connection=` to
    `Auth::Org::Social::SessionsController#new`, which ignores that parameter entirely. `#edit`
    rendered one Connect form per connection row. A correctly configured single-tenant deployment
    holds no connection rows, so the settings screen said "no active connection is available" and
    offered no button while `/social/entra/session/new` worked — a user-visible contradiction
    between two screens for the same ceremony.
  - The screen now asks the only question that still has an answer: can the ceremony be started? It
    decides that exactly the way `Auth::Org::Social::SessionsController` does
    (`ProviderSurfacePolicy` plus the `:social_ceremony_org_entra` availability gate), so the kill
    switch closes both entry points together. `connections` was replaced by a single nullable `form`
    prop, matching the ceremony entry page's prop shape, and `empty_notice` by `unavailable_notice`
    carrying the same string that page shows.
  - `organization_entra_connections` itself is untouched: `20260811190000` deliberately kept the
    table and made `connection_id` nullable, because multi-tenant federation is a plausible future
    requirement. Nothing now reads it on the sign-in path.
  - The old tests only passed because they created a throwaway `OrganizationEntraConnection` to
    satisfy the obsolete association. That fixture is gone; the replacement asserts the ceremony is
    offered with zero connection rows present, and adds kill-switch coverage for both actions.

- Decision: mark `notes/implementation/org-entra-sign-in-entry-point.md` superseded in part rather
  than rewriting it.
  - Why: it justifies the sign-in entry point in terms of per-organization multi-tenancy and cites
    `UmaxicaEntra#active_connection_from_params` / `#configure_for_connection!`, which no longer
    exist. The controller and strategy had already been migrated; only the note was stale. Notes are
    historical handoff context, so the reasoning is preserved and the superseding ADR named.

- Decision: correct three more descriptions that the 2026-08-11 change had made false: the schema
  annotation on `OperatorEntraIdentity` (`connection_id` is nullable and has no foreign key since
  `20260811190000`; the model body was already correct, only the generated annotation had not been
  refreshed), the `Auth::Org::Omniauth::OmniauthCallbacksController` header claiming the AuthHash
  carries `connection_public_id` (it carries `tid`, `oid`, `iss`, `sub`), and the comment and
  fixture in `test/unit/security/entra_omniauth_secret_filtering_test.rb`.
  - Why: it described Entra as `private_key_jwt`-based and asserted a client secret that "should
    never exist for entra". Entra authenticates with a client secret under the 2026-08-11 ADR. The
    assertion list is unchanged; `client_assertion` and key/certificate parameters stay covered
    because the production credential mechanism is not final.

## Provisioning and live smoke test (2026-08-23)

The redirect URI was corrected on the Entra registration to `/social/entra/callback` and the stale
`/social/microsoft/callback` entry removed, so the external contract now matches
`ExternalAuthenticationEntraRedirectUri::CALLBACK_PATH`.

- Decision: provisioning is rake tooling calling a service, not a UI and not a console recipe.
  - Why: the runbook said "records must be created directly", which in practice means a console
    session typing raw column values — the one path where a mistyped tenant, a mistyped operator, or
    an accidentally-ACTIVE record is easiest and least visible. `lib/tasks/entra_identity.rake`
    follows the existing ops-task convention (`lib/tasks/social_ceremony.rake`), and the logic sits
    in `OperatorEntraIdentityProvisioner` / `OperatorEntraIdentityActivation` so it is testable.
  - The tenant is not a parameter: it is read from the pinned configuration, so no administrator can
    bind an operator to a tenant this deployment does not federate.
  - Provisioning creates the record inactive and activation is a separate task. That is the ADR's
    deny-by-default data layer, and it keeps "mapped" and "allowed to sign in" as two auditable
    acts.
  - Both tasks refuse rather than overwrite, in both directions: one Entra identity per operator,
    one operator per Entra object. A mistyped `OPERATOR` fails instead of silently moving an
    account.

- Decision: the automatable half of the smoke test is a preflight task, not a Minitest file.
  - Why: it reaches Microsoft. A test file under `test/` would either run in the ordinary suite or
    be a conditionally skipped test, and the suite must stay offline. `OrgEntraSignInPreflight`
    checks credential presence/shape (never values), the redirect URI, the kill switch, the issuer
    the tenant actually advertises, and whether anyone is provisioned, so a failed browser attempt
    points at one cause. Its unit test injects the metadata fetcher.
  - It fetches the tenant's OpenID configuration only to compare issuers. Runtime Discovery stays
    disabled; the endpoints are still derived from the pinned tenant.

## Offboarding reaches the federated credential (2026-08-23)

The audit above stopped at the sign-in path. `OperatorLifecycleRequest` already had a full join /
withdraw / suspend / terminate / restore workflow, but `OrgOperatorLifecycleExecute` never touched
`OperatorEntraIdentity`, and `RetentionCrossDatabaseChildPurge` did not list it either.

Sign-in was never open to a departed operator: the callback gates on `operator&.login_allowed?`, and
withdraw/terminate make `Withdrawable#active?` false. The defects were what the mapping did around
that gate.

- Decision: `withdraw`/`suspend` set the identity to suspended, `terminate` sets it to revoked, and
  `restore` deliberately does not reactivate it.
  - Why: leaving the mapping ACTIVE meant a later `restore` silently re-granted a federated sign-in
    with no separate decision, which is exactly what the deny-by-default identity table exists to
    prevent. Restoring an operator returns their own credentials; re-granting Entra is a separate,
    explicit act.
  - The write crosses from org_principal to org_zenith inside a transaction on the former, so the
    two are not atomic. The order is chosen so the surviving inconsistency is the safe one: the
    identity is withdrawn first, so a failure leaves the person unable to sign in with Entra rather
    than the reverse.

- Decision: the mapping is a logical delete at offboarding and a real delete at retention purge.
  - Why: the repository owner keeps it for audit and deletes it when the window expires. The row
    keeps `(tid, oid)`, the protocol evidence, and `last_authenticated_at`;
    `RetentionCrossDatabaseChildPurge#purge_operator` is where that window ends. Without it the row
    outlived the operator forever as a cross-database orphan (no FK; the databases differ).

- Decision: a rehire is a new operator, provisioned from scratch; no identity is ever restored.
  - Consequence, stated in the provisioner's own error and in the runbook: a withdrawn mapping still
    occupies its `(tid, oid)` until purge, so a returning person cannot be provisioned onto the same
    Entra object before then. The message says that rather than naming an operator that no longer
    exists.

## `suspend` was a deletion countdown, not a suspension (2026-08-23)

`OperatorLifecycleRequest::ACTION_SUSPEND` existed in the model and was accepted by request
creation, but `OrgOperatorLifecycleExecute` routed it into the withdrawal branch:

    when ACTION_WITHDRAW, ACTION_SUSPEND
      suspend_operator!   # purged_at: now + GRACE_PERIOD

So filing a suspension scheduled the operator for deletion in 31 days. Someone on a leave of absence
for a quarter would return to a purged record, and `restore` could not help because the row was
gone. A name that lies is worse than a missing feature: nothing in the request path suggested the
two actions were the same, and no execution test pinned the behaviour.

- Decision: give `suspend` its own semantics rather than adding a third action.
  - Why: the alternative leaves "suspend deletes you in 31 days" and "leave does not" side by side,
    keeping the trap and adding a name to remember. Splitting the branch fixes the latent data loss
    and the duplicate at once.
  - `suspend` now sets only `deactivated_at`, which is what `Withdrawable#suspended?` reads and what
    `AuthenticationWithdrawalGate` and `AuthenticationCurrentResourceResolver` refuse. It leaves
    `withdrawal_started_at`, `discarded_at`, and `purged_at` untouched, so the record survives a
    leave of any length and `restore` returns it.
  - `withdraw` keeps its countdown; the old body was renamed `withdraw_operator!`.
  - The reason for a suspension (leave of absence, disciplinary) belongs in the request's existing
    `reason` column. It does not need its own state: the mechanics are identical.
  - The Entra mapping is suspended either way. Microsoft's account is untouched; returning needs an
    explicit `entra_identity:activate`, consistent with `restore` not silently re-granting.

## Follow-up needed

- Production client authentication (certificate / `private_key_jwt`) is still undecided; dev and
  test use a client secret. Tracked by `adr/org-entra-single-tenant-credential-configuration.md`.
- There is no UI for provisioning `OperatorEntraIdentity`; records must be created directly. Already
  recorded in the runbook.
- The suite has no outbound-network guard. The Entra surface is now offline-clean, but nothing
  prevents the next test from reaching a third party. Worth a separate decision.
