# Equal-key redundant reference indexes

Status: three removal candidates validated structurally on the permitted isolated parents. No
migration generated/applied, index removed, fixture data inserted or dump overwritten. This is not
closure of the findings or production performance/safety approval.

A fresh read-only catalog check confirms identical key counts/order, operator classes, collations,
ordering flags, NULL-distinct semantics, tablespace/options, expressions, predicate and lack of
INCLUDE columns for each pair. Only index name/OID and uniqueness differ. The retained index is
UNIQUE; the candidate is ordinary, so removing the candidate would retain all uniqueness/FK/data
guarantees. Neither index is replica identity or clustered; both are valid/ready. No pg_constraint
selects either index; pg_depend contains only automatic references to their own table. No extension
ownership was observed. This is stronger evidence than prefix coverage by a wider composite key.

The original three hardening migrations added the unique indexes after the reference indexes already
existed, leaving duplicate access paths. Existing model-layer tests protect one identity per
resource. The locale/validation work does not authorize dropping these indexes.

| Connection | Table / key                       | Candidate to remove                      | Retained UNIQUE                          | Local rows | Candidate bytes |
| ---------- | --------------------------------- | ---------------------------------------- | ---------------------------------------- | ---------: | --------------: |
| app_zenith | personas / client_identity_id     | index_personas_on_client_identity_id     | idx_personas_one_per_client_identity     |          0 |            8192 |
| com_zenith | individuals / visitor_identity_id | index_individuals_on_visitor_identity_id | idx_individuals_one_per_visitor_identity |          0 |            8192 |
| org_zenith | agents / operator_identity_id     | index_agents_on_operator_identity_id     | idx_agents_one_per_operator_identity     |          0 |            8192 |

The actual local equality-query EXPLAINs were captured, but all three parent tables are empty. They
do not prove production plan stability, workload selectivity or material savings. Future local
rehearsal needs an explicitly authorized receipt-owned clone, representative non-sensitive fixtures,
up/down/up with concurrent remove/add, complete preexisting-row and constraint retention, and
before/after equality/ordered query plans. Migration down must recreate the original ordinary index
with its exact name/options rather than changing retained uniqueness. Removal failure must stop for
identity/state inspection instead of dropping another similarly named index.

Production prerequisites: fresh target catalog identities/properties/dependencies, table/index size
and workload review, long-transaction/lock budget, recovery build cost and scheduling. No assumption
that these local empty parents represent production. Any proposal to replace the currently empty
app_zenith/com_zenith/org_zenith dumps requires separate scoped authorization; preserve unrelated
work.

Separately, catalog normalization found four duplicate UNIQUE(id)/primary-key access definitions on
Visitor preference option tables that the current redundant-index checkers do not report. They are a
detection limitation, not four resolved findings and not authorization for adjacent removal. Their
constraints/dependencies and runtime ownership still need review before any action.
