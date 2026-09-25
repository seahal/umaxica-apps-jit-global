# DB Write Allowlist

## Purpose

Normal `GET` and `HEAD` requests should be read-only unless the write is an explicit lifecycle
exception. This allowlist records the current accepted exceptions so future CI can fail any
unreviewed `INSERT`, `UPDATE`, or `DELETE` observed during read-only request tests.

The database remains the source of truth. JWTs are projections or runtime credentials, not an
authority to invent new state.

## Current Allowlist

| ID  | Classification                    | Request phase               | Expected write                                                                                                               | GET/HEAD lifecycle exception? | Current scope                                                                                      |
| --- | --------------------------------- | --------------------------- | ---------------------------------------------------------------------------------------------------------------------------- | ----------------------------- | -------------------------------------------------------------------------------------------------- |
| W8  | Preference explicit update        | Preference write endpoint   | Persist an intentional preference update from PATCH/PUT/DELETE/POST.                                                         | No                            | non-GET preference endpoints                                                                       |
| W9  | Preference reset/rebootstrap      | Preference reset endpoint   | Retire or replace the current shared preference and rebootstrap a fresh preference.                                          | No                            | explicit reset/delete endpoint                                                                     |
| W10 | Cookie consent write              | Web/API preference endpoint | Persist cookie-consent flags and reissue preference token state.                                                             | No                            | Core `/api/v0/preferences/cookie`, legacy non-Core `/web/v0/cookie`, and preference cookie screens |
| W11 | Theme write                       | Web/API preference endpoint | Persist theme choice and reissue preference token state.                                                                     | No                            | Core `/api/v0/preferences/theme`, legacy non-Core `/web/v0/theme`, and preference theme screens    |
| W12 | Login-time adoption               | Authentication lifecycle    | Sync shared App/Org/Com preference values with Client/Operator/Visitor local preference values.                              | No                            | successful login/adoption flow                                                                     |
| W13 | Com/Visitor adoption              | Authentication lifecycle    | Sync shared Com preference values with Visitor local preference values, symmetric with App/Org adoption.                     | No                            | successful login/adoption flow                                                                     |
| W16 | OIDC callback                     | Protocol callback           | Exchange code, create or update local session/token state, and complete callback lifecycle.                                  | No                            | OIDC callback endpoints                                                                            |
| W17 | Social/auth callback              | Protocol callback           | Complete external login callback state and create or update local session/token state.                                       | No                            | social/OIDC ceremony callbacks                                                                     |
| W18 | Maintenance or repair task        | Explicit operator task      | Repair, admin, or maintenance writes performed outside ordinary read-only request handling.                                  | No                            | explicitly invoked tasks only                                                                      |

The former W1-W7 preference GET writes and W14-W15 authentication GET writes were removed from the
allowlist on 2026-09-25 after checking the current request lifecycle. `set_preferences_cookie`
returns through read-only preference loading for `GET`/`HEAD`; `transparent_refresh_allowed?`
rejects browser navigation; and authenticated session activity tracking defaults off for
`GET`/`HEAD`. The preference transport and authentication refresh records are changed only at their
explicit write endpoints. W16-W17 remain separate protocol-callback write boundaries.

## CI Direction

Future CI should subscribe to SQL and fail `GET`/`HEAD` request tests when `INSERT`, `UPDATE`, or
`DELETE` appears outside this allowlist. A new write path must update this document before the test
allowlist expands.

The allowlist is intentionally behavioral. It does not grant permission to move writes into generic
controller setup, to repair broken JWTs from the database on normal reads, or to introduce hidden
state changes behind read-only routes.
