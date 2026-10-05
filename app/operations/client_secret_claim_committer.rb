# frozen_string_literal: true

class ClientSecretClaimCommitter
  class << self
    public

    # Commit the Ticket locator before the independent irreversible source claim.
    # This operation alone grants neither authentication evidence nor a session.
    def bind_oidc_flow!(secret:, transaction:, ceremony:)
      unless transaction.is_a?(ClientOidcAuthorizationTransaction) && transaction.persisted? &&
          ceremony.is_a?(ClientAuthCeremonySession) && ceremony.persisted?
        raise ArgumentError, "Secret OIDC binding requires durable app transaction and browser ceremony"
      end

      credential = ClientSecretLookupQuery.call(secret: secret)
      return unless credential

      AppZenithRecord.connected_to(role: :writing) do
        credential.client.with_lock do
          AppTicketRecord.connected_to(role: :writing) do
            transaction.with_lock do
              flow = transaction.secret_sign_in_flow
              flow&.lock!
              ceremony.lock!
              credential.lock!
              now = ClientSignInFlow.database_now
              return nil unless oidc_binding_admitted?(credential, transaction, ceremony, now)

              if flow
                return flow if flow.principal_id == credential.client_id && flow.sign_in_primary_pending? &&
                  !flow.expired?(now)

                return nil
              end
              flow = ClientSignInFlow.create!(
                principal_id: credential.client_id, status_id: ClientSignInFlowStatus::PRIMARY_PENDING,
                state: "PRIMARY_PENDING", step: "primary", issued_at: now,
                expires_at: [transaction.expires_at, transaction.login_challenge_expires_at,
                             ceremony.expires_at, now + ClientSignInFlow.default_ttl,].min,
                nonce_digest: ClientSignInFlow.digest_nonce(SecureRandom.base58(32)),
              )
              transaction.update!(secret_sign_in_flow: flow)
              flow
            end
          end
        end
      end
    end

    def call_for_oidc!(secret:, transaction:, ceremony:)
      flow = bind_oidc_flow!(secret: secret, transaction: transaction, ceremony: ceremony)
      return nil unless flow

      call!(secret: secret, flow: flow, ceremony: ceremony, authorization_transaction: transaction)
    end

    def call!(secret:, flow:, ceremony:, authorization_transaction: nil)
      verify_claim_request!(flow, ceremony, authorization_transaction)

      credential = ClientSecretLookupQuery.call(secret: secret)
      return unless credential

      actor = credential.client
      claim = nil
      # The Ticket lock spans the independent source commit. A later evidence rollback
      # does not roll back the irreversible Zenith claim.
      AppTicketRecord.connected_to(role: :writing) do
        ClientSignInFlow.transaction do
          AppZenithRecord.connected_to(role: :writing) do
            actor.with_lock do
              authorization_transaction&.lock!
              flow.lock!
              ceremony.lock!
              credential.lock!
              ticket_now = ClientSignInFlow.database_now
              source_now = Client.database_now
              unless actor.login_allowed? && flow.sign_in_primary_pending? && !flow.expired?(ticket_now) &&
                  (flow.principal_id.nil? || flow.principal_id == actor.id) && ceremony.active?(now: ticket_now) &&
                  ceremony.admitted? && claim_admission_matches?(
                    credential, flow, ceremony, authorization_transaction, ticket_now,
                  ) && !ceremony.authentication_evidence_recorded? &&
                  credential.available_at?(at: source_now) && credential.matches_secret?(secret)
                return nil
              end

              flow.update!(principal_id: actor.id)
              context = ActorValuesContext.empty.with(subject: actor, actor_type: :client, tld: :app, surface: :sign)
              claim = credential.commit_sign_in_claim!(
                actor_context: context, flow: flow, ceremony: ceremony,
                at: source_now,
              )
            end
          end
        end
      end
      claim
    end

    private

    def verify_claim_request!(flow, ceremony, transaction)
      unless flow.is_a?(ClientSignInFlow) && flow.persisted? &&
          ceremony.is_a?(ClientAuthCeremonySession) && ceremony.persisted?
        raise ArgumentError, "Secret claim requires durable app flow and browser ceremony"
      end
      return unless transaction
      return if transaction.is_a?(ClientOidcAuthorizationTransaction) && transaction.persisted?

      raise ArgumentError, "Secret authorization transaction must be durable app OIDC"
    end

    def claim_admission_matches?(credential, flow, ceremony, transaction, now)
      if transaction
        transaction.secret_sign_in_flow_id == flow.id && oidc_binding_admitted?(credential, transaction, ceremony, now)
      else
        ceremony.admission_purpose == "local_sign_in" && ceremony.local_sign_in_flow_ref == flow.public_id
      end
    end

    def oidc_binding_admitted?(credential, transaction, ceremony, now)
      credential.available_at?(at: Client.database_now) && credential.client.login_allowed? &&
        transaction.status == "pending" && !transaction.expired?(now: now) &&
        !transaction.login_challenge_expired?(now: now) && ceremony.admitted? && ceremony.active?(now: now) &&
        ceremony.admission_purpose == "authentication_handoff" && !ceremony.authentication_evidence_recorded? &&
        ceremony.authorization_transaction_ref == transaction.transaction_id
    end
  end
end
