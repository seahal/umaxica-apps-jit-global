# Agent runtime compatibility

Documentation reviewed: 2026-10-09. These are documented behaviors, not promises about every client
or future release. Earlier local inspection found Codex CLI 0.162.0 and Claude Code 2.1.295; consult
the accompanying evidence for checks actually run. This migration does not invoke hosted models,
change machine settings or claim a two-model behavioral evaluation.

## Shared source and adapters

`AGENTS.md` is the shared entry point; `CLAUDE.md` remains `@AGENTS.md`. Each retained Claude Skill
folder is a relative symlink to `../../.agents/skills/<name>`. Only these paths are unignored;
settings, worktrees, transcripts and other local Claude files stay ignored. Canonical Skill bodies
use portable `name` and `description` metadata. Vendor-only tool/permission settings stay outside
shared bodies. Whole-directory links and forwarding prompts are not required.

## OpenAI documented behavior

- [AGENTS discovery](https://learn.chatgpt.com/docs/agent-configuration/agents-md): global guidance
  followed by root-to-working-directory instructions, with per-directory override precedence and
  a default project instruction byte cap. Nested files are supported by the runtime, but this
  repository deliberately uses only the root router. Splitting imports does not itself save context.
- [Skills](https://learn.chatgpt.com/docs/build-skills): repository `.agents/skills/`, user and admin
  scopes, progressive disclosure and symlinked Skill folders are documented. Metadata consumes
  discovery context; numerous broad triggers are not free even when bodies remain unloaded.
- [Rules](https://learn.chatgpt.com/docs/agent-configuration/rules) are command policy, not `.mdc`
  prose. [Sandboxing](https://learn.chatgpt.com/docs/sandboxing) and
  [permissions](https://learn.chatgpt.com/docs/permissions) are separate runtime controls. Permissions
  profiles were documented as beta; preserve compatibility rather than guessing precedence.
- [Hooks](https://learn.chatgpt.com/docs/hooks) depend on event, configuration trust and client.
  Some failure paths are nonblocking; post-tool events cannot undo an executed tool.
- [Subagents](https://learn.chatgpt.com/docs/agent-configuration/subagents) suit independent read-heavy
  work; write coordination has a cost. Context and permission inheritance must be checked for the
  chosen runtime, not generalized from another vendor.

[GPT-6.1 Sol](https://developers.openai.com/api/docs/models/gpt-6.1-sol) is a documented model;
an API model description is not a Codex client capability guarantee. The
[September 2026 prompting discussion](https://developers.openai.com/blog/rethinking-skills-and-prompts-for-gpt-6-astra)
supports concise, task-relevant context, but model-specific observations do not justify removing
repository security controls.

## Anthropic documented behavior

- [Memory](https://code.claude.com/docs/en/memory): ancestor guidance and nested-file loading differ;
  imports resolve relative to the importing file and expand into context. Newer AGENTS support has
  version and coexisting-CLAUDE conditions. The explicit one-line import avoids depending on those
  conditions. A recommended document length is not an enforcement threshold.
- [Skills](https://code.claude.com/docs/en/skills): project `.claude/skills/`, user scope, progressive
  disclosure and individual symlinked Skill folders are documented. This is the chosen adapter;
  plugin packaging has different discovery behavior and is not assumed equivalent.
- [Authoring](https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices): concise
  descriptions, clear triggers, supporting references and model-specific evaluation are recommended.
- [Hooks](https://code.claude.com/docs/en/hooks): blocking behavior is event-specific; asynchronous
  hooks are not gates and post-tool hooks cannot undo an action.
- [Subagents](https://code.claude.com/docs/en/sub-agents#what-loads-at-startup): startup context varies
  by agent type. Explore/Plan omit CLAUDE context; do not assume parent chat, invoked Skills or
  instruction inheritance. Supply required boundaries explicitly.
- [Plugins](https://code.claude.com/docs/en/plugins) are a distribution mechanism, useful when
  versioned sharing across repositories earns the added packaging cost. This repository does not
  need one. [Context practices](https://code.claude.com/docs/en/best-practices) favor focused context.

[Opus 5.5](https://www.anthropic.com/claude-opus-5-5) was announced in September 2026. Availability
in a product/account and behavior on this repository remain separate verification questions.

## Local checks and limitations

Run `scripts/check-repository-knowledge`. It checks managed navigation, root routed paths, Skill
metadata and individual adapter targets. Pass `--base <commit>` to check added evidence filenames
and hashes plus changed spec statuses/IDs in the committed diff. Explicit file arguments include
uncommitted new specs/evidence. It checks simple inline file links, not remote URLs, anchors,
reference-style Markdown links, semantic truth, approval authority or every historical document.

The proposed CI job is currently an unapplied patch in the owning spec because this workspace mounts
`.github/workflows/ci.yml` read-only. The checker is also the first step in local `bin/ci`; the remote job is not installed. The full
local `bin/ci` pipeline was not run for this documentation/tooling change. GitHub Rails CI includes
invariants through the full suite; local `bin/ci` also defines an explicit invariant step.

After an authorized runtime upgrade, use an isolated copy and representative requests to inspect
actual instruction/Skill discovery, symlink loading, and scoped behavior on each target runtime.
Record observed versions, model IDs, tasks and limitations. This requires a separate authorized
hosted execution when external environments are excluded. Do not infer runtime success from a
filesystem check. On a platform that cannot preserve symlinks, evaluate a generated mirror with
provenance/drift checks; do not introduce a second human-maintained source.

Local ignored hooks may still run asynchronous auto-fix commands with stale paths. They were outside
this change; inspect them explicitly before relying on that machine's hook behavior.
