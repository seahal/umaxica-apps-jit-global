# Finalized identifier HMAC rotation blocker

Commit: `48ff7040de2b50a8a08ed660fa71878a029ba577`.
The worktree had uncommitted changes, including the new rotation regression cases.

Existing scoped rotation tests exercised only unfinalized stale digests. Four new APP/COM ×
Email/Telephone cases finalize ownership before changing the selected HMAC key. The first run
changed only ENV, while Rails combined credentials retained their cached configured value, so the
digest did not change (13 runs, 126 assertions, four failures). The test now selects its explicit
ENV-backed replacement through the existing configuration seam, without mocking the rotation itself.

`bin/rails test test/services/realm_identifier_hmac_rotation_test.rb` then produced 13 runs,
118 assertions, zero failures, four errors, no skips. All four errors are PostgreSQL's existing
`effective contact binding owner and digest are immutable` exception. The rotation operation reaches
its real record save and the APP/COM binding-fact triggers reject it. These triggers exist in HEAD's
Contact migrations; the defect is an existing incompatibility newly exposed by acceptance coverage,
not a failure caused by channel budget separation.

No trigger was disabled, no permission flag or fallback was added, and the failing tests remain.
A restricted realm/channel maintenance role and guarded forward-trigger change were proposed for
explicit approval. Normal role ownership/PII/binding protections must remain enforced. No database
role, production credential or migration implementing that proposal has been changed.
