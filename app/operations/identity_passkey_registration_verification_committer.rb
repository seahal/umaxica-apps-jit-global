# frozen_string_literal: true

# Auth's half of Passkey registration: verify the attestation against the transaction-bound
# challenge and record the verified material as a candidate. No credential is created here; only
# Base may turn the candidate into one.
class IdentityPasskeyRegistrationVerificationCommitter
  class << self
    public

    def call!(actor:, token:, transaction:, session_record:, config:, reference:, credential_params:, description:)
      validate_binding!(actor, token, transaction, session_record)
      challenge = session_record.consume_bound_passkey_registration_challenge!(
        transaction: transaction, reference: reference, rp_id: config.rp_id, origin: config.origin,
      )
      context = Webauthn::RegistrationVerifier.verify!(
        credential_params: credential_params, challenge: challenge, config: config,
      )
      material = candidate_material(context, credential_params, config, description)
      Client.connection_class_for_self.connected_to(role: :writing) do
        actor.with_lock do
          refuse!("registration actor unavailable") unless actor.login_allowed?
          # A courtesy check for the person registering; the unique index decides at finalization.
          refuse!("passkey credential is already registered") if ClientPasskey.exists?(
            webauthn_id: material.fetch(:webauthn_id),
          )

          record_candidate!(actor, token, transaction, material)
        end
      end
    end

    private

    def refuse!(message)
      raise IdentityPasskeyCeremonyContract::Error, message
    end

    def validate_binding!(actor, token, transaction, session_record)
      return if actor.is_a?(Client) && token.is_a?(ClientToken) &&
        transaction.is_a?(ClientStepUpCeremonyTransaction) && session_record.is_a?(ClientStepUpSession) &&
        token.user_id == actor.id && session_record.user_token_id == token.id &&
        session_record.step_up_ceremony_transaction_ref == transaction.transaction_id

      refuse!("passkey registration binding mismatch")
    end

    def candidate_material(context, credential_params, config, description)
      metadata = Webauthn::AuthenticatorMetadata.attributes_from(context)
      label = description if description.is_a?(String) && description.present? && description.exclude?("\0")
      {
        webauthn_id: context.webauthn_id,
        public_key: WebAuthn::Credential.from_create(
          credential_params, relying_party: config.relying_party,
        ).public_key,
        sign_count: context.sign_count.to_i,
        description: label || metadata[:provider_name].presence || I18n.t("sign.default_passkey_description"),
        transports: Array(context.transports).map(&:to_s),
        metadata: metadata.as_json,
      }
    end

    def record_candidate!(actor, token, transaction, material)
      AppTicketRecord.connected_to(role: :writing) do
        token.with_lock do
          transaction.with_lock do
            now = ClientStepUpCeremonyTransaction.database_now
            unless token.currently_usable?(now) && transaction.actor_ref == actor.public_id &&
                transaction.session_ref == token.public_id && transaction.surface == "app" &&
                %w(bootstrap credential_registration).include?(transaction.purpose) &&
                transaction.status == "pending" && !transaction.expired?(now: now) &&
                transaction.allowed_methods_array.include?("passkey")
              refuse!("passkey registration unavailable")
            end

            candidate = IdentityPasskeyCeremonyCandidate.create!(
              ref: SecureRandom.uuid, digest: IdentityPasskeyCeremonyCandidate.digest_for(**material),
              surface: "app", actor_ref: actor.public_id, session_ref: token.public_id,
              step_up_ceremony_transaction_ref: transaction.transaction_id,
              expires_at: transaction.expires_at, **material,
            )
            transaction.record_registration_verification!(method: "passkey", verified_at: now)
            candidate
          end
        end
      end
    rescue IdentityStepUpCeremonyContract::Error, ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid
      refuse!("passkey registration unavailable")
    end
  end
end
