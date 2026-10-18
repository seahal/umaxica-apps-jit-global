# Retention Frozen Plan final re-review

- Date: 2026-09-22 UTC
- HEAD: `277673d13547d722fc88f830711eee69b923a7e8`
- Scope: Frozen Plan retention-purge acceptance wording and its adversarial re-review.
- Worktree: pre-existing implementation and documentation changes were preserved. This review did
  not modify application code, tests, migrations, schema, configuration, databases, or external
  services.
- External writes: none; no GitHub, AWS, Cloudflare, provider, production, shared database, email,
  or SMS service was contacted.

## Ambiguity found and corrected

The superseded retention wording described the FREQ-0064 acceptance criterion as
`dry-run/bounded deletion`, and the requirement ledger placed the work in `Phase 5/6 audit and
dry-run slices`. The slash made a new dry-run capability appear co-equal with the actual safety
property of bounded destructive processing. A separate Phase 7 dependency also called the
source-owner inventory a `source-owner dry-run` without saying that it was an unrelated, read-only
authority-mapping investigation.

The Frozen Plan now states that RetentionPurgeJob safety is provided by the existing explicit
allowlist, finite batch/scope execution, writer-database clock, retention holds, enforcement
blocks, and operational kill switch. The Phase 7 dependency is now named `read-only source-owner
inventory`. The remaining uses of `dry run` or `preview` are explicitly classified as separate
source-owner inventory history, separately approved data transformation safety, or optional
promotional-unsubscribe UX; none is a RetentionPurgeJob capability.

## Revised acceptance contract

Retention deletion/anonymization must:

- use an explicit allowlisted model/scope set;
- process each operation through an explicit finite batch/scope;
- evaluate eligibility using the writer-database retention clock at the decision point;
- respect applicable retention holds and enforcement blocks;
- stop before destructive work when the operational kill switch is enabled; and
- preserve data required by an approved model-specific retention, hold, enforcement, or archive
  rule.

`RetentionPurgeJob.preview`, `perform(dry_run: true)`, a dry-run-only service or command, a
dry-run-only audit event, and a dry-run-only schema are not required and must not be added solely
for this acceptance criterion. Notification delivery, receipt, retry, and permanent-failure
semantics remain independent.

## Evidence for the existing implementation

- `app/jobs/retention_purge_job.rb:22-43` defines the explicit allowlist.
- `app/jobs/retention_purge_job.rb:55-79` uses the writer-database clock and
  `in_batches(of: batch_size)` with the recurring `batch_size: 500`.
- `app/jobs/retention_purge_job.rb:45-59` checks the operational kill switch before destructive
  work.
- `app/jobs/retention_purge_job.rb:88-100` applies bounded operator deletion and enforcement
  exclusion.
- `app/jobs/retention_purge_job.rb:124-151` re-evaluates client/visitor holds and enforcement
  before anonymization.
- `app/services/sign_up_artifact_cleanup.rb:31-63` keeps sign-up artifact cleanup bounded and
  uses `FOR UPDATE SKIP LOCKED`.
- `test/jobs/retention_purge_job_test.rb`, the retention-hold tests, and the cross-database purge
  tests cover eligibility, keep behavior, lifecycle separation, idempotence, allowlist coverage,
  enforcement blocking, kill-switch catch-up, hold handling, bounded child cleanup, and audit
  retention.
- `adr/retainable-concern-and-retention-purge.md:134-152` already documents the same contract and
  explicitly excludes a preview/simulation requirement.
- Existing Compose-backed evidence records the focused retention set passing with
  `42 runs, 173 assertions, 0 failures, 0 errors, 0 skips`, and the broader current runtime
  record includes the retention contract in a passing `61 runs, 440 assertions` set. Those are
  historical execution records; this plan-only review did not rerun Rails outside the Compose
  service.

## Adversarial result

- No acceptance criterion requires a nonexistent RetentionPurgeJob API after the correction.
- `bounded` is defined as per-operation finite batching, not a new total-run cap or preview count.
- Safety goals are separated from implementation mechanisms; the existing batch path is sufficient.
- No example or recommendation is promoted to a RetentionPurgeJob MUST.
- The absence of a dry-run interface is not a defect.
- The reverse-direction `safe_constantize` allowlist typo observation remains a non-blocking
  hardening follow-up recorded in the earlier retention re-audit; this plan-only phase does not
  change it or treat it as a reason to invent a dry-run feature.

## Disposition

`Retention blocker: CLOSED`.

Retention purge is `ACCEPTED_AS_EXISTING_IMPLEMENTATION` under the revised contract. Notification
delivery/receipt/retry/permanent-failure remains an independent blocker and is not closed here.

## Verification

- Frozen Plan validator: 70 canonical source rows, 70 FREQ rows, zero mapping/closure errors,
  `result: PASS`.
- `git diff --check -- plans/backlog/2026-09-17-integrated-hardening-plan.md`: passed.
- Current application code, tests, migrations, and schema were not changed in this re-review.
