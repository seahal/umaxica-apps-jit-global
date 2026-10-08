# frozen_string_literal: true

require "test_helper"

# Boolean snapshots avoid exposing OTP, destination and root material on failure.
# rubocop:disable Minitest/AssertEqual, Minitest/AssertOperator, Minitest/MultipleAssertions
class ContactRegistrationOtpDeliveryIssuerTest < ActiveSupport::TestCase
  %w(app com).each do |surface|
    %i(email telephone).each do |channel|
      %i(valid_code missing_code stale_generation superseded_generation wrong_destination wrong_code
         verified released revoked device_revoked flow_expired consumed missing_challenge
         foreign_contact foreign_transaction cancelled_otp finalized).each do |scenario|
        test "#{surface} #{channel} registration delivery #{scenario} retains original candidate authority" do
          actor, token, contact, flow_model =
            case surface
            when "app"
              owner = Client.create!(status_id: ClientStatus::ACTIVE)
              root = ClientToken.create!(user: owner, discard_at: 1.day.from_now)
              candidate =
                if channel == :email
                  owner.client_emails.create!(
                    raw_address: "delivery-#{SecureRandom.hex(8)}@example.test", confirm_policy: "1",
                  )
                else
                  owner.client_telephones.create!(
                    raw_number: "+8190#{SecureRandom.random_number(10**8).to_s.rjust(8, "0")}",
                    confirm_policy: "1", confirm_using_mfa: "1",
                  )
                end
              [owner, root, candidate, (channel == :email) ? ClientEmailCeremonyTransaction :
                ClientTelephoneCeremonyTransaction,]
            when "com"
              owner = Visitor.create!
              root = VisitorToken.create!(visitor: owner, discard_at: 1.day.from_now)
              candidate =
                if channel == :email
                  owner.visitor_emails.create!(
                    raw_address: "delivery-#{SecureRandom.hex(8)}@example.test", confirm_policy: "1",
                  )
                else
                  owner.visitor_telephones.create!(
                    raw_number: "+8190#{SecureRandom.random_number(10**8).to_s.rjust(8, "0")}",
                    confirm_policy: "1", confirm_using_mfa: "1",
                  )
                end
              [owner, root, candidate, (channel == :email) ? VisitorEmailCeremonyTransaction :
                VisitorTelephoneCeremonyTransaction,]
            end
          token.rotate_refresh_token!
          nonce = SecureRandom.urlsafe_base64(32)
          issuer, verifier, guard, source =
            case channel
            when :email
              [EmailCredentialRegistrationOtpIssuer, EmailCredentialRegistrationOtpVerificationCommitter,
               EmailCredentialRegistrationOtpDeliveryGuard, { email: contact },]
            when :telephone
              [TelephoneCredentialRegistrationOtpIssuer, TelephoneCredentialRegistrationOtpVerificationCommitter,
               TelephoneCredentialRegistrationOtpDeliveryGuard, { telephone: contact },]
            end
          issued = issuer.call(actor:, token:, browser_nonce: nonce, **source)

          assert_predicate issued, :success?
          transaction = issued.transaction
          code = issued.code
          generation = transaction.otp_generation
          destination = (channel == :email) ? contact.address : contact.number
          arguments = { transaction:, generation:, destination:, code:, **source }
          case scenario
          when :missing_code
            arguments[:code] = nil
          when :stale_generation
            arguments[:generation] = SecureRandom.uuid
          when :superseded_generation
            case channel
            when :email then transaction.reissue_email_otp!
            when :telephone then transaction.issue_telephone_otp!(purpose: "credential_registration")
            end
          when :wrong_destination
            arguments[:destination] = (channel == :email) ? "foreign@example.test" : "+819012345678"
          when :wrong_code
            arguments[:code] = (code == "000000") ? "000001" : "000000"
          when :verified
            verified = verifier.call(actor:, token:, transaction:, browser_nonce: nonce, code:, **source)

            assert_predicate verified, :success?
            assert_predicate verified, :verified_evidence?
            assert_nil transaction.reload.otp_verifier
            assert_not_nil transaction.otp_consumed_at
            assert_not_nil transaction.otp_receipt_verifier
          when :released
            contact.finalize_binding!
            contact.release_binding!
          when :revoked
            token.revoke!
          when :device_revoked
            token.device_session.revoke!
          when :flow_expired
            # D-115 permits moving a persisted deadline instead of fabricating a business transition.
            transaction.update_columns(expires_at: flow_model.database_now - 1.second)
          when :consumed
            transaction.consume_result!(result_jti: SecureRandom.uuid, consumed_at: flow_model.database_now)
          when :missing_challenge
            transaction.update!(purpose: nil, otp_generation: nil, otp_verifier: nil, otp_expires_at: nil)
          when :foreign_contact
            other =
              case [surface, channel]
              when ["app", :email]
                actor.client_emails.create!(
                  raw_address: "foreign-#{SecureRandom.hex(8)}@example.test", confirm_policy: "1",
                )
              when ["com", :email]
                actor.visitor_emails.create!(
                  raw_address: "foreign-#{SecureRandom.hex(8)}@example.test", confirm_policy: "1",
                )
              when ["app", :telephone]
                actor.client_telephones.create!(
                  raw_number: "+8190#{SecureRandom.random_number(10**8).to_s.rjust(8, "0")}",
                  confirm_policy: "1", confirm_using_mfa: "1",
                )
              when ["com", :telephone]
                actor.visitor_telephones.create!(
                  raw_number: "+8190#{SecureRandom.random_number(10**8).to_s.rjust(8, "0")}",
                  confirm_policy: "1", confirm_using_mfa: "1",
                )
              end
            arguments[(channel == :email) ? :email : :telephone] = other
            arguments[:destination] = (channel == :email) ? other.address : other.number
            other_facts = other.reload.attributes
          when :foreign_transaction
            candidate_fields =
              if channel == :email
                { email_candidate_ref: contact.public_id, normalized_email_digest: contact.address_digest }
              else
                { telephone_candidate_ref: contact.public_id, normalized_number_digest: contact.number_digest }
              end
            arguments[:transaction] = flow_model.create_transaction!(
              surface:, actor_ref: actor.public_id, session_ref: transaction.session_ref, operation: "registration",
              **candidate_fields,
            )
          when :cancelled_otp
            case channel
            when :email then transaction.cancel_email_otp!
            when :telephone then transaction.cancel_telephone_otp!
            end
          when :finalized
            contact.finalize_binding!
          end
          contact_facts = contact.reload.attributes
          ticket_facts = transaction.reload.attributes
          supplied_ticket_facts = arguments.fetch(:transaction).reload.attributes
          root_facts = token.reload.attributes
          device_facts = token.device_session.reload.attributes
          owner_facts = actor.reload.attributes
          calls = 0

          assert_raises(ArgumentError) { guard.call(**arguments) }

          eligible =
            guard.call(**arguments) do
              calls += 1

              assert contact_facts == contact.reload.attributes, "Transport must not replace Source evidence"
              assert ticket_facts == transaction.reload.attributes, "Transport must retain the original Ticket"
            end
          expected = scenario == :valid_code

          assert_equal expected, eligible
          assert_equal(expected ? 1 : 0, calls)
          assert contact_facts == contact.reload.attributes, "Delivery must not consume or reconstruct Source evidence"
          assert ticket_facts == transaction.reload.attributes, "Delivery must not complete the original Ticket"
          assert supplied_ticket_facts == arguments.fetch(:transaction).reload.attributes,
                 "Delivery must not mutate a substituted Ticket"
          assert root_facts == token.reload.attributes, "Delivery must retain root facts"
          assert device_facts == token.device_session.reload.attributes, "Delivery must retain device facts"
          assert owner_facts == actor.reload.attributes, "Delivery must retain owner facts"
          assert other_facts == other.reload.attributes, "A foreign candidate must remain unchanged" if other_facts
        end
      end
    end
  end
end
# rubocop:enable Minitest/AssertEqual, Minitest/AssertOperator, Minitest/MultipleAssertions
