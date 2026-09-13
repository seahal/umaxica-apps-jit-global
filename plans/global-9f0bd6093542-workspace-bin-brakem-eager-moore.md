# Fix Brakeman HTTP Verb Confusion in OIDC End-Session Flow

## Context

`bin/brakeman -a` reports one Weak-confidence warning:

```
HTTP Verb Confusion @ app/services/oidc_end_session_request.rb:70
  if request.get? then ... end
  -- `HEAD` is routed like `GET` but `request.get?` will return `false`
```

The route `resource :logout, only: %i(show create)` (config/routes/acme.rb:104, :244, :392) binds
GET and POST. Per Rack/Rails, HEAD requests reach the same controller action as GET, but
`request.get?` returns `false` and `request.head?` returns `true`. The current code therefore
mis-classifies HEAD as the "POST/confirm" branch and applies side effects that should only happen on
user confirmation.

Two concrete consequences:

1. `app/services/oidc_end_session_request.rb:70` — a HEAD request carrying a legacy `logout_request`
   token falls through `request.get?`, calls `OidcLogoutRequest.verify`, and **consumes the
   single-use token** (replay-store delete). A safe method must not have side effects.
2. `app/controllers/concerns/sign_oidc_logout.rb:24` — identical `request.get?` guard. A HEAD
   request with a valid `id_token_hint` against an authenticated session bypasses the "render
   confirmation page" branch and executes `perform_oidc_end_session_logout` — **revoking tokens,
   clearing cookies, resetting the session, and emitting backchannel logout notifications** for what
   should be a metadata-only probe.

The Brakeman finding is the visible symptom; the concern carries the same latent bug. Both will be
fixed in this change.

## Approach

Treat HEAD as equivalent to GET wherever the code uses `request.get?` to mean "safe / read-only /
show confirmation". This is the documented mitigation for Brakeman's `VerbConfusion` check and is
the smallest correct fix.

### Code changes

**File: `app/services/oidc_end_session_request.rb`**

- Line 70: replace `if request.get?` with `if request.get? || request.head?`.

  ```ruby
  return success(source: SOURCE_LOGOUT_REQUEST, requires_confirmation: true) if request.get? || request.head?
  ```

  Intent: GET and HEAD both mean "the user has not yet confirmed; do not consume the single-use
  `logout_request` token."

**File: `app/controllers/concerns/sign_oidc_logout.rb`**

- Line 24: replace `if request.get?` with `if request.get? || request.head?`.

  ```ruby
  return render :show, status: :ok if request.get? || request.head? || @oidc_end_session_request.requires_confirmation?
  ```

  Intent: GET and HEAD both render the confirmation view; only POST is allowed to trigger logout
  side effects. Rails strips the body from HEAD responses automatically, so `render :show` on HEAD
  remains safe.

No helper method is introduced — only two call sites share the predicate, and the explicit
`request.get? || request.head?` keeps intent readable inline (matches user-confirmed idiom).

### Tests

**File: `test/services/oidc/end_session_request_test.rb`**

Add a HEAD-equivalent test next to the existing GET test (lines 148–158, "legacy logout_request is
not consumed on get"):

- Build a `Request.new(host: @request.host, method: "HEAD")` and assert that:
  - `OidcEndSessionRequest.call(params: { logout_request: token }, request: head_request)` returns
    `success?` with `requires_confirmation?` true and `source == :logout_request`.
  - `OidcLogoutRequest.verify(token)` still returns non-nil after the HEAD call (replay protection
    preserved).

Reuse the existing `Request` test double already used at line 151 and the `call` helper / `@request`
setup in the test file.

**Files: `test/controllers/acme/{app,com,org}/oidc/logouts_controller_test.rb`** (the directories
`test/controllers/acme/app/oidc/`, `.../com/oidc/`, `.../org/oidc/` already exist as untracked per
`git status` — the new controller tests live there)

For at least one surface (recommended: `app`, the highest-traffic surface), add a controller test
that exercises HEAD against the logout endpoint with a valid `id_token_hint` and an authenticated
session, asserting:

- response is 200 and renders `:show` (i.e., does not trigger `perform_oidc_end_session_logout`),
- the session-token record is not revoked,
- `Actor` / session state remains intact,
- no backchannel logout notification is enqueued.

Mirror the pattern used by the existing GET test for the same flow. If the surface-level test
scaffolds differ, scope the new test to the surface that already has authenticated-session helpers
wired up and reference the others with a TODO only if necessary (preferably add to all three for
parity, since the concern is shared).

### Out of scope

- Restricting HEAD at the routing layer — not idiomatic in Rails resource routes and out of
  proportion for a Weak-confidence finding.
- Introducing a `safe_method?` helper — only two call sites; explicit inline form is clearer.
- Touching other `request.get?` call sites in the repo unless they share the same "do/don't perform
  side effect" semantics. None found in the OIDC end-session path.

## Critical files

| File | Change | |
----------------------------------------------------------------------------------------- |
---------------------------------------------------------------------- | --- | -------------- | |
`app/services/oidc_end_session_request.rb` | Line 70: add
`                                                         |     | request.head?` | |
`app/controllers/concerns/sign_oidc_logout.rb` | Line 24: add
`                                                         |     | request.head?` | |
`test/services/oidc/end_session_request_test.rb` | Add HEAD-equivalence test mirroring the existing
GET test at L148 | | `test/controllers/acme/app/oidc/logouts_controller_test.rb` (and `com/`, `org/`
siblings) | Add HEAD-does-not-perform-logout coverage for the `id_token_hint` flow |

## Required harness rules

Per `AGENTS.md`, this change touches a service used by controllers, the surface-shared concern, and
adds tests. Read before editing:

- `.agents/harnesses/rules/project/value-object-boundaries.mdc` — `OidcEndSessionRequest` is a
  service object; preserve its result-data shape.
- `.agents/harnesses/rules/generic/no-silent-fallback.mdc` — the fix must not hide HEAD as a no-op;
  it must explicitly take the "show confirmation, preserve token" branch.
- `.agents/harnesses/rules/generic/testing.mdc` and
  `.agents/harnesses/rules/generic/no-test-only-code.mdc` — new tests cover real behavior, not the
  predicate in isolation.
- `.agents/harnesses/rules/project/surfaces.mdc` — coverage added per surface where the concern is
  included.
- `.agents/harnesses/rules/generic/absolute-rules.mdc` — no `skip_*`, `rescue nil`, or logging of
  tokens introduced.

## Verification

Static (no execution requested by user for this turn — listed for the implementation turn):

1. `bin/brakeman -a` → the `VerbConfusion` warning at `oidc_end_session_request.rb:70` no longer
   appears; total warning count drops from 1 to 0.

Tests:

2. `bin/rails test test/services/oidc/end_session_request_test.rb` — both the existing GET test and
   the new HEAD test pass; the existing "verifies on post and preserves replay protection" test
   still passes.
3. `bin/rails test test/controllers/acme/app/oidc/logouts_controller_test.rb` (and `com/`, `org/`
   equivalents) — HEAD with `id_token_hint` renders confirmation and does not revoke the session
   token; existing GET/POST coverage still passes.
4. `bin/rails test test/controllers/acme/oauth_oidc_authority_test.rb` — broader end-session-related
   integration coverage still passes.

End-to-end sanity (manual, optional):

5. `curl -I -b <session-cookie> 'https://app.example.test/oidc/logout?id_token_hint=<jwt>'` —
   returns 200 with no body, the session cookie remains valid on a follow-up authenticated GET, and
   no logout audit row is written.
