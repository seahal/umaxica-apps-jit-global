# WU-02 review: Visa split test migration (partial)

Commit: `ba570a0007b1d40eabe32990a34831317fd98a93`, with the uncommitted WU-02 work (Codex) and this
cycle's other uncommitted changes in the worktree.

## Review result

The WU-02 production design (`adr/visa-op-host.md`) is coherent:

- Visa OP and Base RP have separate host-only sessions and separate `VISA_*` / `BASE_*` key
  namespaces.
- There is no Base OP fallback or alias.
- The Cancel and curfew exits were moved to `visa_*_oauth_authorization_url`.

No production defect was found in the parts checked. The large suite regression was in test support
and in test flows that still assume the pre-split Base OP.

## Fixed (test support and test flows only)

- **Owner APIs over HTTP:** `test/support/in_process_op_transport.rb` now also routes the owner APIs
  on the Base hosts in-process. `base_for_resource_type` returns an `OriginValue`, so it compares
  its `host`. This removed 322 "outbound HTTP is not stubbed" errors.
- **Shared helper:** `visa_host_for_test_base_host` in `test/test_helper.rb`.
- **Hand-written admission setups (13 files):**
  - the authorization step is expected on Visa;
  - the browser switches to the target host before the GET;
  - later POSTs use the Visa Origin;
  - Jump `rt` values are unwrapped with `jump_rt_url_from_location_for_test`.
- **Host-to-surface maps (25 files):** Visa hosts added.
- **Email sign-up `assert_includes [base_host, auth_host]` variant (5 files):** the Visa host is
  accepted.
- **`app_secret_signup_journey_test.rb`:** the second Jump hop is verified with `VISA_APP` and the
  Visa issuer host.

## Runs

- **full-24** (Codex state, before these fixes): 18462 runs, 208 F / 465 E; 587 names not in G-1.
- **full-25** (after the support and setup fixes): 18462 runs, 216 F / 15 E; 170 names not in G-1.
- After full-25, the email sign-up variant fix: those 5 files pass (48 runs, 0 F).
- No full run was made after that.

## Remaining (not done; for the next implementer)

These are mostly tests that still call or expect Base (`www`) for endpoints that now live on Visa
(404s, "Expected www, Actual visa"). The highest counts in full-25:

- `test/controllers/base/edge_v0_token_refresh_binding_test.rb` and
  `edge_v0_token_refreshes_test.rb` post to Base hosts, but the edge-token routes moved to
  `config/routes/visa.rb`.
- `auth_invalid_cookie_recovery_test`, `telephone_signup_source_proof_retry_test`,
  `telephone_signup_http_delivery_test`, `sign_out_inertia_history_clear_test`, `oidc_rp_logout_*`.
- `sign_up_checkpoint_cancellation_test`, `oauth_redirect_uri_conformance_test`,
  `ceremony_admission_boundary_test`, `org_oidc_auth_handoff_root_completion_test`,
  `core/warp sign/outs`, `oidc_discovery_route_stability_test`.
- Each must be checked against the Visa route ownership before its expectation is changed. Do not
  weaken an assertion to make it pass.
- The WU-07 refusal catalogue (`SignInPathRefusalValue`, `SignInPathRefusal`) was subsequently
  verified with the resolver and Sentry boundary: 26 runs, 359 assertions, no failures or errors.

## Reconciliation

The remaining WU-02 browser migrations were completed for the current Rails slice. The OIDC RP
browser flow and ORG handoff tests now follow Visa's authorization and result resources, including
the automatic navigation confirmation and the terminal result replay rule. The old Base OP form
sequence is no longer asserted.
