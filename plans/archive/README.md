# Plans archive

Historical proposals and cycle archives. Nothing here is normative or evidence, and nothing here is
maintained against the current implementation. See
[knowledge architecture](../../docs/reference/repository-knowledge-architecture.md).

## Cycle archives

A cycle archive keeps the working documents of one significant implementation cycle (implementation
plan, detailed definitions, addenda, acceptance definitions, reports, notes) as a clue to why the
implementation took its shape.

- Directory: `NNNN-<slug>/`. `NNNN` is a four-digit generation number, one higher than the highest
  existing generation; `<slug>` is a short lowercase hyphenated topic. Dates are informational only.
- Each archive has a `README.md` with its title, generation, approximate period, outcome, what was
  stopped or deferred, links to where lasting results went, and a table from working file names to
  archived file names.
- Archived files have descriptive English names and English content. They are frozen snapshots: only
  a one-line archive note under the title and relative-link rewrites are added.
- Before closing a cycle, move anything that must keep holding into `adr/`, `docs/`,
  `docs/checklists/`, `plans/backlog/` or `evidence/`. A cycle archive may be deleted at any time,
  so nothing may depend on it alone; references to it are provenance only.

| Generation | Archive                                             |
| ---------- | --------------------------------------------------- |
| 0001       | [OP/RP separation](0001-op-rp-separation/README.md) |
| 0002       | [Authentication cycle 2026-10](0002-authentication-cycle-2026-10/README.md) |
