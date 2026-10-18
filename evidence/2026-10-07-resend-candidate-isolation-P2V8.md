# Email resend candidate isolation and explicit dependency failure

- Commit: `6fa6867d44b5499632079775cb0fb22cbfddd339`.
- Worktree had inherited and current uncommitted changes.
- Owned `20261007fresh3` test manifest, seed 42, one Rails test process at a time.

The dependency-failure regression first failed (2 runs, 2 assertions, one failure): the resender
returned invalid state instead of raising. It now reports `handled: false` and propagates the
original failure. Provider-failure coverage retains the consumed cooldown slot and verifies a
second request is blocked without another provider attempt. Invalid signatures remain normal
non-disclosing refusals, not operational failures.

Two new app/com regressions create independent same-destination pending candidates before the
effective owner. Both first failed (2 runs, 4 assertions): delivery selected the oldest candidate.
The resender now uses only the effective binding, whose destination cardinality is DB-enforced,
and rechecks lock/release state before rotating its OTP. The destination-wide clear loop and its
silent per-record error continuation were removed. Tests verify delivery selects the effective
owner and every independent candidate attribute remains unchanged. Existing real-delivery fixtures
establish binding facts through the public finalization method.

An intermediate implementation used an unavailable Rails finder and failed with six errors and
one failure. Installed framework source was checked and the supported `take` finder used under
the partial UNIQUE invariant. This regression was repaired, not classified as environment failure.

```bash
bin/rails test test/services/sign_in_otp_resender_failures_test.rb \
  test/services/sign/in/otp_resend_service_test.rb \
  test/services/sign/in/otp_resend_policy_test.rb --seed 42
```

Behavioral result: **21 runs, 94 assertions, zero failures, errors or skips**. After test formatting,
the combined eight-file signup OTP, Contact audit and resend matrix also passed at seed 42:
**61 runs, 459 assertions, zero failures, errors or skips**.
Complete flow/browser-bound resend evidence, purpose/state checks at late delivery, timing
parity, and Final Verification remain open; no Phase 19 acceptance checkbox was closed by this slice.

## HTTP admission boundary

New independent-browser app/com tests used a correctly signed resend state without confirmed
admission. Both initially failed because the endpoint allocated an EmailOccurrence dispatch slot
(2 runs, 4 assertions, two failures). Both endpoints now require the same confirmed sign-in
ceremony admission as email verification and keep FQDN validation first. Tests arrange existing
admitted endpoint contexts via public issue/attach/confirm/redeem, while the attack browser has an
independent cookie jar. Existing APP real-delivery fixtures now establish effective bindings.
The COM fixture initially changed its host only after redemption, losing the correctly scoped
cookie; setting the browser host before admission repaired that fixture without changing cookies
or weakening admission.

Both complete endpoint files passed at seed 42: **7 runs, 46 assertions, zero failures, errors or
skips**. Scoped RuboCop corrected six formatting offenses and exited 0. This prevents an
unadmitted browser from using a signed resend state, but does not yet prove that two independently
admitted browsers cannot exchange states; strict originating flow/browser binding remains open.

## Originating Auth continuity

An APP real-HTTP state issuance followed by an independently admitted second browser reproduced
one unauthorized dispatch reservation (1 run, 11 assertions, one failure). Earlier fixture
iterations hit canonical region redirects or read the wrong Inertia embedding; the existing
InertiaPageObject reader and explicit region corrected those fixtures before the actual red case.

State issuance/parsing and the resender now require `browser_binding:` supplied by the admitted
Auth continuity's persisted digest. The existing AES-GCM MessageEncryptor purpose incorporates
that binding; a purpose mismatch normally refuses before dispatch. The installed framework source
documents purpose mismatch returning nil, which is handled explicitly. No raw sid, request-owned
binding input, key rotation, optional legacy path or new persistent budget key was added.
APP and COM independent-admitted-browser HTTP tests both verify no dispatch reservation.
Public state-interface tests cover 63/64/65 characters, lowercase hex classification, missing,
empty, zero, false and array inputs, and another valid 64-character binding.

The seven-file email sign-in/resend service/policy/HTTP matrix passed at seed 42:
**95 runs, 733 assertions, zero failures, errors or skips**. This certifies originating continuity
binding, not candidate/owner snapshots, delivery-time lifecycle checks or complete timing parity.
