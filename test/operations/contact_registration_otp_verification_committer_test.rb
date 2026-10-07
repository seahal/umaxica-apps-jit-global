# frozen_string_literal: true

require "test_helper"
require "minitest/mock"

# Boolean snapshots avoid disclosing OTP, proof and root material when an assertion fails.
# rubocop:disable Minitest/AssertEqual, Minitest/AssertOperator, Minitest/MultipleAssertions
class ContactRegistrationOtpVerificationCommitterTest < ActiveSupport::TestCase
  %w(app com).each do |surface|
    %i(email telephone).each do |channel|
      %i(success wrong_code foreign_browser foreign_owner foreign_root foreign_candidate foreign_ticket
         released revoked destination_locked candidate_locked
         challenge_before challenge_at challenge_after proof_before proof_at proof_after).each do |scenario|
        test "#{surface} #{channel} registration verification #{scenario} preserves its original authority" do
          actor, token, contact, flow_model, token_model =
            case [surface, channel]
            when ["app", :email], ["app", :telephone]
              owner = Client.create!(status_id: ClientStatus::ACTIVE)
              root = ClientToken.create!(user: owner, discard_at: 1.day.from_now)
              candidate =
                if channel == :email
                  owner.client_emails.create!(
                    raw_address: "verification-#{SecureRandom.hex(8)}@example.test", confirm_policy: "1",
                  )
                else
                  owner.client_telephones.create!(
                    raw_number: "+8190#{SecureRandom.random_number(10**8).to_s.rjust(8, "0")}",
                    confirm_policy: "1", confirm_using_mfa: "1",
                  )
                end
              [owner, root, candidate, (channel == :email) ? ClientEmailCeremonyTransaction :
                ClientTelephoneCeremonyTransaction, ClientToken,]
            when ["com", :email], ["com", :telephone]
              owner = Visitor.create!
              root = VisitorToken.create!(visitor: owner, discard_at: 1.day.from_now)
              candidate =
                if channel == :email
                  owner.visitor_emails.create!(
                    raw_address: "verification-#{SecureRandom.hex(8)}@example.test", confirm_policy: "1",
                  )
                else
                  owner.visitor_telephones.create!(
                    raw_number: "+8190#{SecureRandom.random_number(10**8).to_s.rjust(8, "0")}",
                    confirm_policy: "1", confirm_using_mfa: "1",
                  )
                end
              [owner, root, candidate, (channel == :email) ? VisitorEmailCeremonyTransaction :
                VisitorTelephoneCeremonyTransaction, VisitorToken,]
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
          arguments = { actor:, token:, contact:, transaction:, channel:, browser_nonce: nonce, code: }
          issued_context = contact.reload.credential_registration_otp_context.deep_dup
          original_otp = contact.get_otp
          ticket_facts = transaction.reload.attributes
          root_count = token_model.count
          expected_status = :unavailable
          case scenario
          when :success
            expected_status = :verified
          when :wrong_code
            arguments[:code] = (code == "000000") ? "000001" : "000000"
            expected_status = :invalid_code
          when :foreign_browser
            arguments[:browser_nonce] = SecureRandom.urlsafe_base64(32)
          when :foreign_owner
            arguments[:actor] = (surface == "app") ? Client.create!(status_id: ClientStatus::ACTIVE) : Visitor.create!
          when :foreign_root
            replacement =
              (surface == "app") ? ClientToken.create!(user: actor, discard_at: 1.day.from_now) :
                           VisitorToken.create!(visitor: actor, discard_at: 1.day.from_now)
            replacement.rotate_refresh_token!
            arguments[:token] = replacement
            root_count = token_model.count
          when :foreign_candidate
            other =
              case [surface, channel]
              when ["app", :email]
                actor.client_emails.create!(
                  raw_address: "other-#{SecureRandom.hex(8)}@example.test",
                  confirm_policy: "1",
                )
              when ["com", :email]
                actor.visitor_emails.create!(
                  raw_address: "other-#{SecureRandom.hex(8)}@example.test",
                  confirm_policy: "1",
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
            arguments[:contact] = other
            other_facts = other.reload.attributes
          when :foreign_ticket
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
            other_ticket_facts = arguments.fetch(:transaction).reload.attributes
          when :released
            contact.finalize_binding!
            contact.release_binding!
          when :revoked
            token.revoke!
          when :destination_locked
            destination_digest = (channel == :email) ? contact.address_digest : contact.number_digest
            5.times do
              OtpVerificationFailureBudget.new.verify!(
                surface: surface.to_sym, purpose: :credential_registration, channel:, destination_digest:, valid: false,
              )
            end
            expected_status = :locked
          when :candidate_locked
            wrong_code = (code == "000000") ? "000001" : "000000"
            5.times do |attempt|
              status = ContactRegistrationOtpVerificationCommitter.call!(**arguments.merge(code: wrong_code))

              assert_equal((attempt < 4) ? :invalid_code : :locked, status)
            end
            expected_status = :locked
          end
          if %i(proof_before proof_at proof_after).include?(scenario)
            assert_equal :verified, ContactRegistrationOtpVerificationCommitter.call!(**arguments)
            proof = contact.reload.credential_registration_otp_context.deep_dup

            assert_nil contact.get_otp
            # Both persisted deadlines use PostgreSQL timestamptz(6): one microsecond is the nearest neighbor.
            boundary = Time.iso8601(proof.fetch("result_expires_at"))

            assert_equal [Time.iso8601(proof.fetch("verified_at")) + 60.seconds, transaction.expires_at].min, boundary
            offset = { proof_before: -Rational(1, 1_000_000),
                       proof_at: 0,
                       proof_after: Rational(1, 1_000_000), }.fetch(scenario)
            decision_time = boundary + offset
            expected_status = (scenario == :proof_before) ? :verified : :unavailable
          elsif %i(challenge_before challenge_at challenge_after).include?(scenario)
            # Explicit DB clocks avoid Ruby travel pretending to advance a PostgreSQL clock.
            # timestamptz(6) represents both neighbors of the strict expiry boundary.
            boundary = Time.iso8601(issued_context.fetch("expires_at"))
            offset = { challenge_before: -Rational(1, 1_000_000),
                       challenge_at: 0,
                       challenge_after: Rational(1, 1_000_000), }.fetch(scenario)
            decision_time = boundary + offset
            expected_status = (scenario == :challenge_before) ? :verified : :unavailable
          end
          if decision_time
            contact.class.stub(:database_now, decision_time) do
              flow_model.stub(:database_now, decision_time) do
                status = ContactRegistrationOtpVerificationCommitter.call!(**arguments)

                assert_equal expected_status, status
              end
            end
          else
            status = ContactRegistrationOtpVerificationCommitter.call!(**arguments)

            assert_equal expected_status, status
          end

          assert ticket_facts == transaction.reload.attributes, "Verification must leave the original Ticket pending"
          assert_equal root_count, token_model.count
          assert other_facts == other.reload.attributes, "Foreign candidate must remain unchanged" if other_facts
          if other_ticket_facts
            assert other_ticket_facts == arguments.fetch(:transaction).reload.attributes,
                   "Foreign Ticket must remain unchanged"
          end
          context = contact.reload.credential_registration_otp_context
          if proof
            assert proof == context, "Exact proof retries and expiry refusals must not extend or replace evidence"
          elsif expected_status == :verified
            assert_nil contact.get_otp
            assert_not_nil context.fetch("verified_at")
            assert issued_context.except("verified_at", "result_expires_at") ==
              context.except("verified_at", "result_expires_at"),
                   "Verification must preserve every original issuance binding fact"
            assert_equal [Time.iso8601(context.fetch("verified_at")) + 60.seconds, transaction.expires_at].min,
                         Time.iso8601(context.fetch("result_expires_at"))
            assert_nil contact.binding_finalized_at
            assert_not contact.binding_effective?
            if scenario == :success
              committed = context.deep_dup

              assert_equal :verified, ContactRegistrationOtpVerificationCommitter.call!(**arguments)
              assert committed == contact.reload.credential_registration_otp_context,
                     "Immediate exact retry must retain the committed proof"
            end
          else
            assert issued_context == context, "Refusal must not manufacture verification evidence"
            unless scenario == :candidate_locked
              assert original_otp == contact.get_otp, "Refusal must not consume the candidate OTP"
            end
          end
        end
      end
    end
  end
end
# rubocop:enable Minitest/AssertEqual, Minitest/AssertOperator, Minitest/MultipleAssertions
