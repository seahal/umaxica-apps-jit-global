# Handoff Acceptance Checklist (Manual, Development)

Date: 2026-11-06. Owner operates the browser; Claude Code reads `log/development.log` and
`log/development.access.jsonl` after each step and records the result here. Codex keeps working
on `plans/2026-11-07-machine-handoff-closure.md` in parallel. This checklist covers behavior changed
on 2026-11-03..06; it is not the two.md or five.md acceptance matrix.

Run each step on APP (`umaxica.app`) and, where marked, ORG (`umaxica.org`). Start from a browser
with this site's cookies and site data cleared once (old Auth service workers included), then do
not clear them again unless a step says so. Result: OK / NG (with log trace id) / Not run (reason).

## A. Sign-in and session

| ID | Step | Expected | APP | ORG |
|---|---|---|---|---|
| A-1 | Base top → sign in with email OTP | OTP mail arrives; code accepted; lands on `/selector` or `/dashboard` | | n/a |
| A-2 | Sign out, then sign in again in the same browser without clearing cookies | No "この画面は古くなっています" (409); method page shows | | |
| A-3 | Open sign-in, abandon at the OTP page, start sign-in again from Base | New sign-in proceeds; no 409 | | |
| A-4 | ORG sign-in (passkey or Entra as configured) | Lands on `/selector` or `/dashboard` | n/a | |
| A-5 | Google sign-in, twice in a row (sign out between) without clearing cookies | Both succeed; no `csrf_detected` | | n/a |

## B. Persona selection

| ID | Step | Expected | APP | ORG |
|---|---|---|---|---|
| B-1 | After sign-in with several personas, choose one on `/selector` | `/dashboard` shows the chosen persona name and avatar | | |
| B-2 | Browser Back to the selector page and submit again | Goes to `/switcher`; the selection does not change | | |
| B-3 | Switch persona or avatar on `/switcher` | Dashboard reflects the new choice | | |
| B-4 | Open `/` while signed in | 403 page (by design); `/dashboard` works | | |

## C. Identity hub and step-up

| ID | Step | Expected | APP | ORG |
|---|---|---|---|---|
| C-1 | Open `/identity`; follow every link once | No 404/500; ORG shows the MFA reset link | | |
| C-2 | Start a protected action (e.g. passkey removal, Security Mode change) | Step-up: Base → Visa → Auth method choice → Visa → back to the target | | |
| C-3 | Repeat C-2 within the step-up window | No second step-up prompt | | |
| C-4 | Email or telephone registration from `/identity` | Currently refused with a localized 503 (O-12 interim); no 500 | | |
| C-5 | Social identities page `/identity/social_identities` | Read-only status shown | | |

## D. Sign-up and OTP

| ID | Step | Expected | APP |
|---|---|---|---|
| D-1 | Sign up with a new email address | OTP arrives; birthdate step; account created | |
| D-2 | Sign up with an already registered email (the 2026-11-05 incident) | Same "OTP sent" screen; no OTP mail arrives; any code is refused; no 500 | |
| D-3 | Sign up with a new telephone number | SMS OTP (development delivery) arrives; completes | |
| D-4 | Sign up with an already registered telephone number | Same screen; no SMS; any code refused; no 500 | |

## E. Sign-out

| ID | Step | Expected | APP | ORG |
|---|---|---|---|---|
| E-1 | Sign out from Base | Signed out on Base; returning to `/dashboard` asks to sign in | | |

## Not covered here

O-9 social link start and passkey registration through Visa (not connected), the cookie migration
(`specs/browser-flow-state-cookies`, not implemented), withdrawal/erasure/recovery (backlog), and
Edge/Jump/Away (two.md WU-E).
