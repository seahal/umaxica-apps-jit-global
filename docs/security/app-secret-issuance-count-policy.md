# app Secret issuance counts

This is the approved app policy. Count calculation and the protected manual
reservation step exist in the current implementation; complete registration,
allocation and delivery UI integration is still pending. See the
[decision record](../../adr/app-secret-issuance-count-policy.md).

Passkey registration allocates additional Secrets, rather than topping up to a
target balance. It uses writer DB facts when the registration's issuance reserves
capacity, for both sign-up and signed-in registration.

| Active before registration | New candidates | Active after all candidates are confirmed |
| --- | --- | --- |
| 0 | 2 | 2 |
| 1 | 2 | 3 |
| 2 | 2 | 4 |
| 17 | 2 | 19 |
| 18 | 2 | 20 |
| 19 | 1 | 20 |
| 20 | 0 | 20 |

At nineteen, explain that the maximum of twenty permits only one rather than
two. At twenty, explain that no new Secret was issued and existing saved Secrets
remain usable. The server supplies count and reason through inline feedback;
Japanese customer copy belongs in I18n. Wording distinguishes an upcoming
distribution from a completed one. Rails flash is not the feedback channel.

Twenty is normal omission: generate no Secret, candidate, reservation or plaintext
payload, and require no new Secret storage declaration. A registration meeting
its other requirements can finish. Keep the omission bound to that registration
so later retries do not allocate a batch after capacity changes.

Manual addition produces one candidate per authorized operation, including at
nineteen; at twenty it explains that addition is unavailable. A pending issuance
is a separate conflict: eighteen active plus two reserved does not mean twenty
active. Another session cannot obtain the pending candidate set or plaintext.

The manual reservation operation currently commits a one-slot allocation and
source audit under the Client lock without generating candidates or plaintext.
It rereads the owning session and scoped Step-Up before either starting or
returning an existing allocation. An expired result stays expired on ordinary
retry; another explicit operation may use the freed capacity without a cleanup job.
Separate writer-connection tests cover simultaneous manual starts at eighteen,
nineteen and twenty active credentials. Passkey/manual competition and confirmation
races remain to be tested when those operations are connected.

Owner cancellation releases its reservation and retires unconfirmed candidates
and payload in the same Zenith transaction as source audit. An ordinary retry of
that operation remains canceled rather than starting another allocation. Expiry
cleanup preserves the derived expired state and only prepares remaining candidates
and payload for recovery; capacity was already freed at the expiry timestamp.
Separate-connection races cover cancellation versus a new reservation and expiry
cleanup versus a new reservation. The latter leaves the new operation's one-slot
reservation intact. Neither cleanup extends an existing terminal deadline.

The candidate quantity stays fixed after reservation. Expiry frees the reserved
capacity without waiting for a job, but the expired issuance cannot be confirmed.
Storage declaration is an explicit user assertion about the presented set; it
is neither authentication evidence nor successful Step-Up. Candidates remain
unusable until the entire set is confirmed atomically.

Ordinary validated updates cannot clear or replace a stored presentation or
confirmation timestamp. A confirmed allocation keeps R at zero, including after
its former reservation deadline. This preserves recorded facts; the protected
presentation and atomic batch-confirmation operations are still unfinished.

Consumption from two to one to zero is ordinary use. With a usable Passkey,
that balance alone causes no warning, automatic addition, forced navigation,
registration refusal or login restriction. Lack of another permitted Step-Up
method still prevents sensitive changes; low balance never exempts Step-Up.
