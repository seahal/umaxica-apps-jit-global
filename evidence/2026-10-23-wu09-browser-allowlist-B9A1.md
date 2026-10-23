# WU-09: browser allowlist on Sign-in path pages

- Date: 2026-10-23. Base commit `6e4d70d0b0799a4ef9bd9fc4cea2c21d4b3eca72`; change uncommitted (tests only).
- Decision: D-50 (1).

Finding: every browser-facing surface `ApplicationController` (Auth, Base, Core, Warp, Palm, Edit,
Tech; app/com/org) already declares `allow_browser versions: :modern`; the token endpoint and the
Back-Channel Logout receiver inherit `ActionController::API`. No production change was needed.

New `test/integration/sign_in_path_browser_allowlist_test.rb`: Safari 16 gets 406 on
`/sign/in` for APP, COM and ORG Auth hosts; `POST /oauth/token` (Base) and
`POST /oidc/backchannel-logout` (Core) answer neither 404 nor 406. 3 runs, 0 failures.
When WU-15 renames the receiver to `/oidc/closures`, the last case moves with it.
