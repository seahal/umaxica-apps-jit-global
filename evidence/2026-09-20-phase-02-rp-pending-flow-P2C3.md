# Phase 02 RP pending-flow and redirect-security verification

Date: 2026-09-20  
Repository: `seahal/umaxica-apps-jit-global`  
Phase: 02 — state-indexed pending flows and local return-target validation

## Implemented protections

The neutral browser RP path uses the existing state-indexed pending-flow storage with a maximum
of two entries. Each entry carries its own verifier, nonce, return target, creation time, and
optional max-age. A third entry evicts only the oldest bounded entry.

An invalid or stale callback no longer clears all unrelated pending flows. A matching callback
consumes only its own state; an expired matching state is removed while other states remain. A
callback that does not match any pending state clears only legacy scalar compatibility keys and
does not touch the state-indexed flow map.

OIDC return-target validation now delegates to `RedirectsPathTargetResolver`, so external,
protocol-relative, userinfo-bearing, encoded-host, control-character, and nested redirect query
targets are reduced to `/` consistently with the rest of the application.

## Verification performed

Environment was loaded with `UMAXICA_ENV_FILE=/home/global/workspace/.env.devcontainer.example`.

Focused tests:

```text
PARALLEL_WORKERS=1 bin/rails test \
  test/controllers/concerns/oidc/sso_initiator_test.rb \
  test/controllers/concerns/oidc/callback_test.rb \
  test/integration/routes/neutral_rp_entry_contract_test.rb \
  test/services/redirects_path_target_resolver_security_test.rb

33 runs, 367 assertions, 0 failures, 0 errors, 0 skips
```

Static analysis:

```text
bin/rubocop <4 Phase 02 Ruby files>
4 files inspected, no offenses detected
```

Full Rails suite:

```text
bin/rails test
11340 runs, 72391 assertions, 0 failures, 0 errors, 5 skips
```

## Adversarial cases covered

The focused tests cover bounded flow creation, distinct verifier/nonce values, consumed-flow
isolation, expired-flow isolation, invalid callback isolation, and unsafe return-target
partitions including external URLs, protocol-relative URLs, nested redirect parameters, encoded
host escapes, and control characters.

No raw state, nonce, PKCE verifier, or return target was added to logs or evidence. No database
reset, external service modification, GitHub write, or Jump RT key/namespace redesign was done.
