# Identifier index and partition catalog inventory

HEAD: `e091786d132176d2957a2db7b81a2439818a7208`. The worktree includes uncommitted ORG Telephone
application/backfill/test changes and unrelated source-policy changes. This is a read-only catalog
observation, not independent acceptance or a complete code snapshot.

During the pending backfill Gate 2, a temporary Rails runner script used
`Umaxica::TestEnvironment::DatabaseSafety.verify!` and the public
`ActiveRecord::Tasks::DatabaseTasks.with_temporary_connection` interface to inspect the twenty
distinct physical databases in owned fleet `20261010p3d2`. The complete manifest preparation list,
test configuration and workers 1 were retained. No shared/production catalogs or secrets were read.

The script queried public-schema `pg_index`, `pg_class`, `pg_namespace` and `pg_am` for Hash indexes
or indexes whose valid, ready or live flag was false. It also queried `pg_partitioned_table` for
public-schema partition parents. All twenty recorded configuration results had empty flagged-index
and partition-parent sets. A separate log inspection asserted exactly twenty records and those empty
sets; that inspection exited 0. The runner's process was already retired when its session was
polled, so its exit status was not recoverable and is not claimed here.

This observation does not establish identifier-key uniqueness, predicate correctness, INCLUDE
semantics, collation, immutability, ownership classification or production deployment state. Those
conditions remain subject to ID-1 through ID-9 and their public/direct-DB tests. No index
replacement or partition introduction is justified solely by older reports. Rails Gate 2 remains
running; no new feature edit was made while awaiting it.
