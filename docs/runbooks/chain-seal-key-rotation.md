# ChainSeal Key Rotation

## Runtime Model

ChainSeal uses ES384 P-384 signing keys. The signing boundary receives an active `kid` and private
key from a key provider. Verifiers use public JWKS material selected by `kid`.

Do not place private PEM, private DER, private JWK fields, secret backend names, or credentials in
public JWKS output.

## Rotation Procedure

1. Generate a new P-384 ES384 key.
2. Choose a globally unique `kid`.
3. Store the new private key in the production secret backend.
4. Publish the new public JWK as a grace verification key.
5. Deploy verifiers with both old and new public keys.
6. Switch the ChainSeal key provider active `kid` and private key.
7. Deploy signers.
8. Confirm new seals use the new `kid`.
9. Keep old public keys available for the audit export verification window.
10. Retire old public keys only after evidence-custody and export requirements allow it.

## Emergency Revocation

1. Mark the compromised `kid` as revoked in verifier configuration.
2. Deploy verifier rejection before deploying a replacement signer.
3. Generate and install a replacement P-384 key with a new `kid`.
4. Remove the compromised public key from public JWKS.
5. Re-seal only through an approved incident or evidence-custody procedure.

## Rollback

Keep previous private key versions until rotation rollback is closed. To roll back, restore the
previous active `kid` and private-key version, keep both public keys in JWKS, and record the
operational reason for the rollback.
