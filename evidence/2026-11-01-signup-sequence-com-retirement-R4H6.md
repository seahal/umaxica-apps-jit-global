# Sign-up sequence COM retirement documentation update

- HEAD: `efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8`.
- The worktree was already dirty, including earlier edits in `docs/security/sign-up-sequence.md`;
  those APP social route updates were retained.
- Source review confirmed the Auth routes define APP user and ORG staff scopes, with no COM Auth
  route scope. The current APP sign-up controllers are under `app/controllers/auth/app/sign/up/`;
  `app/controllers/auth/com/` has no files.
- Updated the document's current route inventory and shared-flow wording to describe APP and ORG.
  Retained COM/Visitor Email and Telephone narratives under headings and notices that identify them
  as retired historical material, not current routes or implementation targets.
- `git diff --check -- docs/security/sign-up-sequence.md` passed. No application or test files were
  changed for this documentation update; no tests were run for this documentation-only change.
