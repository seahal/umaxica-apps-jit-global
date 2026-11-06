# O-9 source-owner boundary review

Date: 2026-11-05

Commit: `b30345216886c98af1f04cbd434f067f12decf01`

The worktree had extensive uncommitted changes that affected the inspected contract and source.

## Work performed

- Read the 2026-11-04 16:00 O-9 owner decision in `zero.md`, the revision 13 O-11 ownership
  contract, and `specs/op-mediated-step-up/contracts/o9-visa-roundtrip-design.md`.
- Confirmed the current passkey source writer is `IdentityPasskeyRegistrationFinalCommitter`, called
  by `Base::App::Verification::CompletionsController`.
- Confirmed `Auth::App::Social::LinkCompletionsController` owns the APP social-link completion path
  and calls `ExternalAuthenticationLinkUseCase`.
- Traced the current APP social-link lock boundary: the controller locks Client, consumes the
  candidate and grant in an OP transaction, then closes that transaction before the App principal
  transaction commits the link. The current unlink path keeps its OP transaction around the source
  use case but still depends on the legacy root-token proof.
- Updated the O-9 design to make the source owners and the missing O-10 owner-side commit handoff
  explicit. Visa's browser callback must not be treated as the source write or as authority to write
  on behalf of either owner.
- Updated `specs/op-mediated-step-up/contracts/lock-order-inventory.md` to record the distinct link
  and unlink lock/commit boundaries.
- Kept O-9 endpoint and route integration disconnected. The owner-specific handoff, durable result
  receipt, and required `secret_digest` column disposition remain for review.
- Rechecked `five.md` at SHA-256 `ab191cb1d6d1099dbf38d6c4c85faa68b5850733ba3483e9e2425860d211ab45`.
  The C9 closed slices are already implemented; unresolved C5 items remain outside C0's
  implementation boundary. No new five-specific dilemma was found.

## Verification

- No tests were run; this was a source and design review.
- No routes, controllers, persistence, or databases were changed; only the O-9 design and lock-order
  documentation were updated.
- No-index whitespace checks of the untracked design and evidence files emitted no errors.

The broader O-10 lock graph remains incomplete: the inventory names 88 lexical candidates but is not
an exhaustive interprocedural proof. The Q-1, contact-registration, O-10 registration-receipt, and
Support session-revocation contracts remain proposals without required shape approval.
