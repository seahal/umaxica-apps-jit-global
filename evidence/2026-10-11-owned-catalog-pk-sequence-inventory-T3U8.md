# Rebuilt owned-catalog primary-key and sequence inventory

HEAD: `f21bdb55b0b8b37d62e4d9f18781507339d5acf0`, branch feature; prior owned implementation, tests,
migration, generated schema, rebuild tooling and unrelated source-policy/OTP document work are
uncommitted. This is read-only metadata research during the pending full Gate 2, not another feature
change or final acceptance.

`bundle exec ruby /tmp/identifier-pk-sequence-catalog-20261011.rb` exited 0 against the twenty newly
rebuilt manifest databases in owned fleet 20261010p3d2, primary. Each connection checked its actual
OID/owner/comment against the manifest, used BEGIN READ ONLY and a five-second statement timeout,
and queried only catalog metadata. No nextval, setval, real identifier values, token data, secret
output or application data change was performed.

The actual public-schema catalogs contain 890 primary-key constraints and 852 sequences. Forty
nonstandard keys belong to Rails' schema_migrations/ar_internal_metadata tables. The remaining
observed non-bigint candidate is org_zenith.staff_identity_audit_events.id (character varying), with
its own primary-key constraint. All other observed primary keys are single id/bigint. A second
read-only pass also checked every public ordinary/partitioned table for a missing PK and found none.
This does not by itself establish every table's application/framework ownership or prove safe
migration of that application-owned event catalog and its references.

All 852 sequences have actual bigint type, increment one, cache one, noncycling configuration and an
owning table/column dependency. No public-schema Hash index or partition parent/child was found in
these rebuilt isolated catalogs. These facts do not verify live sequence position/is_called,
explicit-ID writers, replication/failover allocation, other namespaces, production topology, every
identifier index's key/uniqueness/predicate/validity, or the correctness of semantic ID
classification. No partition or replacement index was introduced merely because it was discussed in
the plan.

The local JSON metadata artifact has SHA-256
`fb4bdbceaabe0cb2a5f25f09fd8a10d72f658caf303a5a956c52eabc5ba0da93`. The artifact and runner are
temporary, not committed or permanent policy. ID-1/ID-6 and MIG-1 remain partial pending their
consumer, ownership, migration and dynamic guarantees. This result concerns only the stated owned
test catalogs, not development or production data.
