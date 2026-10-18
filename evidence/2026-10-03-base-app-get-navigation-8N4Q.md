# Base app GET navigation

Completed on 2026-10-03 against commit `f313b126931cfe3c9ecf64bbb72fb1cd3a0aada5` with uncommitted navigation changes and unrelated concurrent work. The investigation began at `bab7343c9de26b86f4ab22ae18ca0074db045394`; another workspace operation advanced HEAD during this session. Unrelated work was preserved.

The app dashboard now exposes Preference independently of Cookie consent. Avatar lists expose New; resource details/forms have parent links. Telephone lists expose both the plural resource New page and the existing verification-registration entry. Session rows expose GET details independently of DELETE controls; detail props now include the column labels required by the existing component. Groups displays its policy-scoped entries and links to the existing JSON detail. Organization detail links directly to authorized membership index/new/show/edit entries, keeping them within three links of Dashboard. Membership browser pages remain explicit unavailable-management shells; JSON index/show contracts and mutations are unchanged.

Shared React components accept optional navigation destinations supplied only by app controllers. No com/org controller or page was edited for this task.

## Results

- `bin/rails test test/controllers/base/app/organizations/memberships_controller_test.rb test/controllers/base/identity_sessions_presentation_test.rb test/controllers/base/app/avatars_controller_test.rb test/controllers/base/app/accounts_controller_test.rb test/controllers/base/app/groups_controller_test.rb test/controllers/base/app/identity/telephones_controller_test.rb test/controllers/base/app/organizations_controller_test.rb`: 56 tests, 366 assertions, no failures, errors, or skips. Includes membership-policy filtering and rejection of another principal's membership, resource ownership tests, session detail navigation, and preservation of com/org session payloads.
- `bin/rails test test/controllers/base/app/welcome_dashboard_authority_slice_1c_test.rb:35 test/controllers/base/app/organizations_controller_test.rb test/controllers/base/app/organizations/memberships_controller_test.rb test/controllers/base/app/accounts_controller_test.rb`: 19 selected tests, 122 assertions, no failures, errors, or skips, after controller formatting.
- `bun run test spec/pages/base/app/identity/identity_pages.test.tsx spec/features/self_service/self_service_pages.test.tsx spec/pages/base/app/groups/index.test.tsx spec/features/base_org/identity_screens.test.tsx spec/features/base_com/base_com_identity_pages.test.tsx`: 138 tests in five files passed. Covers actual rendered GET anchors, empty collections, and existing shared-component behavior.
- `bun run build`: passed; Vite transformed 2,361 modules and built production assets in 1.16 seconds.
- `bundle exec rubocop` on the seven changed app resource controllers: passed. The dashboard controller had unrelated in-flight edits and was not autoformatted.
- `oxlint` on the changed pages, list/session components, and specs: passed, excluding AvatarForm's existing violations. Running the same check including AvatarForm reported its existing duplicate React import, unused `_segment`, and underscore-name violations; those lines were preserved.
- `git diff --check`: passed.

## Existing failures and limits

- The complete `welcome_dashboard_authority_slice_1c_test.rb` run had 19 tests and two failures: anonymous/expired dashboard requests redirected (302), while existing assertions expected 404. Both failures were observed in the initial regression run before changing application implementation, and persisted afterward. The authenticated dashboard navigation test passed.
- `bun run typecheck` remains unsuccessful with seven errors outside this change: Auth passkey fixtures in four test locations and the existing org Avatar page's optional description. Errors introduced by this change were corrected; no changed navigation file appeared in the final diagnostics.
- An intermediate parallel Rails run could not clone a database because another session was connected. A sandboxed command with an environment prefix also could not resolve the database host; the ordinary approved Rails test command succeeded. These failed runs are not counted as passing verification.
- Browser interaction and responsive-layout checks were not run; no Chrome DevTools tool was available. Verification used HTTP responses, rendered component markup, and the production build. No deployment was performed.
