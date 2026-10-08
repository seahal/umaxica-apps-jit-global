# frozen_string_literal: true

require "test_helper"

# Boolean comparisons prevent retained browser and proof material from appearing in failure output.
# Each journey keeps admission, signup, and exact proof replay in the same real browser context.
# rubocop:disable Minitest/AssertEqual, Minitest/AssertOperator, Minitest/AssertPredicate, Minitest/MultipleAssertions
class EmailSignupBaseRootCompletionTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    ClientSignUpFlowStatus::DEFAULTS.each { |id| ClientSignUpFlowStatus.find_or_create_by!(id: id) }
    VisitorSignUpFlowStatus::DEFAULTS.each { |id| VisitorSignUpFlowStatus.find_or_create_by!(id: id) }
    ClientSignUpFlowCleanupStatus::DEFAULTS.each { |id| ClientSignUpFlowCleanupStatus.find_or_create_by!(id: id) }
    VisitorSignUpFlowCleanupStatus::DEFAULTS.each { |id| VisitorSignUpFlowCleanupStatus.find_or_create_by!(id: id) }
    VisitorSecretCredentialKind::DEFAULTS.each { |id| VisitorSecretCredentialKind.find_or_create_by!(id: id) }
    VisitorSecretCredentialStatus::DEFAULTS.each { |id| VisitorSecretCredentialStatus.find_or_create_by!(id: id) }
  end

  %w(app com).each do |surface|
    test "#{surface} email signup binds its original OIDC browser and Base commits exactly one root" do
      previous_protection = ActionController::Base.allow_forgery_protection
      previous_turnstile = [TurnstileVerifierStub.enabled, TurnstileVerifierStub.response]
      previous_challenge = [TurnstileVerifierStub.challenge_enabled, TurnstileVerifierStub.challenge_response]
      ActionController::Base.allow_forgery_protection = true
      TurnstileVerifierStub.enabled = true
      TurnstileVerifierStub.response = { "success" => true }
      TurnstileVerifierStub.challenge_enabled = true
      TurnstileVerifierStub.challenge_response = { "success" => true }
      base_host, auth_host, issuer_name, signup_model, contact_model, actor_model, token_model, owner_key,
        contact_parameter =
        case surface
        when "app"
          [ENV.fetch("PUBLIC_BASE_SERVICE_URL"), ENV.fetch("PUBLIC_AUTH_SERVICE_URL"),
           "BASE_APP", ClientSignUpFlow, ClientEmail, Client, ClientToken, :user_id, :client_email,]
        when "com"
          [ENV.fetch("PUBLIC_BASE_CORPORATE_URL"), ENV.fetch("PUBLIC_AUTH_CORPORATE_URL"),
           "BASE_COM", VisitorSignUpFlow, VisitorEmail, Visitor, VisitorToken, :visitor_id,
           :visitor_email,]
        end
      owner = open_session
      owner.host!(base_host)
      owner.https!
      base_headers = { "Origin" => "https://#{base_host}", "Sec-Fetch-Site" => nil }
      auth_headers = { "Origin" => "https://#{auth_host}", "Sec-Fetch-Site" => nil }
      owner.get("/sign", params: { ri: "jp" })

      assert_equal 200, owner.response.status
      csrf = owner.response.parsed_body.at_css('input[name="authenticity_token"]')["value"]
      owner.post(
        "/sign", params: { ri: "jp", authenticity_token: csrf }, headers: base_headers,
      )

      assert_equal 303, owner.response.status

      cookie_name = JitSessionCookieConfig.cookie_key(force_secure: JitSessionCookieConfig.force_secure?)
      issuer = JitSecurityJwtRegistry.surface(issuer_name)
      parameters = nil
      entry_reference = nil
      2.times do |index|
        rt = Rack::Utils.parse_query(URI.parse(owner.response.location).query).fetch("rt")
        payload, = JWT.decode(
          rt, JitSecurityJwtRegistry.public_key_for(issuer.id, issuer.current_kid), true,
          algorithms: ["ES384"], verify_iss: true, iss: "https://#{base_host}",
          verify_aud: true, aud: Rails.configuration.x.boot_config.fetch(:jump).audience,
        )
        target = URI.parse(payload.fetch("url"))

        assert_equal "https", target.scheme
        assert_equal(index.zero? ? base_host : auth_host, target.host)
        owner.host!(target.host)
        owner.get(target.request_uri, params: { ri: "jp" })
        if index == 1
          entry_reference = Rack::Utils.parse_query(target.query).fetch("entry_ref")
          next
        end

        form = owner.response.parsed_body.at_css("form#base-authorization-ceremony-start-form")
        fields = form.css("input[name]").to_h { |input| [input["name"], input["value"]] }
        parameters = fields.except("authenticity_token", "ceremony_action")
        owner.post(form["action"], params: fields, headers: base_headers)

        assert_equal 303, owner.response.status
      end
      binding = BaseAuthAdmissionCoordinator.find_admission_binding!(surface:, reference: entry_reference)
      parent = binding.authorization_transaction
      original_parent_id = parent.id
      original_binding_id = binding.id
      3.times do |index|
        form = owner.response.parsed_body.at_css("form")

        assert_not_nil form, "Admission step #{index} must render a real continuation form"
        assert_nil binding.reload.base_confirmed_at if index == 1
        fields = form.css("input[name]").to_h { |input| [input["name"], input["value"]] }
        owner.post(
          form["action"], params: fields, headers: {
            "Origin" => "https://#{owner.host}", "Sec-Fetch-Site" => nil,
          },
        )

        assert_equal 303, owner.response.status
        assert binding.reload.base_confirmed_at.present? if index == 1
        next if index == 2

        target = URI.parse(owner.response.location)

        assert_equal "https", target.scheme
        assert_equal(index.zero? ? base_host : auth_host, target.host)
        owner.host!(target.host)
        owner.get(target.request_uri, params: { ri: "jp" })
      end
      auth = owner

      assert_equal 303, auth.response.status
      assert binding.reload.redeemed?
      ceremony = binding.class.auth_admission_session_class.find(binding.admitted_auth_ceremony_session_id)

      assert ceremony.authorization_transaction_ref == parent.transaction_id,
             "Auth must retain the original OIDC parent"

      auth.get("/sign/up/email/new", params: { ri: "jp" })

      assert_equal 200, auth.response.status
      csrf = auth.response.parsed_body.at_css('meta[name="csrf-token"]')["content"]
      auth.post(
        "/sign/up/email", params: {
          contact_parameter => { raw_address: "signup-root-#{surface}-#{SecureRandom.hex(8)}@example.com",
                                 confirm_policy: "1", },
          :authenticity_token => csrf,
          "cf-turnstile-response" => "test",
          :ri => "jp",
        }, headers: auth_headers,
      )

      assert_equal 302, auth.response.status
      otp_uri = URI.parse(auth.response.location)
      locator = Rack::Utils.parse_query(otp_uri.query).fetch("fb")
      decoded = SignFlowBindingCodec.decode(locator)
      signup = signup_model.find_by!(public_id: decoded.flow_public_id)
      contact = contact_model.find(signup.pending_contact_id)
      actor = actor_model.find(contact[owner_key])

      assert_equal 0, token_model.where(owner_key => actor.id).count
      transaction_model = (surface == "app") ? ClientEmailCeremonyTransaction : VisitorEmailCeremonyTransaction
      transaction = transaction_model.find_by!(email_candidate_ref: contact.public_id)
      delivery =
        (enqueued_jobs + performed_jobs).reverse.find do |entry|
          next false unless entry.fetch(:job) == OtpNotifierEmailDeliveryJob

          notification = ActiveJob::Arguments.deserialize(entry.fetch(:args)).last
          notification.fetch(:params).fetch(:sign_up_email_transaction_ref) == transaction.transaction_id
        end
      notification = ActiveJob::Arguments.deserialize(delivery.fetch(:args)).last
      delivery_params = notification.fetch(:params)
      code = OutboundSensitivePayload.decrypt_email_otp(delivery_params.fetch(:encrypted_hotp_token))

      assert delivery_params.fetch(:sign_up_flow_ref) == signup.public_id, "Delivery must name the original signup"
      assert delivery_params.fetch(:sign_up_email_otp_generation) == transaction.otp_generation,
             "Delivery must name the current typed ceremony generation"
      queued_contains_code = JSON.generate(delivery.fetch(:args)).include?(code)

      assert_not queued_contains_code, "Queued delivery must not contain plaintext code"
      auth.get(otp_uri.request_uri)

      assert_equal 200, auth.response.status
      csrf = auth.response.parsed_body.at_css('meta[name="csrf-token"]')["content"]
      auth.patch(
        otp_uri.request_uri, params: {
          :user_email => { pass_code: code }, :authenticity_token => csrf, "cf-turnstile-response" => "test",
        }, headers: auth_headers,
      )

      assert_equal 302, auth.response.status
      assert transaction.reload.otp_consumed_at.present?, "The actual browser must consume its typed Email proof"
      active_verifier_cleared = transaction.otp_verifier.nil?

      assert active_verifier_cleared, "Fresh consumption must remove the active verifier"
      birthdate_uri = URI.parse(auth.response.location)

      assert SignFlowBindingCodec.decode(Rack::Utils.parse_query(birthdate_uri.query).fetch("fb")) == decoded,
             "The checkpoint must retain the original signed signup binding"
      auth.get(birthdate_uri.request_uri)

      assert_equal 200, auth.response.status
      csrf = auth.response.parsed_body.at_css('meta[name="csrf-token"]')["content"]
      if surface == "com"
        session_flow_ref = auth.request.session[:auth_com_up_sequence_id]

        assert session_flow_ref == decoded.flow_public_id, "The browser session must retain the signed signup Parent"
        stored_signup = signup_model.find_by(public_id: session_flow_ref)

        assert stored_signup.present?, "The original signed signup Parent must still exist"
        assert Visitor.exists?(id: stored_signup.principal_id), "The signup principal Visitor must exist"
        assert Visitor.exists?(id: contact.reload.visitor_id), "The Contact owner Visitor must exist"
        assert stored_signup.principal_id == contact.visitor_id,
               "The original signup principal must match the Contact owner"
        assert stored_signup.principal_id == actor.id, "The birthdate checkpoint must retain the original Visitor"
        assert binding.reload.authorization_transaction.id == original_parent_id,
               "Admission must retain the original OIDC Parent"
      end
      auth.patch(
        birthdate_uri.request_uri, params: {
          requirement: "birthdate",
          birthdate: "2000-01-01",
          checkpoint_version: signup.reload.checkpoint_version,
          authenticity_token: csrf,
        }, headers: auth_headers,
      )

      assert_equal 302, auth.response.status
      assert signup.reload.sign_up_completed?
      assert contact.reload.binding_effective?
      assert_equal 0, token_model.where(owner_key => actor.id).count
      auth.get(URI.parse(auth.response.location).request_uri)

      assert_equal 302, auth.response.status
      handoff_uri = URI.parse(auth.response.location)

      assert_equal "/sign/oidc/handoff", handoff_uri.path
      auth.get(handoff_uri.request_uri)

      assert_equal 200, auth.response.status
      form = auth.response.parsed_body.at_css("form")
      csrf = form.at_css('input[name="authenticity_token"]')["value"]
      auth.post(form["action"], params: { authenticity_token: csrf }, headers: auth_headers)

      assert_equal 303, auth.response.status
      completion = URI.parse(auth.response.location)

      assert_equal "https", completion.scheme
      assert_equal base_host, completion.host
      assert_equal "/oauth/authorize", completion.path
      submission = Rack::Utils.parse_query(completion.query)

      assert submission.fetch("transaction_ref") == parent.transaction_id, "Result must name the original OIDC parent"
      assert parent.reload.actor_ref == actor.public_id, "Result must bind the original Contact owner"
      assert_equal "email_otp", parent.auth_method
      assert_nil parent.base_finalized_at
      assert_equal 0, token_model.where(owner_key => actor.id).count
      before_parent = parent.reload.attributes
      before_contact = contact.reload.attributes

      owner.host!(base_host)
      owner.post("/oauth/authorize", params: submission, headers: base_headers)

      assert_equal 422, owner.response.status
      assert before_parent == parent.reload.attributes, "CSRF refusal must preserve the OIDC parent"
      assert_equal 0, token_model.where(owner_key => actor.id).count
      foreign = open_session
      foreign.host!(base_host)
      foreign.https!
      foreign.get("/oauth/authorize", params: parameters)

      assert_equal 200, foreign.response.status
      csrf = foreign.response.parsed_body.at_css('input[name="authenticity_token"]')["value"]
      foreign.get(completion.request_uri)

      assert_equal 400, foreign.response.status
      foreign.post("/oauth/authorize", params: submission.merge(authenticity_token: csrf), headers: base_headers)

      assert_equal 400, foreign.response.status
      assert before_parent == parent.reload.attributes, "Another browser must not consume the original owner's proof"
      assert before_contact == contact.reload.attributes, "Refusals must preserve the finalized Contact"
      assert_equal 0, token_model.where(owner_key => actor.id).count

      root_reference = nil
      2.times do |attempt|
        owner.get(completion.request_uri)

        assert_equal 200, owner.response.status
        csrf = owner.response.parsed_body.at_css('input[name="authenticity_token"]')["value"]
        owner.post("/oauth/authorize", params: submission.merge(authenticity_token: csrf), headers: base_headers)

        assert_equal 303, owner.response.status
        assert parent.reload.base_finalized_at.present?
        root_reference ||= parent.browser_session_ref

        assert root_reference == parent.browser_session_ref, "Proof replay must retain the first root"
        assert_equal 1, token_model.where(owner_key => actor.id).count
        root = token_model.find_by!(public_id: root_reference)

        assert_equal actor.id, root[owner_key]
        assert_equal original_parent_id, parent.id
        assert_equal original_binding_id, binding.reload.id
        assert_equal original_parent_id, binding.authorization_transaction_id
        assert before_contact == contact.reload.attributes, "Base completion must preserve the original binding facts"
        next unless attempt.zero?

        cookie_value = owner.response.cookies[cookie_name]
        if cookie_value.nil?
          raw = owner.response.headers["Set-Cookie"] || owner.response.headers["set-cookie"]
          lines = (raw.is_a?(String) && raw.start_with?("[")) ? JSON.parse(raw) : Array(raw)
          line =
            lines.flat_map { |entry| entry.to_s.split("\n") }.find do |entry|
              entry.split(";", 2).first.to_s.start_with?("#{cookie_name}=")
            end

          assert line.present?, "Successful completion must emit the rotated Base browser session"
          cookie_value = Rack::Utils.unescape(line.split(";", 2).first.split("=", 2).last)
        end
        owner.cookies.delete(cookie_name)
        _received_cookie = owner.cookies.merge(
          "#{cookie_name}=#{Rack::Utils.escape(cookie_value)}", URI.parse("https://#{base_host}/"),
        )
      end
    ensure
      ActionController::Base.allow_forgery_protection = previous_protection
      TurnstileVerifierStub.enabled, TurnstileVerifierStub.response = previous_turnstile
      TurnstileVerifierStub.challenge_enabled, TurnstileVerifierStub.challenge_response = previous_challenge
    end
  end
end
# rubocop:enable Minitest/AssertEqual, Minitest/AssertOperator, Minitest/AssertPredicate, Minitest/MultipleAssertions
