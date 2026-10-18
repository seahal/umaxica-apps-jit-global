# Email OTP response parity and measurements

- Commit: `6fa6867d44b5499632079775cb0fb22cbfddd339`.
- Inherited and current uncommitted changes affect the results.
- Owned disposable fleet: `20261007fresh3`, manifest
  `tmp/auth-boundary-isolated-20261007fresh3.json`; no shared database application.
- No real email/SMS delivery or browser automation was performed.

## Regression observations

The four existing enumeration/security/extra selections initially produced 23 runs, 24 assertions,
22 failures. Their requests omitted confirmed Admission; registered fixtures lacked effective
binding. The fixtures now execute public HTTP attachment/redemption with synthetic public Base
confirmation and explicit effective Contact finalization. They preserve production denial:
23 runs, 108 assertions, no failures, errors or skips (seed 42). An intermediate one-failure run
used the wrong literal checkpoint URL; the assertion now uses the current public route helper.
Successful Auth JSON reports evidence and redirect, not a root access token. Dummy refusal creates
no Identity, Contact or root token and does not expose an owner-required persistence error.

The new APP/COM integration tests compare actual code-entry controls, feedback, redirect path
and opaque-state length, then wrong-code feedback and resend. Before adding a response floor the
shape assertions passed: 2 runs, 44 assertions. The first draft compared different address lengths
and correctly failed length equality; equal-length caller inputs isolate existence leakage.
The explicit 100ms timing guard tests then failed on both surfaces: 2 runs, 18 assertions,
2 failures. The initial response-floor implementation passed: 2 runs, 76 assertions, no failures,
errors or skips.

## Operational timing baseline

Command: `bundle exec ruby tmp/email-sign-in-parity-probe-20261007.rb` in the isolated test
environment. The driver measures full HTTP requests; 2 warmups are excluded and 30 samples per
surface/mode/stage are retained, with alternating real/dummy order. Independent admitted cookie
jars and unique destinations/caller addresses preserve genuine throttling rather than disabling
it. Delivery uses the test queue; FQDN test-memory flags are explicitly enabled. This is a local
synthetic server measurement, not production delivery, browser/RUM or whole-system conformance.

Before the fix (median / p95 milliseconds):

| Surface | Stage | Real | Dummy |
| --- | --- | --- | --- |
| app | receipt | 61.836 / 69.431 | 54.867 / 77.940 |
| app | entry | 9.961 / 21.538 | 8.981 / 23.432 |
| app | resend | 13.719 / 27.089 | 6.750 / 18.257 |
| app | wrong code | 18.115 / 31.589 | 16.432 / 47.857 |
| com | receipt | 60.828 / 64.226 | 54.942 / 55.975 |
| com | entry | 8.908 / 10.968 | 9.293 / 10.660 |
| com | resend | 12.265 / 16.519 | 7.047 / 9.718 |
| com | wrong code | 11.641 / 19.364 | 6.292 / 7.415 |

The old minimum covered only a lookup or APP verification, not the full operation. Real OTP
storage, dispatch bookkeeping and COM verification created a repeatable gap. The implementation
uses a 100ms monotonic minimum for accepted real/dummy receipt processing, valid-state resend and
well-formed six-digit verification. It does not change database deadlines, counters or success
authority. Invalid input remains a genuine rejection and dependency/provider exceptions propagate.
One scheduler/GC outlier reached 122.688ms before the fix; a floor cannot prove equal tails.

The same driver after the response-floor implementation completed all 30 samples per cell:

| Surface | Stage | Real median / p95 ms | Dummy median / p95 ms |
| --- | --- | --- | --- |
| app | receipt | 105.645 / 111.420 | 104.774 / 107.142 |
| app | entry | 10.794 / 23.337 | 9.294 / 18.975 |
| app | resend | 105.739 / 109.104 | 104.748 / 115.496 |
| app | wrong code | 107.090 / 109.877 | 105.521 / 128.229 |
| com | receipt | 104.907 / 106.544 | 104.827 / 105.533 |
| com | entry | 11.280 / 15.667 | 9.203 / 10.631 |
| com | resend | 105.799 / 107.025 | 104.898 / 105.835 |
| com | wrong code | 106.263 / 107.746 | 105.664 / 107.348 |

Every measured protected stage exceeded 100ms. COM's wrong-code median gap narrowed from
5.349ms to 0.599ms; its receipt gap from 5.886ms to 0.080ms. This deliberately trades bounded
extra request latency for a common floor; it is not a throughput improvement. The APP dummy
wrong-code maximum was 202.406ms after the change, so equality of distribution tails is NOT VERIFIED.

Three early operational-driver attempts stopped before completion: FQDN test-memory flags were
not enabled, then the genuine caller rate limit refused the accumulated requests. The driver was
corrected to establish test flags explicitly and use separate callers. Those attempts are not
passing measurements. The successful driver declared no Minitest test cases; its trailing
zero-test autorun is not a test-suite success claim.

Late delivery, flow-specific OTP evidence, cancellation/expiry parity, production distribution
and the complete fault matrix remain unverified. No task checkbox is closed by this partial record.

After extracting only the duplicated new code-format/floor guard into private CommonOtp,
the combined 12-file selection passed: 126 runs, 962 assertions, no failures, errors or skips
(seed 42). Files: the new parity integration test; APP/COM email sign-in main and enumeration
tests; APP security/extra tests; APP/COM resend endpoint tests; resend service, provider-failure
and resend-policy tests. Scoped RuboCop on CommonOtp, policy, resender, both sign-in controllers
and the parity test inspected 6 files with no offenses, exit 0. The initial lint found COM method
size violations; no exclusion or threshold change was added.
