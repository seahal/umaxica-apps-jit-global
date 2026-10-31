# Auth admission attachment navigation metadata

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`; the worktree contained substantial uncommitted changes affecting the checks.
- An HTTP boundary test sent an APP attachment request with no Fetch Metadata; before the change it returned 303 instead of the expected refusal (1 run, 1 assertion, 1 failure). The test stopped on that first APP assertion, so it did not observe the pre-change ORG case.
- APP and ORG attachment now require GET navigation/document metadata before the reference lookup, Sentry and attachment. HEAD, missing or mismatched metadata, `empty` and `iframe` are refused. The boundary test checks both realms for unchanged binding/session counts and no Auth SID issuance, followed by successful document navigation (1 run, 64 assertions).
- The admission and boundary group passed (104 runs, 1,451 assertions). The 19-file shared-entry helper group passed (385 runs, 4,368 assertions).
- A further 14-file group initially had 15 failures and 19 errors because several simulated redirects lacked navigation metadata. After updating those test requests, the group finished with 172 runs, 1,827 assertions, no failures and 2 errors. Both error IDs are in `plans/2026-10-28-baseline-failing-tests.md` and concern signup email rate-limit tests.
- Scoped RuboCop passed (7 files). The full suite and a real service-worker navigation remain unverified. The shared browser navigation concern still allows `empty` for other callers; the attachment and entry follow the accepted Design D `document` requirement.
