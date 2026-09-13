# /doctor cleanup — apply approved changes

## Context

A `/doctor` health check found the install clean and the always-loaded guidance (`AGENTS.md`, ~1,855
est. tokens) lean — nothing to trim. Two categories of finding were surfaced to the user:

1. **4 unused extensions** enabled but never used in the 50-session / ~4.6-day scan window.
2. **Default permission mode** — user scope is `plan`; the repo's checked-in `auto` is ignored as
   repo-controllable, so the effective default is `plan`.

User decisions at the confirmation gate:

- **Clean up everything** — disable the 2 unused MCP servers and 2 unused plugins.
- **Keep plan mode** — do NOT change the default permission mode. (No edit to
  `~/.claude/settings.json` `permissions.defaultMode`.)

All actions below are reversible.

## Actions to apply

### 1. Disable 2 unused plugins (user scope)

Both are enabled in `~/.claude/settings.json` under `enabledPlugins`, both with 0 lifetime uses and
0 transcript hits:

- `claude-code-setup@claude-plugins-official`
- `frontend-design@claude-plugins-official`

Set each to `false`. **Do not read the whole settings file** (it holds `env` secrets) — edit
key-scoped via `jq` into a `mktemp` temp file, then move it over the original:

```
tmp=$(mktemp)
jq '.enabledPlugins["claude-code-setup@claude-plugins-official"]=false
    | .enabledPlugins["frontend-design@claude-plugins-official"]=false' \
   ~/.claude/settings.json > "$tmp" && mv "$tmp" ~/.claude/settings.json
```

Undo: set the same two keys back to `true` (or re-enable via `/plugin`).

### 2. Disable 2 unused MCP servers (user scope)

- `blog-seahal-net` (0 calls in window; exposes only auth tools)
- `seahal-blog` (0 calls in window)

Use the documented reversible path — the user runs these in the current project (per-project toggle;
repeat in any other project where they should be off):

```
/mcp disable blog-seahal-net
/mcp disable seahal-blog
```

Do NOT use `claude mcp remove` (permanently deletes config + wipes OAuth tokens). Undo:
`/mcp enable <name>`.

### 3. No permission-mode change

User declined auto mode. Leave `~/.claude/settings.json` `permissions.defaultMode` untouched (stays
effectively `plan`).

## Verification

- After the plugin edit: `jq '.enabledPlugins' ~/.claude/settings.json` shows both keys `false`.
- After `/mcp disable`: `/mcp` list shows both servers disabled;
  `jq '.projects["/home/mslo/Projects/ghq/github.com/seahal/umaxica-apps-global"].disabledMcpServers' ~/.claude.json`
  includes both names.
