# typed: false
# frozen_string_literal: true

class WithdrawalPersonalDataAnonymizer
  def self.call(actor:)
    new(actor:).call
  end

  def initialize(actor:)
    @actor = actor
  end

  def call
    anonymize_client if actor.is_a?(Client)
    anonymize_visitor if actor.is_a?(Visitor)
    # Explicit, ordered cleanup of non-audit children that live in other
    # databases (no implicit cross-DB AR cascade). Chronicle/audit is
    # intentionally retained.
    RetentionCrossDatabaseChildPurge.call(actor: actor)
    actor
  end

  private

  attr_reader :actor

  def anonymize_client
    ClientEmail.where(user_id: actor.id).find_each(&:retire_for_withdrawal!)
    ClientTelephone.where(user_id: actor.id).find_each(&:retire_for_withdrawal!)
    revoke_records(
      ClientPasskey.where(user_id: actor.id), status_column: :status_id, revoked_status: ClientPasskeyStatus::REVOKED,
    )
    actor.with_lock do
      credentials = ClientSecretCredential.where(client_id: actor.id)
      next unless credentials.exists? || ClientSecretIssuance.exists?(client_id: actor.id)

      now = Client.database_now
      purge_at = now + ClientSecretLifetimesValue.purge_delay
      ClientSecretIssuance.where(client_id: actor.id).order(:id).find_each do |issuance|
        issuance.cancel_for_withdrawal!(at: now, purge_at: purge_at)
      end
      credentials.order(:id).find_each do |credential|
        credential.commit_withdrawal_revocation!(at: now, purge_at: purge_at)
      end
    end
    revoke_records(
      ClientTotpCredential.where(user_id: actor.id),
      status_column: :user_identity_totp_credential_status_id, revoked_status: ClientTotpCredentialStatus::REVOKED,
    )
    remove_common_social_identities
  end

  def anonymize_visitor
    VisitorEmail.where(visitor_id: actor.id).find_each(&:retire_for_withdrawal!)
    VisitorTelephone.where(visitor_id: actor.id).find_each(&:retire_for_withdrawal!)
    revoke_records(
      VisitorPasskey.where(visitor_id: actor.id), status_column: :status_id, revoked_status: VisitorPasskeyStatus::REVOKED,
    )
    revoke_records(
      VisitorSecretCredential.where(visitor_id: actor.id),
      status_column: :visitor_secret_credential_status_id, revoked_status: VisitorSecretCredentialStatus::REVOKED,
    )
  end

  def revoke_records(scope, status_column:, revoked_status:)
    scope.find_each do |record|
      attrs = { status_column => revoked_status }
      attrs[:discard_at] = Time.current if record.respond_to?(:discard_at=)
      record.update!(attrs)
    end
  end

  def remove_common_social_identities
    AppPrincipalRecord.transaction do
      actor.client_external_identities.order(:id).each do |identity|
        ClientExternalIdentity.with_subject_lock(
          provider: identity.provider, issuer: identity.issuer, subject: identity.subject,
        ) do
          identity.release!
          ClientSocialAuditOutbox.record!(identity: identity, owner: actor, event_name: "unlinked")
          identity.destroy!
        end
      end
    end
  end
end
