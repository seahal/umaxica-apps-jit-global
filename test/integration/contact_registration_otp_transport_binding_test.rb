# frozen_string_literal: true

require "test_helper"
require "minitest/mock"

# Boolean comparisons prevent failure output from exposing OTP and binding material.
# rubocop:disable Minitest/AssertEqual, Minitest/AssertOperator, Minitest/AssertIncludes, Minitest/MultipleAssertions
class ContactRegistrationOtpTransportBindingTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  %i(app com).each do |surface|
    %i(email telephone).each do |channel|
      states = %i(current verified reissued revoked expired missing_ticket wrong_destination wrong_code wrong_binding)
      states += [:current_localized] if channel == :telephone
      states.each do |state|
        test "#{surface} #{channel} registration transport #{state} checks encrypted original authority" do
          owner_model, contact_model, owner_key, flow_model, mailer =
            case [surface, channel]
            when [:app, :email]
              [Client, ClientEmail, :user_id, ClientEmailCeremonyTransaction, Email::App::OtpMailer]
            when [:app, :telephone]
              [Client, ClientTelephone, :user_id, ClientTelephoneCeremonyTransaction, nil]
            when [:com, :email]
              [Visitor, VisitorEmail, :visitor_id, VisitorEmailCeremonyTransaction, Email::Com::OtpMailer]
            when [:com, :telephone]
              [Visitor, VisitorTelephone, :visitor_id, VisitorTelephoneCeremonyTransaction, nil]
            end
          actor = owner_model.create!(status_id: (surface == :app) ? ClientStatus::ACTIVE : VisitorStatus::ACTIVE)
          token =
            (surface == :app) ? ClientToken.create!(user: actor, discard_at: 1.day.from_now) :
                        VisitorToken.create!(visitor: actor, discard_at: 1.day.from_now)
          token.rotate_refresh_token!
          destination =
            (channel == :email) ? "transport-#{SecureRandom.hex(8)}@example.test" :
                         "+8190#{SecureRandom.random_number(10**8).to_s.rjust(8, "0")}"
          contact = contact_model.create!(
            owner_key => actor.id, :confirm_policy => "1",
            ((channel == :email) ? :raw_address : :raw_number) => destination,
            **((channel == :telephone) ? { confirm_using_mfa: "1" } : {}),
          )
          secret = ROTP::Base32.random_base32
          contact.store_otp(secret, 1, (contact.class.database_now + 10.minutes).to_i)
          otp = contact.get_otp
          code = ROTP::HOTP.new(otp.fetch(:otp_private_key)).at(otp.fetch(:otp_counter)).to_s
          nonce = SecureRandom.urlsafe_base64(32)
          transaction = ContactRegistrationOtpIssuer.call!(
            actor:, token:, contact:, channel:, browser_nonce: nonce, code:,
          )
          provider = Minitest::Mock.new
          message_style = (state == :current_localized) ? :localized_verification : :default
          expected_body =
            (state == :current_localized) ? I18n.t("sign.telephone_verification.sms_message", code:) :
                              "Your verification code: #{code}"
          clear_enqueued_jobs
          adapter = OtpAdapter.for(surface:, channel:)

          assert_instance_of((channel == :email) ? OtpEmailAdapter : OtpTelephoneAdapter, adapter)

          OutboundSms.stub(:provider, provider) do
            adapter.deliver(
              record: contact, otp_code: code, purpose: "credential_registration", public_id: contact.public_id,
              contact_ceremony_transaction_ref: transaction.transaction_id, contact_otp_counter: "1",
              message_style:,
            )
          end

          assert_equal 1, enqueued_jobs.length
          arguments = enqueued_jobs.first.fetch(:args)

          assert_not arguments.to_s.include?(code), "Queued transport must not expose the plaintext OTP"
          if channel == :email
            params = arguments.last.fetch("params").symbolize_keys

            assert params.fetch(:contact_ceremony_transaction_ref) == transaction.transaction_id,
                   "Email must retain the original ceremony UUID"
            assert params.fetch(:public_id) == contact.public_id, "Email must retain the original Contact"
            assert_equal "credential_registration", params.fetch(:purpose)
            assert_equal "1", params.fetch(:contact_otp_counter)
            assert OutboundSensitivePayload.decrypt_email_otp(params.fetch(:encrypted_hotp_token)) == code,
                   "Email ciphertext must contain the issued HOTP"
          else
            payload = OutboundSensitivePayload.decrypt_sms_delivery(arguments.first.fetch("encrypted_payload"))

            assert_equal 2, payload.fetch(:version)
            assert payload.fetch(:otp_binding) ==
              [surface.to_s, "credential_registration", transaction.transaction_id, contact.public_id, "1"],
                   "SMS envelope must retain the complete original five-tuple"
            assert payload.fetch(:to) == destination, "SMS must retain the original destination"
            assert payload.fetch(:body) == expected_body, "SMS must encrypt the issued HOTP in the selected template"
          end
          case state
          when :verified
            assert_equal :verified, ContactRegistrationOtpVerificationCommitter.call!(
              actor:, token:, contact:, transaction:, channel:, browser_nonce: nonce, code:,
            )
            assert_nil contact.reload.get_otp
          when :reissued
            contact.store_otp(secret, 2, (contact.class.database_now + 10.minutes).to_i)
          when :revoked
            token.revoke!
          when :expired
            # D-115 permits moving the original persisted deadline without inventing a business transition.
            transaction.update_columns(expires_at: flow_model.database_now - 1.second)
          when :missing_ticket, :wrong_binding
            replacement_ref = SecureRandom.uuid
            if state == :wrong_binding
              candidate_fields =
                (channel == :email) ?
                  { email_candidate_ref: contact.public_id, normalized_email_digest: contact.address_digest } :
                  { telephone_candidate_ref: contact.public_id, normalized_number_digest: contact.number_digest }
              other_transaction = flow_model.create_transaction!(
                surface:, actor_ref: actor.public_id, session_ref: token.public_id, operation: "registration",
                **candidate_fields,
              )
              replacement_ref = other_transaction.transaction_id
              other_ticket_facts = other_transaction.reload.attributes
            end
            if channel == :email
              params[:contact_ceremony_transaction_ref] = replacement_ref
            else
              payload[:otp_binding][2] = replacement_ref
            end
          when :wrong_destination
            foreign_destination = (channel == :email) ? "foreign@example.test" : "+819012345678"
            if channel == :email
              params[:email_address] = foreign_destination
            else
              payload[:to] = foreign_destination
            end
          when :wrong_code
            wrong_code = (code == "000000") ? "000001" : "000000"
            if channel == :email
              params[:encrypted_hotp_token] = OutboundSensitivePayload.encrypt_email_otp(wrong_code)
            else
              payload[:body] = "Your verification code: #{wrong_code}"
            end
          end
          contact_facts = contact.reload.attributes
          ticket_facts = transaction.reload.attributes
          root_facts = token.reload.attributes
          device_facts = token.device_session.reload.attributes
          owner_facts = actor.reload.attributes
          if channel == :email
            before = ActionMailer::Base.deliveries.length
            mailer.with(params).create.deliver_now
            sent = ActionMailer::Base.deliveries.length - before
            if state == :current
              delivered = ActionMailer::Base.deliveries.last

              assert delivered.to == [destination], "Delivered email must target the bound destination"
              assert_not_nil delivered.text_part, "OTP email must include the existing plain-text MIME part"
              assert delivered.text_part.body.decoded.include?(code), "Delivered email must contain the issued OTP"
            end
          else
            expected_calls = %i(current current_localized).include?(state) ? 1 : 0
            calls = 0
            if expected_calls == 1
              provider.expect(:send_message, OutboundResult.accepted(channel: :sms)) do |**fields|
                calls += 1
                fields == { to: destination, title: "Verification code", body: expected_body }
              end
            end
            encrypted = OutboundSensitivePayload.encrypt_sms_delivery(**payload.slice(:to, :title, :body, :otp_binding))
            OutboundSms.stub(:provider, provider) do
              Outbound::SmsDeliveryJob.perform_now(encrypted_payload: encrypted)
            end
            provider.verify
            sent = calls
          end

          assert_equal(%i(current current_localized).include?(state) ? 1 : 0, sent)
          assert contact_facts == contact.reload.attributes, "Transport must preserve Source OTP and proof facts"
          assert ticket_facts == transaction.reload.attributes, "Transport must preserve the original Ticket"
          assert root_facts == token.reload.attributes, "Transport must preserve root facts"
          assert device_facts == token.device_session.reload.attributes, "Transport must preserve device facts"
          assert owner_facts == actor.reload.attributes, "Transport must preserve owner facts"
          if other_ticket_facts
            assert other_ticket_facts == other_transaction.reload.attributes,
                   "Transport must preserve a substituted Ticket"
          end
        end
      end
    end
  end
end
# rubocop:enable Minitest/AssertEqual, Minitest/AssertOperator, Minitest/AssertIncludes, Minitest/MultipleAssertions
