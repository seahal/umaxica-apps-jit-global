# Visa CSP report cookie finding

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`.
- The worktree contained uncommitted changes affecting this result.
- A temporary public HTTP test sent a valid `application/csp-report` POST with `Origin: null` to APP Visa while Rails forgery protection was enabled. The endpoint returned 204 but also returned `XSRF-TOKEN` and `session` cookies, contrary to the intake concern's stated stateless intent. The test stopped on APP before testing ORG or malformed input.
- An exploratory change to normalize the request format suppressed the XSRF cookie in that test but still produced a session cookie; adding session-skip made that narrow test pass. This workaround was not retained: the installed Inertia after-action also triggers for XHR requests, so the approach was not established safe for all request forms. The temporary test was removed from the suite and saved as `/tmp/wua14-visa-csp-test.txt`; both exploratory controller edits were reverted.
- No persistent fix, ORG verification, XHR test or complete CSP intake acceptance was performed. Cookie values are intentionally omitted from this record.
