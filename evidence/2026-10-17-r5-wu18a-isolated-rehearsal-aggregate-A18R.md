# R5-WU18A isolated adversarial rehearsal aggregate (TC-R5-18A-001): NO-GO

- Commit: 17903f7d121aa33efe29f2db9235c9aa5db4b001; worktree has the uncommitted R4/R5 changes under
  test.
- Date: 2026-10-17T13:57:59Z
- Targets: isolated test fleet `codex_integrity_20261017c1a2_*` (in-process, `shared` role unless a
  test sets an `rp-*`/`op-base-*` role) and the local development PostgreSQL with provisioned role
  logins. Restore cases: NOT_APPLICABLE (`NO_PRESERVED_ENVIRONMENT`, one.md 1.2A).

Full suite run 13 (seed 42061, 8 workers): 15484 runs, 2 failures (model naming list, architecture
baseline), both fixed and rerun (5 runs, 0 failures).

| two.md section 13 coverage                                                                         | Executed evidence                                                                                                           | Result                                                                                                                                                                          |
| -------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| JWT type/issuer/audience/client/profile binding (TC-R5-04-001, 07-001)                             | test/adapters/oidc_op_protocol_verifiers_test.rb, test/services/rp_request_authenticator_test.rb                            | PASS in-process; key-rotation-under-JWKS-failure in an isolated rotation: NOT_RUN                                                                                               |
| Callback State/Nonce/PKCE and browser binding (TC-R5-07-001)                                       | test/controllers/concerns/oidc/callback_test.rb, Palm cell callback tests                                                   | PASS in-process; two-connection stale-replica case: NOT_RUN                                                                                                                     |
| Callback/logout incl. unknown sid (TC-R5-07-002, 10-001)                                           | test/operations/rp_callback_committer_test.rb, test/integration/rp_backchannel_logout_receiver_test.rb, Palm tombstone test | PASS in-process; paused two-connection ordering: NOT_RUN                                                                                                                        |
| Callback/Refresh/late install (TC-R5-07-003)                                                       | test/operations/rp_refresh_committer_test.rb                                                                                | PASS in-process; paused-after-OP-commit race across processes: NOT_RUN                                                                                                          |
| Rotation/replay/5-second receipt (TC-R5-08-001)                                                    | test/unit/oidc_refresh_delivery_receipt_test.rb, rp_refresh_committer_test.rb                                               | PASS in-process; admitted timeout budget under independent processes: NOT_RUN                                                                                                   |
| Identity stop vs issuance and redelivery (TC-R5-06-001)                                            | test/operations/op_identity_event_invalidator_test.rb, test/jobs/op_identity_event_sweep_job_test.rb                        | PASS                                                                                                                                                                            |
| Secret and master-key isolation (TC-R5-03A-001)                                                    | rp-palm-app-jp runner probe                                                                                                 | FAIL: role process can read other roles' key files and decrypt the op-base-app bundle (same UID, no container split). Process environment reduced from 39 to 3 own private keys |
| Cross-RP/OP/Zenith DB denial (TC-R5-03A-001, 17-001)                                               | role login probes, rp-palm-app-jp runner and server                                                                         | PASS (CONNECT refused; own store and flag tables only)                                                                                                                          |
| Old credential rejection incl. unchanged Base IDs (TC-R4-03-001 adapted, 07-004, 19-001 rehearsal) | retired `emergency` context refused; epoch mismatch refused in rp_request_authenticator_test                                | PARTIAL; isolated pre-/post-switch rehearsal of TC-R5-19-001: NOT_RUN                                                                                                           |
| Queue/outbox/crash/retry and receiver ACK (TC-R5-09-001, 10-001)                                   | test/operations/op_logout_committer_test.rb, test/jobs/op_outbox_dispatch_job_test.rb, receiver test; sweeps now scheduled  | PASS in-process; stopped-Queue restart against real workers: NOT_RUN                                                                                                            |
| Migration keeps invalidation truth (TC-R3-07-001 adapted)                                          | standby migrations applied to fleet and development; constraint dumps checked                                               | PASS (restore NOT_APPLICABLE)                                                                                                                                                   |
| R2 protections, context and policies (TC-R5-07-004, TC-REG-001)                                    | full suite run 13                                                                                                           | PASS                                                                                                                                                                            |

## Verdict

NO-GO for R5-WU19 activation: TC-R5-03A-001 secret isolation FAILS in the single-container
development setup, and every cross-process case is NOT_RUN because a separate OP process is
reachable only through the development ingress (Jump/Edge), which is outside the authorized scope.

Later observation (2026-10-18): the two-connection ordering, cached-reading-caller and
JWKS-rotation-outage sub-cases were run in-process; see
`evidence/2026-10-18-r5-wu18a-two-connection-and-jwks-rotation-W18B.md`. The verdict above is
unchanged.
