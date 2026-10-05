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
    anonymize_emails(actor.client_emails, status_column: :user_email_status_id)
    anonymize_telephones(actor.client_telephones, status_column: :user_identity_telephone_status_id)
    revoke_records(actor.client_passkeys, status_column: :status_id, revoked_status: ClientPasskeyStatus::REVOKED)
    actor.with_lock do
      next unless actor.client_secret_credentials.exists? || ClientSecretIssuance.exists?(client_id: actor.id)

      now = Client.database_now
      purge_at = now + ClientSecretLifetimesValue.purge_delay
      ClientSecretIssuance.where(client_id: actor.id).order(:id).find_each do |issuance|
        issuance.cancel_for_withdrawal!(at: now, purge_at: purge_at)
      end
      actor.client_secret_credentials.order(:id).find_each do |credential|
        credential.commit_withdrawal_revocation!(at: now, purge_at: purge_at)
      end
    end
    revoke_records(
      actor.client_totp_credentials, status_column: :user_identity_totp_credential_status_id,
                                     revoked_status: ClientTotpCredentialStatus::REVOKED,
    )
    remove_common_social_identities
  end

  def anonymize_visitor
    anonymize_emails(actor.visitor_emails, status_column: :visitor_email_status_id)
    anonymize_telephones(actor.visitor_telephones, status_column: :visitor_telephone_status_id)
    revoke_records(actor.visitor_passkeys, status_column: :status_id, revoked_status: VisitorPasskeyStatus::REVOKED)
    revoke_records(
      actor.visitor_secret_credentials, status_column: :visitor_secret_credential_status_id,
                                        revoked_status: VisitorSecretCredentialStatus::REVOKED,
    )
  end

  def anonymize_emails(scope, status_column:)
    scope.find_each do |email|
      email.update!(
        :address => "withdrawn-#{email.class.name.underscore.dasherize}-#{email.id}@anonymous.invalid",
        :address_digest => nil,
        :otp_private_key => "withdrawn",
        :otp_counter => "0",
        :otp_attempts_count => 0,
        :otp_expires_at => -Float::INFINITY,
        :locked_at => -Float::INFINITY,
        status_column => revoked_or_suspended_email_status(email),
      )
    end
  end

  def anonymize_telephones(scope, status_column:)
    scope.find_each do |telephone|
      telephone.update!(
        :number => "+100000#{telephone.id.to_s.rjust(9, "0")}",
        :number_digest => nil,
        :otp_private_key => "withdrawn",
        :otp_counter => "0",
        :otp_attempts_count => 0,
        :otp_expires_at => -Float::INFINITY,
        :locked_at => -Float::INFINITY,
        status_column => revoked_or_suspended_telephone_status(telephone),
      )
    end
  end

  def revoke_records(scope, status_column:, revoked_status:)
    scope.find_each do |record|
      attrs = { status_column => revoked_status }
      attrs[:discard_at] = Time.current if record.respond_to?(:discard_at=)
      record.update!(attrs)
    end
  end

  def remove_common_social_identities
    actor.client_external_identities.find_each do |identity|
      identity.destroy!
    end
  end

  def revoked_or_suspended_email_status(email)
    if email.is_a?(ClientEmail)
      ClientEmailStatus::SUSPENDED
    else
      VisitorEmailStatus::SUSPENDED
    end
  end

  def revoked_or_suspended_telephone_status(telephone)
    if telephone.is_a?(ClientTelephone)
      ClientTelephoneStatus::SUSPENDED
    else
      VisitorTelephoneStatus::SUSPENDED
    end
  end
end
