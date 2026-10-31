# OIDC logout confirmation referrer policy recheck

HEAD: `336811e5072a93c0523e484f905082635b28f48f`. The worktree had uncommitted changes affecting this check.

`PARALLEL_WORKERS=1 bin/rails test test/integration/oidc_current_device_logout_test.rb -n '/logout_confirmation_posts_to_its_separate_confirmation_endpoint/'` passed: 2 runs, 26 assertions. The APP and ORG cases exercise initial and repeated confirmation responses and check `strict-origin` and the confirmation form destination. The implementation marks confirmation renders in `SignOidcLogout` and selects that policy in `SignOutNotice`.

This repeats and is consistent with the earlier `2026-10-31-wua12-oidc-confirmation-referrer-V6H4.md` evidence. It does not test a real browser, all logout outcomes, or WU-A12 as a whole. No implementation was changed in this check.
