# WU-A6 ORG Standby enforcement and IAM recheck

## Result

The focused Standby controller tests passed for the four enforcement-case operations and IAM grant
and revocation.

Command:

```text
PREFERENCE_COM_JWT_ISSUER=https://www.umaxica.com PREFERENCE_COM_JWT_AUDIENCE=com PREFERENCE_COM_JWT_REVOKED_KIDS= VALKEY_NAMESPACE_RUN_ID=wua6-matrix-20261102 PARALLEL_WORKERS=1 bin/rails test test/controllers/base/org/support/standby_enforcement_cases_controller_test.rb
```

Result: 6 runs, 78 assertions, 0 failures, 0 errors, 0 skips. The cases include Standby requests
with matching fresh Step-Up evidence; enforcement and grant/revocation effects remain refused.

This is only the Standby side of selected operations. Normal Step-Up success comparison for each
operation, the complete policy-derived matrix, and actual Auth Standby-to-Visa Root issuance remain
unverified. No full suite was run, and no application or schema change was made in this slice.

## Revision and worktree

- HEAD: `efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8`
- The worktree contained broad uncommitted changes; 558 tracked paths and 276 untracked paths were
  present before adding this evidence file. No paths were staged.
