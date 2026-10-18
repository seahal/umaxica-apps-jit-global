# Tech Browser RP rollout and recovery

Tech is the independent `tech-org` Operator RP on `tech.umaxica.org`, with private origin
`tech.org.localhost`. Its actor and capability records use `org_zenith`; Device, root and RP session
records use `op_base_org`. Storage sharing with Edit does not share credentials, client assertions,
host cookies or business authorization. See the accepted
[participation ADR](../../adr/tech-and-palm-browser-rp-participation.md).

This procedure prepares a separately authorized rollout. External configuration, production grants
and deployment have not been performed by the local implementation work.

## Prerequisites and owners

| Area           | Required preparation                                                                                                                                                            | Owner                    |
| -------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------ |
| Rails hosts    | Set `PUBLIC_TECH_STAFF_URL=tech.umaxica.org` and `PRIVATE_TECH_STAFF_URL=tech.org.localhost`; verify the Tech route and host authorization independently of health probes       | Rails operator           |
| Private origin | Confirm the connector and Rails share the private frontend network and the Tech alias resolves to Rails port 3000                                                               | Infrastructure operator  |
| Access         | Create and validate the Tech-specific Access application and intended operator policy before publishing the hostname                                                            | Cloudflare account owner |
| Tunnel and DNS | Merge the Tech hostname into the current browser tunnel ingress, targeting `http://tech.org.localhost:3000`; preserve other ingress entries and the separate Workers VPC tunnel | Cloudflare account owner |
| Keys           | Provision dedicated `TECH_ORG` client assertion material and the corresponding verification configuration                                                                       | Key owner                |
| IAM            | Identify eligible named operators and the audited initial-grant procedure                                                                                                       | IAM operator             |

Follow the [private origin contract](cloudflare-private-origin.md) for transport, Access, Host
Authorization and route gates. A healthy `/health` response alone does not verify the Tech host
boundary. Do not add a Tech Jump edge or a backchannel logout receiver.

## Client assertion keys

The required namespace is `TECH_ORG`, with `OIDC_CLIENT_TECH_ORG_ACTIVE_KID` and
`OIDC_CLIENT_TECH_ORG_PRIVATE_KEY`. The registry also consumes `OIDC_CLIENT_TECH_ORG_PUBLIC_KEYSET`
and `OIDC_CLIENT_TECH_ORG_REVOKED_KIDS` for public/grace and revocation configuration. Public
keysets contain only public material. Use the existing [JWT rotation procedure](jwt-key-rotation.md)
and registry validation; never copy Edit's private key or use its namespace as a fallback.
Development/test material is managed by the existing local keyset installer; it is not production
key provisioning.

Boot with the intended environment and confirm the registry admits `tech-org` with audience
`tech-org` and the dedicated namespace. Record only the validation outcome and public key
identifiers, never private keys, assertions, tokens or cookies. Each published JWKS endpoint must
satisfy its existing one-to-four-key and byte-size limits before release.

## Initial IAM and delegation

Use the audited [Operator capability runbook](operator-capability-runbook.md). Confirm the Chronicle
`compliance` retention policy exists before a mutation. In development, dry-run the existing
bootstrap for one explicitly identified eligible Operator and `tech.access`, with the change ticket
and finite expiry. Apply only through that same audited bootstrap after validating its target and
inputs. Do not insert grants directly, create a temporary allow-all, or create a production grant as
part of local verification.

Subsequent delegation uses the existing IAM flow. The granter needs current `iam.capability.read`,
`iam.capability.grant` and `tech.access`; self-grant is refused. Preserve the required Step-Up,
reason and Chronicle audit. Grant intervals are finite and at most 366 days. Operator eligibility,
Entra login and access to Edit do not substitute for `tech.access`.

## Browser acceptance

Use controlled operators with and without the capability and record ACCEPT/REJECT separately:

1. Open `/` and GET/HEAD `/sign`; neither creates a flow. Submit `/sign` with a same-session
   authenticity token and complete the normal Base/Auth Code+PKCE flow.
2. With a valid grant, verify `/dashboard` shows the empty tools state and sign-out navigation.
   Without the grant, verify a no-store 403 with sign-out and no protected content or newly issued
   Tech authentication cookie.
3. Revoke the grant after a successful login; the next protected request and both refresh paths must
   refuse it. Sign-out must remain available.
4. Run simultaneous Edit and Tech flows; failures, callback replay and replacement must preserve the
   other flow and its credentials. Test wrong state, nonce, issuer, audience and return target.
5. Start shared sign-out from Tech and another participating RP; confirm captured-parent authority,
   protected completion POST and refusal of revoked credentials at the next request. An absent or
   different IdP session must produce the plain error without revoking the origin.

Local automated results do not substitute for these browser observations or external rollout gates.

## Close-Tech recovery

If Tech publication is unsafe, the infrastructure owner denies new Tech traffic using its own Access
application and removes or disables only the Tech public hostname/ingress through the account's
recovery process. Preserve the other RPs, browser tunnel entries and Workers VPC path. Record the
change and recovery conditions. This containment does not itself revoke sessions.

Retain grant rows, revocation facts, identity bindings, RP session history and Chronicle records. If
authority must be revoked, use the existing audited IAM revocation path and reconcile any unknown
audit result before retrying. Global sign-out intentionally affects the captured parent and its
children; do not use it to implement a Tech-only infrastructure closure.

Keep required Tech configuration while the application still registers `tech-org`; removing keys
alone can prevent the shared Rails application from booting. Recover by forward repair of the
specific host/key/grant dependency and repeat the gates before reopening. If existing `tech.access`
grant history makes the catalog migration reversal unsafe, retain the catalog and constraint and
repair forward. Never delete grant or audit history to make rollback succeed.
