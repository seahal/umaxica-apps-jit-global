# Historical A05-3 social signup Flow

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`.
- The worktree had uncommitted changes affecting these results.
- The two existing Google/Apple signup cases first passed with 82 assertions. They now also check that the social entry creates exactly one Flow, that its Admission is redeemed for signup, that its expiry does not exceed the Admission curfew, and that the successful callback leaves the same Flow as the only new Flow. Equivalent pre-existing confirmation/status assertions were combined without removing their checks.
- The signup cases and the two existing sign-in cases, which check no signup Flow is created, passed together: 4 runs, 109 assertions, 0 failures, 0 errors. Provider and protocol network transport are stubbed at test boundaries.
- RuboCop reported the same 16 existing offenses in the large integration file as before this change; scoped `git diff --check` passed. The missing-Flow and other refused callback partitions, actual provider delivery and full suite were not run. A05-3 remains partial.

## Missing Flow follow-up

- The current repeated Google-entry case passed first (1 run, 12 assertions). New Google and Apple request cases start a signup under `prompt=create`, delete only their own test Flow, and verify that the callback returns 400 without creating a replacement Flow, Client, token or Google/Apple identity. Admission binding confirmation is direct and OmniAuth runs in test mode.
- The two missing-Flow cases and the earlier four signup/sign-in cases passed together: 6 runs, 133 assertions, 0 failures, 0 errors. RuboCop passed for the new test file.
- This supersedes the earlier missing-Flow limitation for these providers. Actual external providers, a full Base browser admission in the new cases and the full suite were not checked.
