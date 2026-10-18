# R5-WU19 source preparation and WU19/WU20 status

- Commit: 17903f7d121aa33efe29f2db9235c9aa5db4b001; worktree has the uncommitted R4/R5 changes.
- Date: 2026-10-17T13:57:59Z

## R5-WU19 source delivered (no activation performed)

- `op_client_activations` in op_base_app/com/org (migration 20261017150000; unique client+epoch,
  positive epoch, 64-hex manifest digest), models `Op{App,Com,Org}ClientActivation`. Applied to the
  development databases and the test fleet; dumps regenerated from the fleet (62 added lines each,
  nothing removed).
- `OpClientActivationWriter` (single writer, epoch row lock, actor/audit/digest) and
  `OpClientAdmissionQuery` (current epoch only).
- `OpClientAdmissionGate` at `/oauth/authorize` and `/oauth/token` in `op-base-*` processes:
  `unauthorized_client` when not admitted. The `shared` role does not consult it.
- RP browser admission: `UMAXICA_RP_BROWSER_ADMISSION` (open|closed, required in rp-* processes);
  closed cells serve only back-channel logout and health.
- docs/mermaid/idp-op-client-activation.mmd, README inventory row and transition inventory section.

Tests: test/operations/op_client_activation_writer_test.rb and
test/integration/op_client_admission_gate_test.rb (11 runs, 0 failures); role guard/admission tests
(33 runs, 0 failures); full suite run 13 as above.

## Status

- R5-WU19 actual 19-COMMON batch and per-cell activation: NOT_RUN. R5-WU18A is NO-GO
  (evidence/2026-10-17-r5-wu18a-isolated-rehearsal-aggregate-A18R.md), and one.md forbids activation
  before an actual R5-WU18A PASS. The activation table shape is implemented as one.md describes but
  has had no separate S review.
- R5-WU18 old OP-chain RP path removal: NOT_DONE; it follows the R5-WU19 cutover.
- R5-WU20 final acceptance: NOT_RUN; depends on R5-WU19.
