# N1 Reproduced by Hand: Cancel Accepted After an App Passkey Challenge

Date: 2026-10-28. Commit: `b6e7871073bdc43a55fc5f05e8476de8ee71252f`. The worktree held uncommitted
changes outside this path (compose aliases, Base ORG translation keys, the Switch admission N+1 fix,
the app sign-up link label).

## What was done

The owner, in a browser on the development server, started an app sign-in from the Base self-RP
(`www.umaxica.app`), kept the first Auth sign-in page open in one tab, moved to the Passkey sign-in in
a second tab of the same browser and requested options, then pressed Cancel on the first tab. The
owner believed the defect had not reproduced. Claude read `log/development.log`.

## What the log shows (in order)

1. `Auth::App::Sign::In::PasskeysController#new` — 200.
2. `Auth::App::Sign::In::Passkey::OptionsController#create` — 200 (a Passkey challenge was issued).
3. `Auth::App::Sign::CancellationsController#create` — **303**, redirected through Jump to
   `visa.umaxica.app/oidc/cancellation`.
4. `Visa::App::Oidc::CancellationsController#show` — 303 (twice), then Jump.
5. `Base::App::Oidc::CallbacksController#show` with `error=access_denied` — 303 to
   `/sign/interruption`.
6. `Base::App::Sign::InterruptionsController#show` — 200.

No `not_on_first_page` refusal appears between step 2 and step 3.

## Result

The defect reported as N1 in `one.md` appendix C reproduced: after a Passkey challenge was issued for
the admitted ceremony, the first-page Cancel was still accepted and the OIDC request ended with
`access_denied`. The owner's browser showed the Base interruption page, which looks like a normal
outcome and is why the reproduction was not recognised in the browser.

Limits: one manual run on the app surface; DB state (ceremony `cancelled_at`, parent status) was not
inspected; Switch, ORG Entra (N2) and the N3 continuity loss were not exercised.
