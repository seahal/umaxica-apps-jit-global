# Plans

This directory contains planning material that has not yet become an implementation source of truth.

## Directories

- `analysis/` contains investigation and decision-support material. Analysis documents are not
  implementation specifications.
- `backlog/` contains proposed future work that has not yet been accepted for implementation.
- `archive/` contains historical planning material retained only when useful for traceability.

## Source of truth

GitHub issues are the source of truth for accepted active implementation work.

Documents under `plans/` MUST NOT override current accepted ADRs, explicit architecture contracts,
or current implementation decisions.

An open, recent, or detailed plan does not by itself establish current architecture.

## Lifecycle

Planning material should normally move through:

`analysis -> backlog -> GitHub issue -> implementation`

After implementation, obsolete planning documents should be deleted or moved to `archive/` only when
historical traceability is useful.

Do not maintain a parallel `active/` implementation backlog in this directory.

## Maintenance rules

- Keep planning documents in English.
- Do not keep generated prompts, agent conversation residue, or duplicated implementation
  instructions.
- Do not preserve obsolete plans merely because they contain a small amount of still-useful
  information. Move the useful information to its canonical destination and remove the obsolete
  document.
- Historical documents in `archive/` are non-normative.
- Do not place current architecture summaries in this README. Architecture belongs in the
  appropriate ADR or architecture documentation.
- Broken references and references to deleted planning paths should be removed or replaced when
  encountered.
