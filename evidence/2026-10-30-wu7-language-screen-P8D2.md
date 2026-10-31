# WU-7 language settings screen

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`. The worktree contained uncommitted changes affecting the result.
- After explicitly saving Japanese, the com language edit screen rendered with English from `lx=en` while its selector showed Japanese. The shared locale-pinning code relies on `explicit_fields`, which the com schema intentionally removed. App and org retained their existing behavior.
- The com screen now pins its locale to the selected language when an active preference is loaded. The preference behavior documentation records this screen-specific exception. The three-surface language selection, com language/timezone write cases, and read-only GET/HEAD selection passed: 6 runs, 114 assertions, zero failures, errors or skips.
- RuboCop found two formatting offenses in the newly changed timezone assertions, which were corrected, and one pre-existing offense at `test/integration/acme_preference_test.rb:705` in the then-current file. Full-suite comparison was not re-run in this slice.
