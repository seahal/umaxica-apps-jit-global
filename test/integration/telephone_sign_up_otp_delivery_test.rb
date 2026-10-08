# frozen_string_literal: true

require "test_helper"

class TelephoneSignUpOtpDeliveryTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    [ClientSignUpFlowStatus, VisitorSignUpFlowStatus,
     ClientSignUpFlowCleanupStatus, VisitorSignUpFlowCleanupStatus,].each do |model|
      model::DEFAULTS.each { |id| model.find_or_create_by!(id: id) }
    end
  end

  %w(app com).each do |surface|
    %w(current reissued cancelled consumed expired browser_changed).each do |state|
      test "#{surface} queued Telephone signup authenticates #{state} proof immediately before SMS transport" do
        owner_model, telephone_model, flow_model, owner_key, status =
          case surface
          when "app" then [Client, ClientTelephone, ClientSignUpFlow, :user_id, ClientStatus::UNVERIFIED_WITH_SIGN_UP]
          when "com" then [Visitor, VisitorTelephone, VisitorSignUpFlow, :visitor_id, VisitorStatus::ACTIVE]
          end
        owner = owner_model.create!(status_id: status)
        telephone = telephone_model.create!(
          owner_key => owner.id, :raw_number => "+12025550145", :confirm_policy => true,
        )
        now = flow_model.database_now
        nonce = "telephone-delivery-browser"
        flow = flow_model.create!(
          principal_id: owner.id, status_id: flow_model::STATUS_MODEL::CONTACT_PENDING, step: "contact",
          nonce_digest: flow_model.digest_nonce(nonce), issued_at: now, expires_at: now + 15.minutes,
          entry_method: "telephone", pending_contact_type: "telephone", pending_contact_id: telephone.id,
        )
        issued = TelephoneSignUpOtpIssuer.call(flow: flow, telephone: telephone, session_nonce: nonce)
        clear_enqueued_jobs
        delivered = OtpTelephoneAdapter.new(surface: surface.to_sym).deliver(
          record: telephone, otp_code: issued.code, purpose: :sign_up,
          sign_up_flow_ref: flow.public_id,
          sign_up_telephone_transaction_ref: issued.transaction.transaction_id,
          sign_up_telephone_otp_generation: issued.transaction.otp_generation,
        )

        assert_predicate delivered, :accepted?
        assert_equal 1, enqueued_jobs.length
        arguments = enqueued_jobs.fetch(0).fetch(:args)

        assert_not JSON.generate(arguments).include?(issued.code)
        assert_not JSON.generate(arguments).include?(telephone.number)
        payload = OutboundSensitivePayload.decrypt_sms_delivery(arguments.fetch(0).fetch("encrypted_payload"))

        assert_equal issued.code, payload.fetch(:otp_code)
        assert_equal [surface, "sign_up", flow.public_id, issued.transaction.transaction_id,
                      issued.transaction.otp_generation,], payload.fetch(:otp_binding)
        transaction = issued.transaction
        transaction.issue_telephone_otp!(purpose: "sign_up") if state == "reissued"
        transaction.cancel_telephone_otp! if state == "cancelled"
        if state == "consumed"
          verified = TelephoneSignUpOtpVerificationCommitter.call(
            flow: flow, telephone: telephone, session_nonce: nonce, code: issued.code,
          )

          assert_predicate verified, :success?
        end
        flow.update!(nonce_digest: flow_model.digest_nonce("other-browser")) if state == "browser_changed"
        transported = []
        decision_time = (state == "expired") ? transaction.otp_expires_at : now
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
end
