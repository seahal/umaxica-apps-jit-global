# WU-A2 social callback refusal matrix contract correction

HEAD: `efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8`. The worktree had 487 changed or untracked paths
before this evidence record was added, with no staged changes. Existing work was preserved.

The baseline-listed `SocialCallbackRefusalMatrixTest#test_A07-1e/A08/A34-2` treated every callback
as producing no `ClientSignUpFlow`. Its `unknown` subject plus admitted `sign_up` partition is a
verified successful Google/Apple callback under the current R-AU-49 contract and creates one pending
Flow; the Client, token and external identity remain unchanged at this stage. The test now asserts
that distinction and continues to require no authority writes for the other partitions.

With `.env.container.devcontainer` loaded,
`bin/rails test test/integration/social_callback_refusal_matrix_test.rb:43` passed: 1 run, 1,204
assertions, 0 failures, 0 errors, 0 skips. RuboCop on the test file reported no offenses; `ruby -c`
and `git diff --check` passed. The full suite was not run.
