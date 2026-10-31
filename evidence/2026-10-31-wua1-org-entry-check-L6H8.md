# WU-A1 org entry and classification check

HEAD: `336811e5072a93c0523e484f905082635b28f48f`. Staged, unstaged and untracked worktree
changes affected the run. The local test environment was used; production and Neon were not targeted.

`PARALLEL_WORKERS=1 bin/rails test test/unit/security/sign_entry_classification_guard_test.rb
test/controllers/auth/org/sign_ins_controller_test.rb` produced 15 runs, 51 assertions,
6 failures, no errors and no skips. All six failure names occur in
`plans/2026-10-28-baseline-failing-tests.md`; each expected a successful sign-in page but received
a 303 ceremony-binding confirmation redirect. The cause was not determined. The combined result
does not establish WU-A1 acceptance.

Static inspection found the JSON Email OTP route under the Auth app host scope and no Email OTP
controller under `app/controllers/auth/org/sign/`. This narrow source inventory does not replace
a complete route enumeration. A subsequent `RAILS_ENV=test bin/rails routes -g
web_v0_in_email_otp` returned only `auth_app_web_v0_in_email_otp` pointing to the Auth app
controller; this route-name filter does not prove absence of every other possible org OTP route.
No production code or schema was changed.
