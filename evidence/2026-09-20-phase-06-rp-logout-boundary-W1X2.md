# Phase 06 RP Logout Boundary Verification

- Date: 2026-09-20
- Repository: `seahal/umaxica-apps-jit-global`
- HEAD at verification: `52efa31df2a28763ad405f604bb3ef0c416b3b93`
- Working tree: pre-existing and task changes were present; no commit, push, or external write was performed.

## Scope

The verification covered the Phase 06 RP-session logout boundary, exact RP-session revoke scope,
Auth/Base logout compatibility, surface isolation, refresh/revoke regression behavior, and the
Core multi-surface smoke and authority tests.

The seven browser RPs use explicit RP-session authority for POST `/sign/out`. Auth's three
ceremony surfaces retain their existing Base Browser Session logout ceremony and are not treated as
RPs. RP logout accepts only the surface-local host-bound RP credentials; it does not fall back to a
Bearer header or a root Browser Session cookie and does not revoke the parent or sibling RP Session.

## RED and correction

The first post-change full-suite run exposed five failures/errors in the logout boundary:

- the three Auth sign-out tests reached the RP-only resolver even though Auth is not an RP;
- the Core BFF smoke and Core authority tests used one integration cookie jar across multiple hosts,
  so host-only RP cookies were not sent after the first surface.

The correction was to make logout authority explicit in the shared concern and to use independent
browser sessions with real RP Access/Refresh cookies in the multi-surface Core tests. No bearer
fallback, root-cookie fallback, or CSRF weakening was added.

## Verification commands and results

Focused Phase 06 suite, after correction and formatting:

```text
PARALLEL_WORKERS=1 bin/rails test [Phase 06 logout/revoke/controller/service test set]
186 runs, 1016 assertions, 0 failures, 0 errors, 0 skips
```

Final authority-explicitation regression subset:

```text
PARALLEL_WORKERS=1 bin/rails test [Auth/Core logout boundary test set]
30 runs, 269 assertions, 0 failures, 0 errors, 0 skips
```

Targeted static checks:

```text
bundle exec rubocop [14 changed Phase 06 files]
14 files inspected, no offenses detected

git diff --check
passed
```

Full Rails suite:

```text
bin/rails test
11375 runs, 72641 assertions, 0 failures, 0 errors, 5 skips
```

The five skips are existing suite skips reported by the test runner; no skip was added for this
change. Routine OmniAuth test diagnostics and existing `LocalEnvironment::KEY` reinitialization
warnings appeared during the suite but did not produce failures or errors.

## Security verification

- RP revoke is performed through `RpSessionRevoker` with `scope: :rp_session`.
- Parent Browser Session and sibling RP Sessions remain outside the RP revoke scope.
- RP Access JWT validation binds issuer, audience, client, resource type, `sid`, JTI, and subject
  to the exact surface-local RP Session.
- Auth/Base logout remains on the pre-existing Base Browser Session path.
- GET sign-out behavior and Rails CSRF protection were not weakened.
- Already-issued Access JWTs remain valid until their natural expiration and configured clock-skew
  window; RP revoke stops refresh and new Access JWT issuance but is not an immediate JWT blacklist.
