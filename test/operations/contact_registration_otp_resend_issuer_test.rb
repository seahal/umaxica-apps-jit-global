# frozen_string_literal: true

require "test_helper"
require "minitest/mock"

# Boolean snapshots keep credentials, destinations and binding references out of failure output.
class ContactRegistrationOtpResendIssuerTest < ActiveSupport::TestCase
  %i(app com).each do |surface|
    %i(email telephone).each do |channel|
      scenarios = %i(success candidate_attempts candidate_locked shared_budget foreign_browser foreign_root
                     foreign_owner foreign_candidate foreign_flow verified revoked device_revoked expires_before
                     expires_at expires_after maximum_uuid_generation source_fault)
      scenarios += %i(cooldown_before cooldown_at cooldown_after) if channel == :email
      scenarios.each do |scenario|
        test "#{surface} #{channel} resend #{scenario} retains the original challenge authority and budgets" do
          budget_model = (channel == :email) ? EmailOtpVerificationFailureBudget : TelephoneOtpVerificationFailureBudget
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
          actor = owner_model.create!(
            security_mode_id: SecurityModeConfigurable::NORMAL,
            status_id: (surface == :app) ? ClientStatus::ACTIVE : VisitorStatus::ACTIVE,
          )
          token = root_model.create!(:authentication_epoch => 0, owner_key => actor.id, :discard_at => 1.day.from_now)
          token.rotate_refresh_token!
          destination =
            (channel == :email) ? "resend-#{SecureRandom.hex(8)}@example.test" :
                         "+8190#{SecureRandom.random_number(10**8).to_s.rjust(8, "0")}"
          contact = contact_model.create!(
            owner_key => actor.id, :confirm_policy => "1",
            ((channel == :email) ? :raw_address : :raw_number) => destination,
            **((channel == :telephone) ? { confirm_using_mfa: "1" } : {}),
          )
          issuer, resend_issuer, verifier, guard, source, issue_result =
            case channel
            when :email
              [EmailCredentialRegistrationOtpIssuer, EmailCredentialRegistrationOtpResendIssuer,
               EmailCredentialRegistrationOtpVerificationCommitter, EmailCredentialRegistrationOtpDeliveryGuard,
               { email: contact }, EmailCredentialRegistrationOtpIssueResult,]
            when :telephone
              [TelephoneCredentialRegistrationOtpIssuer, TelephoneCredentialRegistrationOtpResendIssuer,
               TelephoneCredentialRegistrationOtpVerificationCommitter, TelephoneCredentialRegistrationOtpDeliveryGuard,
               { telephone: contact }, TelephoneCredentialRegistrationOtpIssueResult,]
            end
          source_before_issuance = contact.reload.attributes
          nonce = SecureRandom.urlsafe_base64(32)
          issued =
            if scenario == :maximum_uuid_generation
              # The maximum v4 fixture is opaque generation data, not a successor-arithmetic boundary.
              SecureRandom.stub(:uuid, "ffffffff-ffff-4fff-bfff-ffffffffffff") do
                issuer.call(actor:, token:, browser_nonce: nonce, **source)
              end
            else
              issuer.call(actor:, token:, browser_nonce: nonce, **source)
            end

          assert_predicate issued, :success?
          assert_withheld("Issuance must not write Source counters, proof or destination lookup facts") {
            source_before_issuance.except(
              "otp_last_sent_at", "updated_at",
            ) ==
              contact.reload.attributes.except("otp_last_sent_at", "updated_at")
          }
          transaction = issued.transaction
          code = issued.code
          generation = transaction.otp_generation
          verification = { actor:, token:, transaction:, browser_nonce: nonce, code:, **source }
          arguments = verification.except(:code)
          digest = (channel == :email) ? contact.address_digest : contact.number_digest
          wrong_code = (code == "000000") ? "000001" : "000000"
          case scenario
          when :candidate_attempts, :candidate_locked

            ((scenario == :candidate_locked) ? 5 : 3).times do |attempt|
              assert_equal(
                (attempt < 4) ? :invalid_code : :locked, verifier.call(
                  **verification.merge(code: wrong_code),
                ).status,
              )
            end
          when :shared_budget

            3.times do
              assert_equal :invalid_code, budget_model.new.verify!(
                surface:, purpose: :credential_registration, channel:, destination_digest: digest, valid: false,
              )
            end
          when :foreign_browser
            arguments[:browser_nonce] = SecureRandom.urlsafe_base64(32)
          when :foreign_root
            replacement = root_model.create!(
              :authentication_epoch => 0, owner_key => actor.id,
              :discard_at => 1.day.from_now,
            )
            replacement.rotate_refresh_token!
            arguments[:token] = replacement
          when :foreign_owner
            arguments[:actor] =
              owner_model.create!(
                security_mode_id: SecurityModeConfigurable::NORMAL,
                status_id: (surface == :app) ? ClientStatus::ACTIVE : VisitorStatus::ACTIVE,
              )
          when :foreign_candidate
            other_destination =
              (channel == :email) ? "foreign-resend-#{SecureRandom.hex(8)}@example.test" :
                           "+8190#{SecureRandom.random_number(10**8).to_s.rjust(8, "0")}"
            arguments[(channel == :email) ? :email : :telephone] = contact_model.create!(
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
              surface:, actor_ref: actor.public_id, session_ref: transaction.session_ref, operation: "registration",
              **candidate_fields,
            )
          when :verified
            verified = verifier.call(**verification)

            assert_predicate verified, :success?
            assert_nil transaction.reload.otp_verifier
            assert_not_nil transaction.otp_consumed_at
          when :revoked
            token.revoke!
          when :device_revoked
            token.device_session.revoke!
          end
          original = contact.reload.attributes
          context = transaction.reload.attributes
          ticket_facts = transaction.reload.attributes
          supplied_contact_facts = arguments.fetch((channel == :email) ? :email : :telephone).reload.attributes
          supplied_ticket_facts = arguments.fetch(:transaction).reload.attributes
          root_facts = token.reload.attributes
          owner_facts = actor.reload.attributes
          issued_at = contact.otp_last_sent_at
          decision_time = issued_at + 61.seconds
          if %i(expires_before expires_at expires_after).include?(scenario)
            # PostgreSQL timestamptz(6) supplies both nearest representable neighbors of the strict deadline.
            boundary = transaction.otp_expires_at
            offset = { expires_before: -1, expires_at: 0, expires_after: 1 }.fetch(scenario)
            decision_time = boundary + Rational(offset, 1_000_000)
          elsif %i(cooldown_before cooldown_at cooldown_after).include?(scenario)
            # The Email send policy is thirty seconds; PostgreSQL represents both microsecond neighbors.
            boundary = contact.otp_last_sent_at + 30.seconds
            offset = { cooldown_before: -1, cooldown_at: 0, cooldown_after: 1 }.fetch(scenario)
            decision_time = boundary + Rational(offset, 1_000_000)
          end
          issuance = nil
          contact_model.stub(:database_now, decision_time) do
            flow_model.stub(:database_now, decision_time) do
              if scenario == :source_fault
                fired = false
                fault =
                  lambda do |event|
                    sql = event.payload.fetch(:sql)
                    next if fired || !sql.start_with?("UPDATE") || sql.exclude?(contact_model.table_name) ||
                      sql.exclude?("otp_last_sent_at")

                    fired = true
                    raise ActiveRecord::StatementInvalid, "injected resend Source persistence failure"
                  end

                ActiveSupport::Notifications.subscribed(fault, "sql.active_record") do
                  assert_raises(ActiveRecord::StatementInvalid) { resend_issuer.call(**arguments) }
                end

                assert fired, "The actual resend Source persistence boundary must be reached"
              else
                issuance = resend_issuer.call(**arguments)
              end
              if %i(success candidate_attempts shared_budget expires_before cooldown_at
                    cooldown_after maximum_uuid_generation).include?(scenario)
                assert_kind_of issue_result, issuance
                assert_predicate issuance, :success?
                assert_withheld("Resend must retain the original transaction") { issuance.transaction == transaction }
                updated = transaction.reload.attributes
                contact.reload

                assert_match(/\A[0-9]{6}\z/, issuance.code)
                assert_not_equal generation, transaction.otp_generation
                assert_not_equal context.fetch("otp_verifier"), transaction.otp_verifier
                assert_equal original.fetch("otp_attempts_count"), contact.otp_attempts_count
                assert_equal context.fetch("otp_expires_at"), transaction.otp_expires_at
                assert_withheld("Resend must preserve all original bindings and both original deadlines") {
                  context.except(
                    "otp_generation", "otp_verifier", "updated_at", "lock_version",
                  ) ==
                    updated.except("otp_generation", "otp_verifier", "updated_at", "lock_version")
                }
                assert_equal context.fetch("lock_version") + 1, transaction.lock_version
                assert_equal decision_time, contact.otp_last_sent_at
                assert_withheld("Resend must preserve every other Source fact") {
                  original.except(
                    "otp_last_sent_at",
                    "updated_at",
                  ) ==
                    contact.attributes.except("otp_last_sent_at", "updated_at")
                }
                old_delivered = false
                new_delivered = false

                assert_not guard.call(
                  transaction:, generation:, destination:, code:, **source,
                ) { old_delivered = true }
                assert guard.call(
                  transaction:, generation: transaction.otp_generation, destination:,
                  code: issuance.code, **source,
                ) { new_delivered = true }
                assert_not old_delivered
                assert new_delivered
                if %i(candidate_attempts shared_budget).include?(scenario)
                  assert_equal :invalid_code, budget_model.new.verify!(
                    surface:, purpose: :credential_registration, channel:, destination_digest: digest, valid: false,
                  )
                  assert_equal :locked, budget_model.new.verify!(
                    surface:, purpose: :credential_registration, channel:, destination_digest: digest, valid: false,
                  )
                end
              else
                expected =
                  case scenario
                  when :cooldown_before then :rate_limited
                  when :candidate_locked then :locked
                  else :unavailable
                  end
                unless scenario == :source_fault
                  assert_equal expected, issuance.status, "Resend refusal must return its exact classified status"
                end

                assert_withheld("Refusal or fault must preserve the original Source issuance") {
                  original == contact.reload.attributes
                }
                assert_withheld("A substituted Contact must remain unchanged") {
                  supplied_contact_facts ==
                    arguments.fetch((channel == :email) ? :email : :telephone).reload.attributes
                }
              end
            end
          end

          if issuance&.success?
            allowed = %w(otp_generation otp_verifier updated_at lock_version)

            assert_withheld("Resend must not renew or replace the original Ticket") {
              ticket_facts.except(*allowed) == transaction.reload.attributes.except(*allowed)
            }
            assert_equal ticket_facts.fetch("lock_version") + 1, transaction.lock_version
          else
            assert_withheld("Refusal or Source fault must retain original proof") {
              ticket_facts == transaction.reload.attributes
            }
            assert_withheld("A substituted Ticket must remain unchanged") {
              supplied_ticket_facts == arguments.fetch(:transaction).reload.attributes
            }
          end

          assert_withheld("Resend must retain root facts") { root_facts == token.reload.attributes }
          assert_withheld("Resend must retain owner facts") { owner_facts == actor.reload.attributes }
        end
      end
    end
  end
end
