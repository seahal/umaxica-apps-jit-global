# HMAC PostgreSQL role lifecycle recheck

- Repository: `/home/global/workspace`
- Branch: `feature`
- HEAD: `ccceabd05d2e3a8f923ce398046f99d026a5b78e`
- Worktree: dirty; all pre-existing staged, unstaged and untracked changes were preserved.
- Scope: read-only catalog and migration-source inspection. No role, database, schema, grant or
  migration-history mutation was performed.

## Observed implementation

The APP, COM and ORG HMAC maintenance migrations are already recorded in the corresponding local
development databases (`20261008025001`, `20261008025005` and `20261008025009`). Their `up` paths
create a missing role or reuse one only after checking restricted role attributes, memberships and
foreign database dependencies; an incompatible existing role raises `ActiveRecord::MigrationError`.
The current development catalog contains the expected twelve NOLOGIN, non-superuser roles with no
membership and only the owning development database as a dependency.

The same three applied migration files still contain `DROP ROLE` in `down`. That rollback path does
not prove that the role was created by that migration or that it is not needed by a related
database. This is a historical rollback hazard under the current role-lifecycle contract.

## Disposition

The role-creation/reuse and isolated run-owned cleanup paths remain usable and were not changed.
The old applied migration history was not edited, and no shared or development role was deleted.
The remaining hazard cannot be repaired by a schema/data operation without either editing an
applied migration or introducing an explicit forward-only rollback boundary. Treat rollback of
those historical versions as blocked until the owning migration policy supplies that repair. A
future isolated rebuild may delete only roles whose creation receipt, OID, attributes and complete
dependency set prove that the current run owns them.
