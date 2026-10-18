# Dead history visibility and lifecycle matrix

Commit: `48ff7040de2b50a8a08ed660fa71878a029ba577`. Uncommitted implementation and test changes
affected these results; all persistence was local synthetic test data.

The six history schema/interface and product-boundary tests, together with the existing six-host
MCP withdrawal checks, passed six runs and 34 assertions, seed 37289. The two independent channel
guards reject direct History/fingerprint-verifier references from ordinary controllers, rendering,
serializers, notifiers, routes and MCP tools. This is a static disclosure guard, not a claim that
arbitrary indirect dataflow has been formally proven absent. No internal Operator endpoint was added.

The eight-file matrix covers minimal history columns/indexes, protected Source destruction, whole
APP/COM owner erasure, HMAC/Argon2id fingerprint isolation and malformed inputs, physical purge,
purge/reuse races, retention and product visibility. Its initial 106 runs had eight cleanup errors,
seed 23404: old nontransactional race fixtures attempted destruction of still-recoverable APP/COM
owners. The new admission guard correctly refused them. Cleanup now explicitly establishes an
already-matured, valid retention window on only those synthetic owners before ordinary destruction;
the guard and all race assertions remain intact.

The matrix then passed 106 runs and 834 assertions, seed 9448, using the ordinary 16-process runner,
with no failures, errors or skips. RuboCop passed for the two changed visibility/concurrency tests.
The standalone minimal-history/fingerprint/visibility task is checked complete; the broader live
uniqueness task and final project gates remain separately incomplete.
