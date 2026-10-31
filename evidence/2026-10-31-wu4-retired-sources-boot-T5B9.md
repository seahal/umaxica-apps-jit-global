# Retired COM authentication and native-push source check

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`. The worktree contained extensive uncommitted changes affecting this result.
- Searched Ruby source in `app`, `lib` and `config` for the `Visitor`, `VisitorToken`, `VisitorSession` and `CoreComVisitorBridge` constants; no matches. Searched `app`, `lib`, `config`, Gemfile and Gemfile.lock for `action_push_native`, `ApplicationPush`, `outbound_channel_suspension` and `native_push`, case-insensitively; no matches.
- Ran `RAILS_ENV=development bin/rails zeitwerk:check` with required local Preference JWT settings: exit 0, eager loading reported all good. No database reset or production/Neon operation was performed.
- These searches cover the listed spellings only. They do not prove all possible renamed consumers, public job behavior, APP/ORG authentication, or completion of WU-4/5/6.
