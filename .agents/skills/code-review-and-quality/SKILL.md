---
name: code-review-and-quality
description: Review a concrete diff for contract, correctness and material security or maintenance risks. Use for requested reviews or substantive change assessment; avoid redundant review-agent passes.
---

# Code review and quality

Read the diff, intended change contract and relevant tests. Follow `AGENTS.md` routing to the affected
constraints. Inspect the public behavior, failure paths, ownership and boundary conditions rather
than counting files or enforcing arbitrary size limits.

Report actionable findings with a path, triggering condition, impact and evidence. Distinguish
confirmed defects from unresolved questions. Check that verification claims match actual results;
a named test or checklist is not a passed test. Consider security and performance where the change
can affect them; measure performance claims rather than inventing estimates.

Keep review within scope and preserve unrelated changes. Integrate assessment into the normal
implementation loop; do not automatically spawn another model or demand a second verification
pass. For a high-impact security decision, apply adversarial questions from the security workflow
only when they add information. A review does not authorize merge, deployment or external messages.
