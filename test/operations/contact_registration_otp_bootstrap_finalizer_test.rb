# frozen_string_literal: true

require "test_helper"
require "minitest/mock"

# Boolean fact comparisons keep credentials and binding references out of failure diagnostics.
# rubocop:disable Minitest/AssertEqual, Minitest/AssertOperator, Minitest/MultipleAssertions
class ContactRegistrationOtpBootstrapFinalizerTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  %i(app com).each do |surface|
    %i(success primary_freshness_elapsed missing_parent foreign_parent foreign_owner foreign_root foreign_browser
       expired_parent canceled_parent canceled_then_restarted_parent
       revoked_root changed_policy foreign_return_target wrong_scope_target empty_return_target unknown_scope
       source_fault contact_receipt_fault bootstrap_receipt_fault).each do |scenario|
      test "#{surface} first email bootstrap #{scenario} retains original registration authority without freshness" do
        owner_model, token_model, contact_model, policy_model, auth_model, audit_model, owner_key =
          if surface == :app
            [Client, ClientToken, ClientEmail, ClientEmailPolicy, ClientAuthCeremonySession,
             ClientContactAuditOutbox, :user_id,]
          else
            [Visitor, VisitorToken, VisitorEmail, VisitorEmailPolicy, VisitorAuthCeremonySession,
             VisitorContactAuditOutbox, :visitor_id,]
          end
        actor = owner_model.create!(
          id: SecureRandom.random_number(1 << 60) + 1_000_000_000,
          status_id: (surface == :app) ? ClientStatus::ACTIVE : VisitorStatus::ACTIVE,
        )
        token = token_model.create!(
          owner_key => actor.id,
          :root_login_established_at => token_model.database_now -
            ((scenario == :primary_freshness_elapsed) ? 9.minutes + 30.seconds : 0.seconds),
          :discard_at => 1.day.from_now,
        )
        token.rotate_refresh_token!
        nonce = SecureRandom.urlsafe_base64(32)
        bootstrap_requirement = StepUpRequirement.new(
          step_up_required: false, scope: "settings_email", purpose: "bootstrap",
          allowed_methods: [:email_otp], ttl: 15.minutes, audience: "step_up:#{surface}",
          phishing_resistant_required: false, user_verification_required: false,
          full_reauthentication_required: false, session_binding: token.public_id,
          token_binding: token.public_id, require_session_binding: true,
          actor_ref: actor.public_id, resource_ref: nil, tenant_ref: nil,
        )
        admission = BaseStepUpAdmissionIssuer.call!(
          actor:, token:, requirement: bootstrap_requirement, return_to: "/identity/emails",
          base_browser_nonce: nonce, base_token: token,
        )
        parent = admission.transaction
        binding = BaseAuthAdmissionCoordinator.find_admission_binding!(surface:, reference: admission.reference)
        attached, sid = auth_model.issue!
        binding.attach_auth_session!(auth_session: attached, confirmation_ref: SecureRandom.uuid)
        binding.confirm_base!(
          base_token: token,
          browser_digest: AuthAdmissionBinding.browser_digest(surface:, entry_ref: binding.entry_ref, nonce:),
        )
        BaseAuthAdmissionCoordinator.consume_entry_reference!(
          reference: admission.reference, surface:, expected_intent: "bootstrap", binding:, raw_auth_sid: sid,
        )
        ceremony, = auth_model.rotate_and_admit!(
          admission_purpose: "bootstrap_handoff", previous_raw_sid: sid,
          step_up_ceremony_transaction_ref: parent.transaction_id,
        )
        binding.redeem!(auth_session: attached, admitted_auth_session: ceremony)

        assert_equal "pending", parent.reload.status
        assert_equal "bootstrap", parent.purpose
        assert_equal ["email_otp"], parent.allowed_methods_array
        assert_nil token.reload.last_step_up_at

        contact = contact_model.create!(
          owner_key => actor.id, :raw_address => "bootstrap-#{SecureRandom.hex(8)}@example.test",
          :confirm_policy => "1",
        )
        issued = EmailCredentialRegistrationOtpIssuer.call(
          actor:, token:, email: contact, browser_nonce: nonce, bootstrap_transaction: parent,
        )
        transaction = issued.transaction
        code = issued.code

        assert_predicate EmailCredentialRegistrationOtpVerificationCommitter.call(
          actor:, token:, email: contact, transaction:, browser_nonce: nonce, code:,
        ), :success?
        requirement = policy_model.new(contact, user: actor).credential_registration_requirement(token:)
        actor_context = ActorValuesContext.empty.with(
          subject: actor, actor_type: (surface == :app) ? :client : :visitor, tld: surface, surface: :base,
        )

        assert_not_predicate StepUpResolver.call(token:, requirement:, now: token_model.database_now), :satisfied?
        arguments = {
          actor:,
          actor_context:,
          token:,
          email: contact,
          transaction:,
          code:,
          browser_nonce: nonce,
          requirement:,
          bootstrap_transaction: parent,
        }
        case scenario
        when :missing_parent
          arguments[:bootstrap_transaction] = nil
        when :foreign_parent
          foreign_actor = owner_model.create!(
            id: SecureRandom.random_number(1 << 60) + 1_000_000_000,
            status_id: (surface == :app) ? ClientStatus::ACTIVE : VisitorStatus::ACTIVE,
          )
          foreign_token = token_model.create!(
            owner_key => foreign_actor.id, :root_login_established_at => token_model.database_now,
            :discard_at => 1.day.from_now,
          )
          foreign_token.rotate_refresh_token!
          foreign_requirement = StepUpRequirement.new(
            **bootstrap_requirement.to_h.merge(
              actor_ref: foreign_actor.public_id, session_binding: foreign_token.public_id,
              token_binding: foreign_token.public_id,
            ),
          )
          foreign_admission = BaseStepUpAdmissionIssuer.call!(
            actor: foreign_actor, token: foreign_token, requirement: foreign_requirement,
            return_to: "/identity/emails", base_browser_nonce: SecureRandom.urlsafe_base64(32),
            base_token: foreign_token,
          )
          arguments[:bootstrap_transaction] = foreign_admission.transaction
        when :foreign_owner
          arguments[:actor] = owner_model.create!(
            status_id: (surface == :app) ? ClientStatus::ACTIVE : VisitorStatus::ACTIVE,
          )
        when :foreign_browser
          arguments[:browser_nonce] = SecureRandom.urlsafe_base64(32)
        when :foreign_root
          replacement = token_model.create!(owner_key => actor.id, :discard_at => 1.day.from_now)
          replacement.rotate_refresh_token!
          arguments[:token] = replacement
        when :expired_parent
          # D-115 permits deadline fixtures; no lifecycle transition is fabricated.
          parent.update_columns(expires_at: parent.class.database_now - 1.second)
        when :canceled_parent
          parent.commit_cancellation!(now: parent.class.database_now)
        when :canceled_then_restarted_parent
          IdentityStepUpCeremonyCancellationCommitter.call!(actor:, token:, transaction: parent)
          restarted = BaseStepUpAdmissionIssuer.call!(
            actor:, token:, requirement: bootstrap_requirement, return_to: "/identity/emails",
            base_browser_nonce: nonce, base_token: token,
          )
          arguments[:bootstrap_transaction] = restarted.transaction

          assert_equal "canceled", parent.reload.status
          assert_not_equal parent.transaction_id, restarted.transaction.transaction_id,
                           "A new permission must not adopt proof issued for the canceled bootstrap"
        when :revoked_root
          token.revoke!
        when :changed_policy
          arguments[:requirement] = StepUpRequirement.new(**requirement.to_h.merge(allowed_methods: [:email_otp]))
        when :foreign_return_target
          parent.update_columns(return_to: "https://foreign.example.test/identity/emails")
        when :wrong_scope_target
          parent.update_columns(return_to: "/identity/telephones")
        when :empty_return_target
          parent.update_columns(return_to: "")
        when :unknown_scope
          parent.update_columns(required_scope: "unknown_operation")
        end
        source_facts = contact.reload.attributes
        proof = transaction.attributes.slice("otp_consumed_at", "otp_receipt_verifier", "otp_result_expires_at")
        ticket_facts = transaction.reload.attributes
        parent_facts = parent.reload.attributes
        root_facts = token.reload.attributes
        binding_facts = binding.reload.attributes
        supplied_parent = arguments[:bootstrap_transaction]
        supplied_parent_facts = supplied_parent&.reload&.attributes
        audits = audit_model.where(operation_ref: transaction.transaction_id)

        assert_equal 0, audits.count
        assert_not EmailCredentialRegistrationOtpFinalizer.bootstrap_receipt_pending?(**arguments),
                   "Unfinalized Source proof must not authorize receipt-only recovery"

        if %i(source_fault contact_receipt_fault bootstrap_receipt_fault).include?(scenario)
          fired = false
          fault =
            lambda do |event|
              sql = event.payload.fetch(:sql)
              next unless sql.start_with?("UPDATE")

              boundary =
                case scenario
                when :source_fault
                  sql.include?(contact_model.table_name) && sql.include?("binding_finalized_at")
                when :contact_receipt_fault
                  sql.include?(transaction.class.table_name)
                when :bootstrap_receipt_fault
                  sql.include?(parent.class.table_name)
                end
              next if fired || !boundary

              fired = true
              raise ActiveRecord::StatementInvalid, "injected registration persistence failure"
            end

          ActiveSupport::Notifications.subscribed(fault, "sql.active_record") do
            assert_raises(ActiveRecord::StatementInvalid) { EmailCredentialRegistrationOtpFinalizer.call!(**arguments) }
          end
          assert fired, "The real persistence boundary must be reached"
          assert ticket_facts == transaction.reload.attributes, "Contact receipt must remain pending after failure"
          assert parent_facts == parent.reload.attributes, "Bootstrap receipt must remain pending after failure"
          assert proof == transaction.reload.attributes.slice(*proof.keys), "Verified proof must survive failure"
          assert_nil transaction.reload.otp_verifier
          assert_not_nil transaction.otp_consumed_at
          if scenario == :source_fault
            assert source_facts == contact.reload.attributes, "Source failure must preserve the original candidate"
            assert_equal 0, audits.count
          else
            assert_predicate contact, :binding_effective?
            assert_equal 1, audits.where(event_name: "finalized", contact_ref: contact.public_id).count
            assert EmailCredentialRegistrationOtpFinalizer.bootstrap_receipt_pending?(**arguments),
                   "Original committed Source facts must permit only their pending receipt"
            assert_not EmailCredentialRegistrationOtpFinalizer.bootstrap_receipt_pending?(
              **arguments.merge(browser_nonce: SecureRandom.urlsafe_base64(32)),
            ), "A different browser cannot recover the committed Source receipt"
            assert_not EmailCredentialRegistrationOtpFinalizer.bootstrap_receipt_pending?(
              **arguments.merge(bootstrap_transaction: nil),
            ), "Committed Source is not a replacement for the original bootstrap permission"
            assert_not EmailCredentialRegistrationOtpFinalizer.bootstrap_receipt_pending?(
              **arguments.merge(
                requirement: StepUpRequirement.new(**requirement.to_h.merge(allowed_methods: [:email_otp])),
              ),
            ), "A changed operation policy cannot recover the committed Source receipt"
          end
        end

        if %i(success primary_freshness_elapsed source_fault contact_receipt_fault
              bootstrap_receipt_fault).include?(scenario)
          finalization_now = contact_model.database_now +
            ((scenario == :primary_freshness_elapsed) ? 31.seconds : 0.seconds)
          contact_model.stub(:database_now, finalization_now) do
            transaction.class.stub(:database_now, finalization_now) do
              parent.class.stub(:database_now, finalization_now) do
                if scenario == :primary_freshness_elapsed
                  assert finalization_now >= token.root_login_established_at + 10.minutes,
                         "Primary freshness is an issuance prerequisite, not a finalization prerequisite"
                end

                assert_equal :finalized, EmailCredentialRegistrationOtpFinalizer.call!(**arguments)
                assert_predicate contact.reload, :binding_effective?
                assert_equal "consumed", transaction.reload.status
                assert_equal "consumed", parent.reload.status
                assert_not EmailCredentialRegistrationOtpFinalizer.bootstrap_receipt_pending?(**arguments),
                           "Consumed receipts cannot authorize another operation"
                assert_equal "email_otp", parent[:method]
                assert parent.verified_credential_ref == contact.public_id, "Parent must name the original candidate"
                assert proof == transaction.attributes.slice(*proof.keys),
                       "Finalization must retain the exact verified proof"
                assert_equal 1, audits.where(event_name: "finalized", contact_ref: contact.public_id).count
                committed_source = contact.attributes
                committed_ticket = transaction.attributes
                committed_parent = parent.attributes

                assert_equal :finalized, EmailCredentialRegistrationOtpFinalizer.call!(**arguments)
                assert committed_source == contact.reload.attributes, "Exact retry must not rewrite Source facts"
                assert committed_ticket == transaction.reload.attributes, "Exact retry must not replace Contact receipt"
                assert committed_parent == parent.reload.attributes, "Exact retry must not replace Bootstrap receipt"
                assert_equal 1, audits.count
              end
            end
          end
        else
          assert_equal :unavailable, EmailCredentialRegistrationOtpFinalizer.call!(**arguments)
          assert source_facts == contact.reload.attributes, "Refusal must preserve the candidate and verified proof"
          assert ticket_facts == transaction.reload.attributes, "Refusal must preserve the original Contact Ticket"
          assert parent_facts == parent.reload.attributes, "Refusal must preserve the original Bootstrap parent"
          assert supplied_parent_facts == supplied_parent&.reload&.attributes, "Refusal must preserve foreign parents"
          assert_equal 0, audits.count
        end

        assert root_facts == token.reload.attributes, "Bootstrap must never issue freshness or replace Root authority"
        assert binding_facts == binding.reload.attributes, "Finalization must not replace original admission binding"
        assert_nil token.last_step_up_at
        assert_nil transaction.reload.otp_verifier
        assert_not_nil transaction.otp_consumed_at
      end
    end
  end
end
# rubocop:enable Minitest/AssertEqual, Minitest/AssertOperator, Minitest/MultipleAssertions
