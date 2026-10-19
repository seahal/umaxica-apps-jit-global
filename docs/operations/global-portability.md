# Global portability contract

This document is the operational contract for the Global repository. It keeps application settings
portable while leaving Compose responsible for infrastructure topology only.

## 1. Repository scope

This repository remains the Global application. Regional responsibilities are not split here and no
Regional repository is created by this work.

## 2. Runtime modes

The supported local mode is the Dev Container with Compose infrastructure. Bare-metal Rails is not
supported.

## 3. Configuration authority

Application configuration is the non-secret environment contract, not a Compose service definition.
The Dev Container receives `.env.container.devcontainer` through `env_file`. `config/boot.rb` also
loads the ignored `.env` when present; exported values always win. Production never reads
repository-local environment files.

## 4. Host contract

There is no host-native environment file. The host runs Podman Compose and the Dev Container only.

## 5. Dev Container contract

`.env.container.devcontainer` is the same application contract with only topology-sensitive
endpoints changed to Compose service names. The tracked Dev Container overlay consumes it with
`env_file`.

## 6. Compose boundary

`compose.yaml` provides PostgreSQL primary/replica, Valkey cache/rate-limit stores, FakeCloud, and
observability/tunnel topology. It has no Rails application service. The Dev Container overlay adds
only `core` and does not inline application variables.

## 7. PostgreSQL

Rails runs only in the Dev Container and reaches `primary` and `replica` through the backend
network. `config/database.yml` owns the development and test hosts, login and database names as
fixed literals; production reads the `NEON_*` variables. The loopback publications serve host-side
tools such as `psql`, not Rails.

## 8. Valkey

Cache and rate-limit stores remain physically separate. Host mode uses ports 6379 and 6380; the
container contract uses the two Compose service names. Neither store is a correctness datastore.

## 9. Object storage

FakeCloud is a disposable local S3-compatible endpoint on loopback for host tools and the
`fakecloud` service name for the container. Local access-key values are visibly fake test values.

## 10. Host exposure

Every published development port remains explicitly loopback-only. PostgreSQL and Valkey are not
reachable from the LAN, and no service uses host networking.

## 11. Secrets

No master key, secret key base, private key, bearer token, production database password, or cloud
credential belongs in `.env.container.devcontainer`. Rails encrypted credentials and the ignored
`.env` remain provisioned out of band.

## 12. Frontend toolchain

Bun is the sole package manager and script runner. Vite, Vitest, Playwright, TypeScript, and the two
Rails frontend stacks remain intact. The package manager is pinned in `package.json` and the image.

## 13. Bare-metal startup

Not supported. Use the Dev Container startup in section 14.

## 14. Dev Container startup

Open the repository in a Dev Container. The tracked Compose files and `.env.container.devcontainer`
resolve on a clean checkout. The post-create command installs Bundler and Bun dependencies and
prepares databases.

## 15. Database lifecycle

Local database, queue, cache, replica, and FakeCloud volumes are disposable. Destructive recreation
is acceptable during local recovery; never apply that procedure to a production volume.

## 16. Portability failure mode

Missing required values fail loudly through `ENV.fetch` or the existing typed configuration values.
The loader only fills absent local development values and never replaces explicit process settings.

## 17. URL contract

Private localhost aliases are used for direct local requests. Public URL values remain explicit and
are not inferred from a Compose project name or container hostname.

## 18. Dev Container filesystem

The repository remains a bind mount. Bundler, Bun cache, node modules, and nested Podman state use
named volumes so host ownership and source files remain stable across engines.

## 19. CI contract

CI installs Bun from the pinned setup action, installs from `bun.lock`, runs Bun scripts, and leaves
Rails database setup and tests explicit. The local CI helper follows the same commands.

## 20. Verification contract

The portability test is engine-free and checks the environment files, Compose boundary, host ports,
Dev Container inputs, and loader behavior. Runtime evidence records commands actually run.

## 21. Security review

The change does not alter cookie, session, authentication, authorization, CSRF, WebAuthn, OIDC, or
provider policy. It changes only how non-secret local configuration reaches the existing app.

## 22. Handoff decision

Regional cloning is not a task performed by this repository. The final evidence reports whether the
Global application is ready for that future clone and names any concrete verification blocker.
