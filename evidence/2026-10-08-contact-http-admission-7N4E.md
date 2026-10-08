# Contact HTTP admission verification

Commit: `48ff7040de2b50a8a08ed660fa71878a029ba577`.
Uncommitted worktree changes affected these checks.

The APP/COM email signup controller files initially produced 76 errors before any assertions:
their admission setup lacked required sign-in state reference rows. Each file now initializes
its own sign-in/signup/cleanup semantic DEFAULTS before admission. The same command passed
76 runs/1008 assertions, zero failures, errors or skips (seed 54894). Focused RuboCop passed
for both files. No application authentication guard or foreign key was changed.

The ORG email/telephone registration files plus telephone rate-limit test initially ran
27 tests/86 assertions with one failure: the rate-limit test lacked mandatory Browser RP
credentials and received a sign-in redirect. Its setup now uses public RP-session/token APIs,
HTTPS and an existing verified passkey with explicit Step-Up evidence. It does not invoke
a new helper or add a production authentication bypass.

The focused rate-limit case passed one run/22 assertions (seed 4300). Admitted requests must
either reach the OTP edit redirect or explicitly fail the existing telephone cardinality
validation; an authentication redirect no longer counts as admission. The sixth start still
must return 429 without creating a row. Existing creation and four-contact policy remain
unchanged. A probe also showed the fourth start hitting cardinality with only three persisted
contacts, consistent with the existing loaded association including the unsaved validation
probe; this is not certified as correct cardinality behavior.

Complete ceremony-owned verifier integration and final verification remain outstanding.

After setup correction, the three-file ORG registration selection passed 27 runs/100 assertions,
zero failures, errors or skips (seed 16980). Focused rate-limit RuboCop and `git diff --check`
also passed.

## Telephone cardinality correction

A new HTTP boundary case reproduced refusal of the fourth contact with three persisted rows:
one run/21 assertions, one failure (seed 50543). The ORG Telephone issuer built an association
validation probe and then a second candidate, causing the loaded-association limit validator to
count the first unsaved probe against capacity. It now saves the validated probe itself.
No numeric limit, status, rate-limit or DB constraint changed.

The focused boundary test passed one run/31 assertions (seed 12172), including MAX-1, MAX and
MAX+1. The ORG three-file selection passed 28 runs/129 assertions (seed 10575), no failures,
errors or skips. Focused RuboCop corrected one string-formatting offense and passed.

`bin/rails architecture:baseline` completed. Its measured reductions, including removal of the
ORG issuer's two implicit-visibility offenses, are recorded in both baseline artifacts. Existing
measured increases were restored to their prior ceilings rather than ratcheted upward; their
current violations remain subject to the architecture test.

The architecture test ran three cases/198 assertions and failed once (seed 11611):
`client_external_identity_repository_adapter.rb` has eleven visibility offenses against a
baseline ceiling of nine. The failure is retained; the ceiling was not increased to pass.

## Identifier and ceremony visibility

The architecture measurement located 25 implicit-public offenses across APP/COM Contact models
and the Email/Telephone ceremony concerns. Their public sections are now explicit; callbacks and
private validators keep their existing private sections. No method's runtime visibility was widened.
Baseline regeneration measured 3119 visibility offenses, down from 3144; unrelated increases
remain bounded by their previous ceilings.

The five ceremony primitive files plus direct identifier destruction passed 50 runs/294 assertions,
no failures, errors or skips (seed 24419). `git diff --check` passed.

Focused RuboCop initially reported four callback declaration ordering offenses in the Contact
models. Automatic formatting placed initialization declarations before destruction declarations
without changing order within either callback kind. Six files then had all four offenses corrected.
The destruction/failure-retention selection after formatting passed 36 runs/272 assertions,
no failures, errors or skips (seed 51740). `git diff --check` remained green.
