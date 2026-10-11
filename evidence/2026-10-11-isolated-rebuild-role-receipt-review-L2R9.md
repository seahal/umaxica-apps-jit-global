# Isolated rebuild role ownership receipt review

HEAD: `4959e662ade3a00361279cfb325887a4dc852dc4`. Application/test/task and architecture-baseline
changes remain uncommitted; unrelated source-policy and OTP documentation work are preserved. The
Gate 3 full Rails recovery process is live. This review performed no DDL, DML or rebuild.

Direct JSON inspection of the current `20261010p3d2` manifest found twenty database identities,
twelve created-role identities, and a role-creation log SHA256. No creation-evidence path is
recorded. Only counts/presence were printed, not credentials or source data.

Inspection of `scripts/postgresql-rebuild-isolated-test-fleet` shows the pre-drop ownership guard
checks those role OIDs and the digest's shape before permitting removal. Following database and role
reconstruction, the script refreshes `manifest["databases"]` and applies normal migrations, but does
not refresh `created_roles` or the creation receipt. New PostgreSQL role OIDs would thus not match
the prior receipt on a subsequent guarded rebuild. This is a source-level lifecycle finding, not a
destructive reproduction or proof of a completed reusable D-11 cleanup mechanism.

An eventual repair must retain the pre-existing-role rejection and dependency checks, prove actual
creation by the owned execution, and persist the resulting fresh identities before claiming a
repeatable lifecycle. Merely accepting a matching role name or inventing new receipt metadata is not
sufficient. Current test execution does not authorize another rebuild of this fleet, especially
while its sessions are active. The immutable-ID feature and unrelated accepted work remain
independent of this later teardown/rebuild repair once their required test gates pass.
