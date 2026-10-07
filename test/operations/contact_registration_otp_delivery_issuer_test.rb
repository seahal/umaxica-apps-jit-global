# frozen_string_literal: true

require "test_helper"

# Boolean snapshots avoid exposing OTP, destination and root material on failure.
# rubocop:disable Minitest/AssertEqual, Minitest/AssertOperator, Minitest/MultipleAssertions
class ContactRegistrationOtpDeliveryIssuerTest < ActiveSupport::TestCase
  %w(app com).each do |surface|
    %i(email telephone).each do |channel|
      %i(valid_code valid_without_code stale_counter resent_counter wrong_destination wrong_code
         verified released revoked device_revoked flow_expired consumed missing_context
         foreign_contact foreign_transaction cleared_otp finalized).each do |scenario|
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
          secret = ROTP::Base32.random_base32
          contact.store_otp(secret, 1, (contact.class.database_now + 10.minutes).to_i)
          otp = contact.get_otp
          code = ROTP::HOTP.new(otp.fetch(:otp_private_key)).at(otp.fetch(:otp_counter)).to_s
          nonce = SecureRandom.urlsafe_base64(32)
          transaction = ContactRegistrationOtpIssuer.call!(
            actor:, token:, contact:, channel:, browser_nonce: nonce, code:,
          )
          destination = (channel == :email) ? contact.address : contact.number
          arguments = { transaction:,
                        contact_ref: contact.public_id,
                        counter: contact.otp_counter.to_s,
                        destination:,
                        code:, }
          case scenario
          when :valid_without_code
            arguments.delete(:code)
          when :stale_counter
            arguments[:counter] = "0"
          when :resent_counter
            contact.store_otp(secret, 2, (contact.class.database_now + 10.minutes).to_i)
          when :wrong_destination
            arguments[:destination] = (channel == :email) ? "foreign@example.test" : "+819012345678"
          when :wrong_code
            arguments[:code] = (code == "000000") ? "000001" : "000000"
          when :verified
            assert_equal :verified, ContactRegistrationOtpVerificationCommitter.call!(
              actor:, token:, contact:, transaction:, channel:, browser_nonce: nonce, code:,
            )
            assert_nil contact.reload.get_otp
            assert_not_nil contact.credential_registration_otp_context.fetch("verified_at")
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
          when :missing_context
            contact.update!(credential_registration_otp_context: nil)
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
            other.store_otp(secret, 1, (other.class.database_now + 10.minutes).to_i)
            arguments[:contact_ref] = other.public_id
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
              surface:, actor_ref: actor.public_id, session_ref: token.public_id, operation: "registration",
              **candidate_fields,
            )
          when :cleared_otp
            contact.clear_otp
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

          assert_raises(ArgumentError) { ContactRegistrationOtpDeliveryIssuer.call(**arguments) }

          eligible =
            ContactRegistrationOtpDeliveryIssuer.call(**arguments) do
              calls += 1

              assert contact_facts == contact.reload.attributes, "Transport must not replace Source evidence"
              assert ticket_facts == transaction.reload.attributes, "Transport must retain the original Ticket"
            end
          expected = %i(valid_code valid_without_code).include?(scenario)

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
