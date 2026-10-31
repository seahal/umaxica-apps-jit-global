# Historical A30-6: later ORG journey probe

HEAD: `336811e5072a93c0523e484f905082635b28f48f`. The worktree had extensive uncommitted changes, including the ORG journey and admission flow; the result applies to that worktree.

The existing one-Passkey sign-in test first failed at its expectation of birthdate Step-Up while the second-Passkey gate redirected to registration (`evidence/2026-10-31-wux2-org-one-passkey-signin-C4F7.md`). A temporary test-only second Passkey was created after the registration redirect to inspect the remaining journey. The run progressed beyond that assertion but then errored at the existing three-form admission loop: the expected form was absent (1 run, 53 assertions, 1 error). The temporary test change was removed.

The precise response and reason for the absent form were not established by this probe. It did not perform real second-Passkey registration or repair the separate controller-wide gate issue. The original baseline-listed failure remains and A30-6 is incomplete.
