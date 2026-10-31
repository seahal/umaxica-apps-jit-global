# WU-7 invalid JWT write and complete snapshot

Commit: `336811e5072a93c0523e484f905082635b28f48f`. The worktree contained uncommitted changes affecting this result.

`bin/rails test` on the com Web Push initialization, Web Push API and Preference write-journey integration files passed: 71 runs, 683 assertions, no failures, errors, or skips. A new public request test submits an invalid signature through both the theme API and the theme settings screen. Each creates a distinct preference from defaults, applies the requested theme, leaves the original parent and language child unchanged, and neither copies consent nor creates a browser binding for the new row. Existing tests also cover stale-generation reset and write, signing failure rollback and database-clock expiry.

Anonymous com issuance now rejects an incomplete or invalid display snapshot before signing rather than substituting a language. RuboCop passed for the two changed Ruby files. This does not establish all invalid JWT classes, independent-connection races, realm-specific keys or the complete Preference lifecycle.
