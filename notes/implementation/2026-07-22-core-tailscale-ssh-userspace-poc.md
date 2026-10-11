# Direct-Core Tailscale Cutover Implementation Note

## Decision

Promote the successful userspace Tailscale PoC to the development access path. Use built-in
Tailscale SSH and tailnet-only HTTPS Serve directly in `core`. Remove the legacy `tailscale-codex`
Compose service and its OpenSSH-over- Tailscale path. Keep the independent Cloudflare Tunnel sidecar
unchanged.

## Repository boundary

The digest-pinned official Tailscale image remains a binary source for the development target only.
`tailscale-core-state` preserves the direct node identity and background Serve configuration. The
PID 1 wrapper continues to start `bin/dev`, monitor bounded independent tailscaled restarts, fan out
signals, reap children, and leave local development running when remote access is degraded.

The legacy OpenSSH server package, entrypoint branch, configuration, Serve JSON, sidecar service,
sidecar-only bridge network, and sidecar volume declaration were removed. The physical old state
volume was not deleted.

Rails accepts only the optional exact `TAILSCALE_SERVE_HOST`. A malformed non-empty value fails
development boot; no broad `.ts.net` regex is installed.

## Runtime cutover

On 2026-07-22:

1. Direct-core HTTPS Serve was configured against `127.0.0.1:3000`.
2. The sidecar node was renamed `umaxica-global-core-sidecar-retired`.
3. The direct node was renamed `umaxica-global-core` and Serve was reset once so its
   certificate/name followed the official machine name.
4. Rootless Podman rebuilt and recreated only `core`, preserving its named state volume.
5. External `ssh global@umaxica-global-core` reached the recreated container and showed the expected
   supervisor plus `bin/dev` as PID 1 arguments.
6. The legacy sidecar container was stopped and removed. Its Tailnet node and Podman state volume
   were retained for rollback.

The rebuild also proved the development image no longer contains `/usr/sbin/sshd`; `openssh-client`
remains for outbound Git/SSH tooling.

## Verification boundary

Recreation and a later restart preserved the direct node identity and Serve configuration. `bin/dev`
started Foreman, Rails, Vite, and Solid Queue next to userspace tailscaled without TUN, added
capabilities, or privileged mode. The Cloudflare Tunnel sidecar remained running throughout.

HTTPS Serve reached Rails and returned the same HTTP 500 as a direct localhost request. This proves
the transport and exact Host Authorization path, but not an application-level HTTP success response;
the pre-existing local Rails 500 requires separate diagnosis. Host-reboot recovery and deliberate
tailscaled failure injection also remain unverified.

The focused Rails startup contract may still be blocked by unrelated test database state. Static
YAML, shell syntax, repository-language, and contract checks remain the fallback evidence when that
environment blocker is present.

## Security boundary

Interactive login was used; no Tailscale auth key is present in Compose, image layers, or command
arguments. The remote `global` user has passwordless sudo, so Tailscale state and development
credentials are not a strong internal boundary from Rails, Claude Code, or arbitrary development
code. This exposure is explicitly accepted only for the development container.

## Rollback

Revert the repository change, rename the direct node away from the official name, recreate the
legacy sidecar with the retained state volume, and rename it back to `umaxica-global-core`. Never
operate both identities under that same machine name. Tailnet node deletion and Podman volume
deletion remain separate destructive cleanup steps after the rollback window.
