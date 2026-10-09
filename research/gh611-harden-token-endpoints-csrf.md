# GH-611: Harden Sign Token Endpoints and Remove null_session CSRF Exception

GitHub: #611

`Sign::App::TokensController`, `Sign::Org::TokensController`, and `Sign::Com::TokensController` now
inherit from `Sign::TokenEndpointController`.

The shared base is an `ActionController::API` controller. It accepts JSON requests only, renders the
token exchange response directly, and does not rely on browser session state or CSRF session
mutation. The token exchange logic still lives in `Oidc::TokenExchangeService`.

Regression coverage now includes:

- success and failure paths for app, org, and com token endpoints
- `CustomerToken` issuance for the com flow
- rejection of non-JSON browser-style requests

This replaces the earlier `protect_from_forgery with: :null_session` approach with an explicit
protocol endpoint base.
