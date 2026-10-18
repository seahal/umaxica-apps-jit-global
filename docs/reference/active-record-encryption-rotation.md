# Active Record Encryption Rotation

The six Email/Telephone identifier models use independent APP, COM and ORG keyrings, each keeping
a current encryption key and an optional previous-key chain. Other encrypted PII retains its
existing non-identifier keyring; see `docs/security/identifier-encryption-inventory.md`.

## Configuration

For each explicitly selected realm, configure its required environment values:

- `{APP,COM,ORG}_ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY`
- `{APP,COM,ORG}_ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT`

To keep old ciphertext readable while a rollout is in flight, set:

- `{APP,COM,ORG}_ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY_PREVIOUS`

The optional previous value must be a JSON array of nonempty strings. An absent previous value
means no previous keys; malformed or blank configuration fails explicitly. Identifier attributes
never fall back to the old global keyring. Realm/domain key derivation prevents cross-realm reads
even if configuration values accidentally coincide.

## Rotation procedure

1. Generate a new primary key for the affected realm only.
2. Put that realm's old primary key in its previous-key JSON array.
3. Deploy the config change.
4. Run `bin/rails db:encryption:reencrypt`.
5. Verify the sign-in, OTP, and sign-up paths on `app`, `org`, and `com`.
6. Remove the previous key once the new ciphertext is fully deployed and verified.

## Notes

- The rotation path for email and telephone identifiers relies on the blind-index lookup code in
  `app/models/concerns/email.rb` and `app/models/concerns/telephone.rb`.
- Auth email and telephone identifiers are non-deterministically encrypted. Application lookup code
  must use `find_by_address`, `find_by_number`, `with_address`, `with_number`, or explicit
  `*_digest` queries rather than `find_by(address: ...)` or `find_by(number: ...)`.
- App-side `client_emails` and `client_telephones` store one encrypted identifier column and one HMAC
  digest lookup column (`address_digest` / `number_digest`).
- Keep the affected realm's derivation salt stable during primary-key rotation.
- Identifier HMAC keys are not Active Record Encryption keys. If a
  `{APP,COM,ORG}_EMAIL_ADDRESS_HMAC_KEY` or `{APP,COM,ORG}_TELEPHONE_NUMBER_HMAC_KEY` is exposed, follow
  `docs/security/identifier-hmac-emergency-rotation.md`.

The re-encryption command visits the six identifier models. Unchanged realms continue using their
own configured keyrings; no realm key is transferred to another realm. Boot and keyring primitives
have been checked locally; full HTTP rotation verification remains part of the implementation task.
