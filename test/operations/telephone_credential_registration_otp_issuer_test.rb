# frozen_string_literal: true

require "test_helper"

class TelephoneCredentialRegistrationOtpIssuerTest < ActiveSupport::TestCase
  test "app Telephone registration retries a transaction reference collision in a savepoint" do
    actor = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
    token = ClientToken.create!(authentication_epoch: 0, user: actor, discard_at: 1.day.from_now)
    telephone = actor.client_telephones.create!(
      raw_number: "+12025550149", confirm_policy: true, confirm_using_mfa: true,
    )
    token.rotate_refresh_token!
    collision = "c" * 21
    replacement = "d" * 21
    existing_session = CredentialRegistrationOtpSessionValue.for(
      surface: "app", channel: :telephone, transaction_ref: collision,
      root_ref: token.public_id, browser_nonce: SecureRandom.urlsafe_base64(32),
    )
    ClientTelephoneCeremonyTransaction.create_transaction!(
      transaction_id: collision, actor_ref: actor.public_id, session_ref: existing_session.dump,
      operation: "registration", telephone_candidate_ref: telephone.public_id,
      normalized_number_digest: telephone.number_digest, expires_at: 1.day.from_now,
    )
    generated = [collision, "g" * 21, replacement, "h" * 21]
    generator = -> { generated.shift || raise(RuntimeError, "unexpected transaction reference generation") }

    issued = nil
    PublicId.stub(:generate, generator) do
      issued = TelephoneCredentialRegistrationOtpIssuer.call(
        actor: actor, token: token, telephone: telephone, browser_nonce: SecureRandom.urlsafe_base64(32),
      )
    end

    assert_predicate issued, :success?
    assert_equal replacement, issued.transaction.transaction_id
    assert_equal "h" * 21, issued.transaction.grant_jti
    assert_equal 2, ClientTelephoneCeremonyTransaction.where(actor_ref: actor.public_id).count
  end

  test "app Telephone registration retries a grant reference collision in a savepoint" do
    actor = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
    token = ClientToken.create!(authentication_epoch: 0, user: actor, discard_at: 1.day.from_now)
    telephone = actor.client_telephones.create!(
      raw_number: "+12025550#{SecureRandom.random_number(100_000).to_s.rjust(5, "0")}",
      confirm_policy: true, confirm_using_mfa: true,
    )
    token.rotate_refresh_token!
    collision = "i" * 21
    existing_session = CredentialRegistrationOtpSessionValue.for(
      surface: "app", channel: :telephone, transaction_ref: "j" * 21,
      root_ref: token.public_id, browser_nonce: SecureRandom.urlsafe_base64(32),
    )
    ClientTelephoneCeremonyTransaction.create_transaction!(
      transaction_id: "j" * 21, grant_jti: collision, actor_ref: actor.public_id,
      session_ref: existing_session.dump, operation: "registration", telephone_candidate_ref: telephone.public_id,
      normalized_number_digest: telephone.number_digest, expires_at: 1.day.from_now,
    )
    generated = ["k" * 21, collision, "l" * 21, "m" * 21]
    generator = -> { generated.shift || raise(RuntimeError, "unexpected grant reference generation") }

    issued = nil
    PublicId.stub(:generate, generator) do
      issued = TelephoneCredentialRegistrationOtpIssuer.call(
        actor: actor, token: token, telephone: telephone, browser_nonce: SecureRandom.urlsafe_base64(32),
      )
    end

    assert_predicate issued, :success?
    assert_equal "l" * 21, issued.transaction.transaction_id
    assert_equal "m" * 21, issued.transaction.grant_jti
  end

  test "org registration references an opaque candidate rather than a source database primary key" do
    actor = Operator.create!(security_mode_id: SecurityModeConfigurable::ADVANCED, status_id: OperatorStatus::ACTIVE)
    token = OperatorToken.create!(authentication_epoch: 0, staff: actor, discard_at: 1.day.from_now)
    telephone = actor.staff_telephones.create!(
      raw_number: "+12025550149", confirm_policy: true, confirm_using_mfa: true,
    )
    token.rotate_refresh_token!

    issued = TelephoneCredentialRegistrationOtpIssuer.call(
      actor: actor, token: token, telephone: telephone, browser_nonce: SecureRandom.urlsafe_base64(32),
    )

    assert_predicate issued, :success?
    assert_match(/\A[A-Za-z0-9_-]{21}\z/, issued.transaction.transaction_id)
    reference = issued.transaction.reload.telephone_candidate_ref

    assert_equal 21, reference.length
    assert_not_equal telephone.id.to_s, reference
    assert_equal telephone.reload.public_id, reference
    assert_equal actor.public_id, issued.transaction.actor_ref
    assert_equal telephone.number_digest, issued.transaction.normalized_number_digest
  end

  %w(app com).each do |surface|
    test "#{surface} registration with default Root expiry retains finite ceremony and OTP deadlines" do
      actor, token, telephone =
        case surface
        when "app"
          owner = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
          root = ClientToken.create!(authentication_epoch: 0, user: owner)
          candidate = owner.client_telephones.create!(raw_number: "+12025550145", confirm_policy: true)
          [owner, root, candidate]
        when "com"
          owner = Visitor.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: VisitorStatus::ACTIVE)
          root = VisitorToken.create!(authentication_epoch: 0, visitor: owner)
          candidate = owner.visitor_telephones.create!(raw_number: "+12025550146", confirm_policy: true)
          [owner, root, candidate]
        end
      token.rotate_refresh_token!

      assert_kind_of Time, token.reload.discard_at

      issued = TelephoneCredentialRegistrationOtpIssuer.call(
        actor: actor, token: token, telephone: telephone, browser_nonce: SecureRandom.urlsafe_base64(32),
      )

      assert_predicate issued, :success?
      transaction = issued.transaction.reload

      assert_equal transaction.created_at + IdentityTelephoneCeremonyTransaction::DEFAULT_TTL,
                   transaction.expires_at
      assert_operator transaction.expires_at, :<=, token.discard_at
      assert_operator transaction.otp_expires_at, :<=, transaction.expires_at
      assert_operator transaction.otp_expires_at, :>, transaction.created_at
    end

    test "#{surface} registration issues Telephone ceremony proof without changing Source proof or failures" do
      actor, token, telephone, transaction_model =
        case surface
        when "app"
          owner = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
          root = ClientToken.create!(authentication_epoch: 0, user: owner, discard_at: 1.day.from_now)
          candidate = owner.client_telephones.create!(
            raw_number: "+12025550141", confirm_policy: true, otp_attempts_count: 2,
          )
          [owner, root, candidate, ClientTelephoneCeremonyTransaction]
        when "com"
          owner = Visitor.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: VisitorStatus::ACTIVE)
          root = VisitorToken.create!(authentication_epoch: 0, visitor: owner, discard_at: 1.day.from_now)
          candidate = owner.visitor_telephones.create!(
            raw_number: "+12025550142", confirm_policy: true, otp_attempts_count: 2,
          )
          [owner, root, candidate, VisitorTelephoneCeremonyTransaction]
        end
      token.rotate_refresh_token!
      original = telephone.attributes.slice(
        "otp_private_key", "otp_counter", "otp_expires_at", "credential_registration_otp_context",
        "otp_attempts_count", "locked_at",
      )
      nonce = SecureRandom.urlsafe_base64(32)
      issued = TelephoneCredentialRegistrationOtpIssuer.call(
        actor: actor, token: token, telephone: telephone, browser_nonce: nonce,
      )

      assert_predicate issued, :success?
      assert_instance_of transaction_model, issued.transaction
      assert_match(/\A[0-9]{6}\z/, issued.code)
      assert_not_includes issued.inspect, issued.code
      assert_equal "registration", issued.transaction.operation
      assert_equal "credential_registration", issued.transaction.purpose
      assert_equal actor.public_id, issued.transaction.actor_ref
      assert_equal telephone.public_id, issued.transaction.telephone_candidate_ref
      assert_equal telephone.number_digest, issued.transaction.normalized_number_digest
      binding = CredentialRegistrationOtpSessionValue.for(
        surface: surface, channel: :telephone, transaction_ref: issued.transaction.transaction_id,
        root_ref: token.public_id, browser_nonce: nonce,
      )

      assert_equal binding.dump, issued.transaction.session_ref
      assert_equal original, telephone.reload.attributes.slice(*original.keys)
      assert issued.transaction.otp_verifier
      assert_nil issued.transaction.otp_consumed_at
    end

    test "#{surface} registration rejects a foreign original browser without consuming Telephone proof" do
      actor, token, telephone =
        case surface
        when "app"
          owner = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
          root = ClientToken.create!(authentication_epoch: 0, user: owner, discard_at: 1.day.from_now)
          candidate = owner.client_telephones.create!(
            raw_number: "+12025550143", confirm_policy: true, otp_attempts_count: 2,
          )
          [owner, root, candidate]
        when "com"
          owner = Visitor.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: VisitorStatus::ACTIVE)
          root = VisitorToken.create!(authentication_epoch: 0, visitor: owner, discard_at: 1.day.from_now)
          candidate = owner.visitor_telephones.create!(
            raw_number: "+12025550144", confirm_policy: true, otp_attempts_count: 2,
          )
          [owner, root, candidate]
        end
      token.rotate_refresh_token!
      issued = TelephoneCredentialRegistrationOtpIssuer.call(
        actor: actor, token: token, telephone: telephone, browser_nonce: SecureRandom.urlsafe_base64(32),
      )
      foreign = TelephoneCredentialRegistrationOtpVerificationCommitter.call(
        actor: actor, token: token, telephone: telephone, transaction: issued.transaction,
        browser_nonce: SecureRandom.urlsafe_base64(32), code: issued.code,
      )

      assert_equal :session_mismatch, foreign.status
      assert_not foreign.verified_evidence?
      assert_equal 2, telephone.reload.otp_attempts_count
      assert_nil issued.transaction.reload.otp_consumed_at
      assert issued.transaction.otp_verifier
    end
  end
end
