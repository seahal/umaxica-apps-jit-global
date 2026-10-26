# Visa Jump RT edge handoff

This document is the Rails-side handoff for the Visa OP host split. The Edge/Jump service is a
separate system and is not changed or integration-tested by this repository.

Each row names a directed edge. `iss` is the origin of the issuer namespace and is also the origin
whose `VISA_*` or existing surface JWKS endpoint must be used. The signed `url` is on the
destination origin. The JWT `aud` remains the configured Jump audience (`https://jump.umaxica.net`);
it is not the destination origin.

| Issuer namespace | Issuer origin | Destination namespace | Destination origin | Purpose |
|---|---|---|---|---|
| `AUTH_APP` | `https://auth.umaxica.app` | `VISA_APP` | `https://visa.umaxica.app` | authentication result |
| `AUTH_COM` | `https://auth.umaxica.com` | `VISA_COM` | `https://visa.umaxica.com` | authentication result |
| `AUTH_ORG` | `https://auth.umaxica.org` | `VISA_ORG` | `https://visa.umaxica.org` | authentication result |
| `VISA_APP` | `https://visa.umaxica.app` | `AUTH_APP` | `https://auth.umaxica.app` | authentication ceremony |
| `VISA_COM` | `https://visa.umaxica.com` | `AUTH_COM` | `https://auth.umaxica.com` | authentication ceremony |
| `VISA_ORG` | `https://visa.umaxica.org` | `AUTH_ORG` | `https://auth.umaxica.org` | authentication ceremony |
| `BASE_APP` | `https://www.umaxica.app` | `VISA_APP` | `https://visa.umaxica.app` | authorization start |
| `BASE_COM` | `https://www.umaxica.com` | `VISA_COM` | `https://visa.umaxica.com` | authorization start |
| `BASE_ORG` | `https://www.umaxica.org` | `VISA_ORG` | `https://visa.umaxica.org` | authorization start |
| `CORE_APP` | `https://jp.umaxica.app` | `VISA_APP` | `https://visa.umaxica.app` | authorization start |
| `CORE_COM` | `https://jp.umaxica.com` | `VISA_COM` | `https://visa.umaxica.com` | authorization start |
| `CORE_ORG` | `https://jp.umaxica.org` | `VISA_ORG` | `https://visa.umaxica.org` | authorization start |
| `WARP_APP` | `https://www-jp.umaxica.app` | `VISA_APP` | `https://visa.umaxica.app` | authorization start |
| `WARP_COM` | `https://www-jp.umaxica.com` | `VISA_COM` | `https://visa.umaxica.com` | authorization start |
| `WARP_ORG` | `https://www-jp.umaxica.org` | `VISA_ORG` | `https://visa.umaxica.org` | authorization start |
| `PALM_APP` | `https://palm-jp.umaxica.app` | `VISA_APP` | `https://visa.umaxica.app` | authorization start |
| `VISA_APP` | `https://visa.umaxica.app` | `BASE_APP` | `https://www.umaxica.app` | authorization response |
| `VISA_COM` | `https://visa.umaxica.com` | `BASE_COM` | `https://www.umaxica.com` | authorization response |
| `VISA_ORG` | `https://visa.umaxica.org` | `BASE_ORG` | `https://www.umaxica.org` | authorization response |
| `VISA_APP` | `https://visa.umaxica.app` | `CORE_APP` | `https://jp.umaxica.app` | authorization response |
| `VISA_COM` | `https://visa.umaxica.com` | `CORE_COM` | `https://jp.umaxica.com` | authorization response |
| `VISA_ORG` | `https://visa.umaxica.org` | `CORE_ORG` | `https://jp.umaxica.org` | authorization response |
| `VISA_APP` | `https://visa.umaxica.app` | `WARP_APP` | `https://www-jp.umaxica.app` | authorization response |
| `VISA_COM` | `https://visa.umaxica.com` | `WARP_COM` | `https://www-jp.umaxica.com` | authorization response |
| `VISA_ORG` | `https://visa.umaxica.org` | `WARP_ORG` | `https://www-jp.umaxica.org` | authorization response |
| `VISA_APP` | `https://visa.umaxica.app` | `PALM_APP` | `https://palm-jp.umaxica.app` | authorization response |

The corresponding JWKS endpoints are:

- `https://visa.umaxica.app/.well-known/jwks.json` for `VISA_APP`;
- `https://visa.umaxica.com/.well-known/jwks.json` for `VISA_COM`;
- `https://visa.umaxica.org/.well-known/jwks.json` for `VISA_ORG`.

Jump must continue to refuse unsigned or malformed tokens, an `iss` that does not match the key
namespace, an `aud` other than the configured Jump audience, an unknown or look-alike host, a source
and destination pair absent from the Rails edge catalog, private destinations, URL userinfo or
fragments, and replay-policy or schema values outside the established contract. Rails keeps the
existing signature, CSRF, return-URL and host checks; the Edge integration is a follow-up after the
Rails-side contract lands.
