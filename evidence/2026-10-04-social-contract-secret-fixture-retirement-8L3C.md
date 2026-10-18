# Social contract old Secret fixture retirement

Performed 2026-10-04, approximately 06:14–06:17 UTC (Etc/UTC).
Rails feature HEAD f313b126931cfe3c9ecf64bbb72fb1cd3a0aada5; 435 dirty paths
at final capture, including concurrent work. Results include uncommitted changes.

The interrupted full suite reported all twenty SocialAuthAppFlowContractTest
cases as errors because its explicit fixture list still named the removed
client_secret_credential_statuses fixture. Removing that obsolete declaration
allowed nineteen cases to pass; one case then reached its legacy preparation
helper and failed on the removed client_secret_credential_kinds table.

That helper is removed. The one affected case visibly constructs a confirmed
manual issuance and exact server-generated 32-character Secret through ordinary
validated model creation. It no longer writes old kind/status fields, uses a
fake password digest or saves with validate: false. Existing external-provider
transport fixtures are retained; no successful authentication mock was added.

The social unlink refusal remains unchanged. Client.remaining_social_unlink_methods
has its existing narrower email/Passkey/social policy; this test retirement does
not change it or claim that Secret is excluded from ordinary login inventory.
The test also verifies refusal leaves the Secret available. Setup does not prove
the real Secret presentation/confirmation or login journey.

`bundle exec ruby /tmp/umaxica-registration-fresh-db-task.rb test
test/integration/social_auth_app_flow_contract_test.rb`:
**20 tests, 185 assertions, zero failures/errors/skips** on the guarded disposable
registration fleet. The initial fixture error was not counted as TDD Red for a
product behavior change; this slice repairs obsolete test setup and retains the
observed public contracts.

`bundle exec rubocop test/integration/social_auth_app_flow_contract_test.rb`:
one file, no offenses. `git diff --check`: PASS.

NOT_RUN: another full-suite attempt, real Google/Apple network authentication,
Secret login/issuance HTTP and browser secrecy. Other obsolete app Secret classes,
fixtures and call sites still require retirement. Pending persisted-shape approvals
and Chronicle/audited-purge work remain incomplete.
