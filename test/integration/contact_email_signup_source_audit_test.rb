# frozen_string_literal: true

require "test_helper"
require "minitest/mock"

class ContactEmailSignupSourceAuditTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper
  include SignInFlowCleanup

  self.fixture_table_names = []
  self.use_transactional_tests = false

  setup do
    # The test lock serializes these HTTP journeys; retain pre-existing rows for scoped cleanup.
    @initial_client_ids = Client.pluck(:id)
    @initial_signup_ids = ClientSignUpFlow.pluck(:id)
    @initial_binding_ids = ClientAuthAdmissionBinding.pluck(:id)
    @initial_ceremony_ids = ClientAuthCeremonySession.pluck(:id)
    @initial_parent_ids = ClientOidcAuthorizationTransaction.pluck(:id)
    ClientSignUpFlowStatus::DEFAULTS.each { |id| ClientSignUpFlowStatus.find_or_create_by!(id: id) }
    ClientSignUpFlowCleanupStatus::DEFAULTS.each { |id| ClientSignUpFlowCleanupStatus.find_or_create_by!(id: id) }
    @previous_forgery_protection = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    TurnstileVerifierStub.challenge_enabled = true
    TurnstileVerifierStub.challenge_response = { "success" => true }
  end

  teardown do
    # Delivery runs after real commits, so rollback fixtures cannot clean up this journey.
    owners = Client.where.not(id: @initial_client_ids).to_a
    owner_ids = owners.map(&:id)
    # Completed signup also commits the actor's bootstrap identity and collective graph.
    owners.each do |owner|
      identity_ids = ClientIdentity.where(source_record_id: owner.id).pluck(:id)
      persona_ids = ClientPersona.where(client_identity_id: identity_ids).pluck(:id)
      enterprise_ids =
        (PersonaMembership.where(persona_id: persona_ids).pluck(:enterprise_id) +
          EnterpriseOwnership.where(client_id: owner.id).pluck(:enterprise_id)).uniq
      unit_ids = EnterpriseUnit.where(enterprise_id: enterprise_ids).pluck(:id)
      PersonaMembership.where(persona_id: persona_ids)
        .or(PersonaMembership.where(enterprise_id: enterprise_ids)).delete_all
      PersonaAssignment.where(persona_id: persona_ids).delete_all
      ClientOidcIdentityBinding.where(client_identity_id: identity_ids).delete_all
      AvatarPersonaBinding.where(persona_id: persona_ids).delete_all
      ClientPersonaOwnership.where(client_persona_id: persona_ids).delete_all
      ClientPersonaLifecycle.where(client_persona_id: persona_ids).delete_all
      ClientPersona.where(id: persona_ids).delete_all
      ClientIdentity.where(id: identity_ids).delete_all
      EnterpriseUnitClosure.where(ancestor_id: unit_ids)
        .or(EnterpriseUnitClosure.where(descendant_id: unit_ids)).delete_all
      EnterpriseUnit.where(id: unit_ids).delete_all
      EnterpriseLifecycle.where(enterprise_id: enterprise_ids).delete_all
      EnterpriseOwnership.where(enterprise_id: enterprise_ids).delete_all
      EnterpriseAdministrationGrant.where(enterprise_id: enterprise_ids).delete_all
      EnterpriseDelegationGrant.where(enterprise_id: enterprise_ids).delete_all
      EnterpriseViewGrant.where(enterprise_id: enterprise_ids).delete_all
      EnterpriseOwnershipTransferRequest.where(enterprise_id: enterprise_ids).delete_all
      Enterprise.where(id: enterprise_ids).delete_all
    end
    flows = ClientSignUpFlow.where.not(id: @initial_signup_ids).to_a
    session_refs =
      flows.map do |flow|
        Digest::SHA256.hexdigest(JSON.generate(["email_sign_up", flow.public_id, flow.nonce_digest]))
      end
    ClientEmailCeremonyTransaction.where(session_ref: session_refs).delete_all
    ClientSignUpFlow.where(id: flows.map(&:id)).delete_all
    ClientAuthAdmissionBinding.where.not(id: @initial_binding_ids).delete_all
    ClientAuthCeremonySession.where.not(id: @initial_ceremony_ids).delete_all
    ClientOidcAuthorizationTransaction.where.not(id: @initial_parent_ids).delete_all
    delete_client_sign_in_flows!(ClientSignInFlow.where(principal_id: owner_ids))
    token_ids = ClientToken.where(user_id: owner_ids).select(:id)
    OpAppGrant.where(client_token_id: token_ids).delete_all
    ClientDeviceSession.where(user_id: owner_ids).update_all(current_refresh_token_id: nil)
    ClientToken.where(user_id: owner_ids).delete_all
    ClientDeviceSession.where(user_id: owner_ids).delete_all
    ClientContactAuditOutbox.where(owner_ref: owners.map(&:public_id)).delete_all
    ClientEmail.where(user_id: owner_ids).delete_all
    ClientAccount.where(user_id: owner_ids).delete_all
    ClientOidcConnection.where(user_id: owner_ids).delete_all
    ClientRegistrationCompletion.where(client_id: owner_ids).delete_all
    ClientAuthorityLock.where(client_id: owner_ids).delete_all
    Client.where(id: owner_ids).delete_all
  ensure
    ActionController::Base.allow_forgery_protection = @previous_forgery_protection
    TurnstileVerifierStub.challenge_enabled = false
    TurnstileVerifierStub.challenge_response = nil
  end

  [
    [:app, "PUBLIC_BASE_SERVICE_URL", "PUBLIC_AUTH_SERVICE_URL", ClientSignUpFlow, ClientEmail,
     ClientContactAuditOutbox, :client_email,],
  ].each do |surface, base_host_key, auth_host_key, flow_class, contact_class, outbox, scope|
    %i(complete otp_ticket_failure_retry otp_guardrail_failure_retry otp_checkpoint_failure_retry
       otp_requirement_failure_retry expired_before_locked_decision suspended_owner ticket_failure_retry
       ticket_failure_duplicate_intent ticket_failure_released_binding
       ticket_failure_suspended_owner ticket_failure_expired_flow).each do |outcome|
      # The two-database fault journey checks Source facts and Ticket recovery as one public transaction sequence.
      # rubocop:disable Minitest/MultipleAssertions
      test "#{surface} anonymous email signup #{outcome} preserves its Source boundary" do
        browser = open_session
        base_host = ENV.fetch(base_host_key)
        auth_host = ENV.fetch(auth_host_key)
        browser.host!(base_host)
        browser.https!
        browser.get("/sign", params: { ri: "jp" })
        csrf = browser.response.parsed_body.at_css('input[name="authenticity_token"]')["value"]
        browser.post(
          "/sign", params: { ri: "jp", authenticity_token: csrf }, headers: {
            "Origin" => "https://#{base_host}", "Sec-Fetch-Site" => "same-origin",
          },
        )
        12.times do
          break unless browser.response.redirect?

          target = URI.parse(browser.response.location)
          unless [base_host, visa_host_for_test_base_host(base_host), auth_host].include?(target.host)
            target = URI.parse(jump_rt_url_from_location_for_test(target.to_s))
          end

          assert_includes [base_host, visa_host_for_test_base_host(base_host), auth_host], target.host
          browser.host!(target.host)
          browser.get(
            target.request_uri, headers: {
              "Sec-Fetch-Mode" => "navigate", "Sec-Fetch-Dest" => "document", "Sec-Fetch-Site" => "cross-site",
            },
          )
        end

        assert_equal [200, auth_host], [browser.response.status, browser.host]
        switch_browser_to_sign_up!(browser, surface: surface.to_s)
        browser.get("/sign/up/email/new", params: { ri: "jp" })

        assert_equal 200, browser.response.status
        csrf = browser.response.parsed_body.at_css('meta[name="csrf-token"]')["content"]
        headers = { "Origin" => "https://#{auth_host}", "Sec-Fetch-Site" => "same-origin", "X-CSRF-Token" => csrf }
        clear_enqueued_jobs
        browser.post(
          "/sign/up/email", headers: headers, params: {
            scope => { raw_address: "source-signup-#{surface}@example.test", confirm_policy: "1" },
            "cf-turnstile-response" => "test",
          },
        )

        assert_includes [302, 303], browser.response.status
        flow_ref = browser.session.fetch("auth_#{surface}_up_sequence_id")
        flow = flow_class.find_by!(public_id: flow_ref)
        contact = contact_class.find(flow.pending_contact_id)
        binding = Rack::Utils.parse_query(URI.parse(browser.response.location).query).fetch("fb")
        binding_query = URI.encode_www_form(ri: "jp", fb: binding)
        delivery_job = enqueued_jobs.find { |job| job.fetch(:job) == OtpNotifierEmailDeliveryJob }

        assert_not_nil delivery_job
        delivery = ActiveJob::Arguments.deserialize(delivery_job.fetch(:args)).last.fetch(:params).symbolize_keys
        transaction_class = ClientEmailCeremonyTransaction
        transaction = transaction_class.find_by!(transaction_id: delivery.fetch(:sign_up_email_transaction_ref))
        code = OutboundSensitivePayload.decrypt_email_otp(delivery.fetch(:encrypted_hotp_token))

        # Boolean comparisons keep the producer's code and binding material out of failure output.
        assert_withheld { delivery.fetch(:sign_up_flow_ref) == flow.public_id }
        assert_withheld { delivery.fetch(:sign_up_email_otp_generation) == transaction.otp_generation }
        assert_withheld { transaction.email_candidate_ref == contact.public_id }
        owner = contact_owner_for_test(contact)

        assert_withheld { transaction.actor_ref == owner.public_id }
        assert_not delivery_job.fetch(:args).to_s.include?(code), "Delivery must not queue the plaintext code"
        assert_nil transaction.otp_consumed_at
        otp_failure_write = {
          otp_ticket_failure_retry: 1,
          otp_guardrail_failure_retry: 2,
          otp_checkpoint_failure_retry: 3,
          otp_requirement_failure_retry: 4,
        }[outcome]
        if otp_failure_write
          ticket_writes = 0
          failure =
            lambda do |_name, _started, _finished, _identity, payload|
              if payload[:name] == "#{flow_class} Update" &&
                  transaction.reload.otp_consumed_at
                ticket_writes += 1
                if ticket_writes == otp_failure_write
                  raise ActiveRecord::StatementInvalid, "signup OTP Ticket update unavailable"
                end
              end
            end

          ActiveSupport::Notifications.subscribed(failure, "sql.active_record") do
            assert_raises(ActiveRecord::StatementInvalid) do
              browser.patch(
                "/sign/up/check/email/otp?#{binding_query}", headers: headers, params: {
                  scope => { pass_code: code }, "cf-turnstile-response" => "test",
                },
              )
            end
          end
          proof = transaction.reload.attributes

          assert_nil transaction.otp_verifier
          assert_not_nil transaction.otp_consumed_at
          assert_not_nil transaction.otp_receipt_verifier
          assert_equal [transaction.otp_consumed_at + 60.seconds, transaction.expires_at].min,
                       transaction.otp_result_expires_at
          assert_equal flow_class::STATUS_MODEL::CONTACT_PENDING, flow.reload.status_id
        end
        browser.patch(
          "/sign/up/check/email/otp?#{binding_query}", headers: headers, params: {
            scope => { pass_code: code }, "cf-turnstile-response" => "test",
          },
        )

        assert_includes [302, 303], browser.response.status
        binding = Rack::Utils.parse_query(URI.parse(browser.response.location).query).fetch("fb")
        binding_query = URI.encode_www_form(ri: "jp", fb: binding)
        if otp_failure_write
          # Proof references and keyed digests must not appear in assertion failure output.
          assert_withheld("HTTP retry must not extend or replace committed proof") {
            proof == transaction.reload.attributes
          }
        end
        verified_proof = transaction.reload.attributes

        assert_nil transaction.otp_verifier
        assert_not_nil transaction.otp_consumed_at
        assert_not_nil transaction.otp_receipt_verifier

        assert_nil contact.reload.binding_finalized_at
        assert_not outbox.exists?(operation_ref: flow.public_id)
        browser.get("/sign/up/check/email/birthdate", params: { ri: "jp", fb: binding })

        assert_equal 200, browser.response.status
        csrf = browser.response.parsed_body.at_css('meta[name="csrf-token"]')["content"]
        if outcome == :suspended_owner
          owner_class = Client
          owner_class.find(flow.principal_id).update!(deactivated_at: owner_class.database_now)
        end
        decision_time = flow_class.database_now
        completed_requirement_clock_reads = 0
        clock =
          lambda do
            completed_requirement_clock_reads += 1 if flow.reload.requirement_cleared?(:birthdate)
            if outcome == :expired_before_locked_decision && completed_requirement_clock_reads > 1
              flow.expires_at
            else
              decision_time
            end
          end
        committed_at = nil
        committed_intent = nil
        flow_class.stub(:database_now, clock) do
          if outcome.to_s.start_with?("ticket_failure_")
            failure =
              lambda do |_name, _started, _finished, _identity, payload|
                if payload[:name] == "#{flow_class} Update" && payload[:sql].include?('"status_id"') &&
                    contact.reload.binding_effective?
                  raise ActiveRecord::StatementInvalid, "signup Ticket update unavailable"
                end
              end
            # Fail the real Ticket SQL boundary after Source commit; the domain transitions run normally.
            ActiveSupport::Notifications.subscribed(failure, "sql.active_record") do
              assert_raises(ActiveRecord::StatementInvalid) do
                browser.patch(
                  "/sign/up/check/email/birthdate?#{binding_query}",
                  headers: headers.merge("X-CSRF-Token" => csrf), params: {
                    requirement: "birthdate",
                    checkpoint_version: flow.reload.checkpoint_version,
                    birthdate_year: "1990",
                    birthdate_month: "01",
                    birthdate_day: "15",
                  },
                )
              end
            end

            assert_predicate contact.reload, :binding_effective?
            assert_withheld("Source commit before failed Parent persistence must retain the consumed child proof") {
              verified_proof == transaction.reload.attributes
            }
            committed_at = contact.binding_finalized_at
            committed_intent = outbox.find_by!(operation_ref: flow.public_id)

            assert_equal ClientSignUpFlowStatus::FINALIZING, flow.reload.status_id
            case outcome
            when :ticket_failure_duplicate_intent
              outbox.transaction do
                outbox.record!(
                  **committed_intent.attributes.slice(
                    "contact_kind", "event_name", "owner_ref", "contact_ref", "operation_ref", "actor_ref",
                  ).symbolize_keys,
                )
              end
            when :ticket_failure_released_binding
              contact.release_binding!
            when :ticket_failure_suspended_owner
              owner_class = Client
              owner_class.find(flow.principal_id).update!(deactivated_at: owner_class.database_now)
            when :ticket_failure_expired_flow
              decision_time = flow.expires_at
            end
          end
          if outcome.to_s.start_with?("ticket_failure_")
            # The original checkpoint request is stale. Reconciliation uses the committed receipt,
            # including after release, suspension or expiry; it never repeats source finalization.
            flow.with_cycle_lock { flow.reload }
          end
          browser.patch(
            "/sign/up/check/email/birthdate?#{binding_query}",
            headers: headers.merge("X-CSRF-Token" => csrf), params: {
              requirement: "birthdate",
              checkpoint_version: flow.reload.checkpoint_version,
              birthdate_year: (outcome == :ticket_failure_retry) ? "2001" : "1990",
              birthdate_month: "01",
              birthdate_day: "15",
            },
          )
        end

        assert_withheld(
          "Finalization, retry and denial must not rewrite the original child generation or bounded receipt",
        ) {
          verified_proof == transaction.reload.attributes
        }
        if outcome.to_s.start_with?("ticket_failure_")
          assert_equal 409, browser.response.status
          assert_predicate flow.reload, :sign_up_completed?
          receipt = ClientRegistrationCompletion.find_by!(client_id: flow.principal_id)

          assert_equal [flow.public_id, ClientRegistrationCompletionMethod::IDS.fetch("email")],
                       [receipt.sign_up_flow_ref, receipt.method_id]
          assert_equal committed_at, contact.reload.binding_finalized_at
          assert_equal(
            (outcome == :ticket_failure_duplicate_intent) ? 2 : 1,
            outbox.where(operation_ref: flow.public_id).count,
          )
          assert_equal "1990-01-15", Client.find(flow.principal_id).birthdate
          next
        end

        if %i(expired_before_locked_decision suspended_owner).include?(outcome)
          assert_not contact.reload.binding_effective?
          assert_not outbox.exists?(operation_ref: flow.public_id)
          assert_not flow.reload.sign_up_completed?
          assert_equal((outcome == :suspended_owner) ? 422 : 410, browser.response.status)
          assert_predicate flow, :sign_up_expired? if outcome == :expired_before_locked_decision
          next
        end

        assert_includes [302, 303], browser.response.status
        assert_predicate flow.reload, :sign_up_completed?
        assert_equal flow.public_id,
                     ClientRegistrationCompletion.find_by!(client_id: flow.principal_id).sign_up_flow_ref
        assert_predicate contact.reload, :binding_effective?
        intent = outbox.find_by!(operation_ref: flow.public_id)

        assert_equal ["email", "finalized", contact.public_id],
                     [intent.contact_kind, intent.event_name, intent.contact_ref]
        assert_nil intent.actor_ref
        assert_nil intent.acknowledged_at
        if outcome == :ticket_failure_retry
          owner_class = Client

          assert_equal [committed_at, [committed_intent.id], "1990-01-15"], [
            contact.binding_finalized_at,
            outbox.where(operation_ref: flow.public_id).pluck(:id),
            owner_class.find(flow.principal_id).birthdate,
          ]

        end
      end
      # rubocop:enable Minitest/MultipleAssertions
    end
  end
end
