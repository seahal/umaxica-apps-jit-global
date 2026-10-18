# Valkey cache / KVS physical split (development Compose)

Date: 2026-09-19. Host-side Compose verification only; Rails application logic was not changed.

## Commands

- `podman compose config` (repository root `compose.yaml`, including the auto-discovered override)
- `podman compose up -d valkey-cache valkey-kvs valkey`
- `podman exec … valkey-cli PING` / `CONFIG GET maxmemory-policy` / `CONFIG GET maxmemory`
- loopback `PING` on `127.0.0.1:6379`, `:6380`, `:6381`
- `podman exec global-devcontainer-core getent hosts valkey-cache valkey-kvs valkey`
- throwaway clients on `umaxicaappsglobaldc_backend`: `valkey-cli -h valkey-cache|valkey-kvs|valkey ping`
- `podman compose -f compose.yaml -f .devcontainer/compose.yaml config`

## Results

- `podman compose config` succeeded. Services present: `valkey-cache`, `valkey-kvs`, `valkey`. Extension field `x-valkey-common` is not a service.
- All three containers reached `healthy`. Host PIDs differed (`valkey-cache` 1889084, `valkey-kvs` 1889209, compatibility `valkey` 12220).
- `valkey-cache`: `maxmemory-policy=allkeys-lru`, `maxmemory=268435456`, `PING` → `PONG`. Published `127.0.0.1:6380`.
- `valkey-kvs`: `maxmemory-policy=noeviction`, `maxmemory=268435456`, `PING` → `PONG`. Published `127.0.0.1:6381`.
- Compatibility `valkey`: default `noeviction`, `maxmemory=0`, `PING` → `PONG`. Published `127.0.0.1:6379`.
- Dev Container `core` resolved `valkey-cache.dns.podman`, `valkey-kvs.dns.podman`, and `valkey.dns.podman` to distinct `10.89.0.7` / `10.89.0.8` / `10.89.0.4`. Backend-network clients received `PONG` from each name.
- Combined Dev Container config: `core` `depends_on` `valkey-cache`, `valkey-kvs`, and `valkey` with `service_healthy`.

`.env` was not modified.
