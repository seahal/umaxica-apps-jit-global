# Publishing characterization and index catalog review

Date: 2026-10-19 UTC. HEAD: `87c15e1e5d89344db7dcaaa85ebb1f6972c0c829`. Uncommitted changes
affecting the run: three token reference model fixes and their test additions; a comment-only FIXME
in PublishingTaxonomyTermRecord. New specification/ledger/evidence files and the preexisting
DESIGN.md/diagnostic/evidence files were also present. No migrations ran.

`bin/rails test test/models/publishing/taxonomy_constraints_test.rb  test/models/publishing/taxonomy_retirement_test.rb test/models/publishing/schema_and_models_test.rb  test/models/publishing/media_usage_ownership_test.rb`
with PARALLEL_WORKERS=1 and the existing checked-in test preparation target list: **40 runs, 283
assertions, zero failures/errors/skips**, exit 0. See R6J3 for the exact process-only
preparation-list correction; safeguards stayed enabled.

The current implementation, indexes, helper's normal create!, tests and accepted Publishing taxonomy
ADR confirm that duplicate term slugs raise RecordNotUnique and archived slugs remain reserved. A
standard uniqueness validator would change the exception. The user explicitly chose to preserve this
contract and leave the twelve family term_slug UniqueIndex reports unresolved (decision D1). No
checker/configuration exclusion was introduced and no test was changed for this decision.

A read-only PostgreSQL catalog query captured index definitions, predicates, uniqueness, primary-key
flag, NULLS NOT DISTINCT, validity/readiness and pg_constraint.conindid dependencies for each
model-owned development connection. It covered 3,557 indexes and all 112 reported redundant-index
candidates plus each indicated covering index. Every captured index was valid and ready; no
candidate had a local conindid dependency. This is insufficient to approve deletion: representative
query/ordering/covering behavior, EXPLAIN, production identities and recovery are not verified.
Exact candidate/cover definitions are retained in the open spec's index-review.md. No index or
constraint was changed.

`bundle exec database_consistency` after this cycle: exit 1, **2,113 displayed failure groups**, no
internal checker error. The finding-line set exactly matches C1; individual failures remain 2,171
and the additional warning remains unresolved. `git diff --check`: exit 0.

Local artifacts under `tmp/database-consistency-20261019/`:

| Artifact           | SHA-256                                                            |
| ------------------ | ------------------------------------------------------------------ |
| index-catalog.json | `aedcdc7cbdca5fd8879900a39bd4d71a334522547157c78ff3f34b7c4d827638` |
| c2-after.stdout    | `4669bf9545e3f062f070330cc81c956c64989beb015e80c64ca7ae5b29dac2c1` |

A full Rails run was launched separately and remains unverified by this record. These focused passes
do not establish full-suite success, production migration safety or task completion.
