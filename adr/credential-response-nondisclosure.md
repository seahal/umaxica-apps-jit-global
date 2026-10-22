# Credential response nondisclosure

Status: Accepted, 2026-10-22. Authority: explicit user remediation request and approval of the
session payload change, Org discoverable registration and host-local DBSC advertisement fix.

## Decision

Secret attempt limits use a realm-separated normalized identifier digest for known and unknown
identifiers alike. IP limits remain independent. Database identity lookup does not choose the
observable rate-limit partition. Distinct contacts for one principal have distinct identifier
partitions. The existing account budget remains as defense across those contacts, but exhausting
it returns the ordinary generic credential refusal under the same response floor. Its callback
explicitly enforces the floor because rendering in a before-action halts after-action callbacks.
Failed CAPTCHA checks never spend either a chosen identifier's budget or its account budget.

Org Emergency options return an empty `allowCredentials` array. Selected-Operator binding remains
mandatory: the server stores the fixed-length Operator public reference in the challenge, and
an invalid fixed-length sentinel for unknown or ineligible selections. The sentinel cannot match
the Operator reference alphabet and cannot become an unbound authentication. Repeated options
responses expose no real credential descriptors, credential counts or variable-length actor ids.
Normal Entra-selected Org ceremonies retain their actor-bound descriptor path.

Org registration requires discoverable credentials and UV. This supersedes the Org resident-key
exception in `webauthn-discoverable-direct-sign-in.md`, not the normal Entra first-stage requirement.
Existing non-discoverable Org credentials are not deleted or converted. They retain the normal
Entra-bound descriptor path but need replacement through the existing authenticated registration
ceremony before Emergency Access can use them. Rollout owners must establish discoverable
credentials before relying on Emergency Access; local approval does not authorize a deployment or
credential purge. Recovery is the unchanged normal Entra-bound sign-in and registration workflow.

During the existing Bureau migration closure, the public invitation controller refuses before
looking up any code. It reports the same migration refusal for every code state. The common
surface rate limit is retained by user decision; dedicated invitation limits are deferred.

Recovery/withdrawal real and dummy cookie payloads use identical keys, fixed-length references,
expiry integers, and one-byte compensation for the JSON `true`/`false` size difference. Dummy
references are ephemeral transport padding and never authoritative identities or transactions.
The existing dummy check prevents them from reaching verification. Full issuance work is covered
by the Email response floor; verification refusals use that same floor. Operational tail latency
and provider behavior remain distinct from these bounded mitigations.

Passkey credential refusal uses one public message for missing, disabled, wrong-owner and invalid
assertions, including sign-count failures. Internal risk reasons remain distinct. Admission and
challenge-protocol failures keep their explicit responses and never grant authority. The response
budget covers both options and verification actions.

Preference DBSC registration is an explicit host-local capability. Core surface bases advertise
their canonical Preference DBSC route. Families without that endpoint return no registration
advertisement and issue no registration challenge; existing bound-credential validation remains.
No token DBSC route substitutes for a Preference endpoint, and no cross-host registration is used.

## Verification

See `specs/credential-response-nondisclosure/spec.md` for scoped acceptance and the recorded
evidence for executed checks. Response floors do not prove constant-time behavior under arbitrary
database, queue or network delays.
