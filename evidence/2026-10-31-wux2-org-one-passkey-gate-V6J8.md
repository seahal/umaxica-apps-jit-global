# Historical A30-6: ORG one-Passkey restriction

HEAD: `336811e5072a93c0523e484f905082635b28f48f`. The worktree had extensive uncommitted changes, including the gate and integration test; the results apply to that worktree.

The existing ORG Step-Up journey passed before the probe: 1 run, 21 assertions. A temporary case using the test-created operator reduced its active Passkeys to one, then requested the Passkey inventory. The request returned HTTP 200 where the test expected the existing registration redirect, and failed after 2 assertions. The temporary failing case was removed.

`OrgSecondPasskeyGate` currently allowlists the Passkey controller prefix without distinguishing actions. The historical A30-6 and D-132 require restriction to registration and sign-out, with protocol paths available to complete registration. Only inventory GET was reproduced; update, deletion, registration, sign-out and deployed behavior were not tested in this probe. No production fix was made. A response-contract proposal was presented for owner review: existing HTML registration redirect and JSON `SECOND_PASSKEY_REQUIRED` refusal for non-registration actions.
