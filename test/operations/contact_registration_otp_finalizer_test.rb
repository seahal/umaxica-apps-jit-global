# frozen_string_literal: true

require "test_helper"
require "minitest/mock"
require "webauthn/fake_client"

# Boolean comparisons prevent disclosure of proof, OTP and root facts on assertion failures.
# rubocop:disable Minitest/AssertEqual, Minitest/AssertOperator, Minitest/MultipleAssertions
class ContactRegistrationOtpFinalizerTest < ActiveSupport::TestCase
  %i(app com).each do |surface|
    %i(email telephone).each do |channel|
      %i(success foreign_browser foreign_root foreign_owner foreign_flow proof_before proof_at proof_after revoked
         lost_freshness credential_lost current_policy source_fault receipt_fault
         root_before root_at root_after).each do |scenario|
        test "#{surface} #{channel} finalization #{scenario} preserves original proof and commit authority" do
          owner_model, contact_model, owner_key, flow_model, _, session_model, auth_model, audit_model,
            status_key, verified_status, auth_host =
            case [surface, channel]
            when [:app, :email], [:app, :telephone]
              [Client, (channel == :email) ? ClientEmail : ClientTelephone, :user_id,
               (channel == :email) ? ClientEmailCeremonyTransaction : ClientTelephoneCeremonyTransaction,
               ClientStepUpCeremonyTransaction, ClientStepUpSession, ClientAuthCeremonySession,
               ClientContactAuditOutbox, (channel == :email) ? :user_email_status_id : :user_telephone_status_id,
               (channel == :email) ? ClientEmailStatus::VERIFIED : ClientTelephoneStatus::VERIFIED,
               ENV.fetch("PUBLIC_AUTH_SERVICE_URL"),]
            when [:com, :email], [:com, :telephone]
              [Visitor, (channel == :email) ? VisitorEmail : VisitorTelephone, :visitor_id,
               (channel == :email) ? VisitorEmailCeremonyTransaction : VisitorTelephoneCeremonyTransaction,
               VisitorStepUpCeremonyTransaction, VisitorStepUpSession, VisitorAuthCeremonySession,
               VisitorContactAuditOutbox, (channel == :email) ? :visitor_email_status_id : :visitor_telephone_status_id,
               (channel == :email) ? VisitorEmailStatus::VERIFIED : VisitorTelephoneStatus::VERIFIED,
               ENV.fetch("PUBLIC_AUTH_CORPORATE_URL"),]
            end
          actor = owner_model.create!(
            id: SecureRandom.random_number(1 << 60) + 1_000_000_000,
            status_id: (surface == :app) ? ClientStatus::ACTIVE : VisitorStatus::ACTIVE,
          )
          token =
            (surface == :app) ? ClientToken.create!(user: actor, discard_at: 1.day.from_now) :
                        VisitorToken.create!(visitor: actor, discard_at: 1.day.from_now)
          token.rotate_refresh_token!
          origin = "https://#{auth_host}"
          fake = WebAuthn::FakeClient.new(origin, encoding: :base64url)
          registration = fake.create(challenge: SecureRandom.urlsafe_base64(32), user_verified: true)
          rp = WebAuthn::RelyingParty.new(id: auth_host, allowed_origins: [origin], encoding: :base64url)
          registered = WebAuthn::Credential.from_create(registration, relying_party: rp)
          passkey =
            if surface == :app
              actor.client_passkeys.create!(
                webauthn_id: registered.id, public_key: registered.public_key,
                sign_count: 0,
              )
            else
              actor.visitor_passkeys.create!(
                webauthn_id: registered.id, public_key: registered.public_key,
                sign_count: 0,
              )
            end
          return_to = (channel == :email) ? "/identity/emails" : "/identity/telephones"
          destination =
            (channel == :email) ? "finalizer-#{SecureRandom.hex(8)}@example.test" :
                         "+8190#{SecureRandom.random_number(10**8).to_s.rjust(8, "0")}"
          contact_attributes = {
            owner_key => actor.id,
            :confirm_policy => "1",
            ((channel == :email) ? :raw_address : :raw_number) => destination,
            **((channel == :telephone) ? { confirm_using_mfa: "1" } : {}),
          }
          previous = contact_model.create!(**contact_attributes, status_key => verified_status)
          previous.finalize_binding!
          contact = contact_model.create!(**contact_attributes)
          policy_model =
            case [surface, channel]
            when [:app, :email] then ClientEmailPolicy
            when [:app, :telephone] then ClientTelephonePolicy
            when [:com, :email] then VisitorEmailPolicy
            when [:com, :telephone] then VisitorTelephonePolicy
            end
          requirement = policy_model.new(contact, user: actor).credential_registration_requirement(token:)
          admission = BaseStepUpAdmissionIssuer.call!(
            actor:, token:, requirement:, return_to:, base_browser_nonce: SecureRandom.urlsafe_base64(32),
            base_token: token,
          )
          step = admission.transaction
          binding = BaseAuthAdmissionCoordinator.find_admission_binding!(surface:, reference: admission.reference)
          attached, sid = auth_model.issue!
          binding.attach_auth_session!(auth_session: attached, confirmation_ref: SecureRandom.uuid)
          binding.confirm_base!(base_token: token, browser_digest: binding.base_browser_digest)
          BaseAuthAdmissionCoordinator.consume_entry_reference!(
            reference: admission.reference, surface:, expected_intent: "step_up", binding:, raw_auth_sid: sid,
          )
          ceremony, = auth_model.rotate_and_admit!(
            admission_purpose: "step_up_handoff", previous_raw_sid: sid,
            step_up_ceremony_transaction_ref: step.transaction_id,
          )
          binding.redeem!(auth_session: attached, admitted_auth_session: ceremony)
          session_record = session_model.find_by!(step_up_ceremony_transaction_ref: step.transaction_id)
          config = Webauthn::RelyingPartyConfig.new(rp_id: auth_host, origin:)
          options = Webauthn::AssertionVerifier.options_for(
            config:, allow_ids: [passkey.webauthn_id], purpose: :ordinary_step_up,
          )
          reference = session_record.issue_bound_passkey_challenge!(
            transaction: step, challenge: options.challenge, rp_id: auth_host, origin:,
          )
          assertion = fake.get(challenge: options.challenge, user_verified: true, sign_count: 1)
          IdentityStepUpPasskeyVerificationCommitter.call!(
            actor:, transaction: step, session_record:, config:, reference:, credential_params: assertion,
          )
          result = BaseAuthAdmissionCoordinator.issue_result!(transaction: step, ceremony_session_ref: ceremony.id.to_s)
          IdentityStepUpCeremonyFreshnessCommitter.call!(
            actor:, token:, transaction: step, requirement:, result_reference: result.reference,
          )

          assert_predicate StepUpResolver.call(token: token.reload, requirement:, now: token.class.database_now),
                           :satisfied?

          nonce = SecureRandom.urlsafe_base64(32)
          if channel == :email
            issued = EmailCredentialRegistrationOtpIssuer.call(
              actor:, token:, email: contact, browser_nonce: nonce,
            )
            transaction = issued.transaction
            code = issued.code

            assert_predicate EmailCredentialRegistrationOtpVerificationCommitter.call(
              actor:, token:, email: contact, transaction:, browser_nonce: nonce, code:,
            ), :success?
            proof = transaction.reload.attributes.slice(
              "otp_consumed_at", "otp_receipt_verifier", "otp_result_expires_at",
            )
            finalizer = EmailCredentialRegistrationOtpFinalizer
          else
            issued = TelephoneCredentialRegistrationOtpIssuer.call(
              actor:, token:, telephone: contact, browser_nonce: nonce,
            )
            transaction = issued.transaction
            code = issued.code

            assert_predicate TelephoneCredentialRegistrationOtpVerificationCommitter.call(
              actor:, token:, telephone: contact, transaction:, browser_nonce: nonce, code:,
            ), :success?
            proof = transaction.reload.attributes.slice(
              "otp_consumed_at", "otp_receipt_verifier", "otp_result_expires_at",
            )
            finalizer = TelephoneCredentialRegistrationOtpFinalizer
          end
          actor_context = ActorValuesContext.empty.with(
            subject: actor, actor_type: (surface == :app) ? :client : :visitor, tld: surface, surface: :base,
          )
          arguments = { actor:,
                        actor_context:,
                        token:,
                        contact:,
                        transaction:,
                        channel:,
                        browser_nonce: nonce,
                        requirement:, }
          arguments = arguments.except(:contact, :channel).merge(email: contact, code:) if channel == :email
          arguments = arguments.except(:contact, :channel).merge(telephone: contact, code:) if channel == :telephone
          case scenario
          when :foreign_browser
            arguments[:browser_nonce] = SecureRandom.urlsafe_base64(32)
          when :foreign_root
            replacement =
              (surface == :app) ? ClientToken.create!(user: actor, discard_at: 1.day.from_now) :
                          VisitorToken.create!(visitor: actor, discard_at: 1.day.from_now)
            replacement.rotate_refresh_token!
            arguments[:token] = replacement
          when :foreign_owner
            arguments[:actor] = owner_model.create!(
              status_id: (surface == :app) ? ClientStatus::ACTIVE : VisitorStatus::ACTIVE,
            )
          when :foreign_flow
            candidate_fields =
              (channel == :email) ?
                { email_candidate_ref: contact.public_id, normalized_email_digest: contact.address_digest } :
                { telephone_candidate_ref: contact.public_id, normalized_number_digest: contact.number_digest }
            arguments[:transaction] = flow_model.create_transaction!(
              surface:, actor_ref: actor.public_id, session_ref: token.public_id, operation: "registration",
              **candidate_fields,
            )
          when :revoked
            token.revoke!
          when :lost_freshness
            token.revoke_step_up_authority!
          when :credential_lost
            passkey.update!(discard_at: passkey.class.database_now)
          when :current_policy
            arguments[:requirement] = StepUpRequirement.new(
              **requirement.to_h.merge(
                allowed_methods: [:totp], phishing_resistant_required: false,
                user_verification_required: false,
              ),
            )
          end
          if %i(root_before root_at root_after).include?(scenario)
            root_deadline = flow_model.database_now + 10.seconds
            token.update_columns(discard_at: root_deadline)
          end
          original_contact = contact.reload.attributes
          original_previous = previous.reload.attributes
          ticket_facts = transaction.reload.attributes
          root_facts = token.reload.attributes
          supplied_ticket_facts = arguments.fetch(:transaction).reload.attributes
          audits = audit_model.where(operation_ref: transaction.transaction_id)
          original_audits = audits.count
          if %i(source_fault receipt_fault).include?(scenario)
            fired = false
            fault =
              lambda do |event|
                sql = event.payload.fetch(:sql)
                source_write = sql.start_with?("UPDATE") && sql.include?(contact_model.table_name) &&
                  sql.include?("binding_finalized_at")
                receipt_write = sql.start_with?("UPDATE") && sql.include?(flow_model.table_name)
                next if fired || !((scenario == :source_fault) ? source_write : receipt_write)

                fired = true
                raise ActiveRecord::StatementInvalid, "injected persistence boundary failure"
              end

            ActiveSupport::Notifications.subscribed(fault, "sql.active_record") do
              assert_raises(ActiveRecord::StatementInvalid) { finalizer.call!(**arguments) }
            end

            assert fired, "The actual persistence boundary must be reached"
            assert ticket_facts == transaction.reload.attributes,
                   "A failed receipt must leave the original Ticket pending"
            retained_proof = transaction.reload.attributes.slice(*proof.keys)

            assert proof == retained_proof, "Fault must retain the original verified proof"
            assert_nil transaction.otp_verifier
            if scenario == :source_fault
              assert original_contact == contact.reload.attributes, "Source failure must roll back candidate binding"
              assert original_previous == previous.reload.attributes, "Source failure must preserve the old binding"
              assert_equal original_audits, audits.count
            else
              assert_predicate contact, :binding_effective?, "Source must commit before the Ticket receipt write"
              assert_predicate previous.reload, :binding_released?, "Source replacement must retain its release fact"
              assert_equal 1, audits.where(event_name: "finalized", contact_ref: contact.public_id).count
              assert_equal 1, audits.where(event_name: "released", contact_ref: previous.public_id).count
            end
          end
          status =
            if %i(root_before root_at root_after).include?(scenario)
              offset = { root_before: -Rational(1, 1_000_000),
                         root_at: 0,
                         root_after: Rational(1, 1_000_000), }.fetch(scenario)
              reads = 0
              clock = -> { reads += 1; (reads == 1) ? root_deadline - 1.second : root_deadline + offset }
              flow_model.stub(:database_now, clock) { finalizer.call!(**arguments) }
            elsif %i(proof_before proof_at proof_after).include?(scenario)
              # PostgreSQL timestamptz(6) represents both nearest neighbors of the strict proof deadline.
              boundary = proof.fetch("otp_result_expires_at")
              offset = { proof_before: -Rational(1, 1_000_000),
                         proof_at: 0,
                         proof_after: Rational(1, 1_000_000), }.fetch(scenario)
              flow_model.stub(:database_now, boundary + offset) do
                finalizer.call!(**arguments)
              end
            else
              finalizer.call!(**arguments)
            end
          if %i(success proof_before source_fault receipt_fault root_before).include?(scenario)
            assert_equal :finalized, status
            assert_equal verified_status, contact.reload[status_key]
            assert_predicate contact, :binding_effective?
            assert_predicate previous.reload, :binding_released?
            assert_equal 1, audits.where(event_name: "finalized", contact_ref: contact.public_id).count
            assert_equal 1, audits.where(event_name: "released", contact_ref: previous.public_id).count
            assert_equal 2, audits.where(
              owner_ref: actor.public_id, actor_ref: actor.public_id, contact_kind: channel.to_s,
            ).count
            assert_predicate transaction.reload, :consumed?
            final_proof = transaction.attributes.slice(*proof.keys)

            assert proof == final_proof, "Finalization must not replace OTP proof"
            completed_contact = contact.attributes
            completed_previous = previous.attributes
            completed_ticket = transaction.attributes
            audit_facts = audits.order(:id).map(&:attributes)

            retried =
              if %i(proof_before root_before).include?(scenario)
                # Returning to the real clock would move before the receipt created by the boundary clock.
                flow_model.stub(:database_now, transaction.consumed_at) { finalizer.call!(**arguments) }
              else
                finalizer.call!(**arguments)
              end

            assert_equal :finalized, retried
            assert completed_contact == contact.reload.attributes, "Exact retry must not mutate finalized Source"
            assert completed_previous == previous.reload.attributes, "Exact retry must not re-release previous binding"
            assert completed_ticket == transaction.reload.attributes, "Exact retry must retain the original receipt"
            assert audit_facts == audits.order(:id).map(&:attributes), "Exact retry must not duplicate audits"
          else
            assert_equal :unavailable, status
            assert original_contact == contact.reload.attributes, "Refusal must preserve verified candidate evidence"
            assert original_previous == previous.reload.attributes,
                   "Refusal must preserve the previous effective binding"
            assert ticket_facts == transaction.reload.attributes, "Refusal must preserve the original pending Ticket"
            assert supplied_ticket_facts == arguments.fetch(:transaction).reload.attributes,
                   "Refusal must preserve any substituted Ticket"
            assert_equal original_audits, audits.count
          end

          assert root_facts == token.reload.attributes, "Contact finalization must not replace root authority"
        end
      end
    end
  end
end
# rubocop:enable Minitest/AssertEqual, Minitest/AssertOperator, Minitest/MultipleAssertions
