# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

# Failed comparisons must not expose retained PII or identifier lookup digests.
class WithdrawalPersonalDataAnonymizerTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  %w(app com).each do |realm|
    test "#{realm} withdrawal preserves original finalized identifiers until irreversible retention purge" do
      actor, email_model, telephone_model, owner_key, email_history, telephone_history =
        case realm
        when "app"
          [Client.create!(status_id: ClientStatus::ACTIVE), ClientEmail, ClientTelephone, :user_id,
           ClientEmailHistory, ClientTelephoneHistory,]
        when "com"
          [Visitor.create!(status_id: VisitorStatus::ACTIVE), VisitorEmail, VisitorTelephone, :visitor_id,
           VisitorEmailHistory, VisitorTelephoneHistory,]
        end
      now = actor.class.database_now
      original_address = "withdrawal-original-#{SecureRandom.hex(8)}@example.test"
      original_number = "+8190#{SecureRandom.random_number(10**8).to_s.rjust(8, "0")}"
      email = email_model.create!(owner_key => actor.id, :raw_address => original_address, :confirm_policy => true)
      telephone = telephone_model.create!(
        owner_key => actor.id, :raw_number => original_number, :confirm_policy => true, :confirm_using_mfa => true,
      )
      email.finalize_binding!
      telephone.finalize_binding!
      email_digest = email.address_digest
      telephone_digest = telephone.number_digest
      actor.update!(withdrawn_at: now, terminated_at: now, discard_at: now, purge_eligible_at: now + 1.day)

      WithdrawalPersonalDataAnonymizer.call(actor: actor)

      assert_withheld("Retention must preserve original encrypted email") { email.reload.address == original_address }
      assert_withheld("Retention must preserve original encrypted telephone") {
        telephone.reload.number == original_number
      }
      assert_withheld("Withdrawal must not replace an immutable binding digest") {
        email.address_digest == email_digest
      }
      assert_withheld("Withdrawal must not replace an immutable binding digest") {
        telephone.number_digest == telephone_digest
      }
      assert_empty email_history.where(owner_key => actor.id)
      assert_empty telephone_history.where(owner_key => actor.id)
      assert_equal actor.purge_eligible_at, email.purge_eligible_at
      assert_equal actor.purge_eligible_at, telephone.purge_eligible_at

      after_retention = actor.purge_eligible_at + 1.second
      email_model.stub(:database_now, after_retention) do
        EmailIdentifierPurger.call(record: email)
      end
      telephone_model.stub(:database_now, after_retention) do
        TelephoneIdentifierPurger.call(record: telephone)
      end

      assert actor.class.exists?(actor.id)
      assert_not email_model.exists?(email.id)
      assert_not telephone_model.exists?(telephone.id)
      assert email_history.where(owner_key => actor.id).sole.matches_identifier?(original_address)
      assert telephone_history.where(owner_key => actor.id).sole.matches_identifier?(original_number)
    end

    test "#{realm} withdrawal preserves a longer explicit identifier retention deadline" do
      actor, email_model, telephone_model, owner_key =
        case realm
        when "app"
          [Client.create!(status_id: ClientStatus::ACTIVE), ClientEmail, ClientTelephone, :user_id]
        when "com"
          [Visitor.create!(status_id: VisitorStatus::ACTIVE), VisitorEmail, VisitorTelephone, :visitor_id]
        end
      now = actor.class.database_now
      actor.update!(withdrawn_at: now, terminated_at: now, discard_at: now, purge_eligible_at: now + 1.day)
      longer_deadline = now + 2.days
      email = email_model.create!(
        owner_key => actor.id, :raw_address => "longer-retention-#{SecureRandom.hex(8)}@example.test",
        :confirm_policy => true, :discard_at => now + 1.hour, :purge_eligible_at => longer_deadline,
      )
      telephone = telephone_model.create!(
        owner_key => actor.id, :raw_number => "+819012399927", :confirm_policy => true,
        :confirm_using_mfa => true, :discard_at => now + 1.hour, :purge_eligible_at => longer_deadline,
      )

      WithdrawalPersonalDataAnonymizer.call(actor: actor)

      assert_equal longer_deadline, email.reload.purge_eligible_at
      assert_equal longer_deadline, telephone.reload.purge_eligible_at
    end

    test "#{realm} overdue owner retirement creates an ordered immediately purgeable identifier window" do
      actor, email_model, telephone_model, owner_key =
        case realm
        when "app"
          [Client.create!(created_at: 4.days.ago, discard_at: 2.days.ago, purge_eligible_at: 1.day.ago),
           ClientEmail, ClientTelephone, :user_id,]
        when "com"
          [Visitor.create!(created_at: 4.days.ago, discard_at: 2.days.ago, purge_eligible_at: 1.day.ago),
           VisitorEmail, VisitorTelephone, :visitor_id,]
        end
      email = email_model.create!(
        owner_key => actor.id, :raw_address => "overdue-retirement-#{SecureRandom.hex(8)}@example.test",
        :confirm_policy => true, :created_at => 3.days.ago,
      )
      telephone = telephone_model.create!(
        owner_key => actor.id, :raw_number => "+819012399929", :confirm_policy => true,
        :confirm_using_mfa => true, :created_at => 3.days.ago,
      )

      WithdrawalPersonalDataAnonymizer.call(actor: actor)

      [email.reload, telephone.reload].each do |record|
        assert_operator record.purge_eligible_at, :>=, record.discard_at
        assert record.purgeable?(record.class.database_now)
        assert record.lapsed?(record.class.database_now)
      end
    end

    test "#{realm} withdrawal cleanup preserves identifier failure counts and finite lockout deadlines" do
      actor, email_model, telephone_model, owner_key =
        case realm
        when "app"
          [Client.create!(status_id: ClientStatus::ACTIVE), ClientEmail, ClientTelephone, :user_id]
        when "com"
          [Visitor.create!(status_id: VisitorStatus::ACTIVE), VisitorEmail, VisitorTelephone, :visitor_id]
        end
      now = actor.class.database_now
      deadline = now + 5.minutes
      email = email_model.create!(
        owner_key => actor.id, :raw_address => "withdrawal-failures-#{SecureRandom.hex(8)}@example.test",
        :confirm_policy => true, :otp_attempts_count => 2, :locked_at => deadline,
      )
      telephone = telephone_model.create!(
        owner_key => actor.id, :raw_number => "+819012399925", :confirm_policy => true,
        :confirm_using_mfa => true, :otp_attempts_count => 2, :locked_at => deadline,
      )
      actor.update!(withdrawn_at: now, terminated_at: now)
      WithdrawalPersonalDataAnonymizer.call(actor: actor)

      assert_equal 2, email.reload.otp_attempts_count
      assert_equal 2, telephone.reload.otp_attempts_count
      assert_equal deadline, email.lockout_expires_at
      assert_equal deadline, telephone.lockout_expires_at
    end
  end

  test "retires persisted client credentials while retaining original identifiers and Secret terminal audit" do
    now = Client.database_now
    client = Client.create!(status_id: ClientStatus::ACTIVE)
    email = ClientEmail.create!(
      user: client, address: "withdrawal-#{SecureRandom.hex(8)}@example.com",
    )
    original_address = email.address
    original_address_digest = email.address_digest
    telephone = ClientTelephone.create!(
      user: client, number: "+14155552671",
    )
    original_number = telephone.number
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
    )
    client.reload.update!(withdrawn_at: now, terminated_at: now)
    previous_delay = ENV["APP_SECRET_PURGE_DELAY_SECONDS"]
    ENV["APP_SECRET_PURGE_DELAY_SECONDS"] = "86400"

    assert_same client, WithdrawalPersonalDataAnonymizer.call(actor: client)
    assert_withheld("Original identifier must survive the retention boundary") {
      email.reload.address == original_address
    }
    assert_withheld("Immutable identifier digest must be preserved") { original_address_digest == email.address_digest }
    assert_not email.attributes.key?("otp_private_key")
    assert_not email.attributes.key?("otp_counter")
    assert_equal ClientEmailStatus::SUSPENDED, email.user_email_status_id
    assert_withheld("Original identifier must survive the retention boundary") {
      telephone.reload.number == original_number
    }
    assert_withheld("Immutable identifier digest must be preserved") {
      original_number_digest == telephone.number_digest
    }
    assert_not telephone.attributes.key?("otp_private_key")
    assert_not telephone.attributes.key?("otp_counter")
    assert_equal ClientTelephoneStatus::SUSPENDED, telephone.user_identity_telephone_status_id
    assert_not ClientExternalIdentity.exists?(external_identity.id)
    assert_equal ClientPasskeyStatus::REVOKED, passkey.reload.status_id
    assert_kind_of Time, passkey.discard_at
    assert_equal ClientTotpCredentialStatus::REVOKED, totp.reload.user_identity_totp_credential_status_id
    assert secret.reload.revoked_at
    assert_kind_of Time, secret.discard_at
    assert_nil ClientSecretLookupQuery.call(client: client, secret: raw)
    assert issuance.reload.canceled_at
    assert_equal %w(secret.discarded secret.revoked),
                 ClientSecretAuditOutbox.where(credential_ref: secret.public_id).order(:event_name).pluck(:event_name)
  ensure
    ENV["APP_SECRET_PURGE_DELAY_SECONDS"] = previous_delay
  end

  test "retires persisted visitor credentials without fabricating dead identifier history" do
    visitor = Visitor.create!(status_id: VisitorStatus::ACTIVE)
    now = Visitor.database_now
    email = VisitorEmail.create!(
      visitor: visitor, raw_address: "retired-visitor-#{SecureRandom.hex(8)}@example.test", confirm_policy: true,
    )
    telephone = VisitorTelephone.create!(
      visitor: visitor, raw_number: "+819012399926", confirm_policy: true, confirm_using_mfa: true,
    )
    email.finalize_binding!
    email.update!(visitor_email_status_id: VisitorEmailStatus::VERIFIED)
    [VisitorSecretCredentialStatus::ACTIVE, VisitorSecretCredentialStatus::REVOKED].each do |status|
      VisitorSecretCredentialStatus.find_or_create_by!(id: status)
    end
    VisitorSecretCredentialKind.find_or_create_by!(id: VisitorSecretCredentialKind::LOGIN)
    passkey = visitor.visitor_passkeys.create!(
      webauthn_id: SecureRandom.uuid, public_key: "withdrawal-test-key",
    )
    secret = visitor.visitor_secret_credentials.create!(name: "Withdrawal", password: SecureRandom.base58(32))
    visitor.reload
    visitor.update!(withdrawn_at: now, terminated_at: now, discard_at: now, purge_eligible_at: now + 1.day)

    assert_same visitor, WithdrawalPersonalDataAnonymizer.call(actor: visitor)
    assert_not email.reload.attributes.key?("otp_private_key")
    assert_not email.attributes.key?("otp_counter")
    assert_equal VisitorEmailStatus::SUSPENDED, email.visitor_email_status_id
    assert_not telephone.reload.attributes.key?("otp_private_key")
    assert_not telephone.attributes.key?("otp_counter")
    assert_equal VisitorTelephoneStatus::SUSPENDED, telephone.visitor_telephone_status_id
    assert_equal VisitorPasskeyStatus::REVOKED, passkey.reload.status_id
    assert_kind_of Time, passkey.discard_at
    assert_equal VisitorSecretCredentialStatus::REVOKED, secret.reload.visitor_secret_credential_status_id
    assert_kind_of Time, secret.discard_at
    assert_empty VisitorEmailHistory.where(visitor_id: visitor.id)
    assert_empty VisitorTelephoneHistory.where(visitor_id: visitor.id)
  end
end
