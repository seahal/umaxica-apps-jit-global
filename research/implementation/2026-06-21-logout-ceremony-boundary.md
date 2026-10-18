# Logout ceremony boundary implementation note

Implemented a surface-local logout ceremony across Acme, Sign, Core, and Base:

- `GET /sign/out/new` redirects to `GET /sign/out/edit`.
- `GET /sign/out/edit` renders shared confirmation HTML.
- `POST /sign/out` is direct Acme logout on Acme surfaces and RP launcher on Sign/Core/Base.
- `GET /sign/out/complete` renders a session-bound completion page and consumes a one-time marker.
- `GET/POST /oidc/logout` remain Acme-only protocol endpoints.

The previous URL-token `sot` completion flow was removed from the normal browser path. Completion
state now lives in the Rails session. Registered RP post-logout redirect URIs now point at
`/sign/out/complete`.

Validation notes:

- `bin/rails test test/integration/routes/sign_route_contract_test.rb test/integration/routes/acme_route_contract_test.rb test/integration/routes/base_route_contract_test.rb test/integration/routes/core_route_contract_test.rb`
- `bin/rails test test/controllers/sign/route_naming_test.rb test/controllers/sign/app/sign_outs_controller_test.rb test/controllers/sign/com/sign_outs_controller_test.rb test/controllers/sign/org/sign_outs_controller_test.rb test/controllers/acme/app/sign_outs_controller_test.rb test/controllers/acme/com/sign_outs_controller_test.rb test/controllers/acme/org/sign_outs_controller_test.rb test/controllers/acme/app/oidc/logouts_controller_test.rb test/controllers/acme/com/oidc/logouts_controller_test.rb test/controllers/acme/org/oidc/logouts_controller_test.rb test/controllers/base/app/sign_outs_controller_test.rb test/controllers/core/app/sign_outs_controller_test.rb test/controllers/concerns/sign_out_notice_test.rb`
- `bin/rails test test/controllers/acme/oauth_oidc_authority_test.rb`
- `bin/rails zeitwerk:check`
- `git diff --check`
