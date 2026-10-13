# frozen_string_literal: true

require "test_helper"

class EmailCredentialRegistrationOtpIssuerTest < ActiveSupport::TestCase
  %w(app com org).each do |surface|
    test "#{surface} Email registration bounds its ceremony within the default Root lifetime" do
      owner_model, root_model, email_model, owner_key, active_status =
        case surface
        when "app" then [Client, ClientToken, ClientEmail, :user_id, ClientStatus::ACTIVE]
        when "com" then [Visitor, VisitorToken, VisitorEmail, :visitor_id, VisitorStatus::ACTIVE]
        when "org" then [Operator, OperatorToken, OperatorEmail, :staff_id, OperatorStatus::ACTIVE]
        end
      actor = owner_model.create!(status_id: active_status)
      token = root_model.create!(owner_key => actor.id)
      token.rotate_refresh_token!
      email = email_model.create!(
        owner_key => actor.id, :raw_address => "infinite-root-#{SecureRandom.hex(8)}@example.test",
        :confirm_policy => true, :otp_attempts_count => 1,
      )

      assert_operator token.discard_at, :>, email_model.database_now
      issued = EmailCredentialRegistrationOtpIssuer.call(
        actor: actor, token: token, email: email, browser_nonce: SecureRandom.urlsafe_base64(32),
      )

      assert_predicate issued, :success?
      assert_equal issued.transaction.created_at + EmailCeremonyTransactionable::DEFAULT_TTL,
                   issued.transaction.expires_at
      assert_operator issued.transaction.otp_expires_at, :<=, issued.transaction.expires_at
      assert_operator issued.transaction.expires_at, :<=, token.discard_at
      assert_equal 1, email.reload.otp_attempts_count
    end

    test "#{surface} Email registration verification binds the original Root and browser and consumes once" do
      actor, token, email =
        case surface
        when "app"
          owner = Client.create!(status_id: ClientStatus::ACTIVE)
          root = ClientToken.create!(user: owner, discard_at: 1.day.from_now)
          candidate = owner.client_emails.create!(
            raw_address: "verify-registration-#{SecureRandom.hex(8)}@example.test", confirm_policy: true,
            otp_attempts_count: 1,
          )
          [owner, root, candidate]
        when "org"
          owner = Operator.create!(status_id: OperatorStatus::ACTIVE)
          root = OperatorToken.create!(staff: owner, discard_at: 1.day.from_now)
          candidate = owner.staff_emails.create!(
            raw_address: "verify-registration-#{SecureRandom.hex(8)}@example.test", confirm_policy: true,
            otp_attempts_count: 1,
          )
          [owner, root, candidate]
        when "com"
          owner = Visitor.create!(status_id: VisitorStatus::ACTIVE)
          root = VisitorToken.create!(visitor: owner, discard_at: 1.day.from_now)
          candidate = owner.visitor_emails.create!(
            raw_address: "verify-registration-#{SecureRandom.hex(8)}@example.test", confirm_policy: true,
            otp_attempts_count: 1,
          )
          [owner, root, candidate]
        end
      token.rotate_refresh_token!
      nonce = SecureRandom.urlsafe_base64(32)
      issued = EmailCredentialRegistrationOtpIssuer.call(actor: actor, token: token, email: email, browser_nonce: nonce)
      scope = { actor: actor, token: token, email: email, transaction: issued.transaction, browser_nonce: nonce }
      foreign = EmailCredentialRegistrationOtpVerificationCommitter.call(
        **scope.merge(browser_nonce: SecureRandom.urlsafe_base64(32)), code: issued.code,
      )

      assert_equal :session_mismatch, foreign.status
      assert_not foreign.verified_evidence?
      assert_equal 1, email.reload.otp_attempts_count
      assert_nil issued.transaction.reload.otp_consumed_at
      wrong_code = (issued.code == "000000") ? "000001" : "000000"
      wrong = EmailCredentialRegistrationOtpVerificationCommitter.call(**scope, code: wrong_code)

      assert_equal :invalid_code, wrong.status
      assert_equal 2, email.reload.otp_attempts_count
      verified = EmailCredentialRegistrationOtpVerificationCommitter.call(**scope, code: issued.code)

      assert_predicate verified, :success?
      assert_predicate verified, :verified_evidence?
      assert_equal 0, email.reload.otp_attempts_count
      assert issued.transaction.reload.otp_consumed_at
      assert_nil issued.transaction.otp_verifier
      assert_not email.attributes.key?("credential_registration_otp_context")
      email.update!(otp_attempts_count: 1)
      resumed = EmailCredentialRegistrationOtpVerificationCommitter.call(**scope, code: issued.code)

      assert_equal :already_verified, resumed.status
      assert_not resumed.success?
      assert_predicate resumed, :verified_evidence?
      assert_equal 1, email.reload.otp_attempts_count
    end

    test "#{surface} Email registration owns random proof on the original Root browser bound ceremony" do
      actor, token, email, transaction_model =
        case surface
        when "app"
          owner = Client.create!(status_id: ClientStatus::ACTIVE)
          root = ClientToken.create!(user: owner, discard_at: 1.day.from_now)
          candidate = owner.client_emails.create!(
            raw_address: "email-registration-#{SecureRandom.hex(8)}@example.test", confirm_policy: true,
            otp_attempts_count: 1,
          )
          [owner, root, candidate, ClientEmailCeremonyTransaction]
        when "com"
          owner = Visitor.create!(status_id: VisitorStatus::ACTIVE)
          root = VisitorToken.create!(visitor: owner, discard_at: 1.day.from_now)
          candidate = owner.visitor_emails.create!(
            raw_address: "email-registration-#{SecureRandom.hex(8)}@example.test", confirm_policy: true,
            otp_attempts_count: 1,
          )
          [owner, root, candidate, VisitorEmailCeremonyTransaction]
        when "org"
          owner = Operator.create!(status_id: OperatorStatus::ACTIVE)
          root = OperatorToken.create!(staff: owner, discard_at: 1.day.from_now)
          candidate = owner.staff_emails.create!(
            raw_address: "email-registration-#{SecureRandom.hex(8)}@example.test", confirm_policy: true,
            otp_attempts_count: 1,
          )
          [owner, root, candidate, OperatorEmailCeremonyTransaction]
        end
      token.rotate_refresh_token!
      original = email.attributes.slice(
        "public_id", "address_digest", "number_digest", "user_id", "visitor_id", "staff_id",
      )
      nonce = SecureRandom.urlsafe_base64(32)
      issued = EmailCredentialRegistrationOtpIssuer.call(actor: actor, token: token, email: email, browser_nonce: nonce)

      assert_predicate issued, :success?
      assert_instance_of transaction_model, issued.transaction
      assert_match(/\A[A-Za-z0-9_-]{21}\z/, issued.transaction.transaction_id)
      assert_match(/\A[A-Za-z0-9_-]{21}\z/, issued.transaction.grant_jti)
      assert_match(/\A[0-9]{6}\z/, issued.code)
      assert_not_includes issued.inspect, issued.code
      assert_equal "registration", issued.transaction.operation
      assert_equal "credential_registration", issued.transaction.purpose
      assert_equal actor.public_id, issued.transaction.actor_ref
      assert_equal email.public_id, issued.transaction.email_candidate_ref
      assert_equal email.address_digest, issued.transaction.normalized_email_digest
      expected_session = CredentialRegistrationOtpSessionValue.for(
        surface: surface, channel: :email, transaction_ref: issued.transaction.transaction_id,
        root_ref: token.public_id, browser_nonce: nonce,
      )

      assert_equal expected_session.dump, issued.transaction.session_ref
      assert_equal original, email.reload.attributes.slice(*original.keys)
      assert_equal 1, email.otp_attempts_count
      assert issued.transaction.otp_verifier
      assert_nil issued.transaction.otp_consumed_at
      assert_not issued.transaction.verify_email_otp!(
        code: issued.code, purpose: "sign_in", actor_ref: actor.public_id,
        session_ref: expected_session.dump, operation: "registration", candidate_ref: email.public_id,
      )
      foreign_session = CredentialRegistrationOtpSessionValue.for(
        surface: surface, channel: :email, transaction_ref: issued.transaction.transaction_id,
        root_ref: token.public_id, browser_nonce: SecureRandom.urlsafe_base64(32),
      )

      assert_not issued.transaction.verify_email_otp!(
        code: issued.code, purpose: "credential_registration", actor_ref: actor.public_id,
        session_ref: foreign_session.dump, operation: "registration", candidate_ref: email.public_id,
      )
      assert_nil issued.transaction.reload.otp_consumed_at
    end
  end

  test "app Email registration retries a transaction reference collision in a savepoint" do
    actor = Client.create!(status_id: ClientStatus::ACTIVE)
    token = ClientToken.create!(user: actor, discard_at: 1.day.from_now)
    email = actor.client_emails.create!(
      raw_address: "collision-#{SecureRandom.hex(8)}@example.test", confirm_policy: true, otp_attempts_count: 1,
    )
    token.rotate_refresh_token!
    collision = "a" * 21
    replacement = "b" * 21
    existing_session = CredentialRegistrationOtpSessionValue.for(
      surface: "app", channel: :email, transaction_ref: collision,
      root_ref: token.public_id, browser_nonce: SecureRandom.urlsafe_base64(32),
    )
    ClientEmailCeremonyTransaction.create_transaction!(
      transaction_id: collision, actor_ref: actor.public_id, session_ref: existing_session.dump,
      operation: "registration", email_candidate_ref: email.public_id,
      normalized_email_digest: email.address_digest, expires_at: 1.day.from_now,
    )
    generated = [collision, "g" * 21, replacement, "h" * 21]
    generator = -> { generated.shift || raise(RuntimeError, "unexpected transaction reference generation") }

    issued = nil
    PublicId.stub(:generate, generator) do
      issued = EmailCredentialRegistrationOtpIssuer.call(
        actor: actor, token: token, email: email, browser_nonce: SecureRandom.urlsafe_base64(32),
      )
    end

    assert_predicate issued, :success?
    assert_equal replacement, issued.transaction.transaction_id
    assert_equal "h" * 21, issued.transaction.grant_jti
    assert_equal 2, ClientEmailCeremonyTransaction.where(actor_ref: actor.public_id).count
  end

  test "app Email registration retries a grant reference collision in a savepoint" do
    actor = Client.create!(status_id: ClientStatus::ACTIVE)
    token = ClientToken.create!(user: actor, discard_at: 1.day.from_now)
    email = actor.client_emails.create!(
      raw_address: "grant-collision-#{SecureRandom.hex(8)}@example.test", confirm_policy: true,
      otp_attempts_count: 1,
    )
    token.rotate_refresh_token!
    collision = "i" * 21
    existing_session = CredentialRegistrationOtpSessionValue.for(
      surface: "app", channel: :email, transaction_ref: "j" * 21,
      root_ref: token.public_id, browser_nonce: SecureRandom.urlsafe_base64(32),
    )
    ClientEmailCeremonyTransaction.create_transaction!(
      transaction_id: "j" * 21, grant_jti: collision, actor_ref: actor.public_id,
      session_ref: existing_session.dump, operation: "registration", email_candidate_ref: email.public_id,
      normalized_email_digest: email.address_digest, expires_at: 1.day.from_now,
    )
    generated = ["k" * 21, collision, "l" * 21, "m" * 21]
    generator = -> { generated.shift || raise(RuntimeError, "unexpected grant reference generation") }

    issued = nil
    PublicId.stub(:generate, generator) do
      issued = EmailCredentialRegistrationOtpIssuer.call(
        actor: actor, token: token, email: email, browser_nonce: SecureRandom.urlsafe_base64(32),
      )
    end

    assert_predicate issued, :success?
    assert_equal "l" * 21, issued.transaction.transaction_id
    assert_equal "m" * 21, issued.transaction.grant_jti
  end
end
