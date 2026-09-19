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
| W1  | Preference bootstrap              | Preference transport        | Create the shared surface preference parent row when no valid preference credential exists.                                  | Yes                           | app/com/org preference lifecycle                                                                   |
| W2  | Preference bootstrap children     | Preference transport        | Create default child rows for language, region, timezone, theme, cookie, and display options.                                | Yes                           | app/com/org preference lifecycle                                                                   |
| W3  | Preference token issue            | Preference transport        | Store preference token metadata needed to validate the freshly issued access or refresh token.                               | Yes                           | app/com/org preference lifecycle                                                                   |
| W4  | Preference refresh rotation       | Preference transport        | Rotate a valid preference refresh token and issue a new preference access token.                                             | Yes                           | app/com/org preference lifecycle                                                                   |
| W5  | Preference refresh lifetime touch | Preference transport        | Extend or update refresh-token lifetime metadata after a valid refresh lookup.                                               | Yes                           | app/com/org preference lifecycle                                                                   |
| W6  | Logged-in edit entry refresh      | Preference edit entry       | Copy actor-local DB preference values into the current surface preference before rendering a preference edit screen.         | Yes                           | logged-in HTML preference edit only                                                                |
| W7  | Preference edit child bootstrap   | Preference edit entry       | Create missing option child rows when an existing preference parent enters an edit screen.                                   | Yes                           | preference edit screens only                                                                       |
| W8  | Preference explicit update        | Preference write endpoint   | Persist an intentional preference update from PATCH/PUT/DELETE/POST.                                                         | No                            | non-GET preference endpoints                                                                       |
| W9  | Preference reset/rebootstrap      | Preference reset endpoint   | Retire or replace the current shared preference and rebootstrap a fresh preference.                                          | No                            | explicit reset/delete endpoint                                                                     |
| W10 | Cookie consent write              | Web/API preference endpoint | Persist cookie-consent flags and reissue preference token state.                                                             | No                            | Core `/api/v0/preferences/cookie`, legacy non-Core `/web/v0/cookie`, and preference cookie screens |
| W11 | Theme write                       | Web/API preference endpoint | Persist theme choice and reissue preference token state.                                                                     | No                            | Core `/api/v0/preferences/theme`, legacy non-Core `/web/v0/theme`, and preference theme screens    |
| W12 | Login-time adoption               | Authentication lifecycle    | Sync shared App/Org/Com preference values with Client/Operator/Visitor local preference values.                              | No                            | successful login/adoption flow                                                                     |
| W13 | Com/Visitor adoption              | Authentication lifecycle    | Sync shared Com preference values with Visitor local preference values, symmetric with App/Org adoption.                     | No                            | successful login/adoption flow                                                                     |
| W14 | Auth transparent refresh          | Authentication lifecycle    | Rotate auth refresh state and issue fresh auth cookies when an HTML request has a valid refresh cookie but no access cookie. | Yes                           | authenticated HTML lifecycle                                                                       |
| W15 | Auth session activity touch       | Authentication resolver     | Throttled `last_used_at` update on the token/session row.                                                                    | Yes                           | authenticated request resolver                                                                     |
| W16 | OIDC callback                     | Protocol callback           | Exchange code, create or update local session/token state, and complete callback lifecycle.                                  | No                            | OIDC callback endpoints                                                                            |
| W17 | Social/auth callback              | Protocol callback           | Complete external login callback state and create or update local session/token state.                                       | No                            | social/OIDC ceremony callbacks                                                                     |
| W18 | Maintenance or repair task        | Explicit operator task      | Repair, admin, or maintenance writes performed outside ordinary read-only request handling.                                  | No                            | explicitly invoked tasks only                                                                      |

## CI Direction

Future CI should subscribe to SQL and fail `GET`/`HEAD` request tests when `INSERT`, `UPDATE`, or
`DELETE` appears outside this allowlist. A new write path must update this document before the test
allowlist expands.

The allowlist is intentionally behavioral. It does not grant permission to move writes into generic
controller setup, to repair broken JWTs from the database on normal reads, or to introduce hidden
state changes behind read-only routes.
