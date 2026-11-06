# Preference And Settings Authority

## Authority

`acme/www` owns preference writes, account lifecycle, withdrawal, and dashboards.

`acme/www` owns the general identity/settings shell, preference writes, account lifecycle,
withdrawal, and session-management UI. `sign/id` owns sign-in, sign-up, verification, provider
callbacks, and credential ceremonies that still require the Auth host.

Signed-in Auth `/settings` is being retired as a general settings surface. Under accepted step-up
contract revision 13, Base owns APP TOTP management and social-provider status/unlink, and Base ORG
owns the read-only Entra status display. Auth ORG has no `/settings` route; Entra sign-in remains on
Auth and remains limited to administrator-provisioned identities. The APP Auth route migration and
Visa-mediated link admission remain incomplete; until those slices are delivered, the source still
contains legacy APP settings routes. General identity/settings flows belong to Base `/identity`.

Telephone registration, withdrawal, sessions, secrets, emails, birthdate, activities, and MFA policy
are Acme-owned identity surfaces. Acme should read MFA inventory from a summary or domain-service
boundary instead of depending on Sign controller behavior.

Sign-side tests for the moved routes are boundary tests that verify redirect or gone behavior. They
are not compatibility tests for the retired general settings UI.

## Physical Storage

Existing sign-side preference, settings-shell, dashboard, or credential-management
tables/models/routes do not imply sign-side authority for persisted preference data. Physical DB
movement is out of scope for this implementation phase.

## Runtime Reads

Request-local preference reads may continue through existing runtime projection mechanisms while the
logical writer changes to acme. A read-side preference projection is not a write authority.

## Related

- `docs/architecture/preference.md`
- `docs/identity/authority-boundary.md`
