# Scoped identifier column conventions

HEAD: `b781c0d1135f8bc073f98e11b8631de7f7d78a7c`. ORG Telephone application/query/task/test changes
and unrelated source-policy edits remain uncommitted. The full legacy-inventory Rails gate was
running throughout this documentation-only work; no new feature edits occurred.

Source/schema inspection distinguished operator_telephones.public_id and its cross-DB ceremony
reference from encrypted telephone values/proof verifiers. The new identifier conventions link the
actual producer/consumer and durable criterion owners, distinguish implemented expansion/backfill
from pending constraints/cutover, and retain the permission gap rather than claim ORM protection is
a database guarantee.

The three Passkey models generate external_id with SecureRandom.uuid. ORG's concrete management
controller, shared management concern and OperatorPasskeyPolicy use that field; APP/COM management
uses public_id. Schema definitions retain external_id native UUID separately from webauthn_id and
aaguid. These observations are static consumer/schema facts, not a complete external consumer audit
or executed migration. The guideline explicitly refuses to treat the external_id name as proof of
provider format authority. It preserves actual WebAuthn credential/AAGUID and accepted dedicated
user-handle contracts without changing generation or inventing a protocol bound.

Two old database-refactoring reports recommended UUIDv7 or destructive/raw-SQL repair techniques.
They now identify themselves as historical reports and link the accepted current identifier owner;
their original observations are preserved and are not presented as current authorization/results.
The docs index and identifier checklist link the real conventions file. Comprehensive
classification, executable guards and code exception annotations remain incomplete, not superseded
by this sample.

Oxfmt processed the five owned documents; `git diff --check` passed. Direct local inspection
resolved all 27 relative Markdown links in those five files, exit 0. The existing knowledge checker
was executed with those paths via `ruby -rpathname scripts/check-repository-knowledge`; exit 1 on
the same eight `.claude/skills` adapter errors before document validation. No checker, adapter,
permission or hook was changed. Its blocked global result is not replaced by the limited link check.

No application/test/migration commit, production/shared operation or push occurred. Documentation
commits do not snapshot the full dirty implementation. Rails Gate 2 remains pending, and no next
feature may start until its actual result is inspected.
