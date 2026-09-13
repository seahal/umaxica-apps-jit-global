# Dev Container Usage

The container definition is `umaxica-apps-global-dc` in `.devcontainer/devcontainer.json`. It runs
on rootless Podman; see
[VS Code Dev Containers on Rootless Podman](../operations/devcontainer-cli-podman-startup.md) for
the required host configuration.

## VS Code

- Install the Dev Containers extension.
- Open the repository folder and run **Reopen in Container**.
- `postCreateCommand` runs `bundle install && pnpm install`. Wait for that command to finish in the
  Dev Containers log before starting tasks.

## IntelliJ IDEA (Gateway)

- Install JetBrains Gateway and choose **Dev Containers** as the connection method.
- Select the `umaxica-apps-global-dc` container definition. The `customizations.jetbrains` block
  requests the IntelliJ backend with the Ruby plugin.
- When the IDE connects, run `bin/rails db:prepare` if database setup did not finish automatically.

### Notes

- Published host ports are loopback-only and are declared in `.devcontainer/compose.yaml`: host
  `3001` forwards to Rails `3000`, while Vite uses `3036` on `core`. No JetBrains backend port is
  published; Gateway tunnels its own connection.
  `docs/operations/development-host-port-exposure.md` is the contract.
- The image carries no desktop or X11 libraries. Only the headless IntelliJ backend is supported.
