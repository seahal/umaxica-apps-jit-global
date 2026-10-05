# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class WithdrawalPersonalDataAnonymizerTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  AnonymizedRecord =
    Struct.new(:id, :updated_attrs, :discard_at, :model_class, :destroyed) do
      def update!(attrs)
        self.updated_attrs = attrs
      end

      def class
        model_class
      end

      def is_a?(klass)
        klass == model_class || super
      end

      def destroy!
        self.destroyed = true
      end
    end

  Scope =
    Struct.new(:records) do
      def find_each(&)
        records.each(&)
      end
    end

  test "anonymizes persisted client credentials while retaining Secret terminal audit" do
    now = Client.database_now
    client = Client.create!(status_id: ClientStatus::ACTIVE)
    email = ClientEmail.create!(
      user: client, address: "withdrawal-#{SecureRandom.hex(8)}@example.com",
      otp_counter: "0", otp_private_key: "withdrawal-test",
    )
    original_address_digest = email.address_digest
    telephone = ClientTelephone.create!(
      user: client, number: "+14155552671", otp_counter: "0", otp_private_key: "withdrawal-test",
    )
    original_number_digest = telephone.number_digest
    external_identity = ClientExternalIdentity.create!(
      client: client, provider: "google", issuer: "https://accounts.google.com",
      subject: SecureRandom.uuid, audience: "withdrawal-test", verification_authority: "google",
      state: "active", verified_at: now,
    )
    passkey = ClientPasskey.create!(
      user: client, webauthn_id: SecureRandom.base58(32), external_id: SecureRandom.uuid,
      public_key: "withdrawal-test-key", description: "Withdrawal test",
    )
    totp = ClientTotpCredential.create!(
      user: client, title: "Withdrawal test", private_key: ROTP::Base32.random_base32,
      user_identity_totp_credential_status_id: ClientTotpCredentialStatus::ACTIVE,
    )
    issuance = ClientSecretIssuance.create!(
      client: client, origin: "manual", origin_operation_id: SecureRandom.uuid, attempt_number: 1,
      browser_session_ref: SecureRandom.base58(21), planned_count: 1, expires_at: now + 1.minute,
    )
    raw = SecureRandom.base58(32)
    secret = ClientSecretCredential.create!(
      client: client, issuance: issuance, name: "Pending withdrawal", password: raw,
      lookup_digest: SignSecretLookupDigest.digest(raw),
    )
    client.update!(withdrawn_at: now, terminated_at: now)
    previous_delay = ENV["APP_SECRET_PURGE_DELAY_SECONDS"]
    ENV["APP_SECRET_PURGE_DELAY_SECONDS"] = "86400"

    assert_same client, WithdrawalPersonalDataAnonymizer.call(actor: client)
    assert_equal "withdrawn-client-email-#{email.id}@anonymous.invalid", email.reload.address
    assert_not_equal original_address_digest, email.address_digest
    assert_equal IdentifierBlindIndex.bidx_for_email(email.address), email.address_digest
    assert_equal "withdrawn", email.otp_private_key
    assert_equal "0", email.otp_counter
    assert_equal ClientEmailStatus::SUSPENDED, email.user_email_status_id
    assert_equal "+100000#{telephone.id.to_s.rjust(9, "0")}", telephone.reload.number
    assert_not_equal original_number_digest, telephone.number_digest
    assert_equal "withdrawn", telephone.otp_private_key
    assert_equal "0", telephone.otp_counter
    assert_equal ClientTelephoneStatus::SUSPENDED, telephone.user_identity_telephone_status_id
    assert_not ClientExternalIdentity.exists?(external_identity.id)
    assert_equal ClientPasskeyStatus::REVOKED, passkey.reload.status_id
    assert_kind_of Time, passkey.discard_at
    assert_equal ClientTotpCredentialStatus::REVOKED, totp.reload.user_identity_totp_credential_status_id
    assert secret.reload.revoked_at
    assert_kind_of Time, secret.discard_at
    assert_nil ClientSecretLookupQuery.call(secret: raw)
    assert issuance.reload.canceled_at
    assert_equal %w(secret.discarded secret.revoked),
                 ClientSecretAuditOutbox.where(credential_ref: secret.public_id).order(:event_name).pluck(:event_name)
  ensure
    ENV["APP_SECRET_PURGE_DELAY_SECONDS"] = previous_delay
  end

  test "anonymizes a visitor actor" do
    visitor = Visitor.allocate
    purge_calls = []

    visitor_email = AnonymizedRecord.new(21, nil, nil, VisitorEmail)
    visitor_telephone = AnonymizedRecord.new(22, nil, nil, VisitorTelephone)
    visitor_passkey = AnonymizedRecord.new(23, nil, nil, VisitorPasskey)
    visitor_secret = AnonymizedRecord.new(24, nil, nil, VisitorSecretCredential)

    define_visitor_actor(
      visitor,
      emails: [visitor_email],
      telephones: [visitor_telephone],
      passkeys: [visitor_passkey],
      secrets: [visitor_secret],
    )

    RetentionCrossDatabaseChildPurge.stub(:call, ->(actor:) { purge_calls << actor }) do
      result = WithdrawalPersonalDataAnonymizer.call(actor: visitor)

      assert_same visitor, result
    end

    assert_equal [visitor], purge_calls
    assert_equal "withdrawn-visitor-email-21@anonymous.invalid", visitor_email.updated_attrs.fetch(:address)
    assert_equal "withdrawn", visitor_email.updated_attrs.fetch(:otp_private_key)
    assert_equal "0", visitor_email.updated_attrs.fetch(:otp_counter)
    assert_equal VisitorEmailStatus::SUSPENDED, visitor_email.updated_attrs.fetch(:visitor_email_status_id)

    assert_equal "+100000000000022", visitor_telephone.updated_attrs.fetch(:number)
    assert_equal "withdrawn", visitor_telephone.updated_attrs.fetch(:otp_private_key)
    assert_equal "0", visitor_telephone.updated_attrs.fetch(:otp_counter)
    assert_equal VisitorTelephoneStatus::SUSPENDED, visitor_telephone.updated_attrs.fetch(:visitor_telephone_status_id)

    assert_equal VisitorPasskeyStatus::REVOKED, visitor_passkey.updated_attrs.fetch(:status_id)
    assert_in_delta Time.current.to_f, Float(visitor_passkey.updated_attrs.fetch(:discard_at)), 1

    assert_equal VisitorSecretCredentialStatus::REVOKED,
                 visitor_secret.updated_attrs.fetch(:visitor_secret_credential_status_id)
    assert_in_delta Time.current.to_f, Float(visitor_secret.updated_attrs.fetch(:discard_at)), 1
  end

  private

  def define_visitor_actor(actor, emails:, telephones:, passkeys:, secrets:)
    actor.define_singleton_method(:visitor_emails) { Scope.new(emails) }
    actor.define_singleton_method(:visitor_telephones) { Scope.new(telephones) }
    actor.define_singleton_method(:visitor_passkeys) { Scope.new(passkeys) }
    actor.define_singleton_method(:visitor_secret_credentials) { Scope.new(secrets) }
  end
end
