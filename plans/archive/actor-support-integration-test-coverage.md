# ActorSupport Integration Test Coverage

**Status:** Archived as superseded (verified 2026-05-19).

Do not implement this backlog note as originally written. Reuse only the lifecycle coverage ideas
that match the accepted `Actor.tld`, `Actor.authentication`, and `Actor.preference` API.

The surviving work is tracked by `specs/actor-current-context-api-cleanup.md`. Current coverage
already includes `test/integration/actor_support_lifecycle_test.rb`,
`test/unit/current/actor_support_test.rb`, and
`test/controllers/concerns/actor_support_included_do_test.rb`.

## Goal

Add integration tests that verify `ActorSupport#set_current` correctly populates `Actor` attributes
during the request lifecycle and resets them afterward. The existing unit tests cover `Actor`
current attributes and `Actor::Preference` value objects well, but do not exercise the
`before_action` / `after_action` wiring through real requests.

## Missing Coverage

### 1. `set_current` request lifecycle

Verify that a request through a controller with `ActorSupport` included:

- Sets `Actor.actor`, `Actor.actor_type`, `Actor.tld`, `Actor.authentication`, and
  `Actor.preference` during the action.
- Does not add new assertions against removed readers such as `Actor.domain` or `Actor.surface`.
- Does not add new direct `Actor.session` or `Actor.token` assertions except while verifying
  migration behavior.
- Resets all `Actor` attributes via `_reset_current_state` after the response.

### 2. `resolved_current_preference` fallback chain

Test the three-stage fallback in order:

1. DB preference record present → `Actor.preference` built from record.
2. No DB record, JWT `prf` claim present → `Actor.preference` built from JWT.
3. Neither present → `Actor.preference` is `NULL` with safe defaults.

Each stage should also verify cookie consent propagation.

### 3. authentication claim resolution

Test resolution paths:

- `access_token_payload` available → used.
- `access_token_payload` unavailable, `load_access_token_payload` available → used.
- Both unavailable → `nil`.
- Non-hash return values → ignored.
- Exception during resolution → `nil`.
- The resolved login/session public id is exposed through `Actor.authentication.login_public_id`.
- Raw access-token claims are available only through the low-level migration escape hatch
  `Actor.authentication.access_claims`, not through new direct `Actor.token` assertions.

### 4. `resolved_current_actor_type`

Test type detection from resource:

- Resource responds to `operator?` and returns `true` → `:operator`.
- Resource responds to `visitor?` and returns `true` → `:visitor`.
- Resource is a `Client` → `:client`.
- Resource is `nil` → `:unauthenticated`.
- `Actor.actor_type` already set → preserved.

### 5. Controller integration (real request round-trip)

For at least one current surface family, verify:

- Authenticated request → `Actor.actor` matches the authenticated resource.
- Unauthenticated request → `Actor.actor` is `Unauthenticated.instance`.
- `Actor.preference` reflects the actor's preference record or JWT claim.
- After response completes, `Actor` attributes are reset.

## Approach

- Items 2-4 can be unit tests in `test/unit/current/` using the existing `Host` stub class pattern
  from `actor_support_test.rb`.
- Items 1 and 5 require controller or integration tests with real HTTP requests. Place in
  `test/integration/` or `test/controllers/concerns/`.
- Use the existing test support headers only where they model production-valid authentication
  boundaries.

## Notes

- `test/controllers/concerns/actor_support_included_do_test.rb` currently has a skipped test for
  `after_action` callback verification. This plan supersedes that skip.
- Avoid mocks for DB-backed preference records; use fixtures instead.
