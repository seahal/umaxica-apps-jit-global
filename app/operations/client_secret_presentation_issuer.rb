# frozen_string_literal: true

# The payload stays on the source DB and is destroyed by the presentation commit.
# Only an explicit POST may call this boundary; document reads never deliver values.
class ClientSecretPresentationIssuer
  class Denied < StandardError; end

  class AlreadyPresented < Denied; end

  class PayloadUnavailable < Denied; end

  PURPOSE = "app_secret_issuance_payload"

  class << self
    public

    def prepare!(actor_context:, token:, issuance:)
      with_authorization(actor_context, token, issuance) do |owned, context, now|
        prepare_candidates!(owned, context, now)
      end
    end

    def call!(actor_context:, token:, issuance:)
      with_authorization(actor_context, token, issuance) do |owned, context, now|
        present_candidates!(owned, context, now)
      end
    rescue ActiveSupport::MessageEncryptor::InvalidMessage
      raise PayloadUnavailable, "Secret payload cannot be decrypted"
    end

    def prepare_for_sign_up!(flow:, nonce:, issuance:)
      ClientSecretPasskeyReservationIssuer.with_sign_up_delivery!(
        flow: flow, nonce: nonce,
        issuance: issuance,
      ) do |owned, context, now|
        prepare_candidates!(owned, context, now)
      end
    end

    def present_for_sign_up!(flow:, nonce:, issuance:)
      ClientSecretPasskeyReservationIssuer.with_sign_up_delivery!(
        flow: flow, nonce: nonce,
        issuance: issuance,
      ) do |owned, context, now|
        present_candidates!(owned, context, now)
      end
    rescue ActiveSupport::MessageEncryptor::InvalidMessage
      raise PayloadUnavailable, "Secret payload cannot be decrypted"
    end

    private

    def prepare_candidates!(owned, context, now)
      return owned unless owned.state(at: now) == :pending_presentation

      candidates = ClientSecretCredential.where(issuance_id: owned.id).lock.to_a
      return owned if owned.encrypted_payload && candidates.length == owned.planned_count
      raise PayloadUnavailable, "Secret candidate payload is unavailable" if candidates.any?

      values = Array.new(owned.planned_count) { SecureRandom.base58(32) }
      refs =
        values.map do |raw|
          ClientSecretCredential.create!(
            client: context.subject, issuance: owned, name: "Secret",
            password: raw, lookup_digest: SignSecretLookupDigest.digest(raw),
          ).public_id
        end
      owned.update!(
        encrypted_payload: encryptor.encrypt_and_sign(
          { "issuance" => owned.public_id, "references" => refs, "values" => values },
          purpose: PURPOSE, expires_at: owned.expires_at,
        ),
      )
      owned
    end

    def present_candidates!(owned, context, now)
      raise AlreadyPresented, "Secret presentation is single delivery" if owned.presented_at
      raise Denied, "Secret issuance is unavailable" unless owned.state(at: now) == :pending_presentation
      raise PayloadUnavailable, "Secret payload is unavailable" unless owned.encrypted_payload

      payload = encryptor.decrypt_and_verify(owned.encrypted_payload, purpose: PURPOSE)
      candidates = ClientSecretCredential.where(
        issuance_id: owned.id,
        client_id: context.subject.id,
      ).order(:id).lock.to_a
      unless payload.is_a?(Hash) && payload["issuance"] == owned.public_id &&
          candidates.length == owned.planned_count && payload["values"].is_a?(Array) &&
          payload["references"] == candidates.map(&:public_id) &&
          payload["values"].length == candidates.length &&
          candidates.zip(payload["values"]).all? { |candidate, raw| candidate.matches_secret?(raw) }
        raise PayloadUnavailable, "Secret payload does not match its candidate set"
      end

      candidates.each do |candidate|
        ClientSecretAuditOutbox.record!(
          actor_context: context, client_ref: context.subject.public_id, credential_ref: candidate.public_id,
          operation_ref: owned.origin_operation_id, occurred_at: now, event_name: "secret.presented", item_count: 1,
        )
      end
      owned.update!(presented_at: now, encrypted_payload: nil)
      payload.fetch("values")
    end

    def encryptor
      key = Rails.application.key_generator.generate_key(PURPOSE, ActiveSupport::MessageEncryptor.key_len("aes-256-gcm"))
      ActiveSupport::MessageEncryptor.new(key, cipher: "aes-256-gcm", serializer: JSON)
    end

    def with_authorization(context, token, issuance)
      unless context.is_a?(ActorValuesContext) && context.client? && context.tld == :app &&
          context.surface == :base && context.subject.is_a?(Client) &&
          token.is_a?(ClientToken) && issuance.is_a?(ClientSecretIssuance)
        raise Denied, "Secret presentation requires its Base Client and browser"
      end

      AppTicketRecord.connected_to(role: :writing) do
        ClientToken.transaction do
          AppZenithRecord.connected_to(role: :writing) do
            context.subject.with_lock do
              current = ClientToken.lock.find_by(id: token.id, public_id: token.public_id, user_id: context.subject.id)
              owned = ClientSecretIssuance.lock.find_by(
                id: issuance.id, public_id: issuance.public_id,
                client_id: context.subject.id,
              )
              now = Client.database_now
              unless current && owned && owned.browser_session_ref == current.public_id &&
                  owned.sign_up_flow_ref.nil? && context.subject.login_allowed?
                raise Denied, "Secret presentation context mismatch"
              end

              scope = (owned.origin == "manual") ? "settings_secret_credential" : "settings_passkey"
              requirement = StepUpRequirement.new(
                scope: scope, purpose: "step_up", audience: "step_up:app", session_binding: current.public_id,
                token_binding: current.public_id, require_session_binding: true,
              )
              unless current.currently_usable?(ClientToken.database_now) && !current.restricted? &&
                  StepUpResolver.call(
                    token: current, requirement: requirement,
                    now: ClientToken.database_now,
                  ).satisfied? &&
                  owned.expires_at && owned.expires_at > now && owned.canceled_at.nil?
                raise Denied, "Secret presentation requires current scoped Step-Up and issuance"
              end

              yield owned, context, now
            end
          end
        end
      end
    end
  end
end
