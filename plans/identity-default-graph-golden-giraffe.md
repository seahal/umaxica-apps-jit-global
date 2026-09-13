# Identity Default Graph — Signup Invariant Audit

**Plan name:** identity-default-graph-golden-giraffe  
**Status:** partially implemented — social signup path (Finding 1a) remaining  
**Surfaces:** app / com / org

## Implementation Status

| Finding                                            | Status                        | Notes                                                                                                                   |
| -------------------------------------------------- | ----------------------------- | ----------------------------------------------------------------------------------------------------------------------- |
| Finding 1 — email/tel signup cookie precedes graph | ✅ Fixed                      | `IdentityGraphProvisioner.call!` inserted before `handoff_to_sign_in_flow!` in `sign_up_sequence_controller_support.rb` |
| Finding 1a — social signup cookie precedes graph   | ❌ Open                       | `complete_acme_social_signup_flow!` has no graph provisioning                                                           |
| Finding 2 — no transaction in bootstrap            | ✅ Fixed                      | `AcmeSelectorBootstrapAuthority#call` wraps zenith writes in `rp_account_class.transaction`                             |
| Finding 3 — find_or_create scatter                 | ✅ No action needed           | Isolated to bootstrap service                                                                                           |
| Finding 4 — selector deadlock on missing nodes     | ✅ Mitigated by Finding 1 fix | Safety net still in selector                                                                                            |
| Finding 5 — surface selector state                 | ✅ No action needed           | Auto-select works correctly                                                                                             |
| Finding 5a — org invitation path                   | ⏳ Backlog                    | Out of scope for this slice                                                                                             |
| Finding 6 — no repair task                         | ✅ Fixed                      | `lib/tasks/identity_graph_repair.rake` exists                                                                           |
| Finding 7 — DB constraints                         | ✅ No action needed           | Within-zenith constraints are sound                                                                                     |

**Note:** The implementation uses `IdentityGraphProvisioner` rather than
`IdentityDefaultGraphService` as named in this plan.

---

## Context

The desired invariant is: **a principal that holds a session cookie must already have a
selector-ready identity graph.**

The identity default graph consists of (minimum per principal):

| Node           | app                                      | com                    | org                |
| -------------- | ---------------------------------------- | ---------------------- | ------------------ |
| RpAccount      | `ClientAccount`                          | `VisitorAccount`       | `OperatorAccount`  |
| Identity       | `ClientIdentity`                         | `VisitorIdentity`      | `OperatorIdentity` |
| Account        | `Persona`                                | `Individual`           | `Agent`            |
| Collective     | `Enterprise`                             | `Company`              | `Bureau`           |
| CollectiveUnit | `EnterpriseUnit`                         | `CompanyUnit`          | `BureauUnit`       |
| Membership     | `PersonaMembership`                      | `IndividualMembership` | `AgentMembership`  |
| Avatar         | `Avatar` + `Handle` + `AvatarAssignment` | —                      | —                  |

Currently this invariant is **violated**: the graph is created lazily by
`AcmeSelectorBootstrapAuthority` on the first authenticated selector request, which runs **after**
cookies are already issued. This plan documents the audit findings and the required design changes.

---

## Audit Findings

---

### Finding 1 — Cookie precedes graph in all signup paths

**Evidence**

Email/telephone signup finalization in `sign_up_sequence_controller_support.rb:251–299`
(`finalize_sign_up_from_checkpoint!`):

```
finalize_sign_up_side_effect!            # principal status → VERIFIED_WITH_SIGN_UP
perform_sign_up_event(:finalize, ...)    # ticket DB update
handoff_to_sign_in_flow!(actor)          # ← establish_signed_in_session! → log_in → set_login_auth_cookies
                                         #   COOKIES ISSUED HERE
perform_sign_up_event(:handoff_to_sign_in, ...)
perform_sign_up_event(:complete)
```

Graph creation (`AcmeSelectorBootstrapAuthority.call`) runs only at
`acme/app/selectors_controller.rb:38`, `acme/com/selectors_controller.rb`, and
`acme/org/selectors_controller.rb` — all of which fire on the **subsequent** authenticated selector
request.

