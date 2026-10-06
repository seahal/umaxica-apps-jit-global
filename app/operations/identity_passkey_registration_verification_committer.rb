# frozen_string_literal: true

# Auth's half of passkey registration. The attestation is verified against the admitted,
# transaction-bound challenge and the public material is kept as a realm-local candidate. Base
# alone creates the effective credential.
class IdentityPasskeyRegistrationVerificationCommitter
  CONFIG = {
    "app" => {
      actor_class: Client,
      token_class: ClientToken,
      transaction_class: ClientStepUpCeremonyTransaction,
      session_class: ClientStepUpSession,
      candidate_class: IdentityPasskeyCeremonyCandidate,
      passkey_class: ClientPasskey,
      actor_key: :user_id,
      token_key: :user_token_id,
      surface: "app",
    },
    "com" => {
      actor_class: Visitor,
      token_class: VisitorToken,
      transaction_class: VisitorStepUpCeremonyTransaction,
      session_class: VisitorStepUpSession,
      candidate_class: VisitorPasskeyCeremonyCandidate,
      passkey_class: VisitorPasskey,
      actor_key: :visitor_id,
      token_key: :visitor_token_id,
      surface: "com",
    },
    "org" => {
      actor_class: Operator,
      token_class: OperatorToken,
      transaction_class: OperatorStepUpCeremonyTransaction,
      session_class: OperatorStepUpSession,
      candidate_class: OperatorPasskeyCeremonyCandidate,
      passkey_class: OperatorPasskey,
      actor_key: :staff_id,
      token_key: :staff_token_id,
      surface: "org",
    },
  }.freeze

  class << self
    public

    def call!(actor:, token:, transaction:, session_record:, config:, reference:, credential_params:, description: nil)
      binding = config_for(actor)
      validate_binding!(binding, actor, token, transaction, session_record)
      challenge = session_record.consume_bound_passkey_registration_challenge!(
        transaction: transaction, reference: reference, rp_id: config.rp_id, origin: config.origin,
      )
      context = Webauthn::RegistrationVerifier.verify!(
        credential_params: credential_params, challenge: challenge, config: config,
      )
      material = candidate_material(context, credential_params, config, description)
      binding.fetch(:actor_class).connection_class_for_self.connected_to(role: :writing) do
        actor.with_lock do
          refuse!("registration actor unavailable") unless actor.login_allowed?
          # This is a courtesy check only. The principal database's unique index is authoritative
          # at Base finalization.
          refuse!("passkey credential is already registered") if binding.fetch(:passkey_class).exists?(
            webauthn_id: material.fetch(:webauthn_id),
          )

          record_candidate!(binding, actor, token, transaction, material)
        end
      end
    end

    private

    def config_for(actor)
      CONFIG.values.find { |entry| actor.is_a?(entry.fetch(:actor_class)) } ||
        refuse!("registration actor type unavailable")
    end

    def refuse!(message)
      raise IdentityPasskeyCeremonyContract::Error, message
    end

    def validate_binding!(binding, actor, token, transaction, session_record)
      if token.is_a?(OperatorToken) && token.emergency_authentication_context?
        refuse!("passkey registration binding mismatch")
      end

      unless actor.is_a?(binding.fetch(:actor_class)) && token.is_a?(binding.fetch(:token_class)) &&
          transaction.is_a?(binding.fetch(:transaction_class)) && session_record.is_a?(binding.fetch(:session_class)) &&
          token.public_send(binding.fetch(:actor_key)) == actor.id &&
          session_record.public_send(binding.fetch(:token_key)) == token.id &&
          session_record.step_up_ceremony_transaction_ref == transaction.transaction_id
        refuse!("passkey registration binding mismatch")
      end
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

    def record_candidate!(binding, actor, token, transaction, material)
      candidate_class = binding.fetch(:candidate_class)
      candidate_class.connection_class_for_self.connected_to(role: :writing) do
        token.with_lock do
          transaction.with_lock do
            now = transaction.class.database_now
            unless token.currently_usable?(now) && transaction.actor_ref == actor.public_id &&
                transaction.session_ref == token.public_id && transaction.surface == binding.fetch(:surface) &&
                %w(bootstrap credential_registration).include?(transaction.purpose) &&
                transaction.status == "pending" && !transaction.expired?(now: now) &&
                transaction.allowed_methods_array.include?("passkey") &&
                transaction.step_up_required == false &&
                transaction.user_verification_required == false &&
                transaction.full_reauthentication_required == false &&
                transaction.phishing_resistant_required == false
              refuse!("passkey registration unavailable")
            end

            candidate = candidate_class.create!(
              ref: SecureRandom.uuid,
              digest: candidate_class.digest_for(**material),
              surface: binding.fetch(:surface), actor_ref: actor.public_id, session_ref: token.public_id,
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
