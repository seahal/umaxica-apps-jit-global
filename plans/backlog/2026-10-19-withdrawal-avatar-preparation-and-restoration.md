# Avatar Preparation and Restoration on Withdrawal

Recorded 2026-10-19. Deferred out of the three.md cycle by user decision.

## Current state

- Withdrawal does not suspend or restore Avatars automatically. Existing Avatar lifecycle rules do
  not let a normal owner perform `active -> suspended`.
- Ownership periods, memberships, assignments and transfers are separate contracts.

## Decision needed

- Which authority suspends an Avatar during withdrawal.
- Treatment of exclusively owned, shared and in-transfer Avatars.
- Whether and how recovery restores Avatar/Persona rights without undoing bans, admin stops or
  changed ownership.

## Affected

three.md U09/U10; two.md REQ-W02, REQ-W10; four.md AC-W01/W02, AC-W13, AC-V01-AC-V05; six.md.
