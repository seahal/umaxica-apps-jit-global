# Request-body and Auth/Base boundary review

- Date: 2026-09-17 UTC
- Branch: `feature`
- HEAD at review: `7f99c03f8`
- Working tree: pre-existing `README.md` modification, `misc.md`/`refactor.md` deletions, and
  unrelated untracked subscriber/initializer/test/evidence files were preserved.

## Request-body limit review (#845)

The review searched public controllers, middleware, configuration, and security documentation for
body-size enforcement and raw body reads. The current checkout has bounded endpoint-specific paths:

- `app/controllers/concerns/csp_violation_report.rb:51-58` rejects a declared body larger than the
  CSP intake limit and reads at most one byte beyond that limit.
- `app/controllers/auth/app/apple/notifications_controller.rb:28-57` rejects an oversized Apple
  notification before JSON parsing and reads at most one byte beyond its endpoint limit.

No application-wide pre-parser request-size middleware or approved per-endpoint size/media/
streaming matrix was found in `config/application.rb` or the searched security configuration. The
repository does not expose the Cloudflare/origin configuration, so an upstream limit was not treated
as Rails evidence. No new global limit was implemented: a guessed value could reject valid uploads
or protocol bodies, and a check after Rails parsing would not satisfy the security goal.

Result: `CF-009` remains `BLOCKS_SLICE` / `P1`. A future implementation needs an approved matrix, an
origin/edge responsibility decision, and controlled tests for declared, chunked, compressed, and
valid upload inputs before the first unbounded read.

## Auth/Base issuance review (#846)

The current authentication sequence still calls `log_in` in
`app/controllers/concerns/authentication_sequence_gate.rb:513-575`, retains the Auth-side `sign-rp`
client identity in the surface application controllers, and then calls
`BaseAuthAdmissionCoordinator.register_result_and_issue_resume!` at
`app/controllers/concerns/authentication_sequence_gate.rb:597-624`. The coordinator registers the
OIDC result and issues a resume code in `app/services/base_auth_admission_coordinator.rb:136-148`;
the Auth ceremony consumes admission/result state in
`app/controllers/concerns/auth_ceremony_admission.rb:38-77`.

This is enough to confirm the current handoff shape, but not enough to safely remove or relocate
issuance. The accepted Base-only contract still needs an explicit browser binding, one-shot result
consumption, issuer/realm and AAL/AMR propagation, session-limit behavior, stale-result rejection,
and rollback/failure matrix. No partial issuer cutover was made.

Result: `CF-010` remains `BLOCKS_SLICE` / `P0`. The independent realm, revocation, OTP, and
guardrail hardening commits do not claim to complete this architecture migration.

## Commands

```text
git status --short
git log -1 --oneline
rg -n --hidden -g '!log/**' -g '!tmp/**' -g '!vendor/**' "MAXIMUM_BODY|MAX_BODY|body.*limit|limit.*body|content_length|request\.body\.read|413|content_too_large" app config lib docs adr plans test
rg -n "BaseAuthAdmissionCoordinator|register_result_and_issue_resume|log_in\(|oidc_client_id" app/controllers/auth app/controllers/concerns app/services app/operations
```

The review was static. No external edge configuration, production endpoint, database, or
authentication provider was contacted or changed.
