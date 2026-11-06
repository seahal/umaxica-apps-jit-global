# O-10 social callback lock trace

Date: 2026-11-04

## Scope

Read-only trace of APP Auth's Google / Apple callback branches that appeared in the OP/principal
lock candidate scan.

## Observed result

Existing-account login delegates to `AuthenticationSessionCommitter` and then the standard
`establish_signed_in_session!` path, which acquires the Client before OP sign-in writes. A pending
social signup branch creates an unbound `ClientSignUpFlow` while holding its admission-binding lock,
then locks the Auth ceremony and OP Flow; that branch has no existing Client row to acquire. Link
callbacks redirect to the settings owner. No reverse actor / OP row-lock edge was found in these
direct branches. This bounded trace does not prove unrelated callbacks or indirect callbacks safe.

The reproducible lexical intersection remains 88 candidate files. The inventory now names 17 by full
path and leaves 71 unnamed. This count is triage, not a defect count.

## Evidence and limits

- Inspected `app/controllers/auth/app/omniauth/omniauth_callbacks_controller.rb:245–370,474–505`,
  `app/services/sign_up_cycle_locator.rb:80–108`,
  `app/operations/authentication_session_committer.rb:14–16`, and
  `app/controllers/concerns/authentication_base.rb:405–425`.
- Recomputed candidate and named-path totals from the inventory's recorded search expressions.
- No tests, application code, or databases were changed or accessed.

HEAD: `b30345216886c98af1f04cbd434f067f12decf01`. The worktree was extensively uncommitted; this
read-only source trace was against the worktree content.
