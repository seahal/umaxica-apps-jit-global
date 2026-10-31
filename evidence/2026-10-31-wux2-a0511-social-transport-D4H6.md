# Historical A05-11 social signup transport

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`.
- The worktree had uncommitted changes affecting these results.
- A source search in `app`, `config`, `lib`, and `test` found no occurrence of `commit_signup!`, `committed_signup!`, `commit_login!`, `commit_link!`, `handle_social_sign_up_intent`, `create_social_sign_up_flow!`, `bind_social_sign_up_flow!`, or `social_sign_up_required?`. The last four are the C2 symbols identified in the archived work-unit definition.
- The current Base APP social authentication route declares a continuation but no completion; its matching Base controller directory contains the continuation controller. Auth's separate link-completion endpoint remains and was not treated as the retired Base signup transport.
- `PARALLEL_WORKERS=1 bin/rails test test/integration/apple_social_flows_test.rb -n '/sign_up_waits_for_confirmation_before_creating_user_and_identity/'`: 1 run, 41 assertions, 0 failures, 0 errors. This case checks the current Apple signup handoff to `/sign/in/check`.
- The search is limited to the named symbols and source roots. Google end-to-end signup, deployed routes, and broader historical social authentication requirements were not checked in this slice.
