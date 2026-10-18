# Canceled admission tab isolation

Commit: `6fa6867d44b5499632079775cb0fb22cbfddd339`; dirty worktree with inherited implementation and new regression coverage. Runs used only the owned `20261006fresh1` disposable PostgreSQL test manifest, serially.

Added app/com/org HTTP cases for cancel-and-start after actual Auth attachment and redemption with Rails forgery protection enabled. Public Base confirmation isolates this cancellation boundary; existing independent HTTP cases cover Base confirmation. Old-tab verification GET and Passkey-options POST both return 400/no redirect. The predecessor stays canceled; replacement parent, binding, Step-Up session and absent challenge are unchanged; no replacement continuity or freshness is granted.

- Initial three-case selection: 3 runs / 45 assertions, no failures, errors or skips, seed 33970.
- After adding replacement-session/challenge preservation, the admission/concurrency/CSRF three-file selection passed: 89 runs / 1608 assertions, no failures, errors or skips, seed 40075.
- After line-wrap and assertion-spacing repairs, the new cases passed: 3 runs / 51 assertions, no failures, errors or skips, seed 34155. Scoped RuboCop passed; scoped diff whitespace check passed.

Updated binding reference documentation and the transition inventory to distinguish approved Contact forward-fix direction, approved shared OTP budget direction, retained Social GET contract, and deferred COM distribution recovery. None is silently counted as completed implementation. No migration or production behavior changed in this increment; no Task checkbox was completed.
