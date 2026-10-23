# frozen_string_literal: true

require "test_helper"
require "minitest/mock"

# Boolean snapshots avoid disclosing OTP, proof and root material when an assertion fails.
class ContactRegistrationOtpVerificationCommitterTest < ActiveSupport::TestCase
  %w(app com).each do |surface|
    %i(email telephone).each do |channel|
      %i(success wrong_code foreign_browser foreign_owner foreign_root foreign_candidate foreign_ticket
         released revoked destination_locked candidate_locked
         challenge_before challenge_at challenge_after proof_before proof_at proof_after).each do |scenario|
        test "#{surface} #{channel} registration verification #{scenario} preserves its original authority" do
          budget_model = (channel == :email) ? EmailOtpVerificationFailureBudget : TelephoneOtpVerificationFailureBudget
          actor, token, contact, flow_model, token_model =
            case [surface, channel]
            when ["app", :email], ["app", :telephone]
              owner = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
              root = ClientToken.create!(authentication_epoch: 0, user: owner, discard_at: 1.day.from_now)
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
              owner = Visitor.create!(security_mode_id: SecurityModeConfigurable::NORMAL)
              root = VisitorToken.create!(authentication_epoch: 0, visitor: owner, discard_at: 1.day.from_now)
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
          nonce = SecureRandom.urlsafe_base64(32)
          issuer, verifier, source =
            case channel
            when :email
              [EmailCredentialRegistrationOtpIssuer, EmailCredentialRegistrationOtpVerificationCommitter,
               { email: contact },]
            when :telephone
              [TelephoneCredentialRegistrationOtpIssuer, TelephoneCredentialRegistrationOtpVerificationCommitter,
               { telephone: contact },]
            end
          issued = issuer.call(actor:, token:, browser_nonce: nonce, **source)

          assert_predicate issued, :success?
          transaction = issued.transaction
          code = issued.code
          arguments = { actor:, token:, transaction:, browser_nonce: nonce, code:, **source }
          issued_ticket = transaction.reload.attributes
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
            expected_status = :session_mismatch
          when :foreign_owner
            arguments[:actor] =
              (surface == "app") ? Client.create!(
                security_mode_id: SecurityModeConfigurable::NORMAL,
                status_id: ClientStatus::ACTIVE,
              ) : Visitor.create!(security_mode_id: SecurityModeConfigurable::NORMAL)
          when :foreign_root
            replacement =
              (surface == "app") ? ClientToken.create!(
                authentication_epoch: 0, user: actor,
                discard_at: 1.day.from_now,
              ) :
                           VisitorToken.create!(authentication_epoch: 0, visitor: actor, discard_at: 1.day.from_now)
            replacement.rotate_refresh_token!
            arguments[:token] = replacement
            expected_status = :session_mismatch
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
            arguments[(channel == :email) ? :email : :telephone] = other
            other_facts = other.reload.attributes
          when :foreign_ticket
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
            other_ticket_facts = arguments.fetch(:transaction).reload.attributes
            expected_status = :session_mismatch
          when :released
            contact.finalize_binding!
            contact.release_binding!
          when :revoked
            token.revoke!
          when :destination_locked
            destination_digest = (channel == :email) ? contact.address_digest : contact.number_digest
            5.times do
              budget_model.new.verify!(
                surface: surface.to_sym, purpose: :credential_registration, channel:, destination_digest:, valid: false,
              )
            end
            expected_status = :locked
          when :candidate_locked
            wrong_code = (code == "000000") ? "000001" : "000000"
            5.times do |attempt|
              result = verifier.call(**arguments.merge(code: wrong_code))

              assert_equal((attempt < 4) ? :invalid_code : :locked, result.status)
            end
            expected_status = :locked
          end
          source_facts = contact.reload.attributes
          root_facts = token.reload.attributes
          device_facts = token.device_session.reload.attributes
          owner_facts = actor.reload.attributes
          proof = nil
          if %i(proof_before proof_at proof_after).include?(scenario)
            verified = verifier.call(**arguments)

            assert_predicate verified, :success?
            proof = transaction.reload.attributes

            assert_nil transaction.otp_verifier
            assert_not_nil transaction.otp_receipt_verifier
            boundary = transaction.otp_result_expires_at

            assert_equal [transaction.otp_consumed_at + 60.seconds, transaction.expires_at].min, boundary
            offset = { proof_before: -Rational(1, 1_000_000),
                       proof_at: 0,
                       proof_after: Rational(1, 1_000_000), }.fetch(scenario)
            decision_time = boundary + offset
            expected_status = (scenario == :proof_before) ? :already_verified : :result_expired
            source_facts = contact.reload.attributes
          elsif %i(challenge_before challenge_at challenge_after).include?(scenario)
            boundary = transaction.otp_expires_at
            offset = { challenge_before: -Rational(1, 1_000_000),
                       challenge_at: 0,
                       challenge_after: Rational(1, 1_000_000), }.fetch(scenario)
            decision_time = boundary + offset
            expected_status = (scenario == :challenge_before) ? :verified : :invalid_code
          end
          result = nil
          if decision_time
            contact.class.stub(:database_now, decision_time) do
              flow_model.stub(:database_now, decision_time) do
                result = verifier.call(**arguments)

                assert_equal expected_status, result.status
              end
            end
          else
            result = verifier.call(**arguments)

            assert_equal expected_status, result.status
          end

          assert_equal root_count, token_model.count
          assert_withheld("Verification must preserve Root authority") { root_facts == token.reload.attributes }
          assert_withheld { device_facts == token.device_session.reload.attributes }
          assert_withheld { owner_facts == actor.reload.attributes }
          assert_withheld("Foreign candidate must remain unchanged") {
            other_facts == other.reload.attributes
          } if other_facts
          if other_ticket_facts
            assert_withheld("Foreign Ticket must remain unchanged") {
              other_ticket_facts == arguments.fetch(:transaction).reload.attributes
            }
          end
          if proof
            assert_not_predicate result, :success?
            assert_equal(scenario == :proof_before, result.verified_evidence?)
            assert_withheld("Receipt retries and expiry must not replace bounded evidence") {
              proof == transaction.reload.attributes
            }
            assert_withheld("Retained receipt must not reset Source failures") {
              source_facts == contact.reload.attributes
            }
          elsif expected_status == :verified
            assert_predicate result, :success?
            assert_predicate result, :verified_evidence?
            transaction.reload

            assert_nil transaction.otp_verifier
            assert_not_nil transaction.otp_consumed_at
            assert_not_nil transaction.otp_receipt_verifier
            allowed = %w(otp_consumed_at otp_receipt_verifier otp_verifier otp_result_expires_at updated_at
                         lock_version)

            assert_withheld("Fresh verification may change only committed OTP consumption and bounded receipt facts") {
              issued_ticket.except(*allowed) == transaction.attributes.except(*allowed)
            }
            assert_equal issued_ticket.fetch("lock_version") + 1, transaction.lock_version
            assert_equal [transaction.otp_consumed_at + 60.seconds, transaction.expires_at].min,
                         transaction.otp_result_expires_at
            assert_equal "pending", transaction.status
            assert_nil transaction.consumed_at
            assert_nil contact.reload.binding_finalized_at
            assert_not_predicate contact, :binding_effective?
            if scenario == :success
              committed = transaction.attributes
              committed_source = contact.attributes
              retried = verifier.call(**arguments)

              assert_equal :already_verified, retried.status
              assert_not_predicate retried, :success?
              assert_predicate retried, :verified_evidence?
              assert_withheld("Exact retry must retain the committed proof") {
                committed == transaction.reload.attributes
              }
              assert_withheld { committed_source == contact.reload.attributes }
            end
          else
            assert_not_predicate result, :success?
            assert_not_predicate result, :verified_evidence?
            assert_withheld("Refusal must not consume or manufacture proof") {
              issued_ticket == transaction.reload.attributes
            }
            if scenario == :wrong_code
              assert_equal source_facts.fetch("otp_attempts_count") + 1, contact.reload.otp_attempts_count
              assert_withheld {
                source_facts.except("otp_attempts_count", "updated_at") ==
                  contact.attributes.except("otp_attempts_count", "updated_at")
              }
            else
              assert_withheld("Refusal must retain Source facts") { source_facts == contact.reload.attributes }
            end
          end
        end
      end
    end
  end
end