For social signup (acme ceremony path, `acme/app/social/authentications_controller.rb`), there is a
second cookie-issuance point:

- `complete_social_login!:118` calls `establish_signed_in_session!` immediately when no birthdate
  requirement exists. `complete_acme_social_signup_flow!:184` advances the state machine **after**
  cookies are already in the response.

**Risk**

- Any principal with a valid cookie may have zero zenith graph records. If the first post-signup
  request hits any endpoint protected by `FullAccessController` before the selector, the user gets a
  redirect loop: redirect to selector → selector runs bootstrap → bootstrap fails (any DB error) →
  no graph → selector can present no candidates → `selection_required` with empty list → UI
  deadlock.
- An API client that never hits the selector (e.g., a mobile client that goes directly to an
  authenticated API endpoint) will hold a valid JWT but never trigger graph creation.
- If the bootstrap fails mid-sequence (after `ClientAccount` but before `Persona`), no mechanism
  alerts or retries; the partial state persists until the next selector visit.

**Proposed Change**

Call `IdentityDefaultGraphService.call(surface:, principal:)` in
`sign_up_sequence_controller_support.rb` after `finalized.success?` is confirmed and before
`handoff_to_sign_in_flow!` is called (see Finding 1a below for the social path fix).

**Tests**

- `test/controllers/concerns/sign/up/sequence_controller_support_test.rb`: assert graph provision is
  called before cookie issuance; assert no cookies are issued if graph provision raises.
- Integration test: after email signup, `ClientAccount`, `ClientIdentity`, `Persona`, `Enterprise`,
  `PersonaMembership` exist before the selector is hit.

---

### Finding 1a — Social signup (acme ceremony, no birthdate) issues cookies before graph

**Evidence**

`acme/app/social/authentications_controller.rb`:

- `complete_social_login!:118` → `establish_signed_in_session!` → cookies issued
- Then `complete_acme_social_signup_flow!:184` runs (state machine advance only, no graph creation)

This path fires when a new social account has no additional checkpoint requirements (e.g., birthdate
already supplied via ceremony token). The `Client` is created inside
`SocialAuthSignupFinalizer.call` (inside `AppPrincipalRecord.transaction`), but no graph nodes are
created.

**Risk**

Same as Finding 1, but the window is confined to one request (cookie issued at start of
`complete_social_login!`, graph missing until the selector visit). The selector safety net still
covers it, but the invariant is broken at the response boundary.

**Proposed Change**

Inside `complete_acme_social_signup_flow!`, after the `:finalize` state machine transition succeeds
and before `:handoff_to_sign_in`, call
`IdentityDefaultGraphService.call(surface: :app, principal: commit.user)`.

If `IdentityDefaultGraphService` raises, re-raise; the `with_cycle_lock` block unwinds, the cycle
stays at `:finalize`, and the user is redirected to the sign-in page on the next attempt.

**Tests**

- `test/controllers/acme/app/social/authentications_controller_test.rb`: assert graph provision is
  called inside `complete_acme_social_signup_flow!`; assert a DB error during graph provision does
  not leave the cycle in `:handoff_to_sign_in` state.

---

### Finding 2 — `AcmeSelectorBootstrapAuthority` is not wrapped in a single transaction

**Evidence**

`AcmeSelectorBootstrapAuthority#with_writing_connections` nests multiple
`connected_to(role: :writing)` blocks (principal DB, rp*account/identity DB, token DB, avatar DB).
Each `ensure*\*`call is a separate statement. There is no`ActiveRecord::Base.transaction`or
per-DB`transaction` call wrapping the sequence.

The `ensure_*` methods individually use `find_or_create_by!` with a `RecordNotUnique` rescue
(`create_unique` helper at line 166), which is correct for race safety but does not guarantee
atomicity across all six `ensure_*` steps.

**Risk**

A failure at any step (e.g., `ensure_account!` raises after `ensure_rp_account!` succeeds) leaves a
partial graph. The next bootstrap call is idempotent and will complete the partial graph, but:

- If the failure happens inside the eager provisioning path (Finding 1 fix), no cookies are issued
  and the cycle remains at CHECKPOINT_PENDING — the user can retry.
