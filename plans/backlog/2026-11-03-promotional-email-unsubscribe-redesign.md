# Promotional Email Unsubscribe Screen Redesign

Date: 2026-11-03

Status: Backlog. Raised by the owner while planning the notification settings page
(`plans/backlog/2026-11-03-signed-in-preference-behavior-review.md`). Not investigated; nothing
below has been run or verified at runtime.

## Current shape (source reading only)

- `Base::App::Preference::EmailsController` (and the ORG counterpart) is a bare endpoint
  (`AUTHENTICATION_MODE = :bare`) reached from an email with a signed token, not a session. It
  includes `PromotionalEmailUnsubscribeActions` and renders an Inertia unsubscribe page from the
  token's email.
- Routes in `config/routes/base.rb` (around l.58-60): `resources :emails, only: :edit`, plus
  `delete "emails/:id"` and `post "emails/:id"`. The last two do not follow the resourceful routing
  policy.
- It lives under `preference`, although it is not part of the Preference write pipeline.

## Owner concerns

- The owner considers the screen likely broken; it needs a redesign, not a patch.
- Where it belongs: Base, or Auth. It handles an email address identified by a signed token, which
  is closer to identity/contact handling than to display preferences.
- It stays separate from the planned notification settings page.

## To decide in the redesign

1. Owning surface (Base or Auth) and route shape under the resourceful policy.
2. Token contract: signer, lifetime, single use or reusable, what the token identifies (email
   address, contact record, actor), and behavior for expired, tampered or replayed tokens.
3. What unsubscribe changes and where it is stored (the contact record in zenith, a suppression
   list, or Preference), and its audit record.
4. Behavior for signed-in and signed-out visitors, and CSRF/Origin handling for a token-only POST.
5. Relation to RFC 8058 one-click unsubscribe (`List-Unsubscribe-Post`) if promotional mail is sent.

## First step

Reproduce the current flow in development (send or construct a promotional email token, open the
edit screen, unsubscribe, resubscribe) and record what breaks in `evidence/` before designing.
