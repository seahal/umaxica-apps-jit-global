# Social authentication-event propagation

Date: 2026-09-15

The bounded social-authentication slice was inspected and implemented locally. Google and Apple
provider adapters already construct `ExternalAuthentication::VerifiedPrincipal` with a verified
callback event time. The signed social ceremony result now carries that instant as `auth_time`,
validates it as a non-future integer timestamp, and Base forwards it to
`AuthenticationSessionCommitter`. The legacy app social callback passes the same principal event
time directly.

Checks that completed:

- `ruby -c` for the four changed production files and the affected tests: passed.
- Targeted `bundle exec rubocop` for the four production files and three affected tests: passed,
  no offenses.
- `git diff --check`: passed.

The targeted Rails tests were attempted with
`RUBY_DEBUG_LAZY=1 bin/rails test test/operations/identity_social_ceremony_result_issuer_test.rb test/controllers/base/app/social/authentications_controller_test.rb test/services/identity/social_ceremony_contract_test.rb`.
They stopped during Rails test-schema boot because PostgreSQL host `primary` could not be
resolved/reached; no test assertion, database mutation, Valkey operation, provider call, or
browser behavior is claimed as executed.

The OIDC RP callback was also tightened to reject a verified ID Token without an authentication
event time instead of allowing the generic local-login boundary to substitute `Time.current`.
Its fixtures and missing-claim regression test were updated. Syntax, targeted RuboCop, and diff
checks passed; the combined callback/social Rails run stopped at the same PostgreSQL prerequisite
before assertions.
