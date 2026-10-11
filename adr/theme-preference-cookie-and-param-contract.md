# Theme Preference Cookie And Param Contract

## Status

Accepted on 2026-04-07.

## Context

GitHub issue `#632` tracked the final theme preference UI and the cookie/query contract across
surfaces. The remaining ambiguity was whether the public contract should keep the short theme key
`ct` or move to a longer `theme` key.

## Decision

The theme contract remains `ct`.

The application uses `ct` consistently in:

- preference JWT payloads
- query parameter propagation
- the theme cookie
- web theme endpoints

Theme edit/update flows exist on `app`, `org`, and `com`, and the shared UI exposes explicit
`light`, `dark`, and `system` options.

## Evidence

- `app/controllers/concerns/preference/io_keys.rb` defines the cookie key contract and keeps theme
  as `ct`.
- `test/controllers/concerns/preference/io_keys_test.rb` asserts the contract directly.
- `test/controllers/concerns/preference/base_test.rb` and
  `test/controllers/concerns/preference/jwt_and_color_theme_test.rb` assert
  `Preference::Base::THEME_COOKIE_KEY == "ct"`.
- `test/integration/sign_preference_test.rb` verifies for `app`, `org`, and `com` that:
  - stored default theme initializes the `ct` payload and cookie
  - theme updates persist through the sign preference UI
- `test/integration/preference_global_param_context_test.rb` verifies `ct` propagation rules in
  navigation and internal links.
- Theme UI and update endpoints exist for all sign surfaces:
  - `app/views/sign/shared/preference/_theme_form.html.erb`
  - `app/controllers/sign/app/preference/themes_controller.rb`
  - `app/controllers/sign/org/preference/themes_controller.rb`
  - `app/controllers/sign/com/preference/themes_controller.rb`

## Consequences

- `ct` is the accepted stable key for theme preference transport.
- Any future migration to a longer name would require an explicit compatibility plan because the
  short key is now relied on across UI, cookies, links, and tests.

## Current Operational Clarification

`ct` may appear as optional request-local context and may be propagated in URLs when explicitly
present and valid. It is not a preference write path. Persistent theme changes must go through the
dedicated preference write endpoints, which update the database and reissue the preference access
token.

Rails may write the `ct` cookie as a browser/UI compatibility mirror, but Rails request code must
not trust JS-readable preference cookies as preference input.

## Related

- Related contract: `adr/localization-preference-flow.md`
