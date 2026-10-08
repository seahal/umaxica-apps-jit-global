# Identifier encryption ownership inventory

Inspected commit: `48ff7040de2b50a8a08ed660fa71878a029ba577`.
The inspected implementation declares 108 encrypted attributes across 51 concrete models.

## Identifier keyrings in this change

ClientEmail and ClientTelephone use APP; VisitorEmail and VisitorTelephone use COM;
OperatorEmail and OperatorTelephone use ORG. Each identifier currently encrypts its address/number
and the old OTP private key. The OTP attribute is temporary until ceremony-owned verifier migration
removes it. No identifier reads the non-identifier global keyring.

## Existing non-identifier keyring retained

- Client, Visitor and Operator: administrative lock reason and birthdate.
- ClientExternalIdentity: deterministic subject; ClientTotpCredential: private key.
- IdentitySocialCeremonyCandidate: auth hash; IdentityTotpCeremonyCandidate: private key.
- IdentitySecretCredentialCeremonyCandidate: password digest, with APP/COM/ORG contract ownership
  despite APP Ticket storage.
- Each App/Com/Org EnforcementCase, EnforcementIdentifierEffect and EnforcementAppeal:
  reason note, display value and statement respectively.
- ClientChronicle and OperatorChronicle: previous value, owned by APP and ORG despite shared storage.
- AccountAccessEvent: reason note, a shared-domain record.
- AvatarMoniker: moniker, an Avatar-domain record.
- The 24 Publishing Docs/Help/Info/News App/Com/Org EntryRevision and EntryVersion models:
  title, summary and JSON body. Namespace ownership is distinct from shared Publishing storage.

These are not migrated by this identifier-scoped change. Assigning shared-domain data a realm
without a separate ownership decision would create an implicit cross-realm dependency.

## Rotation boundary

Explicit identifier providers derive keys with the realm's derivation salt and a fixed realm/domain
prefix. Even accidentally identical configured password/salt values do not produce interchangeable
realm ciphertext. Previous keys decrypt;
only the current key encrypts. Global previous schemes are empty so they cannot become an implicit
identifier fallback. Non-identifier rotation retains its previous/current primary-key list.
See [Rails attribute-specific key providers](https://guides.rubyonrails.org/active_record_encryption.html#attribute-specific-key-providers)
and the installed Rails 8.2 `EncryptableRecord#scheme_for`, `KeyProvider` and `KeyGenerator` sources.
