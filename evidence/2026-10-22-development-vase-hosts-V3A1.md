# Development vase Host Authorization

- Commit: `6e4d70d0b0799a4ef9bd9fc4cea2c21d4b3eca72`.
- Worktree had unrelated uncommitted changes; this check includes the uncommitted addition to `config/environments/development.rb`.
- Ran `bin/rails runner` to boot development and evaluate `ActionDispatch::HostAuthorization::Permissions` using `Rails.application.config.hosts`.
- `vase.app.localhost:3001`, `vase.com.localhost:3001`, and `vase.org.localhost:3001` were allowed; `unrelated.example:3001` was refused. Command exited 0.
- Browser access, Cloudflare Tunnel forwarding, and application routing were not verified. A running Rails server needs restarting to load the environment configuration.
- No Minitest or Vitest cases were added, per the environment construction policy.

## Hostname correction

The owner corrected the requested name to `visa`. Replaced the three `vase` entries with
`visa.app.localhost`, `visa.com.localhost`, and `visa.org.localhost` in the development configuration.
Repeated the Rails runner permission check: all three `visa` hosts with port 3001 were allowed;
`vase.com.localhost:3001` and `unrelated.example:3001` were refused. Exit status 0.
The commit and browser/Tunnel verification limits above remain applicable.
