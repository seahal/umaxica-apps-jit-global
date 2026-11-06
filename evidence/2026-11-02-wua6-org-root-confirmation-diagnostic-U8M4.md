# WU-A6 ORG Normal Root confirmation diagnostic

## Result

The Base ceremony-binding confirmation GET in
`OrgRootLoginEstablishmentTest#test_Entra_and_Passkey_establish_Normal_root_credentials_only_on_Visa`
still returns HTTP 400. The test does not verify this confirmation path.

## Checks performed

Command:

```text
PREFERENCE_COM_JWT_ISSUER=https://www.umaxica.com PREFERENCE_COM_JWT_AUDIENCE=com PREFERENCE_COM_JWT_REVOKED_KIDS= VALKEY_NAMESPACE_RUN_ID=wua6-diag3-20261102 PARALLEL_WORKERS=1 bin/rails test test/integration/org_root_login_establishment_test.rb:16
```

The run completed with 1 test, 72 assertions, 1 failure, 0 errors, and 0 skips. Before the failing
GET, temporary test assertions confirmed the persisted binding was an attached, live
`step_up_handoff`; its Base token reference matched the Root token; its Auth ceremony session was
active; its parent transaction was pending or verified, unexpired, and referenced the expected actor
and session; and the Base nonce digest matched the persisted binding digest. The GET still returned
the generic HTTP 400 response.

A follow-up run confirmed the access cookie was present, but
`AuthenticationToken.extract_session_id_allow_expired` returned no session id when that cookie was
decoded with host `base_host`, resource type `operator`, and issuer id `surface:BASE_ORG`. That run
stopped at this diagnostic assertion before issuing the confirmation GET (1 test, 74 assertions, 1
failure). This observation does not establish why the request's full authentication context refuses
the GET. The integration test uses one test client while crossing hosts; host-only cookie handling
is a possible explanation, not a verified cause.

The receiver inherits `Base::Org::AuthorityController`, whose contract excludes RP credentials as
authority proof. The accepted OP/Auth/RP separation ADR preserves the existing D-82 Base/Auth
contract for its existing paths but does not decide a general direct authenticated RP-to-Auth-to-RP
Step-Up protocol. Changing the receiver to the Base self-RP lifecycle would change its credential
boundary. No such change was made; reconciling that protocol remains open.

Immediately before that assertion was added, a run with the cookie-presence check passed and still
reproduced HTTP 400 on the GET (1 test, 74 assertions, 1 failure).

The later invocations used the same command with `VALKEY_NAMESPACE_RUN_ID=wua6-diag4-20261102` for
the cookie-presence run and `VALKEY_NAMESPACE_RUN_ID=wua6-diag5-20261102` for the decode run.

An intermediate diagnostic attempt encountered strict loading when it read the parent association;
the diagnostic was changed to query the parent by its foreign key. All temporary assertions were
then removed. No application or persistent test changes were made in this diagnostic slice.

The original focused test reproduction returned HTTP 400 at the confirmation GET (1 test, 56
assertions). No fix was implemented, and no full suite was run.

## Revision and worktree

- HEAD: `efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8`
- Worktree already contained uncommitted changes affecting the result: 558 tracked paths and 276
  untracked paths; the index was empty.
- Diagnostic assertions were not retained. Existing uncommitted changes to the integration test were
  preserved.
