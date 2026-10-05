# Sign-up admission child binding proposal

Status: Proposed; implementation waits for explicit shape approval.

R01/R02 require Base's admission to remain the root-login authority while Auth performs the existing APP/COM sign-up flow. Current sources create the Base `*_sign_in_flows` parent for both local entry intents and create a separate `*_sign_up_flows` record after contact selection. The Auth ceremony has approved FKs for both, but its current exclusivity constraint prevents their simultaneous use. No active application call site currently populates the sign-up FK.

```text
Before (APP/COM Auth ceremony):
  {admission_purpose, authorization_transaction_ref?, local_sign_in_flow_ref?, local_sign_up_flow_ref?}
  num_nonnulls(authorization_transaction_ref, local_sign_in_flow_ref, local_sign_up_flow_ref) <= 1

After (same columns, no new enum):
  {admission_purpose, authorization_transaction_ref?, local_sign_in_flow_ref?, local_sign_up_flow_ref?}
  num_nonnulls(authorization_transaction_ref, local_sign_in_flow_ref) <= 1
  local_sign_up_flow_ref is NULL, OR:
    admission_purpose = local_sign_up AND local_sign_in_flow_ref IS NOT NULL, OR:
    admission_purpose = authentication_handoff AND authorization_transaction_ref IS NOT NULL
```

The first two references identify mutually exclusive Base authorities; the sign-up reference identifies their exact Auth-owned child. Base creates the local parent, or the existing OIDC coordinator creates the authorization parent. Auth attaches only its own writer-created sign-up row after validating the admitted purpose, parent, browser continuity and deadlines. OIDC child attachment additionally requires the stored authorization intent to equal `sign_up`; ordinary sign-in admission cannot acquire a sign-up child. The child actor must match the principal ultimately recorded in the parent. No actor or scope authority comes from request parameters or the Auth cookie.

Existing FK ownership and all current phase transitions remain. Registration completion does not issue root credentials on Auth or establish step-up freshness. Credential changes and cancellation terminate the exact child and associated continuity. APP/COM alone are affected; ORG registration is not added. Contact, social callback, checkpoint, MFA and final Base issuance retain their existing business checks.

Migration uses new APP/COM ticket migrations with check-constraint replacement and validation, preserving FKs and history. Before applying it, inspect rows that already have a standalone sign-up FK; incompatible legacy rows must fail preflight rather than be silently rewritten. No destructive data operation or shared/development/production migration is authorized by this proposal. Tests use only the approved owned copies. Restoring the old constraint after new dual-reference rows exist requires an explicit recovery plan; an application rollback must not revive Auth root issuance or old grants.

No request, response, Inertia prop, cookie, job or event shape changes are included. The separate Passkey candidate and remaining DB challenge proposals remain independent.
