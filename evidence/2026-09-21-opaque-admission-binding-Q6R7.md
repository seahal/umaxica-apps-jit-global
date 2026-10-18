# Opaque admission binding hardening

Date: 2026-09-21

## Scope

The Base/Auth opaque admission path was tightened so the Valkey consume CAS compares
caller-supplied binding fields before changing `issued` to `consumed`. Surface and actor type
are checked for handoffs and local entries. Auth result POSTs now carry the authorization
transaction reference in the form body, and Base requires it to match the result's subject
reference. A binding mismatch returns without consuming the code. Auth result issuance no longer
places the transaction session reference into the `base_session_ref` field.

The browser transport now uses a non-secret admission reference in the GET URL and consumes the
opaque admission only on a same-origin Rails-CSRF-protected POST. Raw admission codes are rejected
when supplied through the legacy GET query parameter. First-party Core, Side, and Edit OIDC
initiators no longer select `screen_hint` for the ordinary browser flow. The TOTP status schema
default was also aligned with the repository's `NOTHING` reference status rather than the active
status.

## Verification performed

- Ruby syntax checks for all changed Ruby files: passed.
- RuboCop for all changed Ruby files: passed, no offenses.
- `git diff --check`: passed.
- Valid browser-admission integration tests were migrated to exercise the public GET-reference /
  CSRF-protected POST contract; the only remaining raw `admission` query test is the intentional
  legacy-rejection case.
- No application, database, Valkey, AWS, or Cloudflare configuration was changed to make tests
  run.

The local-return-target continuation test only verifies that the existing `pt` parameter is
transported through the continuation form; the production controller remains responsible for
validating its signed local-target contract.

## Unverified

The required Rails/Valkey preflight could not connect in this execution context:

```text
PG::ConnectionBad: could not translate host name "primary" to address: Temporary failure in name resolution
```

`getent hosts primary` and `getent hosts valkey-kvs` returned no records. Therefore the focused
Valkey and Base authorization tests for this slice were not executed, and no full-suite result is
claimed. They remain required after running inside the Podman Compose core-service network.

## Remaining boundary work

The result-purpose selection and the remaining admission URL transport migration still require
their own repository-backed slices. This evidence records only the binding/CAS change above.

The result-purpose selection item was subsequently closed by the server-side transaction-intent
binding correction. The remaining admission URL transport migration is still a separate contract
and is not claimed as complete by this evidence.

## Subsequent verification

The required preflight was later completed against the reachable test PostgreSQL and Valkey
services. The focused admission/OIDC regression set passed with `182 runs, 899 assertions,
0 failures, 0 errors, 0 skips`. The full Rails suite then passed with `11,468 runs, 73,279
assertions, 0 failures, 0 errors, 6 skips`.

During that verification, result issuance was found to reuse the transaction reference used by
the preceding handoff. Because both references share the Valkey reference-pointer namespace, the
handoff pointer could collide with result issuance. Result issuance now receives a fresh opaque
reference while retaining the authorization transaction ID in `subject_ref`; the binding and
one-shot consume contract are unchanged. Test cleanup now removes both admission primary keys and
admission-reference pointers.
