# AGENTS.md and Skills Claude 5 Era Revision Implementation Notes

## Context

- Original plan/spec: user request to re-express `AGENTS.md` as a prompt suited to the Claude Fable
  5 / Sonnet 5 / Opus 5 generation, with content preserved and Anthropic's official documentation as
  the sole permitted basis. Extended in the same session to cover the 24 skills under
  `.agents/skills/`, on the same basis but without the content-preservation constraint.
- Related decisions/docs/plans: `.agents/harnesses/rules/generic/model-behavior-calibration.mdc`
  (already encodes the Opus 5 behavioral corrections),
  `docs/reference/repository-language-policy.md`,
  `.agents/harnesses/rules/project/repository-knowledge-tree.mdc`.
- Implementation date: 2026-08-03.

## Sources

Only these Anthropic pages were used. No third-party prompt-engineering material informed any
change.

- How Claude remembers your project — <https://code.claude.com/docs/en/memory>
- Best practices for Claude Code — <https://code.claude.com/docs/en/best-practices>
- Prompting best practices —
  <https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/claude-prompting-best-practices>
- Prompting Claude Fable 5 —
  <https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/prompting-claude-fable-5>
- Prompting Claude Sonnet 5 —
  <https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/prompting-claude-sonnet-5>
- Prompting Claude Opus 5 —
  <https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/prompting-claude-opus-5>
- Effective context engineering for AI agents —
  <https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents>
- Skill authoring best practices —
  <https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices>
- Extend Claude with skills — <https://code.claude.com/docs/en/skills>

## Change To Source Mapping

| Change in `AGENTS.md`                                                                            | Basis                                                                                                                                                                                                                                                                                                                                                                  |
| ------------------------------------------------------------------------------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Intro states why rules load on demand and that the file is deliberately short                    | Memory page: target under 200 lines, "longer files consume more context and reduce adherence"; context engineering: progressive disclosure                                                                                                                                                                                                                             |
| Implementation Principles now carry the reason for each rule                                     | Prompting best practices: "Providing context or motivation behind your instructions… can help Claude better understand your goals"; Fable 5 over-engineering snippet ("a bug fix doesn't need surrounding cleanup", "don't design for hypothetical future requirements", "don't use feature flags or backwards-compatibility shims when you can just change the code") |
| Working Method kept as a numbered list, with an added lead-in that order and completeness matter | Prompting best practices: "Provide instructions as sequential steps using numbered lists… when the order or completeness of steps matters"                                                                                                                                                                                                                             |
| New pause criteria at the end of Working Method                                                  | Fable 5, Strong instruction following: "Pause for the user only when the work genuinely requires them: a destructive or irreversible action, a real scope change, or input that only they can provide… ask and end the turn, rather than ending on a promise"                                                                                                          |
| Application Boundaries restated positively, with the trust-boundary reason                       | Prompting best practices: "Tell Claude what to do instead of what not to do"; Opus 5: "Positive examples… tend to be more effective than instructions about what not to do"                                                                                                                                                                                            |
| Required Task Context reformatted to a compact lookup table with an explicit path-base sentence  | Memory page: "use markdown headers and bullets to group related instructions"; context engineering: "the minimal set of information that fully outlines your expected behavior"                                                                                                                                                                                        |
| Non-Negotiable Boundaries kept negative, each item paired with its positive alternative          | Prompting best practices, "Control the format of responses": prefer what to do over what not to do, while the constraints themselves remain hard prohibitions                                                                                                                                                                                                          |
| Explicit scope added to the logging and `ENV.fetch` boundaries                                   | Sonnet 5, More literal instruction following: "It does not silently generalize an instruction from one item to another… state the scope explicitly"                                                                                                                                                                                                                    |
| Output Calibration retained in the always-loaded file rather than reduced to a pointer           | Opus 5, Response length and verbosity: "In a long system prompt, pair the instruction with a short reminder near the end of the prompt"                                                                                                                                                                                                                                |
| "No self-verification scaffolding" retained and given its reason                                 | Opus 5, Task scope and over-verification: verification instructions "cause over-verification… removing them reduces wasted tokens with no loss in quality"                                                                                                                                                                                                             |
| Subagent budget line retained                                                                    | Opus 5, Controlling subagent spawning: "Do not delegate work you can finish yourself in a handful of tool calls, and do not use subagents to verify or double-check your own work"                                                                                                                                                                                     |
| New progress-grounding paragraph at the end of Verification                                      | Fable 5, Ground progress claims during long runs: "Before reporting progress, audit each claim against a tool result from this session… if tests fail, say so with the output; if a step was skipped, say that"                                                                                                                                                        |

