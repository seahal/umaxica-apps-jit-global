---
name: frontend-ui-engineering
description: Implement browser interfaces using the repository design system and verify interaction, accessibility and responsive behavior. Use for UI components or pages, not unrelated backend work.
---

# Frontend UI engineering

Read the affected view/component, nearby working examples and the repository's current design and
translation guidance. Load `docs/design.md` for design-system decisions and
`docs/reference/react.md` for React components and hooks. Preserve each surface's
routing, policy and session boundaries; UI visibility never replaces server authorization.

Implement the complete user interaction, including relevant empty, loading, failure and keyboard
states. Use existing components before adding a new abstraction. Verify framework-specific APIs
against installed code or current official documentation when uncertain; avoid copied tutorials
from another stack.

For detailed accessibility review, read [accessibility prompts](references/accessibility-checklist.md).
Use available browser tools for runtime verification and existing `gait/` or `e2e/` coverage for
public behavior. State when browser checks were unavailable. Profile only when there is a measured
performance concern or an explicit budget. Update durable acceptance when the contract changes.
