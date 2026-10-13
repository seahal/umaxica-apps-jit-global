# frozen_string_literal: true

require "test_helper"

class EmailReentryOtpIssuerTest < ActiveJob::TestCase
  test "issuance rejects malformed browser references before proof timestamp or queue mutation" do
    email = ClientEmail.create!(
      user: clients(:one), raw_address: "reentry-nonce-#{SecureRandom.hex(8)}@example.test", confirm_policy: true,
    )
    before = email.attributes
    reference = SecureRandom.uuid

    assert_no_difference "ClientEmailCeremonyTransaction.count" do
      assert_no_enqueued_jobs only: OtpNotifierEmailDeliveryJob do
        [nil, "", 0, false, reference[0...-1], "#{reference}x", "#{reference}\0",
         "\xFF",].each do |invalid|
          assert_raises(ArgumentError) do
            EmailReentryOtpIssuer.call(email: email, operation: "recovery", session_ref: invalid)
          end
        end
      end
    end
    unchanged = before == email.reload.attributes

    assert unchanged
  end

  %w(app com org).each do |surface|
    operations = (surface == "org") ? %w(recovery) : %w(recovery withdrawal)
    operations.each do |operation|
      test "#{surface} #{operation} issuance stores proof only on its ceremony and queues encrypted generation" do
        email_model, transaction_model, owner_key, owner =
          case surface
          when "app" then [ClientEmail, ClientEmailCeremonyTransaction, :user_id, clients(:one)]
          when "com" then [VisitorEmail, VisitorEmailCeremonyTransaction, :visitor_id, visitors(:reserved_visitor)]
          when "org" then [OperatorEmail, OperatorEmailCeremonyTransaction, :staff_id, operators(:one)]
          end
        email = email_model.create!(
          owner_key => owner.id, :raw_address => "reentry-issuer-#{SecureRandom.hex(8)}@example.test",
          :confirm_policy => true, :otp_attempts_count => 1,
        )
        before = email.attributes.slice("otp_private_key", "otp_counter", "otp_expires_at", "otp_attempts_count")
        browser_ref = SecureRandom.uuid
        transaction = nil

        assert_enqueued_jobs 1, only: OtpNotifierEmailDeliveryJob do
          transaction = EmailReentryOtpIssuer.call(email: email, operation: operation, session_ref: browser_ref)
        end
        assert_instance_of transaction_model, transaction
        assert_equal operation, transaction.operation
        assert_equal operation, transaction.purpose
        assert_match(/\A[A-Za-z0-9_-]{21}\z/, transaction.transaction_id)
        assert_match(/\A[A-Za-z0-9_-]{21}\z/, transaction.grant_jti)
        assert_equal browser_ref, transaction.session_ref
        assert_equal owner.public_id, transaction.actor_ref
        assert_equal email.public_id, transaction.email_candidate_ref
        assert_equal before, email.reload.attributes.slice(*before.keys)
        assert email.otp_last_sent_at
        notification = ActiveJob::Arguments.deserialize(enqueued_jobs.last.fetch(:args)).last
        payload = notification.fetch(:params)

        assert_equal %i(email_ceremony_transaction_ref email_otp_generation encrypted_hotp_token
                        encrypted_verification_token public_id purpose), payload.keys.sort
        assert_equal email.to_global_id, notification.fetch(:recipient).to_global_id
        assert_equal transaction.transaction_id, payload.fetch(:email_ceremony_transaction_ref)
        assert_equal transaction.otp_generation, payload.fetch(:email_otp_generation)
        code = OutboundSensitivePayload.decrypt_email_otp(payload.fetch(:encrypted_hotp_token))

        assert_match(/\A[0-9]{6}\z/, code)
        assert transaction.verify_email_otp!(
          code: code, purpose: operation, actor_ref: owner.public_id, session_ref: browser_ref,
          operation: operation, candidate_ref: email.public_id,
        )
        assert_no_enqueued_jobs only: OtpNotifierEmailDeliveryJob do
          assert_nil EmailReentryOtpIssuer.call(email: email, operation: operation, session_ref: browser_ref)
        end
      end
    end
  end

  test "ORG cannot issue withdrawal reentry proof or delivery" do
    email = OperatorEmail.create!(
      staff: operators(:one), raw_address: "unsupported-org-reentry@example.test",
      confirm_policy: true,
    )

    assert_no_enqueued_jobs only: OtpNotifierEmailDeliveryJob do
      error =
        assert_raises(ArgumentError) do
          EmailReentryOtpIssuer.call(email: email, operation: "withdrawal", session_ref: SecureRandom.uuid)
        end

      assert_equal "ORG withdrawal reentry is unsupported", error.message
    end
  end

  test "reentry retries a generated transaction reference collision in a savepoint" do
    owner = clients(:one)
    email = owner.client_emails.create!(
      raw_address: "reentry-collision-#{SecureRandom.hex(8)}@example.test", confirm_policy: true,
    )
    collision = "a" * 21
    existing_session = SecureRandom.uuid
    ClientEmailCeremonyTransaction.create_transaction!(
      transaction_id: collision, actor_ref: owner.public_id, session_ref: existing_session,
      operation: "recovery", email_candidate_ref: email.public_id,
      normalized_email_digest: email.address_digest, expires_at: 1.day.from_now,
    )
    generated = [collision, "g" * 21, "b" * 21, "h" * 21]
    generator = -> { generated.shift || raise(RuntimeError, "unexpected reference generation") }

    issued = nil
    PublicId.stub(:generate, generator) do
      issued = EmailReentryOtpIssuer.call(email: email, operation: "recovery", session_ref: SecureRandom.uuid)
    end

    assert_predicate issued, :persisted?
    assert_equal "b" * 21, issued.transaction_id
    assert_equal "h" * 21, issued.grant_jti
  end

  test "reentry retries a generated grant reference collision in a savepoint" do
    owner = clients(:one)
    email = owner.client_emails.create!(
      raw_address: "reentry-grant-collision-#{SecureRandom.hex(8)}@example.test", confirm_policy: true,
    )
    collision = "i" * 21
    ClientEmailCeremonyTransaction.create_transaction!(
      transaction_id: "j" * 21, grant_jti: collision, actor_ref: owner.public_id,
      session_ref: SecureRandom.uuid, operation: "recovery", email_candidate_ref: email.public_id,
      normalized_email_digest: email.address_digest, expires_at: 1.day.from_now,
    )
    generated = ["k" * 21, collision, "l" * 21, "m" * 21]
    generator = -> { generated.shift || raise(RuntimeError, "unexpected reference generation") }

    issued = nil
    PublicId.stub(:generate, generator) do
      issued = EmailReentryOtpIssuer.call(email: email, operation: "recovery", session_ref: SecureRandom.uuid)
    end

    assert_predicate issued, :persisted?
    assert_equal "l" * 21, issued.transaction_id
    assert_equal "m" * 21, issued.grant_jti
  end
end
