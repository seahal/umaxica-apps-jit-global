# TOTP removal exception response

HEAD: `336811e5072a93c0523e484f905082635b28f48f`. The worktree had uncommitted changes affecting the application and tests.

A temporary copy of the existing Step-Up integration test injected `ArgumentError` at the credential-removal committer and expected the current HTTP 303 response. With the configured local test environment, `PARALLEL_WORKERS=1 bin/rails test tmp/wua4_totp_refusal_probe_test.rb -n /a_refused_TOTP_removal/` passed (1 run, 2 assertions), including that the credential stayed active. The temporary copy was removed.

This establishes the controller's response to an injected exception, not that a specific real-world trigger reaches that exception. The analogous `ActiveRecord::RecordInvalid` exception was not injected. The proposed 422 response has not been implemented.
