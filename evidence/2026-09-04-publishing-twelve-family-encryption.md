# Publishing twelve-family encrypted persistence

Date: 2026-09-04

## MEASURED

- Starting SHA: `88b08c02cef15aec2dedfb9c70e861115a070bc0` on `feature`.
- Local test publishing database rebuilt with
  `RAILS_ENV=test bin/rails db:drop:publishing db:create:publishing db:migrate:publishing` against
  host `primary` (`test_publishing_db`). Schema migration `CreatePublishingSchema` and vocabulary
  seed completed.
- `bin/rails test test/models/publishing/` plus operations, queries, CMS entries controller,
  `publishing_entry_api_contract_test`, `info_surface_publishing_test`, OpenAPI content contract,
  and `read_only_surfaces_test` were run after the rewrite. Encryption test proved raw
  `title`/`summary`/`body` columns do not contain known plaintext and two identical plaintexts
  produce different ciphertext.

## Production safety

- no production database was modified
- no production deployment occurred
- no Cloudflare/AWS/Neon mutation occurred
