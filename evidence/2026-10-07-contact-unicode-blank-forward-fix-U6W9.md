# Unicode blank Contact digest forward fix

Commit: `6fa6867d44b5499632079775cb0fb22cbfddd339`. Uncommitted inherited and current implementation changes affect the observations.

The earlier POSIX-space checks were all validated (read-only `pg_constraint` probe), but the fleet's
PostgreSQL regex considered U+00A0 nonblank. `bin/rails test test/models/contact_binding_constraints_test.rb
-i /effective_digest_rejects_nil/` reproduced the gap: 4 runs, 36 assertions, 4 failures, no errors
or skips (seed 38296). No effective row was changed by those rollback-protected failure probes.

Two further additive migrations, `20261007124539` and `20261007124608`, explicitly exclude Unicode
White_Space additions from finalized email/telephone digests. Both add NOT VALID checks and then
validate outside a migration-wide transaction; existing checks and historical migrations are retained.
The code-point classification was verified against Unicode's primary
[property list](https://www.unicode.org/Public/17.0.0/ucd/PropList.txt).

`bin/rails db:migrate:app_zenith db:migrate:com_zenith` applied only to the owned disposable test fleet.
The full constraint file then passed: 6 runs, 216 assertions, no failures/errors/skips (seed 58774).
It covers NBSP, ideographic space and both ends of U+2000–U+200A, rejecting whitespace while allowing
the immediately adjacent nonblank U+1FFF/U+200B values. A one-character nonblank digest remains valid;
these checks do not introduce a digest-format contract.

One empty generated migration stub (`20261007124420`) was auto-prepared when its generation overlapped
the red test. The uncommitted empty stub was removed and no receipt was destructively edited. That
orphan version exists only in the disposable app database; Final Verification must construct clean
fleets and generate canonical schema snapshots from them rather than reuse that fleet's receipt.
Generators and tests were serialized thereafter. Production/shared rollout and historical recognition
remain unverified.
