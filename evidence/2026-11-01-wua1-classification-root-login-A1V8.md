# WU-A1 current Sign Entry Sentry checks

HEAD: `efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8`. The worktree contained pre-existing uncommitted
changes and the focused test edits recorded here; no staged changes were present. Existing work was
preserved.

Updated the root-login Sentry acceptance test to follow the current Visa result contract: a
read-only result GET renders the same-origin continuation form, and the signed continuation POST
attempts root establishment. When the App Sign In availability flag is disabled after evidence is
recorded, the POST returns `invalid_request/login_failed` without issuing a token or login audit,
finalizing the OIDC parent, changing the sign-in Flow, or terminating the admitted Auth Ceremony.
The initial focused run found a stale test assumption that the result GET returned JSON; the test
raised `NoMethodError` while parsing the HTML form. The corrected public-path assertion passed.

With `.env.container.devcontainer` loaded and `PARALLEL_WORKERS=1`, the focused A1 selection passed:
89 runs, 807 assertions, 0 failures, 0 errors, 0 skips. It covered the closed route classification
guard, App/Org Sentry allow/block behavior, blocked sign-in/continuation endpoints,
attached-unconfirmed Admission preservation, App/Org controller entry, admitted OTP resend, and
root-login refusal. Targeted RuboCop passed for the changed root-login test; Ruby syntax and scoped
`git diff --check` passed for the changed tests. Existing NanoID frozen-string warnings appeared.

The current resolver has four App/Org flags; the older accepted Sentry ADR still describes six flags
including COM. `two.md` §2.1 directs that ADRs remain unchanged in this cycle, so the ADR was not
edited. The test run is local and focused; it is not full-suite or deployment evidence.

The ORG Emergency exception was also exercised through its public Passkey flow while normal Org Sign
In was blocked.
`bin/rails test test/controllers/auth/org/in/emergency/passkeys_controller_test.rb:167` passed: 1
run, 8 assertions, 0 failures, 0 errors, 0 skips. The test reached the standby result without
issuing a normal Operator token.
