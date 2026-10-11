# Read-only physical primary-key inventory

HEAD: `f6c36384712b80f1d089d0b49563ffd702e6cd9d`; application/migrations/tests/docs have uncommitted
changes. This is a scoped catalog observation, not completed I acceptance. Full Rails Gate 3 is
running; no feature edits were made during this inspection.

A normal Rails runner verified Umaxica::TestEnvironment::DatabaseSafety for owned run `20261010p3d2`
and queried the public regular/partitioned table catalog across all twenty distinct configured
physical databases. It inspected actual PK column names and SQL types, including model-less tables.
Extension ownership was inspected separately; no values, credentials or personal data were retrieved
and no catalog state was changed. Runner exited 0.

All observed nonstandard PKs except one were Rails-owned `ar_internal_metadata.key` and
`schema_migrations.version`, which retain their framework contracts. In org_zenith,
`staff_identity_audit_events.id` is character varying, not bigint, with no extension ownership.
`staff_identity_audits.event_id` references it through an actual FK in the schema. The app-owned
historical migration `20260201190010_convert_operator_pks.rb` explicitly creates the string PK and
string reference; there is no evidence making it an externally owned table. No current runtime
model/reference was found by the scoped code search; absence of a model is not an exclusion.

This is an unresolved ID-1/I03/I09 violation. A later P6/P12a slice must preserve any existing event
values, referenced audit rows and authority history while introducing bigint internal identity;
string-to-number casting, table deletion and rewriting applied migrations are not acceptable. This
observation does not authorize data modification, final cutover or new raw SQL/trigger scope. Other
ID-1 requirements (table ownership classification, PK write behavior, reference preservation and
executable regression guard) remain separate and are not proven by this catalog scan.
