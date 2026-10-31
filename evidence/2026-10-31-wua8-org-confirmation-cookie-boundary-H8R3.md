# ORG confirmation cookie boundary probe

HEAD: `336811e5072a93c0523e484f905082635b28f48f`. The worktree contained uncommitted changes affecting the test and application.

A temporary modification of the existing ORG root-login integration test added a second synthetic Passkey and followed the current GET admission redirects. `PARALLEL_WORKERS=1 bin/rails test test/integration/org_root_login_establishment_test.rb:14` completed with 1 run and 59 assertions, using the configured local test environment. It observed that the binding referred to the original active Root token, while the subsequent Base confirmation request returned HTTP 400. The Base request contained the RP access cookie but did not contain the Root access cookie. The temporary test changes were removed after the probe.

The test bypassed real Passkey registration and does not establish deployed browser behavior. It does not repair confirmation or establish a complete authentication design. An earlier diagnostic assertion emitted a synthetic test token into a temporary local log; that log was deleted.
