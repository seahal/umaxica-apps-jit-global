# Surface connection-owner boundary verification

- Date: 2026-09-17 UTC
- Branch: `feature`
- Scope: correct existing connection-owner helpers after the surface writer bases became nested
  abstract Active Record classes.

## Finding and change

Several helpers selected the first abstract ancestor of a model and passed it to `connected_to`. For
example, `Operator` first resolved to `OrgPrincipalRecord`, while Rails requires the abstract class
that established the `OrgZenithRecord` connection. The same pattern also affected preference
synchronization, OIDC RP identity provisioning, current-banner reads, and restricted-session
cleanup. The helpers now use Rails' `connection_class_for_self`, which resolves the actual
connection owner without collapsing the surface-local model boundaries.

The EnforcementAppeal audit-failure regression test also injected failure at the
`EnforcementEvent.create!` persistence boundary, rather than stubbing an association instance that
could be reloaded during the operation.

## Checks performed

- The first focused enforcement run reproduced 11 connection-owner errors and one ineffective audit
  failure injection. No datastore fallback was used.
- `bundle exec bin/rails test test/controllers/base/org/support/enforcement_cases_controller_test.rb test/models/enforcement_appeal_test.rb`
  — passed, 20 runs / 70 assertions.
- The complete focused enforcement set covering app/com/org Cases, appeals, reconciliation, failure
  recovery, and controller guards — passed, 53 runs / 182 assertions.
- The connection-owner consumers covering OIDC RP identity provisioning, restricted sessions,
  current banners, and their view partial — passed, 18 runs / 60 assertions.
- The explicit nested-owner contract (`Client`, `Visitor`, and `Operator` resolving to their
  canonical `*ZenithRecord`) was then added and rerun with those consumers — passed, 22 runs / 66
  assertions.
- Targeted RuboCop over the six production helpers and the appeal test — passed; 7 files inspected,
  no offenses.
- Ruby syntax checks and `git diff --check` — passed.

No migration, reset, production/shared datastore access, worker execution, or external notification
was performed. Full-suite and deployed-environment verification remain subject to CF-002.
