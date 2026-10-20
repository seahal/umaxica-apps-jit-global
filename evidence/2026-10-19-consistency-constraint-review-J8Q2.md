# Actual identifier constraints and cascade/index review

- Revision: `87c15e1e5d89344db7dcaaa85ebb1f6972c0c829`; worktree has uncommitted remediation and
  unrelated configuration/dump work. This is read-only investigation, not closure.
- `run_isolated_command.py public-id-checks-corrected bin/rails runner tmp/database-consistency-20261019/public_id_checks.rb`:
  exit 0. Inspected 222 actual public_id length-failure targets (216 capacity and six missing
  validators). Of the 216, 109 Publishing targets have validated exact-21 CHECKs. The other 107 had
  none requiring exactly 21 in the inspected catalog; consumer compatibility remains unverified.
  Initial diagnostic stopped on calling a private Rails pool method; corrected retry used the public
  method. No application or DB mutation.
- `cascade-review.md`: all eight actual cascade reports reviewed against
  catalog/associations/checker source. Seven are model-versus-DB deletion differences requiring
  retention decisions. Visitor.visitor_tokens is a cross-DB false match to a composite FK to
  visitor_device_sessions; no cascade was added, and the finding remains open.
- `missing-index-review.md`: all 57 remaining raw association-index reports cataloged. Forty-eight
  are four omitted FK reverse indexes per twelve RP cells; six concern state/outbox lookups; three
  bridge reports demand single-key uniqueness although a composite UNIQUE already covers search. D4
  is a pending four-index local proposal; no DDL executed.
- Durable per-model constraints and dispositions:
  `specs/database-consistency-remediation/public-id-check-review.md`, `cascade-review.md`,
  `missing-index-review.md` and `findings.md`. Raw inventories/logs stay in ignored
  `tmp/database-consistency-20261019/`.
- No production data inspected; no production performance, migration applicability or whole-suite
  success claimed.
