# OIDC Private Key JWT Clients

ACME and Core OIDC RP clients now support `private_key_jwt` client authentication at the token
endpoint. The JWT registry has dedicated `oidc_client:*` issuers for:

- `ACME_APP`, `ACME_COM`, `ACME_ORG`
- `CORE_APP`, `CORE_COM`, `CORE_ORG`

These keys are intentionally separate from surface Jump RT keys. Configure them with
`OIDC_CLIENT_<NAMESPACE>_ACTIVE_KID`, `OIDC_CLIENT_<NAMESPACE>_PRIVATE_KEY`, optional
`OIDC_CLIENT_<NAMESPACE>_PUBLIC_KEYSET`, and optional revoked kids.

`client_secret_post` remains available as fallback for clients that do not have a configured OIDC
client assertion key.
