# Avatar lifecycle states replayed by db:seed

Commit: bc16c5369e61728074f9426b8058ba5cf765bb10 (uncommitted changes to
`db/seeds.rb` and `db/avatars_migrate/20260703000001_create_avatar_lifecycle_state_authority.rb`
under test; `.env.example` also modified, unrelated).

## Problem observed

`log/development.log` showed social sign-up completion (Google and Apple) returning 422 with
`identity.graph_provisioning.failed` / `ActiveRecord::RecordNotFound` for
`AvatarLifecycleState key = "active"`. The rows were inserted only by the migration, which a
structure.sql load marks as applied without replaying.

## Checks performed

- `bin/rails db:seed` on the local development database: succeeded.
- `AvatarLifecycleState.order(:sort_order).pluck(:key)` returned
  `["active", "suspended", "archived", "banned", "deleted"]`.
- Second `bin/rails db:seed`: exit 0 (idempotent via `ON CONFLICT (key) DO NOTHING`).
- `bin/rails test test/services/avatar_provisioning`: 5 runs, 0 failures.

Booting required `PUBLIC_JUMP_GATEWAY_URL=https://jump.example.com` for these commands, because the
shell value is not an https origin and is rejected at boot.

Not verified: an end-to-end social sign-up through the browser after a full `db:reset`.