## Skills Change To Source Mapping

The 24 skills under `.agents/skills/` were revised against the skill-authoring checklist. Defects
fixed, and the basis for each:

| Change                                                                                                                                                                                                    | Basis                                                                                                                                                                                            |
| --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| 12 pointers to 5 `references/*.md` files that did not exist now resolve — the files were created by moving existing inline content out of the skills                                                      | Skill authoring: "File references are one level deep", "Test file access patterns: verify Claude can navigate your directory structure"                                                          |
| `security-and-hardening` reduced from 520 to 443 lines by moving its review checklist into `references/security-checklist.md`                                                                             | Skill authoring: "Keep SKILL.md body under 500 lines… Split content into separate files when approaching this limit"                                                                             |
| All 24 descriptions rewritten in third person with concrete triggers; second-person phrasing removed                                                                                                      | Skill authoring: "Always write in third person. The description is injected into the system prompt, and inconsistent point-of-view can cause discovery problems"                                 |
| `## Overview` and `## When to Use` sections folded into a short lead, since the description already carries what-and-when                                                                                 | Skill authoring: "Only add context Claude doesn't already have… Does this paragraph justify its token cost?"                                                                                     |
| All 22 `## Common Rationalizations` tables removed (219 lines)                                                                                                                                            | Skill authoring: "Concise is key… the context window is a public good"; Fable 5: "Skills developed for prior models are often too prescriptive… Review and consider removing older instructions" |
| `using-agent-skills` reduced from 208 to 88 lines; its "Core Operating Behaviors" and "Failure Modes to Avoid" sections removed in favor of a pointer to `AGENTS.md` and `model-behavior-calibration.mdc` | Memory page: "if two rules contradict each other, Claude may pick one arbitrarily. Review… periodically to remove outdated or conflicting instructions"                                          |
| `context-engineering` rewritten around load-cost layers (instruction file / path-scoped rule / skill / bundled reference / session), the 200-line target, and the include-exclude table                   | Memory page ("Write effective instructions", "Organize rules with .claude/rules/"); best practices ("Write an effective CLAUDE.md"); context engineering (progressive disclosure)                |
| `idea-refine` script path corrected from `/mnt/skills/user/idea-refine/…` to the in-repo path, and its three bundled files linked as markdown links                                                       | Skill authoring: file paths are navigated as a filesystem; references link directly from SKILL.md                                                                                                |
| Tables of contents added to the four bundled files over 100 lines                                                                                                                                         | Skill authoring: "For reference files longer than 100 lines, include a table of contents at the top"                                                                                             |
| `doubt-driven-development` references to `references/orchestration-patterns.md`, personas, and an `agents/` roster removed — none of those exist in this repository                                       | Skill authoring: references must resolve; consistency requirement above                                                                                                                          |
| Aggressive and absolutist phrasing softened where it was steering rather than stating a constraint                                                                                                        | Prompting best practices: dial back "CRITICAL: You MUST…" to normal phrasing on current models                                                                                                   |

Net effect: SKILL.md bodies went from 7,555 to 6,594 lines, with 372 lines moved into four bundled
reference files that load only when a skill points at them.

