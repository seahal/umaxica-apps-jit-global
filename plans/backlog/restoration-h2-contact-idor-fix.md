# Restoration H2: Contact IDOR Fix (Audit High)

Extracted from `plans/archive/global-repo-restoration-plan.md` (2026-05-07).

## Source

- `../../adr/audit-findings-2026-03-30.md` (High severity)

## Goal

Close the contact-side IDOR identified in the audit. Authorization on every contact read / write
goes through Action Policy (D1) rather than ad-hoc `current_user.contacts.find(id)` patterns.

## Key surface

Contact controllers and policies.

## Verification

Test that user A cannot read or write user B's contact, even by ID guess.

## Related

landing first.
