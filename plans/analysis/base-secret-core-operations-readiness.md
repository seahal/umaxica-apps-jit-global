# Operations and rollback readiness for Base, app Secret, and Core

Prepared on 2026-10-03 (UTC). This is a proposed operational review procedure for
the target contracts, not a tested production runbook. No failure injection, queue
operation, database mutation, deployment, or rollback was performed by this task.

Use the [accepted contract](../../adr/base-secret-core-contract-precedence.md),
[decision gates](base-secret-core-decision-gates.md), and existing
[Solid Queue runtime documentation](../../docs/operations/solid-queue-runtime.md).
Exact commands, job names, dashboards, permissions, and thresholds must come from
the implemented checkout and authorized environment before promotion to stable docs.

## Minimum operational observations

Track nonsecret correlation/event IDs, source database, operation outcome, and
time. Separate pending issuance, irreversible claim, established session, source
outbox commit, enqueue, Chronicle delivery, and physical purge. Observe undelivered
event count/age, retries, terminal-claim reconciliation, and purge deferrals through
existing instrumentation. Do not invent alert thresholds without workload evidence.

Audit payloads are allowlisted facts. Do not include raw values, digests, prefixes,
cookies, headers, encrypted delivery payloads, user-entered names, or arbitrary
request data. An application log is not a replacement for durable audit data.

## Incident triage and safe recovery

| Observation | Establish first | Recovery boundary |
| --- | --- | --- |
| Chronicle unavailable | Source state/outbox committed; delivery attempt failed rather than event absent | Restore the existing authorized service path and retry through the outbox scanner. Do not log-and-drop or purge preceding undelivered terminal facts. |
| Queue stopped or enqueue failed | Persisted undelivered rows versus jobs scheduled; credential already terminal where applicable | Restore queue operation and periodic scanning using current runbook. Queue failure does not restore credential usability. |
| Crash after Chronicle commit | Immutable event ID already stored externally; source acknowledgement missing | Retry same event ID and deduplicate. Do not create a second semantic event to compensate. |
| Payload missing or decrypt failure | Correct issuance ownership and state; payload unavailable, not just hidden | Fail presentation explicitly; follow the authorized invalidation and explicit reissue operation. Never generate and confirm a hidden replacement. |
| Reservation expired with jobs stopped | Owning DB time, operation deadline, eligibility for late confirmation | Capacity calculation ignores expired reservation; late confirmation refuses. Cleanup follows existing jobs without clearing unrelated operations. |
| Claim exists, Ticket result unknown | Bound trusted flow, Ticket terminal/commit receipt, callbacks still accepted | Reconcile the same operation through existing authority and locks. Do not unclaim, accept a new login from the Secret, or delete live proof. |
| Login committed, response lost | Canonical session/receipt committed; no inference from cookie delivery alone | Use the implemented same-flow continuation behavior. Do not directly create another token or extend flow expiry. |
| Purge delayed | Terminal audit delivered, retention/hold/kill-switch state, unique deletion owner | Repair the actual prerequisite. Avoid manual delete_all, changing retention dates, or disabling holds to empty the backlog. |
| Purge committed, delivery pending | Credential absent; surviving purge event in source outbox | Deliver the existing purge event. Do not recreate credential or delete the event to remove the backlog. |
| Access expired, refresh apparently valid | Accepted browser continuation route and resolver cleanup classification | Follow the current approved contract. New GET mutation, grace, retries, or storage are separate decisions. |
| Core gets HTML/redirect instead of JSON | Public path ownership and response contract; request actually reaches Rails | Diagnose routing without a Worker proxy, widening Origin, or treating HTML as success. External cutover remains separately authorized. |
| Old personalized response after logout | Current subject/session generation and response ownership | Discard the response and stale private query data. Do not reinstate authentication from cached UI state. |

Operational diagnosis is read-only until an authorized recovery procedure is identified.
Replay authentic operation/event IDs only through their implemented public boundaries;
never fabricate receipts or issue direct SQL state repair as routine recovery.

## Local rollback review

1. Identify the coherent change and the newer defenses it depends on. Use a reviewed
   patch in the existing tree; do not reset/checkout/stash or overwrite concurrent work.
2. For Base, verify any rollback's exact response contract. Restoring the historical
   anonymous Dashboard 404 is a behavior reversal requiring an explicit decision;
   retain authorization, selector, Jump, and neutral GET/POST protections.
3. For Secret, distinguish rollback of application code from destructive schema
   rebuild. Old discarded Secret data is unrecoverable through a migration rollback.
   Never run an older issuer against an incompatible schema or resurrect claimed rows.
   Document any temporary loss of Secret functionality honestly rather than adding
   compatibility reads or another login issuer.
4. For audit/purge, preserve committed outbox and receipts across code changes.
   Pausing reclamation is distinct from stopping terminal invalidation or losing audit
   delivery. Confirm the actual supported pause control before proposing its use.
5. For Core, coordinate browser client behavior with public path ownership. A local
   code rollback does not roll back CloudFront or routing. Do not reactivate a forbidden
   Worker-to-Rails fallback or expose a private Rails origin to the browser.
6. Run the affected public-boundary regression checks in an authorized disposable
   environment and record remaining gaps. Review production application separately;
   this procedure does not authorize it.

## Preconditions for a real deployment assessment

- Confirm final Rails and Edge SHAs, migration ownership, fresh/rebuild results,
  secret issuance/claim/session evidence, and unaffected com/org behavior.
- Decide pending durations and requirements with accepted sources. Identify the
  sole purge owner, scanner scheduling, event definitions, and retention policies.
- Prove browser history/storage safety, exact Cookie/Origin/CSRF behavior, stale
  response handling, and the actual permitted continuation route.
- Inspect external public-path routing without executing Workers for Rails-owned
  paths; coordinate old-dispatcher withdrawal with cutover and failure behavior.
- Independently verify CloudFront no-shared-cache/zero-TTL behaviors, required
  forwarded headers and cookies, redirects/error caching, multiple Set-Cookie,
  credential logging/sampling controls, and A/B/anonymous non-sharing.

Keep application boundary, login continuation, and deployment readiness judgments
separate. The documents above describe what needs to be ready, not that it is ready.
