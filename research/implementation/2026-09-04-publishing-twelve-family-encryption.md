# Publishing twelve-family encryption implementation notes

## Context

- Original plan: twelve physical content families + Active Record Encryption
- Related: `adr/publishing-twelve-family-encrypted-persistence.md`
- Date: 2026-09-04
- Starting SHA: `88b08c02cef15aec2dedfb9c70e861115a070bc0`

## Decisions

- DECISION: Remove `Publishing::Edition`. Locale stays on family rows. `REGION_CODE` is a family
  constant.
- DECISION: Split vocabularies, terms, assignments, and media usages per family. `MediaFile` stays
  global.
- DECISION: Non-deterministic `encrypts` on revision/version title, summary, body. Columns are
  `text`. Body is JSON-serialized Hash.
- DECISION: `content_digest` remains SHA-256 of canonical plaintext (Option A). Equality leak
  accepted; not an HMAC.
- DECISION: PostgreSQL `jsonb_typeof(body)` removed; Ruby validates Hash body.
- OBSERVED: Shared completeness/immutability triggers are parameterized with `TG_ARGV` per family.

## Tests run

- MEASURED: publishing model/operation/query tests, CMS entries controller, API contract, OpenAPI
  content contract, read-only surfaces, architecture guards, encryption raw-SQL proof.
- BLOCKED: full `bin/rails test` suite not completed in this session.
- Production/staging databases were not dropped or migrated.
