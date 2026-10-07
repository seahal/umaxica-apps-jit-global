# frozen_string_literal: true

require "test_helper"

class ContactEmailSignupSourceAuditTest < ActionDispatch::IntegrationTest
  setup do
    @previous_forgery_protection = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    TurnstileVerifierStub.challenge_enabled = true
    TurnstileVerifierStub.challenge_response = { "success" => true }
  end

  teardown do
    ActionController::Base.allow_forgery_protection = @previous_forgery_protection
    TurnstileVerifierStub.challenge_enabled = false
    TurnstileVerifierStub.challenge_response = nil
  end

  [
    [:app, "PUBLIC_BASE_SERVICE_URL", "PUBLIC_AUTH_SERVICE_URL", ClientSignUpFlow, ClientEmail,
     ClientContactAuditOutbox, :client_email,],
    [:com, "PUBLIC_BASE_CORPORATE_URL", "PUBLIC_AUTH_CORPORATE_URL", VisitorSignUpFlow, VisitorEmail,
     VisitorContactAuditOutbox, :visitor_email,],
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
        issuer = JitSecurityJwtRegistry.surface("BASE_#{surface.to_s.upcase}")
        2.times do |index|
          rt = Rack::Utils.parse_query(URI.parse(browser.response.location).query).fetch("rt")
          payload, = JWT.decode(
            rt, JitSecurityJwtRegistry.public_key_for(issuer.id, issuer.current_kid), true,
            algorithms: ["ES384"], verify_iss: true, iss: "https://#{base_host}",
            verify_aud: true, aud: Rails.configuration.x.boot_config.fetch(:jump).audience,
          )
          target = URI.parse(payload.fetch("url"))

          assert_includes [base_host, auth_host], target.host
          browser.host!(target.host)
          browser.get(target.request_uri, params: { ri: "jp" })
          next if index == 1

          form = browser.response.parsed_body.at_css("form#base-authorization-ceremony-start-form")
          fields = form.css("input[name]").to_h { |input| [input["name"], input["value"]] }
          browser.post(
            form["action"], params: fields, headers: {
              "Origin" => "https://#{target.host}", "Sec-Fetch-Site" => "same-origin",
            },
          )
        end
        # Redeem through Auth POST, Base confirmation POST, then Auth POST.
        # No admission, browser marker or signed flow locator is installed directly.
        3.times do |index|
          form = browser.response.parsed_body.at_css("form")

          assert_not_nil form, "admission step #{index}, HTTP #{browser.response.status}"
          fields = form.css("input[name]").to_h { |input| [input["name"], input["value"]] }
          browser.post(
            form["action"], params: fields, headers: {
              "Origin" => "https://#{browser.host}", "Sec-Fetch-Site" => "same-origin",
            },
          )
          break if index == 2

          target = URI.parse(browser.response.location)

          assert_includes [base_host, auth_host], target.host
          browser.host!(target.host)
          browser.get(target.request_uri, params: { ri: "jp" })
        end

        assert_equal 303, browser.response.status
        browser.get("/sign/up/email/new", params: { ri: "jp" })

        assert_equal 200, browser.response.status
        csrf = browser.response.parsed_body.at_css('meta[name="csrf-token"]')["content"]
        headers = { "Origin" => "https://#{auth_host}", "Sec-Fetch-Site" => "same-origin", "X-CSRF-Token" => csrf }
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
        otp = contact.get_otp
        code = ROTP::HOTP.new(otp.fetch(:otp_private_key)).at(otp.fetch(:otp_counter)).to_s
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
                  contact.reload.sign_up_otp_context.fetch("verified_at")
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
          proof = contact.reload.sign_up_otp_context.deep_dup

          assert_nil contact.get_otp
          assert_not_nil proof.fetch("verified_at")
          assert_equal flow_class::STATUS_MODEL::CONTACT_PENDING, flow.reload.status_id
        end
        browser.patch(
          "/sign/up/check/email/otp?#{binding_query}", headers: headers, params: {
            scope => { pass_code: code }, "cf-turnstile-response" => "test",
          },
        )

        assert_includes [302, 303], browser.response.status
        if otp_failure_write
          # Proof references and keyed digests must not appear in assertion failure output.
          # rubocop:disable Minitest/AssertEqual, Minitest/AssertOperator
          assert proof == contact.reload.sign_up_otp_context,
                 "HTTP retry must not extend or replace committed proof"
          # rubocop:enable Minitest/AssertEqual, Minitest/AssertOperator
        end

        assert_nil contact.reload.binding_finalized_at
        assert_not outbox.exists?(operation_ref: flow.public_id)
        browser.get("/sign/up/check/email/birthdate", params: { ri: "jp", fb: binding })

        assert_equal 200, browser.response.status
        csrf = browser.response.parsed_body.at_css('meta[name="csrf-token"]')["content"]
        if outcome == :suspended_owner
          owner_class = (surface == :app) ? Client : Visitor
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
        recovery_ids = nil
        reveal_ids = nil
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
            committed_at = contact.binding_finalized_at
            committed_intent = outbox.find_by!(operation_ref: flow.public_id)
            if surface == :com
              recovery_ids = VisitorSecretCredential.where(visitor_id: flow.principal_id).order(:id).pluck(:id)
              reveal_ids = SecurityOneTimeReveal.where(
                actor_type: "Visitor", actor_id: flow.principal_id, purpose: "visitor.recovery_secret_credential",
              ).order(:id).pluck(:id)
            end

            assert_predicate flow.reload, :sign_up_checkpoint_pending?
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
              owner_class = (surface == :app) ? Client : Visitor
              owner_class.find(flow.principal_id).update!(deactivated_at: owner_class.database_now)
            when :ticket_failure_expired_flow
              decision_time = flow.expires_at
            end
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

        if %i(ticket_failure_duplicate_intent ticket_failure_released_binding
              ticket_failure_suspended_owner ticket_failure_expired_flow).include?(outcome)
          assert_equal((outcome == :ticket_failure_expired_flow) ? 403 : 409, browser.response.status)
          assert_not flow.reload.sign_up_completed?
          assert_equal committed_at, contact.reload.binding_finalized_at
          assert_equal(
            (outcome == :ticket_failure_duplicate_intent) ? 2 : 1,
            outbox.where(operation_ref: flow.public_id).count,
          )
          next
        end

        if %i(expired_before_locked_decision suspended_owner).include?(outcome)
          assert_not contact.reload.binding_effective?
          assert_not outbox.exists?(operation_ref: flow.public_id)
          assert_not flow.reload.sign_up_completed?
          assert_equal((outcome == :suspended_owner) ? 422 : 403, browser.response.status)
          next
        end

        assert_includes [302, 303], browser.response.status
        assert_predicate flow.reload, :sign_up_completed?
        assert_predicate contact.reload, :binding_effective?
        intent = outbox.find_by!(operation_ref: flow.public_id)

        assert_equal ["email", "finalized", contact.public_id],
                     [intent.contact_kind, intent.event_name, intent.contact_ref]
        assert_nil intent.actor_ref
        assert_nil intent.acknowledged_at
        if outcome == :ticket_failure_retry
          owner_class = (surface == :app) ? Client : Visitor

          assert_equal [committed_at, [committed_intent.id], "1990-01-15"], [
            contact.binding_finalized_at,
            outbox.where(operation_ref: flow.public_id).pluck(:id),
            owner_class.find(flow.principal_id).birthdate,
          ]
          if surface == :com
            assert_equal [10, recovery_ids, reveal_ids], [
              VisitorSecretCredential.where(visitor_id: flow.principal_id).count,
              VisitorSecretCredential.where(visitor_id: flow.principal_id).order(:id).pluck(:id),
              SecurityOneTimeReveal.where(
                actor_type: "Visitor", actor_id: flow.principal_id, purpose: "visitor.recovery_secret_credential",
              ).order(:id).pluck(:id),
            ]
            return_to = VisitorSignInFlow.where(principal_id: flow.principal_id).order(:id).last&.return_to

            assert return_to.present? && URI.parse(return_to).path == "/identity/recovery-secret",
                   "reconciled COM signup must retain its original recovery distribution destination"
          end
        end
      end
      # rubocop:enable Minitest/MultipleAssertions
    end
  end
end
