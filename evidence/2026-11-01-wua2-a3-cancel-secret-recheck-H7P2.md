# WU-A2/A3 Cancel retry and completed Secret recheck

HEAD: `efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8`. The worktree already contained extensive
uncommitted changes. This slice narrowed fixtures for two integration-test classes and added Org
Cancel retry assertions; no commit, application-code change, or migration was made.

The Org Cancel integration tests do not use fixtures. Their first focused invocation failed during
global fixture loading with an `enterprise_units.enterprise_id` foreign-key violation, before the
test body. Setting `fixture_table_names` to an empty list for this fixture-independent test class
removed that unrelated setup dependency. The focused Entra-after-evidence Cancel/retry test then
passed: 1 run, 27 assertions. The full `test/integration/sign_entry_exit_org_flow_test.rb` file
passed: 5 runs, 70 assertions, 0 failures, 0 errors, 0 skips.

The App entry/exit file uses only the `clients` fixture. Its first full invocation also stopped in
global fixture loading with the same foreign-key error (10 errors before assertions). Restricting
that test class to the `clients` fixture allowed the complete file to run: 10 runs, 188 assertions,
0 failures, 0 errors, 0 skips.

The App and Org replay tests now create a second valid Auth admission, make its `auth_sid` current,
then replay the old Visa cancellation continuation. They assert the replacement parent, binding,
ceremony and SID remain unchanged while the old `access_denied` result is delivered again. After
these additions and formatting, both complete integration files passed together: 15 runs, 268
assertions, 0 failures, 0 errors, 0 skips. Scoped RuboCop, syntax checks and `git diff --check`
passed for both files.

The Org test now retries a Cancel after simulating a lost Auth response, sending only the exact old
`auth_sid`. It confirms the terminal parent, binding and ceremony remain unchanged, the SID stays
cleared, and the same Visa cancellation result is delivered. The APP Secret signup journey was also
rechecked with `.env.container.devcontainer` loaded: 24 runs, 1,484 assertions, 0 failures, 0
errors, 0 skips. Its zero-active-Secret case cancels the still-unfinalized OIDC parent after the
source registration completes, then runs the signup lifecycle job and confirms the completed Flow,
Client, Secret credentials and audit facts remain unchanged.

The initial Rails test invocation without the local environment file stopped at initialization
because the required `preference_com` issuer was absent. Successful test commands loaded
`.env.container.devcontainer`; no secret values were printed. A Playwright Rails public-page smoke
test first could not launch because Playwright's cached browser executable was absent. Re-running
with the existing `/usr/bin/chromium` via `PLAYWRIGHT_CHROMIUM_EXECUTABLE` passed: 1 browser test.
The runner verified 51 live test-database pools and local Valkey reachability. This smoke test only
renders the public Auth landing page; actual browser Back after OTP/Secret/Passkey progress was not
tested. The Rails E2E fixture refuses redirects, and the separate isolated multi-surface E2E runner
is not available in this workspace.

This verifies only these APP/ORG boundaries. AC-40/50/51 and WU-A2/A3 remain open; the full suite,
real-browser behavior and the ORG Switch specification discrepancy remain unverified/unresolved.

## Auth phase-refusal response owner recheck

HEAD remained `efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8`; the worktree remained uncommitted with
pre-existing changes. No migration or database write was made in this slice.

The initial Email and Telephone signup OTP refusal branches previously rendered the localized
phase-violation conflict body directly. Both now call `render_sign_in_phase_refusal!`, the shared
response owner. Added
`test/security/invariants/auth_phase_refusal_response_writer_invariant_test.rb` to pin that the
translation key and exact conflict render remain in that concern. Added public request tests for
both initial OTP refusal branches. The Telephone controller test now explicitly limits fixture
loading to the six fixtures it declares; this avoids inherited `fixtures :all` loading unrelated
cross-database Org fixtures.

The initial two-case focused run passed Email but failed before the Telephone test body during
fixture loading (`enterprise_units.enterprise_id=519260495` had no matching enterprise). After
limiting that class's fixture tables, the focused public cases passed: 2 runs, 9 assertions, 0
failures, 0 errors, 0 skips. The response invariant, response boundary and admitted-order tests
passed together: 15 runs, 129 assertions, 0 failures, 0 errors, 0 skips.

The full Email and Telephone controller files were also run together after fixture isolation: 132
runs, 488 assertions, 52 failures, 27 errors, 0 skips. Several failures expected redirects but
received 503 responses. Their causes were not isolated in this slice, so they remain failures and
are not attributed to a WU or treated as baseline failures. A single Email enqueue case was then
re-run at `test/controllers/auth/app/up/emails_controller_test.rb:649`; it reproduced 1 failure
because the expected mail job count was 1 and the observed count was 0. Its cause was not isolated.
The focused refusal and response-boundary commands passed as noted above. No code was edited while
any test run was active.

Scoped RuboCop passed for all five changed source/test files. Ruby syntax checks and
`git diff --check` passed for the same files. The full suite was not run.
