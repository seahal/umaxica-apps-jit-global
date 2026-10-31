# Com Web Push browser API

- Commit: `336811e5072a93c0523e484f905082635b28f48f`; uncommitted changes affected this result.
- Added Base com GET/PATCH Web Push endpoints. The write uses the existing com transaction boundary and sets a host-only binding after commit. The read requires a verified com JWT, an available preference and a matching binding. A write with a mismatched existing binding is refused to avoid transferring stored consent to another browser; this restriction must be reconciled with the final independent-binding design.
- `bin/rails test test/integration/anonymous_com_web_push_api_test.rb test/integration/anonymous_com_web_push_initialization_test.rb test/models/com_preference_web_push_test.rb`: 6 runs, 32 assertions, no failures or errors. These include matching, missing and mismatched binding reads, mismatched-binding write refusal, an invalid option and a missing-CSRF-token refusal.
- No push subscription or delivery was implemented. The independent binding table, generated structure dump, other realms and broader two.md requirements remain incomplete.
