# OTP guidance documentation sync — 2026-10-12

The current identifier/OTP contract was reconciled against the two duplicate generic security-design
documents before the next handoff. This was a documentation-only correction; application code,
migrations, tests and runtime configuration were not changed.

- Repository: `/home/global/workspace`
- Branch: `feature`
- HEAD before the documentation commit: `7b2b6353fee7660f4c099d0522c6bf5f1a2ecf42`
- Changed paths: `docs/security-design.md` and `docs/spec/security-design.md`.

Both documents now explicitly label their old OTP/HOTP examples as historical generic guidance and
link the current realm-separated ceremony-verifier contract. The former OTP/HOTP section heading is
also marked historical, so its identifier-owned `otp_private_key`/`otp_counter` examples cannot be
mistaken for current UMAXICA authority.

`git diff --check`, the repository knowledge checker and the local documentation commit hook passed.
No CI, Podman, production, shared-database, external-service or acceptance operation was performed.
