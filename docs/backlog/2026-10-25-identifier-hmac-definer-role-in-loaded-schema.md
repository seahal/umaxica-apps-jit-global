# Identifier HMAC rotation functions name a database-specific definer role

Status: Deferred by the owner on 2026-10-25. Not urgent: ordinary lookup, uniqueness, sign-up and
sign-in compute digests in Rails (`IdentifierBlindIndex`) and are unaffected. Only the emergency
digest rotation (`IdentifierHmacEmergencyRotation`, `adr/identifier-hmac-emergency-rotation.md`) is
affected. No implementation change is authorized by this entry.

## Problem

The identifier HMAC maintenance migrations
(`db/{app,com,org}_principals_migrate/2026100802500{1,5,9}_*_identifier_hmac_maintenance.rb`) create
NOLOGIN definer roles named `umaxica_<realm>_<channel>_hmac_definer_<first 12 hex of
SHA-256(current_database())>` and write that literal name into the `rotate_*_hmac` SECURITY DEFINER
function bodies and the digest-guard trigger functions.

A database built from `db/*_zenith_structure.sql` (test, and any environment built by schema load)
therefore carries the role name of whichever database was dumped, and schema load creates neither
the role nor the function ownership. In such a database the rotation functions refuse
("identifier rotation function owner is invalid") and the emergency rotation cannot run. A database
built by running the migrations is correct.

`lib/tasks/db_verify_no_schema_drift.rake#normalize_roles` enforces the same naming rule, so the
committed dumps must come from the database whose name they encode
(`evidence/2026-10-25-schema-drift-hmac-role-H7Q3.md`).

## Options recorded on 2026-10-25

- A. A fixed role name independent of the database name. Simplest; shares one cluster-wide role
  between databases on the same cluster. Check why the per-database suffix was chosen first.
- B. Derive the role name inside the functions from `current_database()`, and create the role and
  ownership as part of schema load. Keeps per-database isolation; recommended at the time.
- C. Build every environment that needs rotation from migrations, never from the structure file.

## Until resolved

Build production (D-159 rebuild) from migrations, not from the structure file, if the emergency
rotation must be available.
