# WU-A8 Core browser API local-session boundary

- HEAD: `efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8`.
- The worktree had 635 staged, modified, or untracked entries at the final status check; no changes
  were committed.

`CoreBrowserApiBoundary` now authenticates every Core browser Access cookie through
`RpRequestAuthenticator` and its cell-local session. Refresh always uses `RpRefreshCommitter`; the
OP-grant/OP-token fallback, canonical resource lookup, and obsolete resource/token class seams were
removed. A valid Core APP local session reached the API and exposed only its local principal public
ID; its numeric primary key was absent. An Access JWT without the opaque local session was refused.
A simulated Core APP local store connection failure returned 503 while retaining Access and
local-session cookies. The successful refresh endpoint test used the in-process OP transport and
verified the cookie-only 204 response.

The Core browser API boundaries, Core session surfaces, and surface-seam contract passed: 26 runs,
174 assertions, 0 failures, 0 errors, 0 skips. Scoped RuboCop inspected five files with no offenses,
`git diff --check` passed, and a source search found no remaining RuntimeRole or OP-fallback
references in the Core API boundary/controller files. No full suite, external Visa network call,
migration, or production/Neon operation was run. Core ORG success/refresh coverage beyond the shared
implementation and local-session readiness case remains limited.
