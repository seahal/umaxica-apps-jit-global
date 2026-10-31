# WU-7 com refresh entry inspection

HEAD: `336811e5072a93c0523e484f905082635b28f48f`. Staged, unstaged and untracked changes affected
the inspection. No files were staged or committed.

- `Base::Com::ApplicationController#set_preferences_cookie` delegates to the shared transport only
  for GET or HEAD. On that read path `PreferenceTransport` explicitly excludes the com claim shape
  from legacy refresh lookup. `ComSelectablePreferenceScreen` also prevents the shared
  `ensure_preferences_record` entry on writes; its saves invoke `write_preference!`.
- The existing integration cases `a generic screen save ignores a legacy com refresh credential`
  and `a com GET ignores legacy refresh and DBSC cookies without creating preference state` were
  among the 75 passing tests recorded in `2026-10-31-wu7-write-read-boundaries-H3R6.md`.
- Shared refresh and DBSC code remains for app/org. This inspection covers the named entry paths,
  not every possible call site; it does not establish complete removal or WU-7 closure.
