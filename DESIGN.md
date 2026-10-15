# Design

This file owns UI/UX, visual appearance, layout, styling, and interaction design for every
user-facing view and screen.

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
