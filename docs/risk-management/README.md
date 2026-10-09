# Risk management

Record a real risk when its exposure, response or acceptance needs durable ownership. This is a
small Markdown register, not a claim of ISO certification or complete enterprise risk coverage.

- [Git-sourced dependency advisory coverage](risks/git-sourced-dependency-advisories.md)

Use established vocabulary informed by [NIST IR 8286 Rev. 1](https://csrc.nist.gov/pubs/ir/8286/r1/final)
(final December 2025) and [IR 8286A Rev. 1](https://csrc.nist.gov/pubs/ir/8286/a/r1/final).
The fields below are a proportional local adaptation, not the full NIST JSON schema.

A risk record identifies the scenario/asset, Risk Owner, likelihood, impact, existing controls,
response, residual risk, acceptance authority/rationale, status, and review trigger/date. Unknown
assessments and unassigned owners remain explicit; an agent cannot invent an accountable person or
approve risk acceptance. Assessment scales need a stated basis before numerical scoring is useful.

Status and response are independent. `status: active` with `response: accept` describes a present
risk intentionally accepted by the responsible authority. Other responses include avoid, mitigate,
transfer and share; record their scope and rationale rather than forcing a single status label.
Risk acceptance identifies who accepted what residual exposure, when, and under which conditions.

Link to existing control implementation and verification. Add `controls/` records only when a
control is shared across real risks and needs its own owner, objective, implementation and evidence
references. Avoid empty control inventories and duplicated Rails security documentation.

Maintain affected records when exposure or response changes and at the recorded review trigger.
Evidence records observations; a planned mitigation or a control description is not verification.
