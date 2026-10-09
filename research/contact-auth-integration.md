# Contact Auth Integration Note

## Status

Accepted implementation note for the contact/auth integration track.

## Scope

This note records the implemented contact/auth contract and the controller boundary that now
consumes it.

## Implemented contract

- `com` stays guest-only for contact submission.
- `app` contact uses the canonical user actor context.
- `org` contact uses the canonical staff actor context.
- `customer` is the canonical subject name for `com` auth state.
- Contact requests read auth-derived contact data through a shared context object instead of
  duplicating lookup logic in each controller.

## Implementation shape

- `Contact::ActorContext` resolves canonical email and telephone values for `user`, `staff`, and
  `customer`.
- `Core::App::ContactsController` and `Core::Org::ContactsController` consume that shared context
  for prefill, validation, persistence, and event logging.
- The `com` contact flow remains public and does not depend on authenticated contact state.

## Verification

- Cookie and host boundary checks were added for the contact surfaces.
- Shared contact context tests cover `user`, `staff`, and `customer`.
- The Rails test harness still has a separate existing `i18n_locale_reset` / document schema issue
  that blocks full `rails test` runs in this workspace.
