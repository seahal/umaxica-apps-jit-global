# frozen_string_literal: true

require "test_helper"

class TelephoneSignupHttpDeliveryTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    ClientSignUpFlowStatus::DEFAULTS.each { |id| ClientSignUpFlowStatus.find_or_create_by!(id: id) }
    VisitorSignUpFlowStatus::DEFAULTS.each { |id| VisitorSignUpFlowStatus.find_or_create_by!(id: id) }
    ClientSignUpFlowCleanupStatus::DEFAULTS.each { |id| ClientSignUpFlowCleanupStatus.find_or_create_by!(id: id) }
    VisitorSignUpFlowCleanupStatus::DEFAULTS.each { |id| VisitorSignUpFlowCleanupStatus.find_or_create_by!(id: id) }
  end

  [
    [:app, "PUBLIC_BASE_SERVICE_URL", "PUBLIC_AUTH_SERVICE_URL", "BASE_APP", ClientSignUpFlow,
     ClientTelephone, ClientToken, :client_telephone, :user_id,],
    [:com, "PUBLIC_BASE_CORPORATE_URL", "PUBLIC_AUTH_CORPORATE_URL", "BASE_COM", VisitorSignUpFlow,
     VisitorTelephone, VisitorToken, :visitor_telephone, :visitor_id,],
  ].each do |surface, base_key, auth_key, issuer_name, flow_class, contact_class, token_class, scope, owner_key|
    %w(current cancelled expired reissued).each do |state|
      test "#{surface} actual Telephone signup queues encrypted code and refuses #{state} stale transport" do
        previous_protection = ActionController::Base.allow_forgery_protection
        previous_turnstile = [TurnstileVerifierStub.enabled, TurnstileVerifierStub.response]
        previous_challenge = [TurnstileVerifierStub.challenge_enabled, TurnstileVerifierStub.challenge_response]
        ActionController::Base.allow_forgery_protection = true
        TurnstileVerifierStub.enabled = true
        TurnstileVerifierStub.response = { "success" => true }
        TurnstileVerifierStub.challenge_enabled = true
        TurnstileVerifierStub.challenge_response = { "success" => true }
        base_host = ENV.fetch(base_key)
        auth_host = ENV.fetch(auth_key)
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

        assert_equal 303, browser.response.status
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

          assert_equal 303, browser.response.status
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
        clear_enqueued_jobs
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
        transaction_model = (surface == :app) ? ClientTelephoneCeremonyTransaction : VisitorTelephoneCeremonyTransaction
        transaction = transaction_model.find_by!(telephone_candidate_ref: contact.public_id)

        assert_instance_of transaction_model, transaction
        assert_predicate transaction.otp_verifier, :present?
        assert_nil transaction.otp_consumed_at
        job_arguments = enqueued_jobs.find { |job| job.fetch(:job) == Outbound::SmsDeliveryJob }.fetch(:args)
        encrypted = job_arguments.fetch(0).fetch("encrypted_payload")
        payload = OutboundSensitivePayload.decrypt_sms_delivery(encrypted)
        code = payload.fetch(:otp_code)

        assert_not JSON.generate(job_arguments).include?(code)
        assert_not JSON.generate(job_arguments).include?(contact.number)
        assert_equal [surface.to_s, "sign_up", flow.public_id, transaction.transaction_id,
                      transaction.otp_generation,], payload.fetch(:otp_binding)

        original_generation = transaction.otp_generation
        if state == "cancelled"
          browser.delete(otp_uri.request_uri, headers: headers)

          assert_equal 303, browser.response.status
          assert_predicate flow.reload, :sign_up_terminal?
        end
        if state == "reissued"
          contact_class.stub(:database_now, contact.otp_last_sent_at + TelephoneOtpPolicy::SEND_COOLDOWN) do
            browser.post(otp_uri.request_uri, headers: headers)
          end

          assert_equal 302, browser.response.status
          assert_not_equal original_generation, transaction.reload.otp_generation
        end
        sent = []
        at = (state == "expired") ? transaction.otp_expires_at : transaction_model.database_now
        if state == "current"
          assert transaction.telephone_otp_deliverable?(generation: original_generation, at: at)
          assert TelephoneSignUpOtpDeliveryGuard.call(
            flow: flow, telephone: contact, transaction: transaction, generation: original_generation,
            destination: payload.fetch(:to), code: code,
          ) { true }
        end
        transaction_model.stub(:database_now, at) do
          OutboundSms.stub(:deliver_now, ->(**message) { sent << message }) do
            Outbound::SmsDeliveryJob.perform_now(encrypted_payload: encrypted)
          end
        end

        assert_equal (state == "current") ? 1 : 0, sent.length
        assert_nil transaction.reload.otp_consumed_at, "Delivery cannot consume the ceremony proof"
        assert_equal 0, contact.reload.otp_attempts_count
        assert_equal 0, token_class.where(owner_key => owner_id).count
      ensure
        ActionController::Base.allow_forgery_protection = previous_protection
        TurnstileVerifierStub.enabled, TurnstileVerifierStub.response = previous_turnstile
        TurnstileVerifierStub.challenge_enabled, TurnstileVerifierStub.challenge_response = previous_challenge
      end
    end
  end
end
