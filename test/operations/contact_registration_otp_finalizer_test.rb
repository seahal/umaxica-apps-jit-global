# frozen_string_literal: true

require "test_helper"
require "minitest/mock"

# Boolean comparisons prevent disclosure of proof, OTP and root facts on assertion failures.
class ContactRegistrationOtpFinalizerTest < ActiveSupport::TestCase
  self.fixture_table_names = []
  self.use_transactional_tests = false

  setup do
    @created_client_ids = []
  end

  teardown do
    client_ids = Array(@created_client_ids)
    client_refs = Client.where(id: client_ids).pluck(:public_id)
    tokens = ClientToken.where(user_id: client_ids).select(:id)
    parents = ClientStepUpCeremonyTransaction.where(actor_ref: client_refs)
    ClientContactAuditOutbox.where(owner_ref: client_refs).delete_all
    ClientEmailCeremonyTransaction.where(actor_ref: client_refs).delete_all
    ClientTelephoneCeremonyTransaction.where(actor_ref: client_refs).delete_all
    ClientAuthAdmissionBinding.where(base_token_id: tokens).or(
      ClientAuthAdmissionBinding.where(step_up_ceremony_transaction_id: parents.select(:id)),
    ).delete_all
    ClientStepUpSession.where(user_token_id: tokens).delete_all
    ClientAuthCeremonySession.where(
      step_up_ceremony_transaction_ref: parents.select(:transaction_id),
    ).delete_all
    parents.delete_all
    OpAppGrant.where(client_token_id: tokens).delete_all
    ClientEmail.where(user_id: client_ids).delete_all
    ClientTelephone.where(user_id: client_ids).delete_all
    ClientPasskey.where(user_id: client_ids).delete_all
    ClientTotpCredential.where(user_id: client_ids).delete_all
    ClientPreference.where(client_id: client_ids).destroy_all
    ClientDeviceSession.where(user_id: client_ids).update_all(current_refresh_token_id: nil)
    ClientToken.where(user_id: client_ids).delete_all
    ClientDeviceSession.where(user_id: client_ids).delete_all
    ClientAuthorityLock.where(client_id: client_ids).delete_all
    ClientChronicle.where(subject_type: "Client", subject_id: client_ids.map(&:to_s)).delete_all
    ClientAccount.where(user_id: client_ids).delete_all
    Client.where(id: client_ids).delete_all
  end

  %i(app).each do |surface|
    %i(email telephone).each do |channel|
      %i(success foreign_browser foreign_root foreign_owner foreign_flow proof_before proof_at proof_after revoked
         legacy_step_up_state_cleared credential_lost current_policy source_fault receipt_fault
         root_before root_at root_after rebound_device registered_destination).each do |scenario|
        test "#{surface} #{channel} finalization #{scenario} preserves OTP receipt and OP authority" do
          owner_model, contact_model, owner_key, flow_model, audit_model, status_key, verified_status =
            case [surface, channel]
            when [:app, :email], [:app, :telephone]
              [Client, (channel == :email) ? ClientEmail : ClientTelephone, :user_id,
               (channel == :email) ? ClientEmailCeremonyTransaction : ClientTelephoneCeremonyTransaction,
               ClientContactAuditOutbox, (channel == :email) ? :user_email_status_id : :user_telephone_status_id,
               (channel == :email) ? ClientEmailStatus::VERIFIED : ClientTelephoneStatus::VERIFIED,]
            end
          actor = owner_model.create!(
            security_mode_id: SecurityModeConfigurable::NORMAL,
            id: SecureRandom.random_number(1 << 60) + 1_000_000_000,
            status_id: ClientStatus::ACTIVE,
          )
          @created_client_ids << actor.id
          token = ClientToken.create!(authentication_epoch: 0, user: actor, discard_at: 1.day.from_now)
          now = OpBaseAppRecord.database_now
          token.device_session_record!
          token.update!(root_login_established_at: now, established_authentication_method: "passkey")
          token.rotate_refresh_token!(now:)
          oidc_client = OidcClientRegistry.find!("base-app-ww")
          grant = OpAppGrant.create!(
            authentication_epoch: token.authentication_epoch, client_token: token,
            oidc_client_id: oidc_client.client_id, oidc_scope: "openid profile", oidc_jti: SecureRandom.uuid,
            oidc_nonce: SecureRandom.hex(16), oidc_auth_time: Time.at(now.to_i).utc,
            oidc_acr: StepUpEvidenceResolver::STEP_UP_ACR, oidc_amr: JSON.generate(["passkey"]),
            refresh_token_expires_at: now + 1.hour,
          )
          grant.issue_refresh_token!(now:)
          step_up_evidence = StepUpEvidenceValue.new(
            acr: grant.oidc_acr, amr: ["passkey"], auth_time: now.to_i, sid: grant.public_id,
            sub: OidcSubject.for(actor, resource_type: "client"), client_id: oidc_client.client_id,
            aud: [oidc_client.aud], jti: grant.oidc_jti,
          )
          passkey = actor.client_passkeys.create!(
            webauthn_id: SecureRandom.uuid, public_key: "credential-lost-test-key", sign_count: 0,
          )
          destination =
            (channel == :email) ? "finalizer-#{SecureRandom.hex(8)}@example.test" :
                         "+8190#{SecureRandom.random_number(10**8).to_s.rjust(8, "0")}"
          contact_attributes = {
            owner_key => actor.id,
            :confirm_policy => "1",
            ((channel == :email) ? :raw_address : :raw_number) => destination,
            **((channel == :telephone) ? { confirm_using_mfa: "1" } : {}),
          }
          previous_attributes = contact_attributes
          if scenario == :registered_destination
            previous_destination =
              if channel == :email
                "previous-#{SecureRandom.hex(8)}@example.test"
              else
                "+8191#{SecureRandom.random_number(10**8).to_s.rjust(8, "0")}"
              end
            previous_attributes = contact_attributes.merge(
              ((channel == :email) ? :raw_address : :raw_number) => previous_destination,
            )
          end
          previous = contact_model.create!(**previous_attributes, status_key => verified_status)
          previous.finalize_binding!
          contact = contact_model.create!(**contact_attributes)
          policy_model =
            case [surface, channel]
            when [:app, :email] then ClientEmailPolicy
            when [:app, :telephone] then ClientTelephonePolicy
            end
          requirement = policy_model.new(contact, user: actor).credential_registration_requirement(token:)
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
            subject: actor, actor_type: :client, tld: surface, surface: :base,
          )
          arguments = { actor:,
                        actor_context:,
                        token:,
                        contact:,
                        transaction:,
                        channel:,
                        browser_nonce: nonce,
                        requirement:,
                        step_up_evidence:, }
          arguments = arguments.except(:contact, :channel).merge(email: contact, code:) if channel == :email
          arguments = arguments.except(:contact, :channel).merge(telephone: contact, code:) if channel == :telephone
          case scenario
          when :foreign_browser
            arguments[:browser_nonce] = SecureRandom.urlsafe_base64(32)
          when :foreign_root
            replacement = ClientToken.create!(
              authentication_epoch: 0, user: actor,
              discard_at: 1.day.from_now,
            )
            replacement.rotate_refresh_token!
            arguments[:token] = replacement
          when :foreign_owner
            arguments[:actor] = owner_model.create!(
              security_mode_id: SecurityModeConfigurable::NORMAL,
              status_id: ClientStatus::ACTIVE,
            )
            @created_client_ids << arguments[:actor].id
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
          when :legacy_step_up_state_cleared
            token.revoke_step_up_authority!
          when :credential_lost
            passkey.update!(discard_at: passkey.class.database_now)
          when :current_policy
            arguments[:requirement] = StepUpRequirement.new(
              step_up_required: true,
              phishing_resistant_required: false,
              user_verification_required: false,
              full_reauthentication_required: false,
              **requirement.to_h.merge(
                allowed_methods: [:totp], phishing_resistant_required: false,
                user_verification_required: false,
              ),
            )
          when :registered_destination
            competitor = owner_model.create!(
              security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE,
            )
            @created_client_ids << competitor.id
            competitor_contact = competitor.public_send((channel == :email) ? :client_emails : :client_telephones).create!(
              **contact_attributes.except(owner_key, status_key),
              status_key => verified_status,
            )
            competitor_contact.finalize_binding!
          end
          if %i(root_before root_at root_after).include?(scenario)
            root_deadline = flow_model.database_now + 10.seconds
            token.update_columns(discard_at: root_deadline)
            grant.update_columns(refresh_token_expires_at: root_deadline)
          end
          original_contact = contact.reload.attributes
          original_previous = previous.reload.attributes
          ticket_facts = transaction.reload.attributes
          root_facts = token.reload.attributes
          supplied_ticket_facts = arguments.fetch(:transaction).reload.attributes
          audits = audit_model.where(operation_ref: transaction.transaction_id)
          original_audits = audits.count
          if scenario == :rebound_device
            replacement = ClientToken.create!(authentication_epoch: 0, user: actor)
            new_device = replacement.device_session_record!
            ClientDeviceSession.where(id: token.device_session_id).update_all(current_refresh_token_id: nil)
            ClientToken.where(id: token.id).update_all(device_session_id: new_device.id)
            ClientDeviceSession.where(id: new_device.id).update_all(current_refresh_token_id: token.id)
            root_facts = ClientToken.find(token.id).attributes
          end
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
              error_class =
                if channel == :email
                  EmailCredentialRegistrationOtpFinalizer::DependencyFailure
                else
                  TelephoneCredentialRegistrationOtpFinalizer::DependencyFailure
                end
              assert_raises(error_class) { finalizer.call!(**arguments) }
            end

            assert fired, "The actual persistence boundary must be reached"
            retained_proof = transaction.reload.attributes.slice(*proof.keys)

            assert_withheld("Fault must retain the original verified proof") { proof == retained_proof }
            assert_nil transaction.otp_verifier
            if scenario == :source_fault
              assert_predicate transaction.reload, :consumed?
              assert_withheld("Source failure must roll back candidate binding") {
                original_contact == contact.reload.attributes
              }
              assert_withheld("Source failure must preserve the old binding") {
                original_previous == previous.reload.attributes
              }
              assert_equal original_audits, audits.count
            else
              assert_withheld("A Ticket failure must roll back candidate binding") {
                original_contact == contact.reload.attributes
              }
              assert_withheld("A Ticket failure must preserve the old binding") {
                original_previous == previous.reload.attributes
              }
              assert_equal original_audits, audits.count
            end
          end
          if scenario == :registered_destination
            competitor_facts = competitor.reload.attributes
            competitor_contact_facts = competitor_contact.reload.attributes

            assert_raises(RuntimeError) { finalizer.call!(**arguments) }

            assert_withheld("Registered destination incident must preserve candidate") {
              original_contact == contact.reload.attributes
            }
            assert_withheld("Registered destination incident must preserve the previous binding") {
              original_previous == previous.reload.attributes
            }
            assert_withheld("Registered destination incident must preserve its verified Ticket") {
              ticket_facts == transaction.reload.attributes
            }
            assert_withheld("Registered destination incident must preserve the other owner") {
              competitor_facts == competitor.reload.attributes
            }
            assert_withheld("Registered destination incident must preserve the other binding") {
              competitor_contact_facts == competitor_contact.reload.attributes
            }
            assert_equal original_audits, audits.count
            assert_withheld("Registered destination incident must preserve Root authority") {
              root_facts == token.reload.attributes
            }
            next
          end
          status =
            if %i(root_before root_at root_after).include?(scenario)
              offset = { root_before: -Rational(1, 1_000_000),
                         root_at: 0,
                         root_after: Rational(1, 1_000_000), }.fetch(scenario)
              reads = 0
              clock =
                -> {
                  reads += 1
                  (reads == 1) ? root_deadline - 1.second : root_deadline + offset
                }
              flow_model.stub(:database_now, clock) do
                OpBaseAppRecord.stub(:database_now, root_deadline + offset) do
                  finalizer.call!(**arguments)
                end
              end
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
          source_committed = %i(
            success proof_before receipt_fault credential_lost legacy_step_up_state_cleared root_before
          ).include?(scenario)
          if source_committed
            assert_equal :finalized, status
            OpBaseAppRecord.transaction do
              assert StepUpEvidenceVerifier.call(evidence: step_up_evidence, actor: actor, token: token.reload)
            end
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

            assert_withheld("Finalization must not replace OTP proof") { proof == final_proof }
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
            assert_withheld("Exact retry must not mutate finalized Source") {
              completed_contact == contact.reload.attributes
            }
            assert_withheld("Exact retry must not re-release previous binding") {
              completed_previous == previous.reload.attributes
            }
            assert_withheld("Exact retry must retain the original receipt") {
              completed_ticket == transaction.reload.attributes
            }
            assert_withheld("Exact retry must not duplicate audits") {
              audit_facts == audits.order(:id).map(&:attributes)
            }
          else
            assert_equal :unavailable, status
            assert_withheld("Refusal must preserve verified candidate evidence") {
              original_contact == contact.reload.attributes
            }
            assert_withheld("Refusal must preserve the previous effective binding") {
              original_previous == previous.reload.attributes
            }
            if scenario == :source_fault
              assert_predicate transaction.reload, :consumed?
              assert_withheld("The consumed Ticket must retain its verified OTP receipt") {
                proof == transaction.reload.attributes.slice(*proof.keys)
              }
            else
              assert_withheld("Refusal must preserve the original pending Ticket") {
                ticket_facts == transaction.reload.attributes
              }
            end
            unless scenario == :source_fault
              assert_withheld("Refusal must preserve any substituted Ticket") {
                supplied_ticket_facts == arguments.fetch(:transaction).reload.attributes
              }
            end

            assert_equal original_audits, audits.count
          end

          assert_withheld("Contact finalization must not mutate the root or spend OP evidence") {
            root_facts == token.reload.attributes
          }
        end
      end
    end
  end
end
