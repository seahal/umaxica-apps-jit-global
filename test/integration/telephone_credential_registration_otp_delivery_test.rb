# frozen_string_literal: true

require "test_helper"

class TelephoneCredentialRegistrationOtpDeliveryTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  %w(app com).each do |surface|
    %w(current reissued cancelled consumed expired root_rotated root_revoked owner_disabled).each do |state|
      test "#{surface} registration queued SMS authenticates #{state} Telephone proof before transport" do
        actor, token, telephone =
          case surface
          when "app"
            owner = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
            root = ClientToken.create!(authentication_epoch: 0, user: owner, discard_at: 1.day.from_now)
            candidate = owner.client_telephones.create!(raw_number: "+12025550161", confirm_policy: true)
            [owner, root, candidate]
          when "com"
            owner = Visitor.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: VisitorStatus::ACTIVE)
            root = VisitorToken.create!(authentication_epoch: 0, visitor: owner, discard_at: 1.day.from_now)
            candidate = owner.visitor_telephones.create!(raw_number: "+12025550162", confirm_policy: true)
            [owner, root, candidate]
          end
        token.rotate_refresh_token!
        nonce = SecureRandom.urlsafe_base64(32)
        issued = TelephoneCredentialRegistrationOtpIssuer.call(
          actor: actor, token: token, telephone: telephone, browser_nonce: nonce,
        )
        clear_enqueued_jobs
        delivered = OtpTelephoneAdapter.new(surface: surface.to_sym).deliver(
          record: telephone, otp_code: issued.code, purpose: :credential_registration,
          public_id: telephone.public_id, contact_ceremony_transaction_ref: issued.transaction.transaction_id,
          contact_otp_generation: issued.transaction.otp_generation,
        )

        assert_predicate delivered, :accepted?
        assert_equal 1, enqueued_jobs.length
        arguments = enqueued_jobs.fetch(0).fetch(:args)

        assert_not JSON.generate(arguments).include?(issued.code)
        assert_not JSON.generate(arguments).include?(telephone.number)
        payload = OutboundSensitivePayload.decrypt_sms_delivery(arguments.fetch(0).fetch("encrypted_payload"))

        assert_equal 4, payload.fetch(:version)
        assert_equal issued.code, payload.fetch(:otp_code)
        assert_equal [surface, "credential_registration", issued.transaction.transaction_id,
                      telephone.public_id, issued.transaction.otp_generation,], payload.fetch(:otp_binding)
        transaction = issued.transaction
        transaction.issue_telephone_otp!(purpose: "credential_registration") if state == "reissued"
        transaction.cancel_telephone_otp! if state == "cancelled"
        if state == "consumed"
          verified = TelephoneCredentialRegistrationOtpVerificationCommitter.call(
            actor: actor, token: token, telephone: telephone, transaction: transaction,
            browser_nonce: nonce, code: issued.code,
          )

          assert_predicate verified, :success?
        end
        if state == "root_rotated"
          rotated = token.class.rotate_refresh!(presented_refresh_digest: token.refresh_token_digest)

          assert_equal :rotated, rotated.fetch(:status)
          assert_not_equal token.id, rotated.fetch(:token).id
        end
        token.update!(discard_at: token.class.database_now) if state == "root_revoked"
        actor.update!(discard_at: actor.class.database_now) if state == "owner_disabled"
        transported = []
        decision_time = (state == "expired") ? transaction.otp_expires_at : transaction.class.database_now
        transaction.class.stub(:database_now, decision_time) do
          OutboundSms.stub(:deliver_now, ->(**message) { transported << message }) do
            perform_enqueued_jobs(only: Outbound::SmsDeliveryJob)
          end
        end

        assert_equal (state == "current") ? 1 : 0, transported.length
        if state == "current"
          assert_equal telephone.number, transported.fetch(0).fetch(:to)
          assert_includes transported.fetch(0).fetch(:body), issued.code
        end
      end
    end
  end

  test "legacy credential SMS counter binding is rejected instead of reconstructed" do
    assert_raises(ArgumentError) do
      OutboundSensitivePayload.encrypt_sms_delivery(
        to: "+12025550163", title: "Verification code", body: "Your verification code: 123456",
        otp_binding: ["app", "credential_registration", SecureRandom.uuid, "candidate", 1],
      )
    end
  end
end
