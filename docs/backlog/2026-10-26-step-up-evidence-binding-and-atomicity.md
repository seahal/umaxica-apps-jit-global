# Step-Up evidence: per-record binding and cross-database atomicity

Status: Open (owner, 2026-10-26). Out of the 2026-10 authentication cycle; the owner wants the
impact of this cycle's changes on Step-Up understood first.

From WU-30 (`evidence/2026-10-26-wu30-step-up-consumption-M3A7.md`):

- Step-Up evidence is consumed per audience and security-mode window; current callers pass
  `resource_ref: nil`, so a proof is not bound to the record it authorizes.
- The target-state database and the root-token database share no transaction: if the token
  database fails after the target write commits, the mutation succeeds while the proof stays usable.
- `totp_registration_boundary_test.rb`: 67 runs, 1 failure, 5 errors at the Auth setup
  route/CSRF/region redirect boundary (unresolved).
