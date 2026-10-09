# frozen_string_literal: true

require "test_helper"

class SignupOtpDeliveryPayloadTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  %i(app com).each do |surface|
    %i(email telephone).each do |channel|
      ((channel == :email) ? [false, true] : [false]).each do |notifier_enabled|
        test "#{surface} #{channel} signup notifier=#{notifier_enabled} retains binding and encrypted code" do
          owner = (surface == :app) ? Client.create! : Visitor.create!
          contact_class, owner_key =
            case [surface, channel]
            when [:app, :email] then [ClientEmail, :user_id]
            when [:app, :telephone] then [ClientTelephone, :user_id]
            when [:com, :email] then [VisitorEmail, :visitor_id]
            when [:com, :telephone] then [VisitorTelephone, :visitor_id]
            end
          destination = (channel == :email) ? "payload-#{SecureRandom.hex(8)}@example.test" : "+819012345670"
          contact = contact_class.create!(
            owner_key => owner.id, :confirm_policy => "1",
            ((channel == :email) ? :address : :number) => destination,
          )
          transaction_ref = SecureRandom.uuid
          generation = SecureRandom.uuid
          delivery_binding =
            if channel == :email
              { sign_up_email_transaction_ref: transaction_ref, sign_up_email_otp_generation: generation }
            else
              { sign_up_telephone_transaction_ref: transaction_ref,
                sign_up_telephone_otp_generation: generation, }
            end
          clear_enqueued_jobs
          OtpEmailNotifierRollout.stub(:enabled?, notifier_enabled) do
            OtpAdapter.for(surface: surface, channel: channel).deliver(
              record: contact, otp_code: "001234", purpose: :sign_up, public_id: contact.public_id,
              sign_up_flow_ref: "flow_ref", **delivery_binding,
            )
          end

          assert_equal 1, enqueued_jobs.length
          arguments = enqueued_jobs.first.fetch(:args)
          if channel == :email
            assert_not enqueued_jobs.first.fetch(:job).log_arguments,
                       "OTP delivery job arguments must not expose original flow references in logs"
            params = arguments.last.fetch("params")

            assert_equal "flow_ref", params.fetch("sign_up_flow_ref")
            assert_equal transaction_ref, params.fetch("sign_up_email_transaction_ref")
            assert_equal generation, params.fetch("sign_up_email_otp_generation")
            assert_equal contact.public_id, params.fetch("public_id")
            plaintext_matches =
              OutboundSensitivePayload.decrypt_email_otp(params.fetch("encrypted_hotp_token")) == "001234"

            assert plaintext_matches, "the encrypted email code must retain the issued value"
          else
            payload = OutboundSensitivePayload.decrypt_sms_delivery(arguments.first.fetch("encrypted_payload"))

            assert_equal 3, payload.fetch(:version)
            assert_equal [surface.to_s, "sign_up", "flow_ref", transaction_ref, generation], payload.fetch(:otp_binding)
            assert_equal destination, payload.fetch(:to)
          end

          assert_not arguments.to_s.include?("001234"), "queued credentials must not contain the plaintext code"
        end
      end
    end
  end
end
