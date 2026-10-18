# ORG Telephone enforcement and permission map

HEAD: `172cdccf13912cc6123c7fe76e95bb4e86c42f6b`. Application/query/task/test changes are
uncommitted alongside unrelated source-policy work. The legacy-inventory full Rails gate was
running. No feature edits or data mutations were performed during this read-only investigation.

A temporary Rails runner verified `Umaxica::TestEnvironment::DatabaseSafety` for the actual test
configuration, selected the OperatorTelephone writing connection in owned fleet `20261010p3d2`, and
read pg_class/pg_namespace/pg_roles/pg_constraint/pg_trigger. It exited 0. No secrets, source PII or
raw proof were printed. The table owner and connection role were both `root`; the connection role
had rolsuper=true and UPDATE privilege on public_id. There were no noninternal triggers on
operator_telephones. The two concrete foreign keys and bigint-ID primary key were validated. The
public_id nonblank CHECK was NOT VALID and explicitly permits NULL.

| Required invariant                                     | Current observed mechanism                                                    | Authorized next step and limit                                                                                                               |
| ------------------------------------------------------ | ----------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------- |
| Source belongs to a concrete Operator/status           | Validated FK constraints                                                      | Preserve those references; no owner substitution.                                                                                            |
| Missing source identities receive one public ID        | Explicit NULL-only bounded backfill under row lock                            | Already implemented separately; preserves old proof, not an ordinary read/write repair path.                                                 |
| No NULL/blank permanent identity after cutover         | Existing nonblank CHECK permits NULL and is not validated                     | Verify backfill/writer/proof prerequisites, then supported Rails constraint validation/NOT NULL migration. No activation on incomplete data. |
| Creation uniqueness                                    | Existing public-ID index documented by the separate catalog/backfill evidence | Real collisions/finite retry are tested separately; this runner did not requery index metadata.                                              |
| Existing identity cannot be changed by bulk/direct SQL | PublicId model validation only; no table trigger; role can UPDATE             | Not established. CHECK/UNIQUE/FK cannot compare OLD with NEW; present superuser/owner privileges do not supply column-update separation.     |

`adr/database-trigger-usage-boundary.md` permits cross-row/table integrity only under its general
rule. Avatar D-3/D-4/D-10 and the named Email/Telephone proof approvals are not a general same-row
public-ID trigger permission. No role creation/change/revoke or new trigger was attempted.

The smallest proposed additional mechanism for this one table is a named BEFORE UPDATE OF public_id
rejection trigger, attached with its function in one reversible migration, raising an explicit
SQLSTATE when a non-NULL OLD identity differs from NEW. It would not mint/rewrite values, change
owner references, log data or block the admitted NULL-only backfill. Ordinary/reference updates
remain legal. This is a proposal requiring scoped user approval, not an accepted exception or
implemented mechanism. Exact inventory registration and real direct-SQL/bulk rejection tests remain
required after approval. No claim is made that it protects against an administrator deliberately
disabling database mechanisms.

Only the ID-4 mechanism for this identified table is held by that permission gap. The current
legacy-inventory gate and independent accepted work remain executable. Broader table discovery,
other ID-4 mechanisms, NOT NULL cutover and real enforcement tests are not proven by this sample.
