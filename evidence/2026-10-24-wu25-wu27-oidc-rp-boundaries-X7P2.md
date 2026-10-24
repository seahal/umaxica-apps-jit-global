# WU-25 and WU-27: OIDC RP boundary and post-containment result handling

Revision: `ba570a0007b1d40eabe32990a34831317fd98a93`.

Observed with an uncommitted worktree. The verification did not mutate production state.

## Implemented

- Visa revocation receives and verifies the registered client authentication method, including
  client assertions, and discovery advertises the methods supported by the client registry.
- The RP result path is a terminal, browser-bound continuation: a lost-response replay cannot issue
  another root or re-run finalization.
- The current browser flow uses Visa's `/oidc/result` and the Base RP callback rather than the
  retired Base OP authorization-form continuation.

## Verification

`PUBLIC_VISA_SERVICE_URL=visa.umaxica.app PUBLIC_VISA_CORPORATE_URL=visa.umaxica.com PUBLIC_VISA_STAFF_URL=visa.umaxica.org bin/rails test test/services/oidc/discovery_document_test.rb test/services/oidc_token_revocation_service_coverage_test.rb`

Result: **9 runs, 124 assertions, 0 failures, 0 errors, 0 skips**.

The updated OIDC RP browser and ORG handoff journeys were also run with the current Visa navigation
contract. Back-channel logout and excluded WU-15/WU-18 work are not claimed here.
