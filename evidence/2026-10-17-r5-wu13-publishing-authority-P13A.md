# R5-WU13 Publishing authority boundary

Date: 2026-10-17 UTC. HEAD `17903f7d121aa33efe29f2db9235c9aa5db4b001`; uncommitted worktree.

- Authority (Publishing-owned, Base org host): `/api/v0/publishing/:surface/:audience/entries`
  (index/show/create/update), `.../entries/:ref/publications` (create/destroy),
  `.../entries/:ref/archive` (create/destroy); fixed 12-cell constraint. Each request requires an
  edit-org-ww private_key_jwt bound to the exact URL (no query string) and the Operator Access JWT
  authenticated for edit-org-ww; the authority applies `PublishingEntryPolicy` with the real
  Operator and calls the existing Forms/Operations. Answers are allowlisted JSON
  (`PublishingManagementEntrySerializer`), 422 with errors + entry, 401/403/404 otherwise.
- Edit RP: `PublishingAuthorityClient` (typed outcomes; non-2xx/transport → dependency, no blind
  retry) and `PublishingRemoteResultPolicy`; the CMS concerns render from authority DTOs and no
  longer call Publishing queries, models or Operations. Forms still validate input shape locally.
- Incident: a first draft overwrote the existing public `PublishingEntrySerializer`; restored from
  HEAD (index==HEAD), new class named `PublishingManagementEntrySerializer`.
- Results: `test/controllers/edit` 48 runs, 0 failures (CMS list/show/create/revise/publish/end/
  archive/unarchive through the in-process authority).
- Not done: Edit controllers still declare `ENTRY_CLASS` constants (class reference only, no SQL);
  explicit per-operation S samples are the implemented request/response shapes above.
