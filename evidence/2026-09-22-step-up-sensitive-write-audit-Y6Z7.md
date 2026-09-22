# Sensitive-write Step-Up inventory revalidation

- Date: 2026-09-22 UTC
- Repository HEAD: `277673d13547d722fc88f830711eee69b923a7e8`
- Branch: `feature`
- Worktree: pre-existing modified and untracked files were preserved; no reset, clean, commit,
  GitHub write, deployment, production/shared database mutation, or external provider call was
  performed.
- Scope: current-tree revalidation of the remaining sensitive-write inventory associated with
  issue #884.

## Established Step-Up gates found

The current controller and concern graph contains the accepted session-bound Step-Up gates for:

- direct secret-credential create/edit/update/destroy on app, com, and org, including the
  bootstrap exception only at setup entry;
- the app MFA reset action;
- direct and compatibility secret-removal routes;
- email and telephone credential changes through the existing verification/Step-Up flow;
- passkey and TOTP configuration through the existing verification flow;
- social-link operations and withdrawal, where the existing ceremony/verification path is the
  authority;
- revoke-all sessions on app, com, and org with the `session_revoke_all` scope on both routed
  mutation aliases.

The revoke-all and secret-removal gates are explicit in the current controllers. The inherited
`VerificationBase` path also runs before authorization on the Base surface and rejects an
Emergency authentication context before a Step-Up credential is requested.

## Candidate paths reviewed

Individual session revocation is intentionally distinct from revoke-all. The accepted assurance
documentation requires Step-Up for revoke-all; the current single-session action only revokes a
selected session and therefore was not changed based on issue wording alone.

Privacy erasure and withdrawal are protected by their own withdrawal ceremony, policy, and
ceremony-bound subject checks. They are not silently converted into a generic Step-Up requirement
because that would change the approved recovery/lifecycle contract.

The app, com, and org organization-membership controllers currently expose placeholder actions:
the create/update actions return an unprocessable response and the destroy actions do not perform a
state transition. They are not evidence of an unguarded live membership mutation. Adding a
Step-Up callback to a placeholder would not implement the missing membership policy.

The app group and group-avatar-membership JSON endpoints do perform local mutations and do not
declare a generic Step-Up scope. The repository's accepted Step-Up scope catalog does not define a
group or avatar-membership scope, and the current emergency-access contract treats the app group
surface separately from the org Emergency session. Their exact assurance classification remains an
open policy/inventory item for #884; this review does not invent a scope or add a weaker generic
gate.

## Disposition

No additional Step-Up controller change is justified by the currently accepted contract and the
repository evidence reviewed here. The remaining #884 work is a complete product-owned sensitive-
operation matrix, including an explicit decision for group/avatar membership mutations. That is
different from a confirmed missing guard in the already-defined credential, withdrawal, social,
MFA, or revoke-all paths.

The current non-Compose shell still cannot run Rails database-backed tests: `primary` and
`valkey-kvs` are not resolvable. This is recorded as an environment verification limitation, not
as evidence that the reviewed Step-Up behavior is correct or incorrect. The Compose-backed focused
results recorded in the earlier Step-Up evidence remain the applicable runtime evidence until the
current dirty HEAD is rerun in the core service.

No CSRF, authentication, authorization, verification, rate-limit, or emergency-context control
was weakened or bypassed during this review.
