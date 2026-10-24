# typed: false
# frozen_string_literal: true

class IdentitySocialCeremonyGrantIssuer
  Issuance = Data.define(:transaction, :grant)

  def self.issue!(surface:, actor_ref:, session_ref:, operation:, provider:, resource_ref: nil, return_to: nil,
                  provider_subject_ref: nil,
                  provider_subject_digest: nil, expires_at: nil, issuer_id: nil, now: Time.current)
    transaction =
      IdentitySocialCeremonyReplayStore.for(surface).create_transaction!(
        surface: surface,
        actor_ref: actor_ref,
        session_ref: session_ref,
        operation: operation,
        provider: provider,
        resource_ref: resource_ref,
        return_to: return_to,
        provider_subject_ref: provider_subject_ref,
        provider_subject_digest: provider_subject_digest,
        expires_at: expires_at,
        now: now,
      )
    Issuance.new(transaction: transaction, grant: new(transaction:, issuer_id:, now:).call)
  end

  def initialize(transaction:, issuer_id: nil, now: Time.current)
    @transaction = transaction
    @issuer_id = issuer_id || IdentitySocialCeremonyContract.acme_issuer_id(transaction.surface)
    @now = now
  end

  def call
    IdentitySocialCeremonyGrant.issue(transaction.grant_claims(now: now), issuer_id: issuer_id, now: now)
  end

  private

  attr_reader :transaction, :issuer_id, :now
end
