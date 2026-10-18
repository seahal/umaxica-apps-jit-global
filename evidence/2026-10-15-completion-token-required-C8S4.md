# Completion continuation requires the Rails authenticity token

Recorded 2026-10-15 UTC against commit `7d4e2d941f4eb576eb77076c2c2a4e54badfa847`, with uncommitted
application/test/documentation changes present.

REQ-006's completion contract explicitly requires CSRF in addition to the captured intent proof.
Added a valid-proof POST carrying invalid form/header authenticity tokens with same-origin Fetch
Metadata to each of the twelve registered clients. Red: Core APP accepted it and returned 303 (1 run
/ 65 assertions / 1 failure). Rails' hybrid provenance strategy permits same-origin without
consulting the token, so the completion boundary lacked its additional required token check.

The shared continuation now invokes Rails' authenticity-token validation and existing unverified
request instrumentation/handler before transaction lookup and mutation on unsafe requests. GET/HEAD
remain read-only; Rails protection settings, Origin/Fetch Metadata checks and intent proof
verification remain in force. No custom Rails verification override or acceptance was added.

Final completion matrix, authority-first, Palm completion and Tech completion selection passed 8
runs / 774 assertions / 0 failures / 0 errors / 0 skips with the normal Rails test database manifest
and isolated-run identifier unset. Every client rejects invalid tokens without advancing its
transaction, then accepts the valid continuation. Targeted RuboCop inspected two files without
offenses; scoped diff checking passed. No reset or isolated fleet was used. Other acceptance
partitions and live browser/external behavior remain separate unfinished work.
