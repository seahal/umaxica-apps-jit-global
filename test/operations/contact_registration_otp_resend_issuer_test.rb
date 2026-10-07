# frozen_string_literal: true

require "test_helper"
require "minitest/mock"

# Boolean snapshots keep credentials, destinations and binding references out of failure output.
# rubocop:disable Minitest/AssertEqual, Minitest/AssertOperator, Minitest/MultipleAssertions
class ContactRegistrationOtpResendIssuerTest < ActiveSupport::TestCase
  %i(app com).each do |surface|
    %i(email telephone).each do |channel|
      scenarios = %i(success candidate_attempts candidate_locked shared_budget foreign_browser foreign_root
                     foreign_owner foreign_candidate foreign_flow verified revoked device_revoked expires_before
                     expires_at expires_after overflow source_fault)
      scenarios += %i(cooldown_before cooldown_at cooldown_after) if channel == :email
      scenarios.each do |scenario|
        test "#{surface} #{channel} resend #{scenario} retains the original challenge authority and budgets" do
          owner_model, root_model, contact_model, owner_key, flow_model =
            case [surface, channel]
            when [:app, :email]
              [Client, ClientToken, ClientEmail, :user_id, ClientEmailCeremonyTransaction]
            when [:app, :telephone]
              [Client, ClientToken, ClientTelephone, :user_id, ClientTelephoneCeremonyTransaction]
            when [:com, :email]
              [Visitor, VisitorToken, VisitorEmail, :visitor_id, VisitorEmailCeremonyTransaction]
            when [:com, :telephone]
              [Visitor, VisitorToken, VisitorTelephone, :visitor_id, VisitorTelephoneCeremonyTransaction]
            end
          actor = owner_model.create!(status_id: (surface == :app) ? ClientStatus::ACTIVE : VisitorStatus::ACTIVE)
          token = root_model.create!(owner_key => actor.id, :discard_at => 1.day.from_now)
          token.rotate_refresh_token!
          destination =
            (channel == :email) ? "resend-#{SecureRandom.hex(8)}@example.test" :
                         "+8190#{SecureRandom.random_number(10**8).to_s.rjust(8, "0")}"
          contact = contact_model.create!(
            owner_key => actor.id, :confirm_policy => "1",
            ((channel == :email) ? :raw_address : :raw_number) => destination,
            **((channel == :telephone) ? { confirm_using_mfa: "1" } : {}),
          )
          original_counter = (scenario == :overflow) ? (1 << 64) - 1 : 1
          secret = ROTP::Base32.random_base32
          contact.store_otp(secret, original_counter, (contact_model.database_now + 10.minutes).to_i)
          otp = contact.get_otp
          code = ROTP::HOTP.new(otp.fetch(:otp_private_key)).at(otp.fetch(:otp_counter)).to_s
          nonce = SecureRandom.urlsafe_base64(32)
          transaction = ContactRegistrationOtpIssuer.call!(
            actor:, token:, contact:, channel:, browser_nonce: nonce,
            code:,
          )
          verification = { actor:, token:, contact:, transaction:, channel:, browser_nonce: nonce, code: }
          arguments = verification.except(:code)
          digest = (channel == :email) ? contact.address_digest : contact.number_digest
          wrong_code = (code == "000000") ? "000001" : "000000"
          case scenario
          when :candidate_attempts, :candidate_locked

            ((scenario == :candidate_locked) ? 5 : 3).times do |attempt|
              assert_equal(
                (attempt < 4) ? :invalid_code : :locked, ContactRegistrationOtpVerificationCommitter.call!(
                  **verification.merge(code: wrong_code),
                ),
              )
            end
          when :shared_budget

            3.times do
              assert_equal :invalid_code, OtpVerificationFailureBudget.new.verify!(
                surface:, purpose: :credential_registration, channel:, destination_digest: digest, valid: false,
              )
            end
          when :foreign_browser
            arguments[:browser_nonce] = SecureRandom.urlsafe_base64(32)
          when :foreign_root
            replacement = root_model.create!(owner_key => actor.id, :discard_at => 1.day.from_now)
            replacement.rotate_refresh_token!
            arguments[:token] = replacement
          when :foreign_owner
            arguments[:actor] = owner_model.create!(status_id: (surface == :app) ? ClientStatus::ACTIVE : VisitorStatus::ACTIVE)
          when :foreign_candidate
            other_destination =
              (channel == :email) ? "foreign-resend-#{SecureRandom.hex(8)}@example.test" :
                           "+8190#{SecureRandom.random_number(10**8).to_s.rjust(8, "0")}"
            arguments[:contact] = contact_model.create!(
              owner_key => actor.id, :confirm_policy => "1",
              ((channel == :email) ? :raw_address : :raw_number) => other_destination,
              **((channel == :telephone) ? { confirm_using_mfa: "1" } : {}),
            )
          when :foreign_flow
            candidate_fields =
              (channel == :email) ?
                { email_candidate_ref: contact.public_id, normalized_email_digest: digest } :
                { telephone_candidate_ref: contact.public_id, normalized_number_digest: digest }
            arguments[:transaction] = flow_model.create_transaction!(
              surface:, actor_ref: actor.public_id, session_ref: token.public_id, operation: "registration",
              **candidate_fields,
            )
          when :verified
            assert_equal :verified, ContactRegistrationOtpVerificationCommitter.call!(**verification)
            assert_nil contact.reload.get_otp
          when :revoked
            token.revoke!
          when :device_revoked
            token.device_session.revoke!
          end
          original = contact.reload.attributes
          context = contact.credential_registration_otp_context.deep_dup
          ticket_facts = transaction.reload.attributes
          supplied_contact_facts = arguments.fetch(:contact).reload.attributes
          supplied_ticket_facts = arguments.fetch(:transaction).reload.attributes
          root_facts = token.reload.attributes
          owner_facts = actor.reload.attributes
          issued_at = Time.iso8601(context.fetch("issued_at"))
          decision_time = issued_at + 61.seconds
          if %i(expires_before expires_at expires_after).include?(scenario)
            # PostgreSQL timestamptz(6) supplies both nearest representable neighbors of the strict deadline.
            boundary = Time.iso8601(context.fetch("expires_at"))
            offset = { expires_before: -1, expires_at: 0, expires_after: 1 }.fetch(scenario)
            decision_time = boundary + Rational(offset, 1_000_000)
          elsif %i(cooldown_before cooldown_at cooldown_after).include?(scenario)
            # The existing shared send policy is thirty seconds; PostgreSQL represents both microsecond neighbors.
            boundary = contact.otp_last_sent_at + 30.seconds
            offset = { cooldown_before: -1, cooldown_at: 0, cooldown_after: 1 }.fetch(scenario)
            decision_time = boundary + Rational(offset, 1_000_000)
          end
          issuance = nil
          contact_model.stub(:database_now, decision_time) do
            flow_model.stub(:database_now, decision_time) do
              if scenario == :overflow
                assert_raises(RangeError) { ContactRegistrationOtpResendIssuer.call!(**arguments) }
              elsif scenario == :source_fault
                fired = false
                fault =
                  lambda do |event|
                    sql = event.payload.fetch(:sql)
                    next if fired || !sql.start_with?("UPDATE") || sql.exclude?(contact_model.table_name) ||
                      sql.exclude?("credential_registration_otp_context")

                    fired = true
                    raise ActiveRecord::StatementInvalid, "injected resend Source persistence failure"
                  end

                ActiveSupport::Notifications.subscribed(fault, "sql.active_record") do
                  assert_raises(ActiveRecord::StatementInvalid) { ContactRegistrationOtpResendIssuer.call!(**arguments) }
                end

                assert fired, "The actual resend Source persistence boundary must be reached"
              else
                issuance = ContactRegistrationOtpResendIssuer.call!(**arguments)
              end
              if %i(success candidate_attempts shared_budget expires_before cooldown_at
                    cooldown_after).include?(scenario)
                assert_kind_of Data, issuance
                assert issuance.transaction == transaction, "Resend must retain the original transaction"
                assert_equal (original_counter + 1).to_s, issuance.counter
                contact.reload
                updated = contact.credential_registration_otp_context
                otp = contact.get_otp

                assert otp, "Successful resend must retain an active Source challenge"
                assert ROTP::HOTP.new(otp.fetch(:otp_private_key)).at(otp.fetch(:otp_counter)).to_s == issuance.code,
                       "Resend must return the actual new HOTP"
                assert_not (otp.fetch(:otp_private_key) == secret), "Resend must replace the private key"
                assert_equal original_counter + 1, otp.fetch(:otp_counter)
                assert_equal original.fetch("otp_attempts_count"), contact.otp_attempts_count
                assert_equal original.fetch("otp_expires_at"), contact.otp_expires_at
                assert_equal context.keys.sort, updated.keys.sort
                assert context.except("counter", "code_digest", "issued_at") ==
                  updated.except("counter", "code_digest", "issued_at"),
                       "Resend must preserve all original bindings and both original deadlines"
                assert_equal decision_time.utc.iso8601(6), updated.fetch("issued_at")
                assert_equal issuance.counter, updated.fetch("counter")
                assert CredentialRegistrationOtpCodeDigest.for(context: updated, channel:, code: issuance.code) ==
                  updated.fetch("code_digest"), "Resend must HMAC-bind the complete updated issuance"
                old_delivered = false
                new_delivered = false

                assert_not ContactRegistrationOtpDeliveryIssuer.call(
                  transaction:, contact_ref: contact.public_id, counter: original_counter.to_s, destination:, code:,
                ) { old_delivered = true }
                assert ContactRegistrationOtpDeliveryIssuer.call(
                  transaction:, contact_ref: contact.public_id, counter: issuance.counter, destination:,
                  code: issuance.code,
                ) { new_delivered = true }
                assert_not old_delivered
                assert new_delivered
                if %i(candidate_attempts shared_budget).include?(scenario)
                  assert_equal :invalid_code, OtpVerificationFailureBudget.new.verify!(
                    surface:, purpose: :credential_registration, channel:, destination_digest: digest, valid: false,
                  )
                  assert_equal :locked, OtpVerificationFailureBudget.new.verify!(
                    surface:, purpose: :credential_registration, channel:, destination_digest: digest, valid: false,
                  )
                end
              else
                expected =
                  case scenario
                  when :cooldown_before then :cooldown
                  when :candidate_locked then :locked
                  else :unavailable
                  end
                unless %i(overflow source_fault).include?(scenario)
                  assert issuance == expected, "Resend refusal must return its exact classified status"
                end

                assert original == contact.reload.attributes,
                       "Refusal or fault must preserve the original Source issuance"
                assert supplied_contact_facts == arguments.fetch(:contact).reload.attributes,
                       "A substituted Contact must remain unchanged"
              end
            end
          end

          assert ticket_facts == transaction.reload.attributes, "Resend must not renew or replace the original Ticket"
          assert supplied_ticket_facts == arguments.fetch(:transaction).reload.attributes,
                 "A substituted Ticket must remain unchanged"
          assert root_facts == token.reload.attributes, "Resend must retain root facts"
          assert owner_facts == actor.reload.attributes, "Resend must retain owner facts"
        end
      end
    end
  end
end
# rubocop:enable Minitest/AssertEqual, Minitest/AssertOperator, Minitest/MultipleAssertions
