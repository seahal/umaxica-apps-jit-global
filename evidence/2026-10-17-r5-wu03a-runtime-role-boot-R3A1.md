# R5-WU03A runtime role boot selection (first packet)

Date: 2026-10-17 UTC. HEAD `17903f7d121aa33efe29f2db9235c9aa5db4b001`; uncommitted worktree with
R1-R3/R5 changes. Environment construction: verified by execution, not Minitest
(`project/no-environment-tests.mdc`).

Change: `lib/runtime_role.rb` (fixed role allowlist, required `UMAXICA_RUNTIME_ROLE`),
`config/application.rb` (per-role credentials paths, boot refusal on missing bundle/key),
`UMAXICA_RUNTIME_ROLE=shared` added to `.env.example`, `.env.devcontainer.example` and local `.env`.

Observed (`bin/rails runner`, development):

- default `.env` (`shared`): role `shared`, credentials path
  `config/credentials/development.yml.enc`.
- `UMAXICA_RUNTIME_ROLE=rp-core-app-jp`: before the boot check it booted with an empty bundle
  (silent); after the check boot stops with `missing credentials bundle for role rp-core-app-jp`.
- `UMAXICA_RUNTIME_ROLE=bogus`: boot stops with `RuntimeRole::UnknownRole`.

Not done yet: per-role bundles/keys, removal of secrets from shared `.env`, per-role DB logins,
queue isolation, AT-R5-03A. Container split declined by the user; recorded as a known gap.
