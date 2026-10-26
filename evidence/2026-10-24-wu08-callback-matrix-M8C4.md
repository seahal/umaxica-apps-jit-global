# WU-08 callback state matrix

Date: 2026-10-24. Revision: `bde2346c17e2aa911acc95de1f6035f80498f2da`.
Checks used the dirty worktree, including pre-existing changes by another implementation agent.
Only WU-08 additions are selected for this commit; this record does not certify the other changes.

## Findings and changes

- A banned subject reached the link repository before refusal. A new public-handler test failed
  with `a banned subject reached identity lookup`. The link handler now checks the provider's
  in-force subject effect before identity lookup or mutation, matching the login handler.
- An orphan identity produced HTML 302 instead of HTTP 500. The real callback test reproduced
  `Expected: 500, Actual: 302`. The APP callback now returns 500 for this invariant error in both
  HTML and JSON; the resolver emits the existing FATAL event and the responder preserves Auth SID.
- No schemas, lifecycle writers, external provider settings or deployment edges changed.

## Acceptance

| Criterion | Executed coverage |
| --- | --- |
| A08-1 | `social_callback_state_matrix_test.rb`: 28 provider/intent/state partitions for L1/L2/L3/L5/L6/L7. `social_callback_refusal_matrix_test.rb`: 36 HTML callback partitions covering L1 through L8 for both providers/intents, plus four JSON L4 partitions. Normal callback success is included. |
| A08-2 | Service matrix: 32 ban-precedence partitions over unknown, registered, unusable, released, unfinished, revoked, deleted and orphan repository states, both intents/providers. Link handler test proves refusal before the first identity lookup for both providers. |
| A08-3 | HTTP L4: both providers/intents and HTML/JSON return 500, emit exactly one FATAL without subject disclosure, preserve Auth SID and record no authentication evidence. The FK prohibits storing an orphan; only the repository's orphan return is substituted. |
| A08-4 | Every HTTP callback asserts unchanged counts for Client, Sign-up Flow, external identity and Root token. Every refusal asserts no authentication evidence and no login cookies. Sign-up Flow creation occurs at provider entry, before the measured callback. |

## Commands and results

Rails commands used these explicit host variables:
`PUBLIC_VISA_SERVICE_URL=visa.umaxica.app PUBLIC_VISA_CORPORATE_URL=visa.umaxica.com PUBLIC_VISA_STAFF_URL=visa.umaxica.org`.

`bin/rails test` with:

- `test/integration/social_callback_refusal_matrix_test.rb`
- `test/services/social_callback_state_matrix_test.rb`
- `test/services/social_auth_link_handler_test.rb`
- `test/services/social_auth_login_handler_test.rb`
- `test/integration/social_login_admission_test.rb`
- `test/services/external_authentication_link_use_case_test.rb`
- `test/services/external_authentication_login_use_case_test.rb`
- `test/services/social_auth_link_handler_diagnostics_test.rb`

Result: **34 runs, 1,852 assertions, zero failures/errors/skips**.

`bin/rails test test/security/invariants/csrf_verification_strategy_invariant_test.rb test/unit/security/standard_csrf_invariant_test.rb test/unit/security/forbidden_rails_patterns_test.rb`:
**11 runs, 21 assertions, zero failures/errors/skips**. An initial concurrent invocation was refused
by the repository's database-process lock; the reported successful run was sequential.

`bin/rubocop` on both changed implementation files and all three changed/new test files:
**5 files, no offenses**. Scoped whitespace checks passed.

The HTTP matrix retains CSRF and rate limiting. Each partition has an independent browser/IP;
using one IP for all partitions originally reached the real 429 limit and was corrected in test setup.
The tests follow Rails-issued Jump targets locally; they do not contact an external Jump service.

WU-08 A08-1 through A08-4 are locally verified. The cycle-wide full-suite/baseline gates and
deployment/provider-network verification were not run here and remain separate open work.
