# WU-A3 Auth admission Fetch Metadata recheck

- HEAD: `efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8`. The worktree already contained 538 changed or
  untracked paths when this check ran; no commit was created.
- Compared with the earlier probe at `336811e5072a93c0523e484f905082635b28f48f`, the current
  `AuthCeremonyAdmission#admit_or_render_sign_ceremony!` now refuses invalid admission navigation
  before resolving the binding. `invalid_admission_navigation?` requires the shared
  `document_navigation_request?` predicate. The HEAD revision contains this guard; the earlier
  revision did not.
- The accepted Design D ADR requires `Sec-Fetch-Mode: navigate` and `Sec-Fetch-Dest: document`; it
  does not allow `empty` for this continuation.
- With `.env.container.devcontainer` loaded and `PARALLEL_WORKERS=1`, ran:
  `bin/rails test test/controllers/auth/app/verifications_controller_test.rb test/controllers/auth/org/verifications_controller_test.rb test/controllers/auth/ceremony_admission_boundary_test.rb`
- Result: 44 runs, 988 assertions, 0 failures, 0 errors, 0 skips. APP and ORG verification cases
  refused missing, partial, non-navigation, `empty`, and framed metadata and HEAD without redeeming
  the binding or issuing the Auth SID cookie. Document navigation redeemed the tested admission. The
  shared boundary cases also exercised APP and ORG attachment refusal and successful navigation.
- Updated `docs/security/public-entrypoints.md` and the APP/ORG admission diagrams to describe the
  confirmed-entry Fetch Metadata requirement. Updated the ignored local `four.md` issue record to
  distinguish the old probe from the current revision. Scoped `git diff --check` passed for the
  tracked documentation files.
- This verifies the exercised verification and admission paths at the current local checkout. It
  does not establish deployed browser behavior or cover every admission purpose independently. No
  application code changed in this recheck; the full suite was not run.
