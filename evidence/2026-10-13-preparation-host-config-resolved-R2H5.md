# Preparation Host Configuration — Completion Verification

Date: 2026-10-13

Verified against commit `40f2559ec0fa29c84ebf268136e4e4794dcbcedc`. The worktree was dirty with the
preparation-step changes in `.devcontainer/compose.yaml`, `.env.devcontainer.example`,
`.env.example`, `app/values/fqdn_availability_registry.rb`, `config/environments/development.rb`,
`config/environments/production.rb`, `lib/config_values_host_family_values.rb`, and
`lib/jit_security_jwt_registry.rb`. The ignored local files `.env` and `.env.local` also contained
the Tech host entries and affected the boot check.

The frozen plan hashes remained `663bb1a858f537edde4da80e53631a73e08a8022c59123fb2df391601d4cbe4c`
for `one.md` and `7297a6e0eb52fc4df2768c926e084297e654f827c0acd83f0d462c6c8ae4086d` for `two.md`.

## Scope and result

Preparation stage items 1–4 are verified: the optional OIDC namespaces are registered, Tech host
values exist in local and checked-in environment files without a code-side default, the host slots
and development/production allowlists are present, and the two Compose network aliases are present.

The Compose aliases were already in the working-tree diff when this session resumed. The diff adds
only `tech.org.localhost` and `tech.umaxica.org` under `services.core.networks.frontend.aliases`.
`findmnt` still reported the `.devcontainer` ZFS mount as read-only, so this session did not write
`.devcontainer/compose.yaml`; the author of the new diff could not be determined.

## Checks performed

- Compose YAML structure and alias uniqueness:

  ```bash
  ruby -ryaml -e 'config = YAML.load_file(".devcontainer/compose.yaml", aliases: true); aliases = config.fetch("services").fetch("core").fetch("networks").fetch("frontend").fetch("aliases"); expected = %w(tech.org.localhost tech.umaxica.org); missing = expected - aliases; duplicates = expected.select { |name| aliases.count(name) != 1 }; raise "missing Compose aliases: #{missing.join(", ")}" unless missing.empty?; raise "Compose aliases must appear once: #{duplicates.join(", ")}" unless duplicates.empty?; puts "Compose YAML parsed; both Tech aliases occur once under core/frontend"'
  ```

  Result: passed.

- The following `awk` check verified that both Tech variables occur exactly once with the approved
  values in each local and checked-in environment file; it printed no other environment data:

  ```bash
  for file in .env .env.local .env.example .env.devcontainer.example; do awk -F= -v file="$file" '$1 == "PUBLIC_TECH_STAFF_URL" { public_count++; public_ok = ($2 == "tech.umaxica.org") } $1 == "PRIVATE_TECH_STAFF_URL" { private_count++; private_ok = ($2 == "tech.org.localhost") } END { if (public_count != 1 || private_count != 1 || !public_ok || !private_ok) { printf "%s: Tech host variables invalid (public_count=%d private_count=%d)\n", file, public_count, private_count; exit 1 } printf "%s: both Tech host variables occur once with expected values\n", file }' "$file" || exit 1; done
  ```

  Result: all four files passed.

- Development application boot and configuration check:

  ```bash
  env -u RUBY_DEBUG_OPEN RAILS_ENV=development UMAXICA_ENV_FILE=.env bin/rails runner 'hosts = Rails.configuration.x.boot_config.fetch(:hosts); allowed_hosts = Array(Rails.application.config.hosts).map(&:to_s); expected_hosts = %w(tech.umaxica.org tech.org.localhost); missing_hosts = expected_hosts - allowed_hosts; raise "missing Tech allowed hosts: #{missing_hosts.join(", ")}" unless missing_hosts.empty?; raise "unexpected Tech boot host" unless hosts.tech_staff.host == "tech.umaxica.org"; namespaces = JitSecurityJwtRegistry::OIDC_CLIENT_NAMESPACES; required = JitSecurityJwtRegistry::REQUIRED_OIDC_CLIENT_NAMESPACES; new_namespaces = %w(PALM_APP TECH_ORG); raise "missing optional namespace" unless (new_namespaces - namespaces).empty?; raise "new namespaces must remain optional until clients exist" unless (new_namespaces & required).empty?; keysets = JSON.parse(Rails.root.join("tmp/local_jwt_keysets.json").read); expected_keysets = %w(OIDC_CLIENT_PALM_APP OIDC_CLIENT_TECH_ORG); raise "local keysets not installed" unless (expected_keysets - keysets.keys).empty?; puts "development boot passed; Tech hosts allowed; Palm/Tech namespaces optional and local keysets installed"'
  ```

  Result: exit 0; the expected success line was printed. Only namespace names were inspected; no key
  material was printed. The first attempt with the inherited debugger setting failed before
  application boot because the sandbox denied its Unix socket bind (`Errno::EPERM`). Unsetting
  `RUBY_DEBUG_OPEN` for the successful command avoided that unrelated debugger socket.

- `bundle exec rubocop app/values/fqdn_availability_registry.rb config/environments/development.rb config/environments/production.rb lib/config_values_host_family_values.rb lib/jit_security_jwt_registry.rb`:
  5 files inspected, no offenses.
- `git diff --check`: exit 0.

No Minitest or Vitest setup tests were added or run. Neither `podman` nor `docker` was available, so
no Compose runtime/render command was run; YAML parsing and the planned development boot check were
completed directly. No production boot, external configuration write or deployment was performed.

## Follow-up

Commit the completed preparation step on `feature` before starting step 3. At the time of this
record the changes were still uncommitted.
