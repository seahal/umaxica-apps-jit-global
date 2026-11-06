# WU-A14 APP Visa session-limit browser-flow route recheck

HEAD: `efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8`. Before this evidence file was added, the worktree
had 558 modified tracked paths and 278 untracked paths, with no staged changes. Existing worktree
changes were preserved.

`test/integration/oidc_rp_browser_flow_test.rb` no longer loads unrelated global fixtures. The tests
create the Client actors they need on demand, so a fixture foreign-key failure no longer prevents
the Visa browser-flow cases from reaching their request assertions.

The focused Visa APP session-limit route case passed: 1 run, 38 assertions. The first run of the
full affected file passed 13 of 14 cases and exposed one stale assertion: OIDC parent cancellation
resumed at `/oidc/cancellation`, while the test expected `/sign`. The current controller and
`docs/security/public-entrypoints.md` describe cancellation delivery through the Visa OIDC endpoint.
The test now verifies that path, the parent transaction reference, and a present cancellation
reference.

After correction, `PARALLEL_WORKERS=1 bin/rails test test/integration/oidc_rp_browser_flow_test.rb`
passed with 14 runs, 223 assertions, 0 failures, 0 errors, and 0 skips. `ruby -c`, scoped RuboCop,
and `git diff --check` passed. NanoID emitted its existing frozen-string warnings. The full Rails
suite and remaining WU-A14 candidate inventory were not run.
