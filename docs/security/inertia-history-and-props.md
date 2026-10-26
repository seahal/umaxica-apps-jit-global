# Inertia History and Page Props

This document records the security rules for what an Inertia page leaves in the browser: the history
entries that hold page props, and the props themselves. `adr/inertia-rails-thin-adapter.md` makes
history encryption mandatory and leaves history clearing and page-prop content to this document.

## Why history needs clearing

Inertia stores each visited page object, props included, in the tab's history so Back can restore
the page without a server request. `encrypt_history` is on globally, but the key that decrypts the
entries lives in the tab's `sessionStorage`. `reset_session`, cookie deletion, session revocation
and `Cache-Control: no-store` do not reach that key, so a same-tab Back after a session ends can
restore the signed-in page from history. Only `clearHistory: true` on a rendered Inertia page, or
`Clear-Site-Data` with `"storage"`, discards the key.

## When history must be cleared

Every response that ends or changes the browser's authenticated state, and every one-time display of
a secret, must end on a page that clears history:

| Event                                                                                  | Mechanism                                                                               | Owner                                                                                                                 |
| -------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------- |
| Root login establishment                                                               | `session[:inertia_clear_history]` after a successful `log_in`                           | `AuthenticationBase#log_in`                                                                                           |
| Detached stale credentials, ended sessions                                             | `reset_session_and_clear_inertia_history!`                                              | `AuthenticationLogoutable`, `AuthenticationBase`                                                                      |
| Visa OP logout (completion and failures after the authority COMMIT)                    | `clear_history: true` on the Inertia result page                                        | `visa/{app,com,org}/oidc/logouts_controller.rb`                                                                       |
| Base RP sign-out (completion, cleanup incomplete, indeterminate)                       | `clear_history: true` on the Inertia result page                                        | `BaseSignOutDestination`                                                                                              |
| Warp, Palm and Auth sign-out pages                                                     | Session flag and redirect to root (Warp); `clear_history: true` (`SignOutInertiaPages`) | Surface sign-out controllers                                                                                          |
| Non-Inertia completion pages (Core, Edit, Tech, Palm completion)                       | `Clear-Site-Data: "cache", "storage"`                                                   | `SignOutClearSiteData`                                                                                                |
| Withdrawal deactivation, ceremony session end and termination                          | `session[:inertia_clear_history]` before the redirect                                   | `BrowserRpAuthentication#clear_browser_rp_cookies!`, `WithdrawalCeremonyAuthentication`, `BaseSettingsWithdrawalFlow` |
| One-time secret display, Step-Up completion and cancellation, session-limit resolution | `session[:inertia_clear_history]`                                                       | The owning controllers and concerns                                                                                   |

Ordinary navigation must not clear history; doing so would break Back for every page.

## The session flag survives only redirects

`session[:inertia_clear_history]` is read by the next Inertia render, either explicitly or through
the inertia_rails default for `clear_history`. The inertia_rails middleware deletes the flag on
every non-redirect response, including plain HTML pages. A flag set before an HTML page is therefore
lost before any Inertia page renders. A terminal page that must clear history is either an Inertia
page with `clear_history: true`, a redirect that carries the flag to such a page, or an HTML page
that sends `Clear-Site-Data` with `"storage"`. `Clear-Site-Data: "storage"` also unregisters service
workers, so it is used only on surfaces that register none they must keep.

## Page props are public to the page viewer

Inertia embeds the whole page object in the HTML (`use_script_element_for_initial_page`) or in the
JSON body of an Inertia visit. Every prop is readable in the page source, whether or not the page
displays it, and is stored in history until cleared. Props must therefore:

- contain only the fields the page displays or needs to act, built field by field rather than by
  serializing a record (`as_json`, `attributes` and similar);
- expose public references (`public_id`) rather than internal database identifiers;
- never carry tokens, credential digests, hashes, keyed proofs or another actor's data;
- keep shared props (`inertia_share`) free of personal data, because every page of the surface
  carries them;
- be built only after the page's authorization, so an unauthorized request never receives them.

A secret shown once (for example an issued App Secret) may be a prop only on its one-time display
page, which clears history.

## Development tooling

The inertia_rails DevTools recorder stores request URLs and props, redacting only a fixed key list.
`config/initializers/inertia_rails.rb` pins it to development, ignoring `INERTIA_DEVTOOLS_ENABLED`
in every other environment.

## Verification

- `test/integration/sign_out_inertia_history_clear_test.rb`: Warp, Palm and failed Base origin
  cleanup on each realm.
- `test/integration/oidc_rp_logout_registered_rp_matrix_test.rb`: Base cleanup-incomplete and
  indeterminate pages for every registered Browser RP.
- `test/controllers/base/{app,com,org}/sign_outs_controller_test.rb` and
  `test/controllers/concerns/authenticated_response_cache_policy_test.rb`: Base sign-out and
  ordinary navigation.
- `test/controllers/base/{app,com}/identity/withdrawals_controller_test.rb` and
  `test/integration/withdrawal_ceremony_session_test.rb`: withdrawal events.
- `test/lib/runtime_role_route_ownership_test.rb`: DevTools routes are unreachable outside
  development.

A full audit of page props is open in `plans/backlog/2026-10-20-inertia-props-exposure-audit.md`.
