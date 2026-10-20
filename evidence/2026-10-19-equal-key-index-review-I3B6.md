# Equal-key reference index candidates

- Revision: `87c15e1e5d89344db7dcaaa85ebb1f6972c0c829`; worktree contains uncommitted remediation
  and unrelated configuration/dump changes. Read-only investigation only.
- `run_isolated_command.py equal-key-index-preflight bin/rails runner tmp/database-consistency-20261019/equal_key_index_preflight.rb`:
  exit 0, three exact key-definition pairs inspected on verified app_zenith/com_zenith/org_zenith
  isolated parents.
- Original ordinary FK indexes on personas.client_identity_id, individuals.visitor_identity_id and
  agents.operator_identity_id match retained UNIQUE indexes in all key/include counts,
  order/opclass/collation/sort flags, NULL-distinct semantics, expressions/predicate,
  tablespace/options. Both members valid/ready; no constraint, replica identity, CLUSTER or
  extension ownership found; automatic table dependency only.
- All three tables have zero local rows; each candidate occupies 8,192 bytes. Actual equality-query
  EXPLAINs were captured but cannot prove production plan stability/selectivity or meaningful
  savings. No synthetic writes were performed.
- Full definitions/properties/plans retained in ignored equal-key-index-preflight.json; durable
  interpretation in specs/database-consistency-remediation/equal-key-index-review.md. All three
  checker findings remain open. No migration, DROP/CREATE, dump update or production operation
  occurred.
