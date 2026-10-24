# WU-05d … WU-05g: Google/Apple sign-up finalized in Auth, Sign In First

Commit: `ba570a0007b1d40eabe32990a34831317fd98a93`, with this cycle's uncommitted changes in the
worktree.

## Changes

- **WU-05d (P1–P5, C1, birthdate)**
  - `SignUpSocialPendingClientSupport#bind_social_pending_client!` runs on the Google/Apple
    confirmation PATCH, after the ceremony-bound Turnstile. It re-checks the Candidate, then creates
    one `UNVERIFIED_WITH_SIGN_UP` Client under the Flow lock and records it on the Flow
    (`principal_id`, `pending_contact_type: social_identity`). A repeat keeps the existing Client.
  - The Candidate's `expires_at` is now `min(Flow expiry, Binding curfew_at)`.
  - `SignUpSocialBirthdateSupport` is deleted. The social birthdate pages use the shared
    `clear_sign_up_birthdate_requirement`, which stores the birthdate on the pending Client.
  - `SignUpArtifactCleanup` retires a contact-less social pending Client, under the principal lock,
    while no External Identity is linked to it.
- **WU-05e (F1–F5)**
  - `finalize_app_sign_up_actor!` has its own `social_identity` branch. It consumes the Candidate
    once, under the Flow lock, then runs `SocialAuthSignupFinalizer` with `user:` (the pending
    Client).
  - The finalizer re-checks the subject under `with_subject_lock` and `released_since_ceremony?`. It
    writes the External Identity and `VERIFIED_WITH_SIGN_UP` in one principal transaction, and
    refuses a Client that is not pending.
- **WU-05f (S1–S3)**
  - The shared handoff (`handoff_to_sign_in_flow!`) now serves Google and Apple.
  - `oidc_flow_evidence_open?` accepts the provider evidence the callback already recorded on the
    ceremony, for the same Google/Apple method only, and records the Sign In flow's own evidence.
  - Any other recorded ceremony evidence still closes the attempt.
- **WU-05g:** removed:
  - the Base `/social/authentication/completion` route and controller;
  - `IdentitySocialCeremonyFinalCommitter`, `ExternalAuthenticationSignupUseCase`,
    `IdentitySocialCeremonyResultIssuer`, `IdentitySocialCeremonyResultConsumer`,
    `SocialCeremonyResultAdapter` and `IdentitySocialCeremonyResult`;
  - their tests.
- **Guards:** stale allowlist entries were updated (forbidden patterns, untrusted decode, redirect
  targets).
- **Docs:** mermaid (`idp-client-social-ceremony`, `idp-identity-social-candidate`, inventory),
  `docs/security/session-limit.md` and `docs/security/authentication-remediation.md`.

## Tests

- **Rewritten journeys:**
  - `SocialLoginAdmissionTest` "an unknown signup completes …":
    - the confirmation creates 1 Client;
    - the birthdate step creates 1 External Identity and no token;
    - the Flow is completed and the graph is present;
    - driving the browser through Sign In First gives Base exactly one Root, whose
      `authentication_event_at` equals the provider ceremony's;
    - the OIDC transaction is consumed.
  - `Base::App::Social::AuthenticationsControllerTest` "completion provisions …": the same
    assertions up to the Sign In flow handoff.
- **New:** `SocialAuthSignupFinalizerTest` covers promoting the pending Client, refusing a subject
  already linked to another Client, and refusing a Client that is not pending.
- **Updated:** `SocialAuthLoginTest` under-age and stale-checkpoint cases now expect the one
  unfinished pending Client.
- **Deleted, because their subject was removed:**
  - the transport tests listed above;
  - four Base-completion cases (outage resume, Avatar failure inside Base completion, notice-free
    redirect, cancelled candidate at Base).
- **Coverage gap:** an Avatar/graph failure after the decisive commit has no test on the new path.

## Runs

- Full suite (full-21): 18438 runs, 56 F / 2 E.
- Against the G-1 names the only new names are the two `SignUpPasskeyTerminationHttpTest` deadline
  cases (timing-dependent, already recorded as flaky; they pass alone).
- **Not done:**
  - the Curfew check (D-105) at Finalization is WU-06;
  - the dead `social_resolution?` branch in `Base::App::Sign::In::LimitationsController` remains and
    is left for a follow-up.

## Current reconciliation

The current Visa split and Auth-finalization journey was re-run with separate Base, Visa and Auth
browser contexts. The social callback, auto-linking, entry/start contracts and checkpoint
cancellation batch passed **33 runs, 235 assertions, 0 failures and 0 errors**. The full historical
WU-05 acceptance set remains broader than this focused batch.
