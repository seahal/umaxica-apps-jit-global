# WU-7 com actor display snapshot

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`; the worktree contained uncommitted changes affecting this result.
- On a Warp com GET with a valid signed preference, rendered `Actor.preferences` previously retained defaults. Base and Warp com now install a request-local actor display snapshot after their preference transport runs. URL display overlays remain request-local. Invalid JWTs retain default display values.
- The Warp request test observes the actor during real template rendering and confirms language, theme, and currency, zero com-preference SQL, and no JWT reissue. It also covers an invalid JWT and an explicit URL overlay.
- `bin/rails test test/controllers/warp/com/roots_controller_test.rb test/controllers/base/com test/unit/actor/preference_test.rb test/integration/anonymous_com_web_push_initialization_test.rb test/security/invariants/actor_context_invariant_test.rb`: 76 runs, 600 assertions, 0 failures, 0 errors, 0 skips.
- The four changed Ruby files passed RuboCop after correcting one layout offense. The architecture document now distinguishes this display snapshot from the binding-checked consent endpoints.
- This does not establish actor consent hydration, realm-separated keys, the lifecycle schema, or WU-7 completion. No migration or full-suite run was performed in this slice.
