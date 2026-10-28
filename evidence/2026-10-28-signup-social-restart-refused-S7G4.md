# App Sign-up Social: Second Provider Start Refused After Returning From Google

Date: 2026-10-28. Commit: `b6e7871073bdc43a55fc5f05e8476de8ee71252f`. The worktree held uncommitted
changes, among them the owner's development database rebuild (`bin/rails db:migrate:reset` and
`bin/rails db:seed`), whose rewritten `db/*_structure.sql` dumps do not affect this runtime result.

## What was done

On the development server the owner opened app Sign Up (`/sign/up?ri=jp`) from an OIDC request,
pressed Google, returned from the provider page with the browser, and pressed Google again. The
browser showed "無効なリクエストです。". Claude read `log/development.log` and the development
database.

## Observed

1. `Auth::App::Social::RegistrationsController#create` — 307 to the provider.
2. `Auth::App::Sign::UpsController#show` — 200 (the Sign Up page is shown again after returning).
3. `Auth::App::Social::RegistrationsController#create` — 400, with
   `sign.refused` `refusal_class: definitive`, `reason_code: phase_violation`.

`ClientSignUpFlow` in the development database: one row, `status_id: 36`, `step: social_callback`,
`entry_method: google`, created at the time of step 1, before any provider callback.

## Result

This confirms the static reading recorded in `one.md`: app Sign Up creates the Sign-up Flow and
advances it to the social-callback step when the provider button is pressed
(`AppSocialCeremonyEntry#issue_sign_up_flow!`), and the one-Flow-per-admission rule
(`app_social_ceremony_entry.rb:65-69`, previous cycle D-198 (3)) then refuses a second start.

Limits: one manual run; the Cancel/Switch visibility on the returned page and an Email or Telephone
registration after returning were not exercised.
