# WU-9 adult gate runtime allowlist

- HEAD: `efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8`.
- The worktree contained extensive uncommitted changes before this slice; no commit was created.
- Removed `adult_content_gate` from `ActorPreferenceExplicitDisplay::ALLOWED_FIELDS`. The explicit
  actor snapshot now accepts only `DISPLAY_FIELDS`; `region` remains non-transferable. The dormant
  model, option and child-table families were not changed.
- Updated the Client Preference snapshot example and the dormant-gate security guard to exclude the
  field from the runtime allowlist. The existing unrelated Client Preference test edits were
  preserved.
- Current Preference architecture, lifecycle checklist, ADR and `two.md` already state that the
  adult gate is dormant and excluded from runtime display/save registries; no documentation change
  was needed.
- `bin/rails test test/unit/security/preference_dormant_adult_gate_test.rb`: 2 runs, 16 assertions,
  0 failures/errors/skips.
- `bin/rails test test/models/client_preference_test.rb:41`: not verified; fixture setup failed
  before assertions because `enterprise_units.enterprise_id=519260495` has no matching `enterprises`
  row.
- RuboCop on the three changed Ruby files, `ruby -c` on each, and scoped `git diff --check` passed.
- No database rows or schema were changed. Production and Neon were not accessed.
