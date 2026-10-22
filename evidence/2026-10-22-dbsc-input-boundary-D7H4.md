# DBSC input and logging boundary

- Date: 2026-10-22.
- Base commit: `febec3225cc9a0cfa53b9cbe817d20d366aba5a2`.
- Worktree: uncommitted changes affected this result. The repository already contained unrelated
  staged, unstaged and untracked work, which was preserved. This record covers only the DBSC input,
  serialization, logging and timestamp changes described below.
- Scope: application-owned implementation. Blazer, Gemfile dependencies and `vendor/bundle` were
  excluded from remediation. No dependency, routing or database-schema change was made.

## Sources and implementation

The W3C [DBSC Editor's Draft](https://w3c.github.io/webappsec-dbsc/), dated 2026-09-08, was inspected
on 2026-10-22, particularly sections 9.1–9.4. The string syntax and escaping were checked against
[RFC 9651](https://www.rfc-editor.org/rfc/rfc9651.html), sections 4.1.6 and 4.2.5.

HTTP fields are parsed once at the controller boundary. Services accept decoded strings.
The parser rejects malformed fields and ignores syntactically valid parameters; the serializer
escapes quotes and backslashes and refuses non-printable/non-ASCII output. Both DBSC concerns
require a matching stored identifier before issuing a challenge. Fixed structured events replace
logs containing identifier/challenge prefixes. Malformed and extreme proof `iat` values are
rejected without converting untrusted numeric dates into Time objects. Existing lifecycle edges
were compared with the six DBSC diagrams; transport notes were updated without changing edges.

## Completed checks

- `bundle exec ruby -Ilib -e 'ARGV.each { |path| require_relative path }'
  test/services/dbsc/header_parser_test.rb test/serializers/dbsc_header_serializer_test.rb
  test/controllers/dbsc_header_boundary_test.rb test/services/dbsc/proof_input_validation_test.rb`
  passed: **20 tests, 313 assertions, zero failures, errors or skips**.
- The controller tests dispatch the actual token and preference concern actions through Rails HTTP
  request/response objects, with in-memory identity/persistence dependencies. They cover accepted
  identifiers, ignored parameters, malformed fields, missing records, mismatched/unregistered
  identifiers, unchanged challenges/cookies on refusal, absence of secret log values, audience
  mismatch and real signature rejection. They do not exercise routing or database persistence.
- Parser/serializer tests include printable-ASCII round trips, adjacent character boundaries,
  escaped delimiters, controls, non-ASCII, malformed/list input and numeric parameter width limits.
- Proof tests cover missing/wrong-type timestamps, zero/extreme dates, both freshness cutoffs and
  their adjacent seconds, and real matching/mismatching EC signatures.
- Scoped RuboCop passed for 16 changed Ruby files. The final added parser boundary test was also
  checked separately.
- `bundle exec brakeman --no-pager --format json --quiet` passed with Brakeman 8.1.0:
  zero warnings, ignored warnings or analysis errors.
- `git diff --check` passed. A source search found no remaining DBSC log interpolation containing
  identifier/challenge values in `app/` or `lib/`.

## Blocked and unverified

The standard command `bin/rails test test/services/dbsc/header_parser_test.rb` could not start test
cases. Rails test preparation attempted the existing `CreatePublishingSchema` migration and failed
with `PG::DuplicateTable` for `publishing_media_files`. No database repair, schema reset or schema
snapshot edit was performed. The database-backed DBSC controller, refresh-binding and service suites,
and boot-dependent security invariant suites, remain unverified in this session. Their HTTP inputs
were updated where needed to use the specified quoted fields.

No DBSC-capable browser interoperability or end-to-end device test was available. The user explicitly
accepted proceeding without verification in their own environment. This record establishes the
checks above, not complete DBSC draft conformance or production/browser interoperability.
