# R5-WU11 Tech capability boundary

Date: 2026-10-17 UTC. HEAD `17903f7d121aa33efe29f2db9235c9aa5db4b001`; uncommitted worktree.

- OP/org authority: `POST /api/v0/tech-capability-checks` on Base org
  (`Base::Org::Api::V0::TechCapabilityChecksController`, rate-limited, no-store) backed by
  `TechCapabilityCheckQuery`: tech-org-ww private_key_jwt bound to the exact endpoint, Access JWT
  authenticated for the Tech client, live Tech grant for its sid on the OP writer, and the existing
  writer-backed `TechAccessPolicy` on the real Operator. Every failure (including DB errors) denies.
- RP: `TechCapabilityClient` (fresh assertion per call, no cache, fail closed) and
  `TechRemoteAccessPolicy`; `Tech::Org::ApplicationController#enforce_tech_access!` now authorizes
  through the org authority with the browser's Access JWT. The Tech callback still checks the local
  `TechAccessPolicy` (moves with the WU07 callback switch).
- Results: Tech controller + revocation integration tests 30 runs green (post-revoke request denied
  through the OP endpoint); `TechCapabilityCheckQueryTest` 4 runs green.
