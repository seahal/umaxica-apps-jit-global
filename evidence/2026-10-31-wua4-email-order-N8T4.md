# WU-A4 XDB-03 Email preference ordering slice

HEAD: `336811e5072a93c0523e484f905082635b28f48f`. Staged, unstaged and untracked changes in the
worktree affected these results. Tests used local test databases; production and Neon were not targeted.

Before the change, a public-operation failure injection observed the new Email preference inside
the OP Step-Up consumption call. The focused test failed because Zenith had already been updated.
The operation now holds the Zenith actor and Email row locks, checks ownership and the no-op case,
then locks and consumes the OP evidence inside the OP transaction before saving the Email change.
The existing caller is the Base app Email controller. Storage errors now raise a distinct dependency
failure that the controller maps to 503; Step-Up denial remains on its existing authorization path.

The focused operation tests passed: 4 runs, 25 assertions. They include failed OP consumption with
the original Email value, and an injected Zenith SQL failure after consumption with the Email value
rolled back and evidence spent. The operation and relevant controller cases passed: 6 runs,
36 assertions, no failures, errors or skips. RuboCop found no offenses in the three changed Ruby
files and scoped `git diff --check` passed after formatting corrections.

These fixture-based tests do not prove actual independent-connection commit ordering or every race.
This is not XDB-03 completion: Step-Up issuance still uses `resource_ref: nil`; an authoritative
same-Zenith-transaction audit for the preference change is not yet implemented; and a separate
public HTTP dependency-failure test remains needed. Those gaps are recorded in `four.md`.
