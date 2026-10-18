# Preparation Host Configuration — Partial Verification

Date: 2026-10-13

Commit under verification: `40f2559ec0fa29c84ebf268136e4e4794dcbcedc`

The worktree had uncommitted preparation changes in `.env.devcontainer.example`, `.env.example`,
`app/values/fqdn_availability_registry.rb`, `config/environments/development.rb`,
`config/environments/production.rb`, `lib/config_values_host_family_values.rb`, and
`lib/jit_security_jwt_registry.rb`. The ignored local files `.env` and `.env.local` also had
uncommitted Tech host entries. These changes affected the result below.

## Completed checks

- Development Rails boot and host/namespace configuration check:

  ```bash
  RAILS_ENV=development UMAXICA_ENV_FILE=.env bin/rails runner 'hosts = Rails.configuration.x.boot_config.fetch(:hosts); allowed_hosts = Array(Rails.application.config.hosts).map(&:to_s); expected_hosts = %w(tech.umaxica.org tech.org.localhost); missing_hosts = expected_hosts - allowed_hosts; raise "missing Tech allowed hosts: #{missing_hosts.join(", ")}" unless missing_hosts.empty?; raise "unexpected Tech boot host: #{hosts.tech_staff.host}" unless hosts.tech_staff.host == "tech.umaxica.org"; keysets = JSON.parse(Rails.root.join("tmp/local_jwt_keysets.json").read); expected_namespaces = %w(OIDC_CLIENT_PALM_APP OIDC_CLIENT_TECH_ORG); missing_namespaces = expected_namespaces - keysets.keys; raise "missing local client namespaces: #{missing_namespaces.join(", ")}" unless missing_namespaces.empty?; puts "development boot passed; Tech hosts and local client namespaces are configured"'
  ```

  Result: exit 0; `development boot passed; Tech hosts and local client namespaces are configured`.
  The command checked namespace names only and did not print key material.

- `bundle exec rubocop app/values/fqdn_availability_registry.rb config/environments/development.rb config/environments/production.rb lib/config_values_host_family_values.rb lib/jit_security_jwt_registry.rb`:
  5 files inspected, no offenses.
- `git diff --check`: exit 0.

No Minitest or Vitest cases were added or run for environment construction, in accordance with
`.agents/harnesses/rules/project/no-environment-tests.mdc`.

## Incomplete check and recovery

Preparation step 2 remains incomplete because the required Compose aliases could not be written.
`findmnt -T .devcontainer/compose.yaml -no TARGET,SOURCE,FSTYPE,OPTIONS` reported the mount source
`tank/Projects[/ghq/github.com/seahal/umaxica-apps-global/.devcontainer]` with `zfs ro`; a
writeability check (`test -w .devcontainer/compose.yaml`) returned exit 1. The writable Compose
change, its verification, and the preparation-step commit remain for a writable checkout or a mount
made writable by its owner. See the handoff in `six.md`.
