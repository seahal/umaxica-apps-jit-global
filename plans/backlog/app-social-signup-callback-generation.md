# Bind App Social Sign-Up Callbacks to a Current Generation

Status: backlog. The owner deferred this on 2026-11-02 because the design is not settled. Nothing
below is approved or started.

## Problem

An App Google or Apple sign-up callback is checked against state held in the signed session cookie.
When two tabs in one browser overlap, a callback that arrived with an older cookie can pass that
check while another tab restarts the provider, and its response can write the older session back.
The other tab's callback then fails. The server has no durable record of which start is current.

Sequential restarts are already refused; see
`evidence/2026-11-01-wua2-social-signup-back-restart-R7M4.md`. No account takeover has been shown,
and no occurrence has been identified in logs. Both the race and its frequency are unmeasured.

## Candidate

`plans/2026-11-01-wua2-social-callback-generation-shape-review.md` proposes persisted one-time
callback generations. That proposal needs owner shape and local migration approval. Claude Code has
not completed a review of it.

## Open Before Implementation

- Reproduce the race with both request orderings, or show that it cannot occur.
- Decide whether a smaller change is enough, given the new tables the candidate adds.
- Check overlap with the App registration completion receipt work in the social finalizer.

## Acceptance

Both concurrent orderings, provider switching, cancellation, cross-parent attempts and replay. A
stale callback creates no authority and writes no old session cookie. No existing check is relaxed.
