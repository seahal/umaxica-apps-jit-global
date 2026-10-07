# frozen_string_literal: true

require "test_helper"

# Retained proof and browser references must not appear in assertion failure output.
# Each case observes the two-database failure and HTTP retry as one transaction journey.
# rubocop:disable Minitest/AssertEqual, Minitest/AssertOperator, Minitest/MultipleAssertions
class TelephoneSignupSourceProofRetryTest < ActionDispatch::IntegrationTest
  [
    [:app, "PUBLIC_BASE_SERVICE_URL", "PUBLIC_AUTH_SERVICE_URL", "BASE_APP", ClientSignUpFlow,
     ClientTelephone, ClientToken, ClientContactAuditOutbox, :client_telephone, :user_id,],
    [:com, "PUBLIC_BASE_CORPORATE_URL", "PUBLIC_AUTH_CORPORATE_URL", "BASE_COM", VisitorSignUpFlow,
     VisitorTelephone, VisitorToken, VisitorContactAuditOutbox, :visitor_telephone, :visitor_id,],
  ].each do |surface, base_host_key, auth_host_key, issuer_name, flow_class, contact_class, token_class,
    outbox, scope, owner_key|
    %i(verify_contact enter_guardrail enter_checkpoint clear_requirement).each_with_index do |failed_event, index|
      test "#{surface} telephone signup Source proof survives Ticket #{failed_event} failure and HTTP retry" do
        previous_protection = ActionController::Base.allow_forgery_protection
        previous_turnstile = [TurnstileVerifierStub.enabled, TurnstileVerifierStub.response]
        previous_challenge = [TurnstileVerifierStub.challenge_enabled, TurnstileVerifierStub.challenge_response]
        ActionController::Base.allow_forgery_protection = true
        TurnstileVerifierStub.enabled = true
        TurnstileVerifierStub.response = { "success" => true }
        TurnstileVerifierStub.challenge_enabled = true
        TurnstileVerifierStub.challenge_response = { "success" => true }
        base_host = ENV.fetch(base_host_key)
        auth_host = ENV.fetch(auth_host_key)
        browser = open_session
        browser.host!(base_host)
        browser.https!
        browser.get("/sign", params: { ri: "jp" })

        assert_equal 200, browser.response.status
        csrf = browser.response.parsed_body.at_css('input[name="authenticity_token"]')["value"]
        browser.post(
          "/sign", params: { ri: "jp", authenticity_token: csrf }, headers: {
            "Origin" => "https://#{base_host}", "Sec-Fetch-Site" => "same-origin",
          },
        )

        assert_equal 302, browser.response.status
        issuer = JitSecurityJwtRegistry.surface(issuer_name)
        2.times do |hop|
          rt = Rack::Utils.parse_query(URI.parse(browser.response.location).query).fetch("rt")
          payload, = JWT.decode(
            rt, JitSecurityJwtRegistry.public_key_for(issuer.id, issuer.current_kid), true,
            algorithms: ["ES384"], verify_iss: true, iss: "https://#{base_host}",
            verify_aud: true, aud: Rails.configuration.x.boot_config.fetch(:jump).audience,
          )
          target = URI.parse(payload.fetch("url"))

          assert_equal "https", target.scheme
          assert_equal(hop.zero? ? base_host : auth_host, target.host)
          browser.host!(target.host)
          browser.get(target.request_uri, params: { ri: "jp" })
          next if hop == 1

          form = browser.response.parsed_body.at_css("form#base-authorization-ceremony-start-form")
          fields = form.css("input[name]").to_h { |input| [input["name"], input["value"]] }
          browser.post(
            form["action"], params: fields, headers: {
              "Origin" => "https://#{base_host}", "Sec-Fetch-Site" => "same-origin",
            },
          )

          assert_equal 302, browser.response.status
        end
        3.times do |step|
          form = browser.response.parsed_body.at_css("form")

          assert_not_nil form, "Admission step #{step} must render an actual continuation form"
          fields = form.css("input[name]").to_h { |input| [input["name"], input["value"]] }
          browser.post(
            form["action"], params: fields, headers: {
              "Origin" => "https://#{browser.host}", "Sec-Fetch-Site" => "same-origin",
            },
          )

          assert_equal 303, browser.response.status
          next if step == 2

          target = URI.parse(browser.response.location)

          assert_equal "https", target.scheme
          assert_equal(step.zero? ? base_host : auth_host, target.host)
          browser.host!(target.host)
          browser.get(target.request_uri, params: { ri: "jp" })
        end
        browser.get("/sign/up/telephone/new", params: { ri: "jp" })

        assert_equal 200, browser.response.status
        csrf = browser.response.parsed_body.at_css('meta[name="csrf-token"]')["content"]
        headers = { "Origin" => "https://#{auth_host}", "Sec-Fetch-Site" => "same-origin", "X-CSRF-Token" => csrf }
        number = "+8190#{SecureRandom.random_number(100_000_000).to_s.rjust(8, "0")}"
        browser.post(
          "/sign/up/telephone", params: {
            scope => { raw_number: number, confirm_policy: "1" }, "cf-turnstile-response" => "test", :ri => "jp",
          }, headers: headers,
        )

        assert_equal 302, browser.response.status
        otp_uri = URI.parse(browser.response.location)
        signed_binding = Rack::Utils.parse_query(otp_uri.query).fetch("fb")
        decoded = SignFlowBindingCodec.decode(signed_binding)
        flow = flow_class.find_by!(public_id: decoded.flow_public_id)
        contact = contact_class.find(flow.pending_contact_id)
        owner_id = contact[owner_key]

        assert_equal flow_class::STATUS_MODEL::CONTACT_PENDING, flow.reload.status_id
        assert_nil contact.binding_finalized_at
        assert_equal 0, token_class.where(owner_key => owner_id).count
        before_requirements = flow.completed_requirements.deep_dup
        before_version = flow.checkpoint_version
        otp = contact.get_otp
        code = ROTP::HOTP.new(otp.fetch(:otp_private_key)).at(otp.fetch(:otp_counter)).to_s
        browser.get(otp_uri.request_uri, params: { ri: "jp" })

        assert_equal 200, browser.response.status
        csrf = browser.response.parsed_body.at_css('meta[name="csrf-token"]')["content"]
        headers["X-CSRF-Token"] = csrf
        ticket_writes = 0
        failure =
          lambda do |_name, _started, _finished, _identity, payload|
            if payload[:name] == "#{flow_class} Update" && contact.reload.sign_up_otp_context.fetch("verified_at")
              ticket_writes += 1
              if ticket_writes == index + 1
                raise ActiveRecord::StatementInvalid, "telephone signup OTP Ticket update unavailable"
              end
            end
          end

        ActiveSupport::Notifications.subscribed(failure, "sql.active_record") do
          assert_raises(ActiveRecord::StatementInvalid) do
            browser.patch(
              otp_uri.request_uri, params: {
                scope => { pass_code: code }, "cf-turnstile-response" => "test", :ri => "jp",
              }, headers: headers,
            )
          end
        end
        proof = contact.reload.sign_up_otp_context.deep_dup

        assert_equal index + 1, ticket_writes
        assert_not_nil proof.fetch("verified_at")
        assert_nil contact.get_otp
        assert_equal flow_class::STATUS_MODEL::CONTACT_PENDING, flow.reload.status_id
        assert before_requirements == flow.completed_requirements, "Failed progression must roll back all requirements"
        assert_equal before_version, flow.checkpoint_version
        assert_nil contact.binding_finalized_at
        assert_not contact.binding_effective?
        assert_not outbox.exists?(operation_ref: flow.public_id)
        assert_equal 0, token_class.where(owner_key => owner_id).count
        browser.patch(
          otp_uri.request_uri, params: {
            scope => { pass_code: code }, "cf-turnstile-response" => "test", :ri => "jp",
          }, headers: headers,
        )

        assert_equal 302, browser.response.status
        guard = URI.parse(browser.response.location)

        assert_equal "/sign/up/guard/telephone", guard.path
        assert SignFlowBindingCodec.decode(Rack::Utils.parse_query(guard.query).fetch("fb")) == decoded,
               "Retry must retain its original signed signup flow"
        assert_equal flow_class::STATUS_MODEL::CHECKPOINT_PENDING, flow.reload.status_id
        assert flow.requirement_cleared?(:otp), "Retry must clear the OTP checkpoint requirement"
        assert proof == contact.reload.sign_up_otp_context, "Retry must preserve the committed Source proof exactly"
        assert_nil contact.get_otp
        assert_equal owner_id, contact[owner_key]
        assert_nil contact.binding_finalized_at
        assert_not contact.binding_effective?
        assert_not outbox.exists?(operation_ref: flow.public_id)
        assert_equal 0, token_class.where(owner_key => owner_id).count
      ensure
        ActionController::Base.allow_forgery_protection = previous_protection
        TurnstileVerifierStub.enabled, TurnstileVerifierStub.response = previous_turnstile
        TurnstileVerifierStub.challenge_enabled, TurnstileVerifierStub.challenge_response = previous_challenge
      end
    end
  end
end
# rubocop:enable Minitest/AssertEqual, Minitest/AssertOperator, Minitest/MultipleAssertions
