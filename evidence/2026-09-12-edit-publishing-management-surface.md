# Edit Publishing Management Surface Verification

Date: 2026-09-12

## Performed

- `ruby -c config/routes.rb config/routes/edit.rb config/routes/base.rb` completed successfully.
- `ruby -c` completed successfully for all 52 Ruby files below `app/controllers/edit` and
  `test/controllers/edit`.
- `git diff --check` completed successfully.
- Static inventory searches found no active `Base::Org::Publishing`, `base_org_publishing`, or
  `base/org/publishing` references outside historical implementation notes.
- The Dev Container `core` service now declares both `edit.org.localhost` and
  `edit.umaxica.org` aliases on `frontend`, the private origin required by the remotely managed
  Cloudflare Tunnel ingress.

## Blocked

- `bin/rails test test/integration/routes/base_org_publishing_management_route_contract_test.rb`
  could not boot. Bundler reported that the git-sourced Rails revision `5d0f2ef19ac3` from the
  current `Gemfile.lock` is absent from `vendor/bundle`. No install or lockfile mutation was made.
- `bun run lint` could not run because `bun` is not installed in this environment.
- `podman compose -f compose.yaml -f .devcontainer/compose.yaml config` could not initialize the
  rootless Podman runtime because `/run/user/1000/libpod` is read-only. No Compose service or
  remote Tunnel state was changed by that failed check.
- The Tunnel ingress, DNS, and Access application are remotely managed in Cloudflare and this
  session has no authenticated Cloudflare browser or API connection. They remain unverified until
  the current Tunnel configuration is read, merged with the `edit.umaxica.org` rule targeting
  `http://edit.org.localhost:3000`, applied, and then checked with DNS and Access-path requests.