- If the failure happens during the lazy selector bootstrap (safety net), the user gets an error on
  the selector page. The next reload re-runs bootstrap from the beginning and fills in the missing
  nodes.

The risk is limited because `find_or_create_by!` is idempotent per-step, and the cycle lock prevents
concurrent finalization. However, a full per-DB transaction would make the zenith writes atomic
within each DB boundary.

**Proposed Change**

Wrap the zenith-DB portion of `AcmeSelectorBootstrapAuthority#call` in a single
`rp_account_class.transaction` block covering steps 2–7 (everything except the principal-DB lock and
avatar-DB writes, which are separate DBs). This guarantees that either all zenith records are
created or none are.

For the avatar DB (app surface only), keep `ensure_avatar!` outside the zenith transaction because
it crosses DB boundaries. The `AvatarAssignment.exists?` guard makes it idempotent.

**Tests**

- `test/services/acme_selector_bootstrap_authority_test.rb`: assert that a simulated failure at
  `ensure_account!` leaves no `ClientIdentity` row (zenith transaction rolled back).
- Assert that the full sequence succeeds on retry after a partial failure.

---

### Finding 3 — Lazy `find_or_create_by!` scatter in bootstrap, not in controllers/policies

**Evidence**

All lazy-create logic is confined to `AcmeSelectorBootstrapAuthority` (service layer). The selectors
controllers call it as a single entry point. There is no `find_or_create` in:

- `FullAccessController` (just checks `Actor.selection.selected?` and redirects)
- `AuthorizationClient` / `AuthorizationVisitor` / `AuthorizationOperator` (Pundit, no graph access)
- `ActorSupport#resolved_current_selection` (reads token columns via `try`, nil-safe)

**Risk** — Low.

The scatter is isolated to the bootstrap service. No controller or policy performs lazy graph
creation. No `nil` fallback silently creates missing nodes outside the bootstrap path.

**Proposed Change** — None required.

Maintain the existing structure: bootstrap authority holds all lazy-create logic, and controllers
call it at a single explicit point.

---

### Finding 4 — Selector failure modes when graph nodes are missing

**Evidence**

`AcmeSelectorAuthority#selectable_candidates` (app/services/acme_selector_authority.rb):

- Queries accounts via `ClientIdentity.source_record_id = principal.id`
- Iterates memberships filtered by `.active?`
- App surface cross-products with owned avatars (`AvatarAssignment.where(user_id:, role: "owner")`)
- `avatars_for` returns `[nil]` for com/org surfaces (avatar not required)
- If `Persona` is missing → no identity match → `candidates = []`
- If `PersonaMembership` is missing → `account.current_memberships = []` → `candidates = []`
- If `Avatar` is missing (app surface) → `avatars_for` returns `[]` → no cross-product →
  `candidates = []`

When `candidates = []`, `prepare` returns `{ status: "selection_required", accounts: [] }` and the
selector UI must present a picker with an empty list. The user has no way to advance past the
selector.

`Actor::SelectedContext#selected?` requires all three of `account_public_id`,
`collective_public_id`, `collective_unit_public_id` to be `present?`. Avatar is explicitly optional.
So a missing avatar does not block selection — missing Persona, Collective, or Membership does.

**Risk**

- Missing `Persona` or `Membership` → zero candidates → selector deadlock for the user.
- Missing `Avatar` (app) → zero candidates → same deadlock.
- No automatic fallback; no error message in the UI distinguishes "missing graph" from "multiple
  accounts" (both produce `selection_required`).

**Proposed Change**

The primary fix is eager graph provisioning (Finding 1). As a belt-and-suspenders guard, add a
`before_action :ensure_identity_graph!` to `Acme::{App,Com,Org}::PreAccessController` (the
`ApplicationController` parent for authenticated requests) that calls `IdentityDefaultGraphService`
if the principal's RpAccount is missing. Remove this guard once the repair task (Finding 6) has been
run and eager provisioning is proven stable in production.

**Tests**

