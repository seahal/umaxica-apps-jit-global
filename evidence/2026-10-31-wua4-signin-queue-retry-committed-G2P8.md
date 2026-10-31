# Sign-in queue refusal and committed resend

HEAD: `336811e5072a93c0523e484f905082635b28f48f`. The worktree had uncommitted changes affecting this check.

The former controller test for initial queue refusal followed by resend ran inside fixture transactions and failed after resend began requiring transaction ownership. It was replaced by an HTTP integration case using committed synthetic records and explicit cleanup. The case verifies the existing 503 and unavailable copy, retention of the issued challenge and contact, a usable resend state, and a successful resend with a new generation. The queue refusal is injected; no actual queue outage is claimed.

The original three affected caller files and the committed HTTP file passed together: 67 runs, 772 assertions. After correcting test cleanup so that an occurrence is eligible for deletion only after its body was confirmed absent, the service, resend HTTP, committed HTTP and serialization files passed together: 56 runs, 338 assertions. Scoped RuboCop for those three edited test files passed. Some whitespace-only formatting was applied after the first combined run.

The full suite and other indirect callers remain unverified. This does not resolve whole-second cooldown precision, other OTP writers' transaction boundaries, or real transport behavior.
