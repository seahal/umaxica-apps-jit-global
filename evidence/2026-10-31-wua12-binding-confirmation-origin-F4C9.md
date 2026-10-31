# Binding confirmation form referrer policy

HEAD: `336811e5072a93c0523e484f905082635b28f48f`. The worktree had extensive uncommitted changes, including the affected controller concern and integration test; these results apply to that worktree.

- The APP admission journey passed before the additional header assertion (1 run, 36 assertions). The new assertion then failed because the form response returned `no-referrer` instead of `strict-origin`.
- `BaseCeremonyBindingConfirmation#show` now sets `strict-origin` when rendering the confirmation POST form. The automatic continuation and refusal paths keep their existing header handling.
- `PARALLEL_WORKERS=1 bin/rails test test/integration/app_passkey_secret_session_step_up_test.rb test/integration/acceptance_wu12_relay_repeat_test.rb` passed: 8 runs, 218 assertions. The APP journey exercises the displayed form and its existing CSRF-protected POST; the relay suite exercises continuation cases.

Real-browser behavior, an ORG form-specific header assertion, and complete WU-A12 acceptance were not verified by this run.