- `test/controllers/acme/app/selectors_controller_test.rb`: assert that if bootstrap is stubbed to
  no-op, a principal without a `Persona` gets `status: "selection_required"` with empty candidates,
  and that with bootstrap active the selector returns `status: "selected"` for a fresh signup.

---

### Finding 5 — Surface-specific initial selector state

**Evidence**

After successful bootstrap, `AcmeSelectorAuthority#prepare` runs:

- If exactly one `selectable_candidate` → calls `persist_selection!`, writes the four
  `selected_*_public_id` columns to the token record, returns `{ status: "selected" }`.
- `SelectorsController#show` on the app surface: if `status == "selected"`, redirects to
  `acme_app_dashboard_path`.

Surface-specific differences:

- **app**: full graph required; avatar is mandatory; single personal `Enterprise` → single candidate
  → auto-select.
- **com**: avatar not required; `[nil]` avatar → single candidate → auto-select.
- **org**: invitation-based; no self-service signup; operator invitation path
  (`OrgOperatorLifecycleInvitationAcceptance`) creates an `OperatorAccount` but does NOT run the
  full bootstrap. Subsequent selector visit triggers bootstrap → creates `Agent`, `Bureau`,
  `BureauUnit`, `AgentMembership`.

For app and com, the post-signup flow is: eager bootstrap (new) → cookies → redirect to selector →
selector sees already-bootstrapped graph → auto-selects → redirects to dashboard. No manual
selection screen for first-time users.

For org, the invitation acceptance path is a separate gap (see Finding 5a).

**Proposed Change**

No surface-level selector state change is needed. The initial selector value (auto-select single
candidate) is already correct. Surface differences are encoded in `AcmeSelectorSurfaceConfig` and
the `requires_avatar` flag; the bootstrap service handles them transparently.

---

### Finding 5a — Org invitation path does not bootstrap full graph

**Evidence**

`sign/org/sign/ups/invitations_controller.rb` and `OrgOperatorLifecycleInvitationAcceptance` create
an `Operator` + `OperatorAccount` during invitation acceptance. They do not call
`AcmeSelectorBootstrapAuthority`, so `Agent`, `Bureau`, `BureauUnit`, and `AgentMembership` are
absent until the first selector visit.

This is the org equivalent of Finding 1. The invitation path issues cookies (via
`establish_signed_in_session!`) without a full graph.

**Risk**

Same as Finding 1 for org operators: selector bootstrap is the only safety net.

**Proposed Change**

Call `IdentityDefaultGraphService.call(surface: :org, principal: operator)` inside the invitation
acceptance finalization, before `establish_signed_in_session!`. The exact insertion point is in
`OrgOperatorLifecycleInvitationAcceptance` (file: find under
`app/services/org_operator_lifecycle_invitation_acceptance.rb` or related concern).

This is out of scope for the first implementation slice of this plan. Track in backlog.

---

### Finding 6 — No repair task for existing graph-less principals

**Evidence**

No background jobs, rake tasks, or scheduled workers exist to provision missing identity graphs.
`AcmeSelectorBootstrapAuthority` is the only repair mechanism, and it runs only when the principal
visits the selector.

**Risk**

Principals created before eager provisioning is deployed will not have graphs. If any of them have
active sessions and encounter a selector bug or a direct API call, they are unrecoverable without a
manual intervention.

**Proposed Change**

Add a one-time repair rake task: `lib/tasks/identity_graph_repair.rake`.

```
SURFACE=app DRY_RUN=true  bundle exec rake identity_graph:repair
SURFACE=app DRY_RUN=false bundle exec rake identity_graph:repair
SURFACE=com DRY_RUN=false bundle exec rake identity_graph:repair
# org: org operators are already handled at invitation time; run to be safe
SURFACE=org DRY_RUN=false bundle exec rake identity_graph:repair
```

The task:

1. Reads principals that have no corresponding RpAccount record.
2. Calls `IdentityDefaultGraphService.call(surface:, principal:)` per principal.
3. Logs success/failure per principal; rescues and continues on failure.
4. Is safe to run multiple times (idempotent).

**Tests**

- `test/tasks/identity_graph_repair_test.rb`: principals missing graph are provisioned; principals
  with graph are untouched (no duplicate rows).

