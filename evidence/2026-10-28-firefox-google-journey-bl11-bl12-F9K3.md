# Firefox Google Journey: BL-12 and BL-11 Observed, Sign-up and Sign-in Completed

Date: 2026-10-28. Commit: `b6e7871073bdc43a55fc5f05e8476de8ee71252f`. Development database freshly
rebuilt by the owner (`bin/rails db:migrate:reset`, `bin/rails db:seed`), so no app account existed at
the start. The worktree held uncommitted changes unrelated to these paths (compose aliases, Base ORG
translation keys, the Switch admission N+1 fix, the app sign-up link label).

## What was done

The owner used Firefox on the development server with one Google account and reported having had to
delete cookies to get through. Claude read `log/development.log`.

## Observed, in order

1. Google **sign-in** with the not-yet-registered account: `OmniauthCallbacksController#omniauth`
   raised `SocialAuth::UnauthorizedError`, logged `social_auth.intent.invalid` (`intent_invalid`) and
   `sign.refused` `definitive` / `intent_crossing`, and returned 400 ("無効なリクエストです。").
2. Google **sign-up** with the same account: `Social::RegistrationsController#create` → callback
   (`handle_pending_social_sign_up_intent`) → `Sign::Up::Guard::GooglesController#show` →
   `Sign::Up::Check::Google::ConfirmationsController` (show, update) →
   `Sign::Up::Check::Google::BirthdatesController` (show, update) → `Sign::In::ChecksController#show`
   → `Sign::OidcHandoffsController#show` → `Visa::App::Oidc::ResultsController#show` → Base signed in.
3. Sign-out from Base: `Base::App::SignOutsController` (new, edit, create) → Visa logout confirmation
   → Base sign-out completion, all successful.
4. New sign-in started from Base in the same browser: admission, binding confirmation and redemption
   succeeded, then `Auth::App::Sign::InsController#show` returned **409** twice with `sign.refused`
   `ownership_mismatch` / `missing_binding`, then 400 (after the owner removed cookies, the clean
   entry had no admission).
5. Fresh start after the cookie removal: Google sign-in → callback completed → checks → OIDC handoff →
   Visa result → Base OIDC callback, token and UserInfo → Base dashboard, all successful.

An unrelated `Base::Com::RootsController#index` 406 also appears in this window.

## Result

- BL-12 confirmed: Google sign-in with an unregistered account ends in the uniform `intent_crossing`
  400; after Google sign-up, the same account signs in successfully (step 5).
- BL-11 reproduced: after a completed sign-in and a sign-out, the next sign-in in the same browser is
  refused with 409 `missing_binding` until Auth cookies are removed.
- Google sign-up and sign-out completed end to end on the rebuilt database.

Limits: one manual run in Firefox; DB rows were not inspected; Apple was not exercised.
