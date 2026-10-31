# WU-7 com regional defaults

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`. Staged, unstaged and untracked work affected the result.
- Section 4.5 names the existing `REGIONAL_DEFAULT_OPTION_NAMES` as the source for region's four dependent display options. The com writer duplicated that table in its own region case. It now uses the existing shared region-default resolver and explicitly writes the region plus the four resolved com option IDs in the same setting transaction.
- Before the change, the selected com region cases passed: 3 runs, 21 assertions. The extended test saves a dark theme and submits conflicting theme/timezone URL overlays while switching to US and back to Japan; the unrelated stored theme and timezone remain unchanged. The broader com/app/org region selection passed: 42 runs, 356 assertions, zero failures, errors or skips. RuboCop passed on both changed Ruby files.
- Full-suite comparison and repository-wide schema drift remain unresolved. No migration or non-test purge was performed.
