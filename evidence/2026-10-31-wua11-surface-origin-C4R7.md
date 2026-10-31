# Surface redirect origin comparison

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`; the worktree contained uncommitted changes affecting these checks.
- `CommonRedirect#redirect_to_surface_url` previously converted an absolute HTTP URL to a local path when only the hostname matched, without comparing scheme or port. It now uses the same full-origin decision as the existing same-origin-or-Jump path: scheme, hostname and effective port must match, and userinfo is rejected.
- The extracted public origin value is checked for implicit/explicit default ports, adjacent different ports, scheme and hostname differences, hostname case, malformed and relative URLs, missing inputs and userinfo. The related redirect and Jump group passed (170 runs, 942 assertions, 0 failures, 0 errors, 0 skips); scoped RuboCop passed (3 files).
- An attempted full HTTP test configured Auth and Base with the same hostname to exercise different ports, but the FQDN availability registry rejected the duplicate host before the target request. That temporary test was removed. The current evidence therefore tests the origin decision directly and related existing HTTP paths, not a real cross-port browser handoff.
- The existing Jump selection remains in place; pending Away/Jump gateway selection, deployed host configuration and the full suite were not verified.
