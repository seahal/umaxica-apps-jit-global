# R5-WU06 identity stop and issuance serialization

Date: 2026-10-17 UTC. HEAD `17903f7d121aa33efe29f2db9235c9aa5db4b001`; uncommitted worktree.

## Change

- Migrations (3 OP stores, `20261017070000`): `authentication_epoch` on roots
  (`client_tokens`/`visitor_tokens`/`operator_tokens`) and grants (`op_*_grants`), nullable for
  pre-R5 history, check `>= 0`. Applied to development and isolated fleet `20261017c1a2`.
- Issuance stamps: roots (`AuthenticationBase#create_login_token_record`) and grants
  (`OidcTokenExchangeCoordinator#create_or_resolve_active_usage!`) record actor
  `authentication_epoch` and the OP `contract_epoch` (`Op*ProtocolEpoch.current_contract_epoch`).
- Lock order (section 7.5): Code exchange locks the canonical actor before device/root locks;
  Refresh passes an `actor_guard` so `OidcRefreshTokenIssuer` locks the actor before OP row locks.
  Issuance is refused when the actor epoch advanced past the root's, or when a root without a
  recorded epoch meets an actor whose epoch is no longer 0.
- Stop writers: `WithdrawalLifecycle#suspend!/terminate!`, `AdministrativeAccessLock#lock!`,
  `OrgOperatorLifecycleExecute` (withdraw/suspend/terminate) now call
  `IdentityAuthenticationStopRecorder` inside the actor transaction (epoch + Zenith event) and,
  after commit, `OpIdentityEventInvalidator.deliver` (dedup inbound receipt, revoke roots with epoch
  < cutoff through the existing OP logout path; on DB failure enqueue `OpIdentityEventDeliveryJob`).
  Method-scoped enforcement revocation and emergency session revoke keep their existing OP-only
  semantics.
- OP structure dumps for the three realms were regenerated from the migrated isolated fleet
  (overwriting the earlier uncommitted dumps; all tables including R5-WU02 ones are present).

## Results

- `OidcTokenExchangeCoordinatorTest` + `OpIdentityEventInvalidatorTest`: 105 runs, 0 failures.
  Covers stamp values, refresh continuing at equal epoch, refusal after stop, unrecorded-epoch rule,
  older-only revocation, delayed event not revoking a post-recovery root, dedup, retry job.
- Withdrawal/access-lock/operator-lifecycle tests (7 files): 60 runs, 0 failures.
- Not done: Base Self-RP reissue path does not pass an actor guard; Mermaid/inventory docs for the
  identity stop axis not yet updated; full suite not re-run after this packet.
