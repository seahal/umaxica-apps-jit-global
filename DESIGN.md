# Design

This file owns UI/UX, visual appearance, layout, styling, and interaction design for every
user-facing view and screen.

## Keyboard Interaction

User-facing views and screens **MUST** follow the applicable guidance in Apple's
[Human Interface Guidelines: Keyboards](https://developer.apple.com/design/human-interface-guidelines/keyboards).
Apply the guidance to the platforms and input methods supported by each surface, including browser
interfaces used with hardware or onscreen keyboards.

When implementing or changing keyboard interactions, implementers **MUST** consult the current
guideline and verify the affected interactions on the supported platforms. Reviewers **MUST** check
the applicable guidance during design and implementation review. Any platform-specific guidance that
does not apply to a browser interface **MUST** be identified with its reason in the change
description.

This requirement defines the design policy; it does not establish that existing interfaces have been
audited or conform to the guideline.

## User-Facing Copy Describes Outcomes, Not Internals

User-facing views, screens, messages, and error pages **MUST** describe what the user can do and
what happened, in terms of the user's task. They **MUST** keep internal implementation details out
of rendered text, including:

- architecture, components, services, or libraries in use
- internal state names, status values, flow steps, or identifiers
- validation order, verification mechanisms, rate limits, or other security controls
- data storage, retention mechanics, or processing pipelines

Why: exposed internals let an attacker infer security controls and their order, and let competitors
copy the design. Keep explanations of internal behavior in `docs/`, ADRs, and code comments.