---

### Finding 7 — DB constraints within zenith are sound; cross-DB invariant is application-only

**Evidence**

Within each zenith DB:

- `ClientIdentity`: UNIQUE on `source_record_id` and on `(issuer, subject, audience)` — enforces one
  bootstrap identity per principal. Validated at DB and model levels.
- `Persona`: UNIQUE on `client_identity_id` (index `idx_personas_one_per_client_identity`) — one
  persona per identity. FK `client_identity_id NOT NULL` with ON DELETE RESTRICT.
- `PersonaMembership`: FK `persona_id NOT NULL`, `enterprise_id NOT NULL`,
  `enterprise_unit_id NOT NULL`. Composite FK enforces unit belongs to same enterprise. Partial
  UNIQUE on `(persona_id) WHERE primary=true AND revoked_at IS NULL AND ends_at IS NULL` — only one
  active primary membership per persona.
- `ClientAccount`: UNIQUE on `user_id` — one RpAccount per principal.

The FK chains within each zenith DB are correct. No orphaned zenith records are possible within a
single surface DB.

Cross-DB (principal DB → zenith DB): `ClientIdentity.source_record_id` is a string FK to
`clients.id` across DBs. No DB-level foreign key exists or can exist across DBs. The invariant that
every `Client` has a `ClientIdentity` is purely application-enforced.

`ClientToken` selection columns (`selected_account_public_id`, `selected_collective_public_id`,
`selected_collective_unit_public_id`, `selected_avatar_public_id`) are all nullable columns. No DB
constraint prevents a token from having null selection. `Actor::SelectedContext#selected?` and
`FullAccessController#require_selected_actor_context!` are the only gates.

**Risk**

- Cross-DB invariant (Client → ClientAccount, ClientAccount → ClientIdentity → Persona → Membership)
  is application-enforced only. A bug in the provisioning path can leave a principal without a graph
  indefinitely.
- Token selection columns being nullable means selection state is not guaranteed even after
  bootstrap runs, if `persist_selection!` is not called.

**Proposed Change**

No new DB migrations required. The existing within-DB constraints are sufficient for the zenith
graph. The cross-DB invariant must be enforced at the application boundary (eager provisioning +
belt-and-suspenders guard).

Verify that the UNIQUE index on `source_record_id` for `ClientIdentity` / `VisitorIdentity` /
`OperatorIdentity` is present in each zenith schema. If missing, add in a migration.

**Tests**

- Verify: attempting to create a second `ClientIdentity` with the same `source_record_id` raises
  `ActiveRecord::RecordNotUnique` (should already pass if index exists).

---

## Design: `IdentityDefaultGraphService`

A thin named wrapper around `AcmeSelectorBootstrapAuthority` that provides:

- Explicit naming for the signup-side provisioning use-case (distinguishes from the lazy
  selector-side repair use-case).
- Structured error logging so failures are observable.
- A single seam for future extensions (metrics, alerting, async fallback).

```ruby
# app/services/identity_default_graph_service.rb
class IdentityDefaultGraphService
  def self.call(surface:, principal:)
    AcmeSelectorBootstrapAuthority.call(surface: surface, principal: principal)
  rescue => e
    Rails.logger.error(
      "identity.default_graph.provision_failed surface=#{surface} " \
      "principal_class=#{principal&.class&.name} principal_id=#{principal&.id} " \
      "error=#{e.class} message=#{e.message}"
    )
    raise
  end
end
```

Do NOT call `AcmeSelectorAuthority` from this service. Selection column writes require a live
session token, which does not exist at finalization time. The selector's
`AcmeSelectorAuthority#prepare` already auto-selects when there is exactly one candidate — keep that
logic in the selector layer.

---

## Insertion Points

### Email/telephone signup — `sign_up_sequence_controller_support.rb`

Between line 285 (`next unless finalized.success?`) and line 288 (`handoff_to_sign_in_flow!`):

```ruby
next unless finalized.success?

IdentityDefaultGraphService.call(
  surface: sign_up_surface,
  principal: context.pending_actor,
)

sign_in_result = handoff_to_sign_in_flow!(context.pending_actor)
```

