# WU-0 important-set inventory and WU-P0 proposal record

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`. The worktree had uncommitted WU-1 realm
  normalization changes (`app/values/oidc_subject.rb`, `app/values/oidc_client_registry.rb`, two
  tests) and unrelated untracked files. They do not affect the document work below.
- Work: documentation only. No application, test suite, database, migration, or external system was
  run. Nothing was deployed.
- Outputs: `plans/2026-10-28-baseline-important-test-set.md` (method and counts),
  `plans/2026-10-28-wu-p0-preference-adr-revisions.md` (WU-P0 proposal). No accepted ADR,
  `docs/architecture/preference.md`, schema, code, route, or test was modified.

## WU-0 important set

`two.md` WU-0 requires the baseline failing/skipped/deleted test identifiers **and** the important
sets (authentication / routing / membership / avatar / preference) in evidence. The earlier baseline
evidence (`evidence/2026-10-28-baseline-test-result-Q6N4.md`) recorded the run and the identifier
inventory but not the important-set partition. This record closes that gap by deriving the partition
from the retained inventory; it does not re-run the suite and does not recover passing identifiers.

Method: read `plans/2026-10-28-baseline-failing-tests.md`, split each entry at `#`, map the class to
its defining test file with a repository grep, and assign the file to the first matching area by path
substring (authentication: `auth|sign|ceremony|oidc|passkey|session|secret|password`; routing:
`rout|path|redirect|jump|url`; membership: `membership|organi|company|individual`; avatar: `avatar`;
preference: `preference`). Test-file and test-case counts over `test/**/*_test.rb` used the same
partition.

| Area | Test files | Approx. test cases | Baseline failing identifiers |
| --- | --- | --- | --- |
| Authentication | 868 | 5,508 | 772 |
| Routing | 72 | 443 | 1 |
| Membership | 37 | 202 | 0 |
| Avatar | 73 | 410 | 3 |
| Preference | 184 | 1,183 | 38 |
| Unassigned | 1,160 | 5,935 | 168 |
| Total | 2,394 | 13,681 | 982 |

Limitations: the failure column is the 982-entry baseline inventory (981 distinct identifiers; one
duplicate line). Ten failing classes could not be mapped to a defining file by the `^class` grep and
are counted in Unassigned. The case counts are a line-based approximation, not a Minitest report.
The area partition is path-based and therefore a bookkeeping aid, not a claim that a test exercises
only that area.

## WU-P0

Read: the four ADRs named in `two.md` §2.1, `adr/invalid-browser-credential-recovery.md`,
`docs/architecture/preference.md`, and the implementing code cited in the proposal. Each proposed
clause was checked against the code first; the proposal lists eight discrepancies (D-1–D-8) rather
than resolving them silently. Under the AGENTS.md conflict rule, the code is authoritative where the
documentation is stale.

Checks performed:

- `docs/architecture/preference.md`, `adr/preference-*.md`: read in full.
- Code claims: `app/values/security_jwt_preference_token_codec.rb`,
  `app/controllers/concerns/preference_jwt_configuration.rb`,
  `app/controllers/concerns/preference_io_keys.rb`,
  `app/controllers/concerns/preference_adoption.rb`,
  `app/controllers/concerns/preference_sign_out_rotation.rb`,
  `app/controllers/concerns/preference_class_registry.rb`, `app/models/app_preference.rb`,
  `app/models/client_preference.rb`, `db/*_structure.sql` (existence and table location).
- Cross-check with `two.md` §2.1, §4, §12.7 for clause coverage.

Not performed: any preference test run, schema change, migration, key generation, or HTTP check.
The proposal is therefore a review artifact and is not evidence that the described contracts hold
in code.

## Open items carried forward

1. WU-3 is not started: it may not be split (`two.md` §1.2) and it removes whole surfaces, so it
   needs an owner decision to begin.
2. WU-0's baseline run used a checkout with different local configuration (`evidence/2026-10-28-baseline-test-result-Q6N4.md`);
   the comparison inventory is not a clean-environment baseline.
3. WU-P0 review questions D-8 and the Web Push option-table shape block the WU-7 shape review.
