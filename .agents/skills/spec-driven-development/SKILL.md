---
name: spec-driven-development
description: Specify and deliver significant accepted changes with scoped acceptance, proportional plans and evidence. Use for high-risk or multi-session work; ordinary obvious edits need no spec.
---

# Spec-driven development

Read the repository's `AGENTS.md` routing and `specs/README.md`. Preserve established authorization;
a workflow phase is not a new approval gate. Clarify only consequential missing requirements.

For a new accepted change, capture purpose, scope, exclusions and observable acceptance before
implementation. Use [change specification](references/change-specification.md) when drafting. Keep
research optional and explicitly non-normative. Record architectural decisions in the owning ADR.

Separate HOW and ordered tasks only when complexity warrants them. Each execution unit should leave
a coherent implementation and state its relevant verification. Avoid fixed file-count limits,
mandatory commits or whole-suite reruns for every slice. Preserve unrelated work, especially when
other agents are writing. Commit only scoped changes when the task authorizes it.

For behavior changes, reproduce a bug or define the expected public behavior before changing it;
run the narrowest relevant tests and broaden for the affected risk. Environment/tooling construction
is verified by running it and recording evidence, not by adding Minitest or Vitest setup tests.

When finishing, use [closure](references/closure.md). A completed implementation and an unverified
runtime claim are different outcomes. Keep incomplete acceptance open and report the limitation.
