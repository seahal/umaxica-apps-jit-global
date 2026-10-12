# typed: false
# frozen_string_literal: true

require "test_helper"

class Auth::Com::Sign::Up::Check::Email::BirthdatesControllerTest < ActionDispatch::IntegrationTest
  # Rate-limit counters are a NullStore by default in test so unrelated tests
  # cannot accumulate them; this file asserts real limiting behavior, so it
  # opts into a deterministic MemoryStore.
  rate_limit_counters!

  include ActiveJob::TestHelper
  include ActiveSupport::Testing::TimeHelpers

  setup do
    VisitorSignInFlowState::DEFAULTS.each { |id| VisitorSignInFlowState.find_or_create_by!(id: id) }
    VisitorSignUpFlowStatus::DEFAULTS.each { |id| VisitorSignUpFlowStatus.find_or_create_by!(id: id) }
    VisitorSignUpFlowCleanupStatus::DEFAULTS.each { |id| VisitorSignUpFlowCleanupStatus.find_or_create_by!(id: id) }
    VisitorSecretCredentialKind::DEFAULTS.each { |id| VisitorSecretCredentialKind.find_or_create_by!(id: id) }
    VisitorSecretCredentialStatus::DEFAULTS.each { |id| VisitorSecretCredentialStatus.find_or_create_by!(id: id) }
    @host = ENV.fetch("PUBLIC_AUTH_CORPORATE_URL")
    @previous_forgery_protection = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    Rails.configuration.x.rate_limit.fetch(:store).clear
    TurnstileVerifierStub.challenge_enabled = true
    TurnstileVerifierStub.challenge_response = { "success" => true }
    browser = self
    base_host = ENV.fetch("PUBLIC_BASE_CORPORATE_URL")
    auth_host = @host
    browser.host!(base_host)
    browser.https!
    browser.get("/sign", params: { ri: "jp" })
    csrf = browser.response.parsed_body.at_css('input[name="authenticity_token"]')["value"]
    browser.post(
      "/sign", params: { ri: "jp", authenticity_token: csrf }, headers: {
        "Origin" => "https://#{base_host}", "Sec-Fetch-Site" => "same-origin",
      },
    )
    issuer = JitSecurityJwtRegistry.surface("BASE_COM")
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
    @headers = { "Origin" => "https://#{auth_host}", "Sec-Fetch-Site" => "same-origin", "X-CSRF-Token" => csrf }
  end

  teardown do
    ActionController::Base.allow_forgery_protection = @previous_forgery_protection
    TurnstileVerifierStub.challenge_enabled = false
    TurnstileVerifierStub.challenge_response = nil
    Rails.configuration.x.rate_limit.fetch(:store).clear
  end

  # Regression: com sign-up must reach finalization. The com finalizer and the
  # com recovery-passcode reveal URL are only exercised from here.
  test "clearing the birthdate completes the com sign-up" do
    clear_enqueued_jobs
    post auth_com_sign_up_email_url(ri: "jp"),
         params: { :visitor_email => { raw_address: "com-birthdate-finalize@example.com",
                                       confirm_policy: "1", },
                   "cf-turnstile-response" => "test", },
         headers: @headers

    assert_response :redirect
    @flow_binding = Rack::Utils.parse_query(URI.parse(response.location).query).fetch("fb")
    cycle = VisitorSignUpFlow.find_by!(public_id: session.fetch(:auth_com_up_sequence_id))
    email = VisitorEmail.find(cycle.pending_contact_id)
    job = enqueued_jobs.reverse.find { |entry| entry.fetch(:job) == OtpNotifierEmailDeliveryJob }

    assert_not_nil job
    notification = ActiveJob::Arguments.deserialize(job.fetch(:args)).last
    delivery = notification.fetch(:params).symbolize_keys
    transaction = VisitorEmailCeremonyTransaction.find_by!(
      transaction_id: delivery.fetch(:sign_up_email_transaction_ref),
    )
    otp_code = OutboundSensitivePayload.decrypt_email_otp(delivery.fetch(:encrypted_hotp_token))

    # Boolean assertions keep ceremony binding material out of failure output.
    assert_withheld("Delivery must address this flow's Email candidate") {
      notification.fetch(:recipient).public_id == email.public_id
    }
    assert_withheld { delivery.fetch(:sign_up_flow_ref) == cycle.public_id }
    assert_withheld { delivery.fetch(:sign_up_email_otp_generation) == transaction.otp_generation }
    assert_withheld { transaction.email_candidate_ref == email.public_id }
    assert_withheld { transaction.purpose == "sign_up" }
    assert_withheld { transaction.operation == "sign_up" }
    assert_withheld { transaction.actor_ref == email.visitor.public_id }
    assert_withheld {
      transaction.session_ref ==
        Digest::SHA256.hexdigest(JSON.generate(["email_sign_up", cycle.public_id, cycle.nonce_digest]))
    }
    assert_not job.fetch(:args).to_s.include?(otp_code), "Queued delivery must not contain plaintext code"
    patch auth_com_sign_up_check_email_otp_url(ri: "jp", fb: @flow_binding),
          params: { :visitor_email => { pass_code: otp_code }, "cf-turnstile-response" => "test" },
          headers: @headers

    assert_response :redirect
    @flow_binding = Rack::Utils.parse_query(URI.parse(response.location).query).fetch("fb")
    assert_redirected_to auth_com_sign_up_check_email_birthdate_url(ri: "jp", fb: @flow_binding)
    assert_not_nil transaction.reload.otp_consumed_at
    assert_nil transaction.otp_verifier
    assert_not_nil transaction.otp_receipt_verifier
    flow = cycle.reload

    assert_equal email.visitor_id, flow.principal_id
    assert_equal email.id, flow.pending_contact_id
    assert Visitor.exists?(id: flow.principal_id), "Birthdate requires the same realm-local owner"

    assert_equal VisitorSignUpFlowStatus::CHECKPOINT_PENDING, flow.status_id
    assert_predicate flow.principal_id, :present?

    patch auth_com_sign_up_check_email_birthdate_url(ri: "jp", fb: @flow_binding),
          params: {
            requirement: "birthdate",
            checkpoint_version: flow.checkpoint_version,
            birthdate_year: "1990",
            birthdate_month: "01",
            birthdate_day: "15",
          },
          headers: @headers

    assert_response :redirect
    assert_equal VisitorSignUpFlowStatus::COMPLETED, flow.reload.status_id
    assert flow.requirement_cleared?(:birthdate)
  end

  test "an underage birthdate terminalizes the com sign-up" do
    instant = Time.zone.local(2026, 6, 25, 12, 0, 0)
    VisitorSignUpFlow.stub(:database_now, instant) do
      VisitorEmailCeremonyTransaction.stub(:database_now, instant) do
        VisitorEmail.stub(:database_now, instant) do
          Visitor.stub(:database_now, instant) do
            VisitorSignInFlow.stub(:database_now, instant) do
              travel_to instant do
                clear_enqueued_jobs
                post auth_com_sign_up_email_url(ri: "jp"),
                     params: { :visitor_email => { raw_address: "com-birthdate-underage@example.com",
                                                   confirm_policy: "1", },
                               "cf-turnstile-response" => "test", },
                     headers: @headers

                assert_response :redirect
                @flow_binding = Rack::Utils.parse_query(URI.parse(response.location).query).fetch("fb")
                cycle = VisitorSignUpFlow.find_by!(public_id: session.fetch(:auth_com_up_sequence_id))
                email = VisitorEmail.find(cycle.pending_contact_id)
                job = enqueued_jobs.reverse.find { |entry| entry.fetch(:job) == OtpNotifierEmailDeliveryJob }

                assert_not_nil job
                notification = ActiveJob::Arguments.deserialize(job.fetch(:args)).last
                delivery = notification.fetch(:params).symbolize_keys
                transaction = VisitorEmailCeremonyTransaction.find_by!(
                  transaction_id: delivery.fetch(:sign_up_email_transaction_ref),
                )
                otp_code = OutboundSensitivePayload.decrypt_email_otp(delivery.fetch(:encrypted_hotp_token))

                # Boolean assertions keep ceremony binding material out of failure output.
                assert_withheld("Delivery must address this flow's Email candidate") {
                  notification.fetch(:recipient).public_id == email.public_id
                }
                assert_withheld { delivery.fetch(:sign_up_flow_ref) == cycle.public_id }
                assert_withheld { delivery.fetch(:sign_up_email_otp_generation) == transaction.otp_generation }
                assert_withheld { transaction.email_candidate_ref == email.public_id }
                assert_withheld { transaction.purpose == "sign_up" }
                assert_withheld { transaction.operation == "sign_up" }
                assert_withheld { transaction.actor_ref == email.visitor.public_id }
                assert_withheld {
                  transaction.session_ref ==
                    Digest::SHA256.hexdigest(JSON.generate(["email_sign_up", cycle.public_id, cycle.nonce_digest]))
                }
                assert_not job.fetch(:args).to_s.include?(otp_code),
                           "Queued delivery must not contain plaintext code"
                patch auth_com_sign_up_check_email_otp_url(ri: "jp", fb: @flow_binding),
                      params: { :visitor_email => { pass_code: otp_code }, "cf-turnstile-response" => "test" },
                      headers: @headers

                assert_response :redirect
                @flow_binding = Rack::Utils.parse_query(URI.parse(response.location).query).fetch("fb")
                assert_redirected_to auth_com_sign_up_check_email_birthdate_url(ri: "jp", fb: @flow_binding)
                assert_not_nil transaction.reload.otp_consumed_at
                assert_nil transaction.otp_verifier
                assert_not_nil transaction.otp_receipt_verifier
                flow = cycle.reload

                assert_equal email.visitor_id, flow.principal_id
                assert_equal email.id, flow.pending_contact_id
                assert Visitor.exists?(id: flow.principal_id), "Birthdate requires the same realm-local owner"

                patch auth_com_sign_up_check_email_birthdate_url(ri: "jp", fb: @flow_binding),
                      params: {
                        requirement: "birthdate",
                        checkpoint_version: flow.checkpoint_version,
                        birthdate: "2024-06-26",
                      },
                      headers: @headers

                assert_response :success
                assert_includes response.body, I18n.t("sign.com.registration.checkpoint.age_restricted")
                assert_equal VisitorSignUpFlowStatus::HALTED, flow.reload.status_id
                assert_not flow.requirement_cleared?(:birthdate)
              end
            end
          end
        end
      end
    end
  end

  test "COM birthdate one day before the thirteenth birthday follows its own age boundary" do
    instant = Time.zone.local(2026, 6, 25, 12, 0, 0)
    VisitorSignUpFlow.stub(:database_now, instant) do
      VisitorEmailCeremonyTransaction.stub(:database_now, instant) do
        VisitorEmail.stub(:database_now, instant) do
          Visitor.stub(:database_now, instant) do
            VisitorSignInFlow.stub(:database_now, instant) do
              travel_to instant do
                clear_enqueued_jobs
                post auth_com_sign_up_email_url(ri: "jp"),
                     params: { :visitor_email => { raw_address: "com-birthdate-2013-06-26@example.com",
                                                   confirm_policy: "1", },
                               "cf-turnstile-response" => "test", },
                     headers: @headers

                assert_response :redirect
                @flow_binding = Rack::Utils.parse_query(URI.parse(response.location).query).fetch("fb")
                cycle = VisitorSignUpFlow.find_by!(public_id: session.fetch(:auth_com_up_sequence_id))
                email = VisitorEmail.find(cycle.pending_contact_id)
                job = enqueued_jobs.reverse.find { |entry| entry.fetch(:job) == OtpNotifierEmailDeliveryJob }

                assert_not_nil job
                notification = ActiveJob::Arguments.deserialize(job.fetch(:args)).last
                delivery = notification.fetch(:params).symbolize_keys
                transaction = VisitorEmailCeremonyTransaction.find_by!(
                  transaction_id: delivery.fetch(:sign_up_email_transaction_ref),
                )
                otp_code = OutboundSensitivePayload.decrypt_email_otp(delivery.fetch(:encrypted_hotp_token))

                # Boolean assertions keep ceremony binding material out of failure output.
                assert_withheld("Delivery must address this flow's Email candidate") {
                  notification.fetch(:recipient).public_id == email.public_id
                }
                assert_withheld { delivery.fetch(:sign_up_flow_ref) == cycle.public_id }
                assert_withheld { delivery.fetch(:sign_up_email_otp_generation) == transaction.otp_generation }
                assert_withheld { transaction.email_candidate_ref == email.public_id }
                assert_withheld { transaction.purpose == "sign_up" }
                assert_withheld { transaction.operation == "sign_up" }
                assert_withheld { transaction.actor_ref == email.visitor.public_id }
                assert_withheld {
                  transaction.session_ref ==
                    Digest::SHA256.hexdigest(JSON.generate(["email_sign_up", cycle.public_id, cycle.nonce_digest]))
                }
                assert_not job.fetch(:args).to_s.include?(otp_code),
                           "Queued delivery must not contain plaintext code"
                patch auth_com_sign_up_check_email_otp_url(ri: "jp", fb: @flow_binding),
                      params: { :visitor_email => { pass_code: otp_code }, "cf-turnstile-response" => "test" },
                      headers: @headers

                assert_response :redirect
                @flow_binding = Rack::Utils.parse_query(URI.parse(response.location).query).fetch("fb")
                assert_redirected_to auth_com_sign_up_check_email_birthdate_url(ri: "jp", fb: @flow_binding)
                assert_not_nil transaction.reload.otp_consumed_at
                assert_nil transaction.otp_verifier
                assert_not_nil transaction.otp_receipt_verifier
                flow = cycle.reload

                assert_equal email.visitor_id, flow.principal_id
                assert_equal email.id, flow.pending_contact_id
                assert Visitor.exists?(id: flow.principal_id), "Birthdate requires the same realm-local owner"

                patch auth_com_sign_up_check_email_birthdate_url(ri: "jp", fb: @flow_binding),
                      params: {
                        requirement: "birthdate",
                        checkpoint_version: flow.checkpoint_version,
                        birthdate: "2013-06-26",
                      },
                      headers: @headers

                assert_response :success
                assert_includes response.body, I18n.t("sign.com.registration.checkpoint.age_restricted")
                assert_equal VisitorSignUpFlowStatus::HALTED, flow.reload.status_id
                assert_not flow.requirement_cleared?(:birthdate)
              end
            end
          end
        end
      end
    end
  end

  test "COM birthdate on the thirteenth birthday follows its own age boundary" do
    instant = Time.zone.local(2026, 6, 25, 12, 0, 0)
    VisitorSignUpFlow.stub(:database_now, instant) do
      VisitorEmailCeremonyTransaction.stub(:database_now, instant) do
        VisitorEmail.stub(:database_now, instant) do
          Visitor.stub(:database_now, instant) do
            VisitorSignInFlow.stub(:database_now, instant) do
              travel_to instant do
                clear_enqueued_jobs
                post auth_com_sign_up_email_url(ri: "jp"),
                     params: { :visitor_email => { raw_address: "com-birthdate-2013-06-25@example.com",
                                                   confirm_policy: "1", },
                               "cf-turnstile-response" => "test", },
                     headers: @headers

                assert_response :redirect
                @flow_binding = Rack::Utils.parse_query(URI.parse(response.location).query).fetch("fb")
                cycle = VisitorSignUpFlow.find_by!(public_id: session.fetch(:auth_com_up_sequence_id))
                email = VisitorEmail.find(cycle.pending_contact_id)
                job = enqueued_jobs.reverse.find { |entry| entry.fetch(:job) == OtpNotifierEmailDeliveryJob }

                assert_not_nil job
                notification = ActiveJob::Arguments.deserialize(job.fetch(:args)).last
                delivery = notification.fetch(:params).symbolize_keys
                transaction = VisitorEmailCeremonyTransaction.find_by!(
                  transaction_id: delivery.fetch(:sign_up_email_transaction_ref),
                )
                otp_code = OutboundSensitivePayload.decrypt_email_otp(delivery.fetch(:encrypted_hotp_token))

                # Boolean assertions keep ceremony binding material out of failure output.
                assert_withheld("Delivery must address this flow's Email candidate") {
                  notification.fetch(:recipient).public_id == email.public_id
                }
                assert_withheld { delivery.fetch(:sign_up_flow_ref) == cycle.public_id }
                assert_withheld { delivery.fetch(:sign_up_email_otp_generation) == transaction.otp_generation }
                assert_withheld { transaction.email_candidate_ref == email.public_id }
                assert_withheld { transaction.purpose == "sign_up" }
                assert_withheld { transaction.operation == "sign_up" }
                assert_withheld { transaction.actor_ref == email.visitor.public_id }
                assert_withheld {
                  transaction.session_ref ==
                    Digest::SHA256.hexdigest(JSON.generate(["email_sign_up", cycle.public_id, cycle.nonce_digest]))
                }
                assert_not job.fetch(:args).to_s.include?(otp_code),
                           "Queued delivery must not contain plaintext code"
                patch auth_com_sign_up_check_email_otp_url(ri: "jp", fb: @flow_binding),
                      params: { :visitor_email => { pass_code: otp_code }, "cf-turnstile-response" => "test" },
                      headers: @headers

                assert_response :redirect
                @flow_binding = Rack::Utils.parse_query(URI.parse(response.location).query).fetch("fb")
                assert_redirected_to auth_com_sign_up_check_email_birthdate_url(ri: "jp", fb: @flow_binding)
                assert_not_nil transaction.reload.otp_consumed_at
                assert_nil transaction.otp_verifier
                assert_not_nil transaction.otp_receipt_verifier
                flow = cycle.reload

                assert_equal email.visitor_id, flow.principal_id
                assert_equal email.id, flow.pending_contact_id
                assert Visitor.exists?(id: flow.principal_id), "Birthdate requires the same realm-local owner"

                patch auth_com_sign_up_check_email_birthdate_url(ri: "jp", fb: @flow_binding),
                      params: {
                        requirement: "birthdate",
                        checkpoint_version: flow.checkpoint_version,
                        birthdate: "2013-06-25",
                      },
                      headers: @headers

                assert_response :redirect
                assert_equal VisitorSignUpFlowStatus::COMPLETED, flow.reload.status_id
                assert flow.requirement_cleared?(:birthdate)
              end
            end
          end
        end
      end
    end
  end

  test "COM birthdate one day after the thirteenth birthday follows its own age boundary" do
    instant = Time.zone.local(2026, 6, 25, 12, 0, 0)
    VisitorSignUpFlow.stub(:database_now, instant) do
      VisitorEmailCeremonyTransaction.stub(:database_now, instant) do
        VisitorEmail.stub(:database_now, instant) do
          Visitor.stub(:database_now, instant) do
            VisitorSignInFlow.stub(:database_now, instant) do
              travel_to instant do
                clear_enqueued_jobs
                post auth_com_sign_up_email_url(ri: "jp"),
                     params: { :visitor_email => { raw_address: "com-birthdate-2013-06-24@example.com",
                                                   confirm_policy: "1", },
                               "cf-turnstile-response" => "test", },
                     headers: @headers

                assert_response :redirect
                @flow_binding = Rack::Utils.parse_query(URI.parse(response.location).query).fetch("fb")
                cycle = VisitorSignUpFlow.find_by!(public_id: session.fetch(:auth_com_up_sequence_id))
                email = VisitorEmail.find(cycle.pending_contact_id)
                job = enqueued_jobs.reverse.find { |entry| entry.fetch(:job) == OtpNotifierEmailDeliveryJob }

                assert_not_nil job
                notification = ActiveJob::Arguments.deserialize(job.fetch(:args)).last
                delivery = notification.fetch(:params).symbolize_keys
                transaction = VisitorEmailCeremonyTransaction.find_by!(
                  transaction_id: delivery.fetch(:sign_up_email_transaction_ref),
                )
                otp_code = OutboundSensitivePayload.decrypt_email_otp(delivery.fetch(:encrypted_hotp_token))

                # Boolean assertions keep ceremony binding material out of failure output.
                assert_withheld("Delivery must address this flow's Email candidate") {
                  notification.fetch(:recipient).public_id == email.public_id
                }
                assert_withheld { delivery.fetch(:sign_up_flow_ref) == cycle.public_id }
                assert_withheld { delivery.fetch(:sign_up_email_otp_generation) == transaction.otp_generation }
                assert_withheld { transaction.email_candidate_ref == email.public_id }
                assert_withheld { transaction.purpose == "sign_up" }
                assert_withheld { transaction.operation == "sign_up" }
                assert_withheld { transaction.actor_ref == email.visitor.public_id }
                assert_withheld {
                  transaction.session_ref ==
                    Digest::SHA256.hexdigest(JSON.generate(["email_sign_up", cycle.public_id, cycle.nonce_digest]))
                }
                assert_not job.fetch(:args).to_s.include?(otp_code),
                           "Queued delivery must not contain plaintext code"
                patch auth_com_sign_up_check_email_otp_url(ri: "jp", fb: @flow_binding),
                      params: { :visitor_email => { pass_code: otp_code }, "cf-turnstile-response" => "test" },
                      headers: @headers

                assert_response :redirect
                @flow_binding = Rack::Utils.parse_query(URI.parse(response.location).query).fetch("fb")
                assert_redirected_to auth_com_sign_up_check_email_birthdate_url(ri: "jp", fb: @flow_binding)
                assert_not_nil transaction.reload.otp_consumed_at
                assert_nil transaction.otp_verifier
                assert_not_nil transaction.otp_receipt_verifier
                flow = cycle.reload

                assert_equal email.visitor_id, flow.principal_id
                assert_equal email.id, flow.pending_contact_id
                assert Visitor.exists?(id: flow.principal_id), "Birthdate requires the same realm-local owner"

                patch auth_com_sign_up_check_email_birthdate_url(ri: "jp", fb: @flow_binding),
                      params: {
                        requirement: "birthdate",
                        checkpoint_version: flow.checkpoint_version,
                        birthdate: "2013-06-24",
                      },
                      headers: @headers

                assert_response :redirect
                assert_equal VisitorSignUpFlowStatus::COMPLETED, flow.reload.status_id
                assert flow.requirement_cleared?(:birthdate)
              end
            end
          end
        end
      end
    end
  end
end
