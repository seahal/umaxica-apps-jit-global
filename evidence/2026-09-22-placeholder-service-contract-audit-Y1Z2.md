# Placeholder service contract audit

- Date: 2026-09-22 UTC
- Repository HEAD: `91d71c6f61d60c13be350bff3b723e05d09adf37`
- Branch: `feature`
- Worktree: pre-existing modified and untracked files were preserved. No reset, clean, commit,
  push, GitHub write, AWS access, Cloudflare access, provider call, or production/shared-database
  operation was performed.

## Scope and evidence

The following files were inspected:

- `app/services/outage_service.rb`
- `app/services/token_emergency_service.rb`
- `test/services/outage_service_test.rb`
- `test/services/token_emergency_service_test.rb`

Repository-wide searches found no production caller, route, controller, job, model, policy, or
documented public contract for either service. The only references outside the implementation are
the two tests that assert the current `NotImplementedError` placeholder behavior.

## Finding

Both classes are intentionally incomplete placeholders. Implementing them now would require
choosing unapproved answers for at least state ownership, surface scope, authorization and
Step-Up requirements, audit semantics, persistence/availability storage, failure behavior, and
token emergency operations. Deleting them would also be an internal API retirement decision, even
though no current in-repository caller was found.

Therefore this is classified as `NEXT_CYCLE / CONTRACT_UNDEFINED`, not as an implementation that
can be safely completed by guessing. The existing placeholder code and its characterization tests
were left unchanged. No production behavior was weakened or removed.

## Reproduction

With the current Rails test environment, the public calls are expected to raise the explicit
placeholder error:

```text
OutageService.update! -> NotImplementedError
TokenEmergencyService.call! -> NotImplementedError
```

A future implementation requires an approved contract and public behavior tests before changing
either class or deleting its characterization tests.