## Decisions Made During Implementation

- Decision: keep `CLAUDE.md` as a bare `@AGENTS.md` import and make no Claude-specific additions.
  - Why: the memory page prescribes exactly this shape — "Claude Code reads `CLAUDE.md`, not
    `AGENTS.md`. If your repository already uses `AGENTS.md`… create a `CLAUDE.md` that imports it"
    — and the repository treats `AGENTS.md` as the single canonical file.
  - Alternatives considered: adding a Claude-only section below the import, which the same page
    permits. Rejected because it would split the canonical instructions across two files.

- Decision: keep the Non-Negotiable Boundaries list in negative form instead of converting it wholly
  to positive instructions.
  - Why: the "say what to do instead" guidance is about steering style and format. These entries are
    hard constraints where the prohibition is the accurate statement; each now carries its positive
    alternative alongside rather than replacing it.

- Decision: keep the Output Calibration summary duplicated between `AGENTS.md` and
  `model-behavior-calibration.mdc`.
  - Why: the rule file only enters context when read, while `AGENTS.md` is always loaded, and the
    Opus 5 page recommends a short conciseness reminder near the end of a long prompt. The summary
    restates the rule rather than contradicting it, so the memory page's warning about conflicting
    instructions does not apply.
  - Follow-up: if `AGENTS.md` approaches the 200-line target again, this summary is the first
    candidate to reduce to a pointer.

- Decision: skill names left in noun-phrase form (`code-review-and-quality`) rather than renamed to
  gerunds.
  - Why: the authoring guide prefers gerund form but lists noun phrases as an acceptable
    alternative, and the names are referenced across `AGENTS.md`, plans, notes, and the skills
    themselves. Renaming would break those references for no behavioral gain.

- Decision: `## Red Flags` and `## Verification` sections kept in every skill.
  - Why: they are checkable signals and feedback loops, which the authoring guide endorses
    ("Implement feedback loops", the checklist pattern). They are procedure, unlike the removed
    rationalization tables.

- Decision: the four new `references/*.md` files were populated by moving content that already
  existed inline, not by writing new guidance.
  - Why: the dangling pointers had to resolve, and moving existing content fixes both the broken
    reference and the length problem without introducing unreviewed material. The exception is
    `accessibility-checklist.md`, which was assembled from the skill's own WCAG 2.1 AA section plus
    the testing steps that section implied but did not enumerate.

- Decision: `.agents/harnesses/rules/*.mdc` left unchanged.
  - Why: out of the scope the user set, which was `AGENTS.md` and then the skills. The rules were
    read to check for contradictions with the revised material and none were found;
    `model-behavior-calibration.mdc` already encodes the Opus 5 behavioral corrections.
  - Follow-up: no action needed unless the rules drift from `AGENTS.md`.

## Review Notes

- Tests run: none. The change is prose in `AGENTS.md`, the 24 skills, and four new bundled reference
  files. No Ruby or JavaScript behavior changed, so `bin/rails test` and `pnpm test` are not
  applicable.
- Checks run:
  - `AGENTS.md` is 200 lines, within the documented target
  - every rule and document path referenced by `AGENTS.md` resolves (26 paths)
  - every SKILL.md body is under 500 lines
  - all 24 frontmatter blocks parse as YAML, carry exactly `name` and `description`, and the name
    matches the directory
  - all 24 descriptions are third person and within the 1,024-character limit
  - all 14 bundled-file references resolve from their containing skill
  - no prose line over 100 characters was introduced; the five that remain predate this change
- Bug found and fixed during verification: an unquoted `directly: "interview me"` introduced into
  `interview-me`'s description made its frontmatter fail YAML parsing. Colons inside a multi-line
  plain scalar start a mapping. Rephrased to avoid the colon.
- Documentation promotion needed: none. This note records how the files were revised; the files
  themselves remain the authority on what the rules are.