`sign_up_surface` is defined on the controller (`sign_up_sequence_controller_support.rb` or
subclass; returns `:app`, `:com`, or `:org`). If `IdentityDefaultGraphService` raises, the exception
propagates out of `with_cycle_lock`, the cycle remains at `CHECKPOINT_PENDING`, and the response
returns a finalization failure — no cookies issued.

### Social signup (acme ceremony, no birthdate required) — `acme/app/social/authentications_controller.rb`

Inside `complete_acme_social_signup_flow!`, after `:finalize` state machine event succeeds, before
`:handoff_to_sign_in`:

```ruby
# after finalize.success? check
IdentityDefaultGraphService.call(surface: :app, principal: commit.user)
# then: SignUpStateMachine.call(event: :handoff_to_sign_in, ...)
```

If the service raises, the cycle stays at `:finalize` and re-raises. On the user's next attempt, the
existing `Client` is found and re-enters the ceremony as an existing account.

---

## Repair Task

`lib/tasks/identity_graph_repair.rake` — run once per surface after deployment:

```
SURFACE=app DRY_RUN=true  bundle exec rake identity_graph:repair
SURFACE=app DRY_RUN=false bundle exec rake identity_graph:repair
SURFACE=com DRY_RUN=false bundle exec rake identity_graph:repair
SURFACE=org DRY_RUN=false bundle exec rake identity_graph:repair
```

---

## Files to Create / Modify

| File                                                                    | Action | Change                                                                                          |
| ----------------------------------------------------------------------- | ------ | ----------------------------------------------------------------------------------------------- |
| `app/services/identity_default_graph_service.rb`                        | Create | Thin wrapper around `AcmeSelectorBootstrapAuthority`; structured error log                      |
| `app/controllers/concerns/sign_up_sequence_controller_support.rb`       | Modify | Call `IdentityDefaultGraphService` after finalized.success?, before `handoff_to_sign_in_flow!`  |
| `app/controllers/acme/app/social/authentications_controller.rb`         | Modify | Call `IdentityDefaultGraphService` inside `complete_acme_social_signup_flow!` after `:finalize` |
| `lib/tasks/identity_graph_repair.rake`                                  | Create | Batch repair rake task; per-surface; idempotent; dry-run                                        |
| `test/services/identity_default_graph_service_test.rb`                  | Create | Delegation, error logging, idempotency                                                          |
| `test/controllers/concerns/sign/up/sequence_controller_support_test.rb` | Modify | Assert provisioning before cookies; assert no-cookie on provision failure                       |
| `test/controllers/acme/app/social/authentications_controller_test.rb`   | Modify | Assert provisioning in `complete_acme_social_signup_flow!`; abort-on-failure                    |
| `test/tasks/identity_graph_repair_test.rb`                              | Create | Missing-principal coverage and idempotency                                                      |

**Out of scope for this slice (track in backlog):**

- Org invitation path (`OrgOperatorLifecycleInvitationAcceptance`) — Finding 5a.
- Belt-and-suspenders `before_action :ensure_identity_graph!` in `PreAccessController` — add after
  repair task confirms zero graph-less principals in production.

---

## Verification

1. **Unit**: `bundle exec rails test test/services/identity_default_graph_service_test.rb`
2. **Concern**:
   `bundle exec rails test test/controllers/concerns/sign/up/sequence_controller_support_test.rb`
3. **Social**:
   `bundle exec rails test test/controllers/acme/app/social/authentications_controller_test.rb`
4. **Selector regression**: confirm existing selector tests still pass:
   `bundle exec rails test test/controllers/acme/app/selectors_controller_test.rb`
5. **Rake dry-run**: `SURFACE=app DRY_RUN=true bundle exec rake identity_graph:repair` should report
   zero missing principals after an empty DB seed, and N principals after creating N Client records
   without bootstrapping.
6. **End-to-end**: after email signup, before hitting the selector, verify that `ClientAccount`,
   `ClientIdentity`, `Persona`, `Enterprise`, `EnterpriseUnit`, and `PersonaMembership` exist for
   the new `Client`.
