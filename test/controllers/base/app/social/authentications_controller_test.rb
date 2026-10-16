# typed: false
# frozen_string_literal: true

require "test_helper"

class Base::App::Social::AuthenticationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @previous_protection = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    @previous_cooldown = Rails.application.config.x.authentication.login_cooldown
    Rails.application.config.x.authentication.login_cooldown = 0.seconds
    OmniAuth.config.test_mode = true
    TurnstileVerifierStub.enabled = true
    TurnstileVerifierStub.challenge_enabled = true
    TurnstileVerifierStub.challenge_response = { "success" => true }
  end

  teardown do
    ActionController::Base.allow_forgery_protection = @previous_protection
    Rails.application.config.x.authentication.login_cooldown = @previous_cooldown
    OmniAuth.config.mock_auth[:google] = nil
    TurnstileVerifierStub.enabled = false
    TurnstileVerifierStub.challenge_enabled = false
    TurnstileVerifierStub.challenge_response = nil
  end

  test "completion provisions and completes the actual signup graph before Root issuance" do
    subject = "new-social-#{SecureRandom.hex(8)}"
    base = self
    auth = open_session
    base_host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    auth_host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    base_headers = { "Origin" => "https://#{base_host}", "Sec-Fetch-Site" => "same-origin" }
    auth_headers = { "Origin" => "https://#{auth_host}", "Sec-Fetch-Site" => "same-origin" }
    base.host!(base_host)
    base.https!
    base.get("/sign", params: { ri: "jp" })

    assert_equal 200, base.response.status
    entry_form = Nokogiri::HTML(base.response.body).at_css("form")
    entry_fields = entry_form.css("input[name]").to_h { |input| [input["name"], input["value"]] }
    base.post(entry_form["action"], params: entry_fields, headers: base_headers)

    assert_equal 303, base.response.status
    issuer = JitSecurityJwtRegistry.surface("BASE_APP")
    target = URI.parse(base.response.location)
    # A same-origin hop moves by path; only a cross-origin hop carries a Jump rt.
    unless target.host == base_host
      target = target
      # A same-origin hop moves by path; only a cross-origin hop carries a Jump rt.
      unless target.host == base_host
        rt = Rack::Utils.parse_query(target.query).fetch("rt")
        payload, = JWT.decode(
          rt, JitSecurityJwtRegistry.public_key_for(issuer.id, issuer.current_kid), true,
          algorithms: ["ES384"], verify_iss: true, iss: "https://#{base_host}",
          verify_aud: true, aud: Rails.configuration.x.boot_config.fetch(:jump).audience,
        )
        target = URI.parse(payload.fetch("url"))
      end
    end

    assert_equal base_host, target.host
    base.get(target.request_uri)
    authorization_form = Nokogiri::HTML(base.response.body).at_css("form#base-authorization-ceremony-start-form")
    authorization_fields = authorization_form.css("input[name]").to_h { |input| [input["name"], input["value"]] }
    base.post(authorization_form["action"], params: authorization_fields, headers: base_headers)

    assert_equal 303, base.response.status
    auth_target = URI.parse(base.response.location)
    # A same-origin hop moves by path; only a cross-origin hop carries a Jump rt.
    unless auth_target.host == base_host
      auth_target = auth_target
      # A same-origin hop moves by path; only a cross-origin hop carries a Jump rt.
      unless auth_target.host == base_host
        handoff_rt = Rack::Utils.parse_query(auth_target.query).fetch("rt")
        handoff_payload, = JWT.decode(
          handoff_rt, JitSecurityJwtRegistry.public_key_for(issuer.id, issuer.current_kid), true,
          algorithms: ["ES384"], verify_iss: true, iss: "https://#{base_host}",
          verify_aud: true, aud: Rails.configuration.x.boot_config.fetch(:jump).audience,
        )
        auth_target = URI.parse(handoff_payload.fetch("url"))
      end
    end

    assert_equal auth_host, auth_target.host
    entry_reference = Rack::Utils.parse_query(auth_target.query).fetch("entry_ref")
    binding = BaseAuthAdmissionCoordinator.find_admission_binding!(surface: "app", reference: entry_reference)
    auth.host!(auth_host)
    auth.https!
    auth.get(auth_app_sign_in_path, params: { entry_ref: entry_reference, ri: "jp" })

    assert_equal 200, auth.response.status
    csrf = nil
    3.times do |admission_index|
      browser = (admission_index == 1) ? base : auth
      form = Nokogiri::HTML(browser.response.body).at_css("form")

      assert_not_nil form, "Admission step #{admission_index} must render its real continuation"
      fields = form.css("input[name]").to_h { |input| [input["name"], input["value"]] }
      csrf = fields.fetch("authenticity_token") if admission_index == 2
      assert_nil binding.reload.base_confirmed_at if admission_index == 1
      browser.post(form["action"], params: fields, headers: (admission_index == 1) ? base_headers : auth_headers)

      assert_equal 303, browser.response.status
      assert_not_nil binding.reload.base_confirmed_at if admission_index == 1
      next if admission_index == 2

      target = URI.parse(browser.response.location)
      receiver = admission_index.zero? ? base : auth

      assert_equal(admission_index.zero? ? base_host : auth_host, target.host)
      receiver.get(target.request_uri)
    end

    binding.reload
    OmniAuth.config.mock_auth[:google] = OmniAuth::AuthHash.new(
      provider: "google", uid: subject, info: { name: "Provider fixture" },
      credentials: { token: "provider-fixture", expires_at: 1.hour.from_now.to_i },
    )
    auth.post(
      auth_app_social_google_registration_path, params: { ri: "jp" },
                                                headers: auth_headers.merge("X-CSRF-Token" => csrf),
    )

    assert_equal 307, auth.response.status
    state = auth.session.fetch(SocialCallbackGuard::SOCIAL_STATE_SESSION_KEY)
    assert_no_difference("Client.count") do
      assert_no_difference("ClientExternalIdentity.count") do
        auth.get(auth_app_social_google_callback_path, params: { state:, ri: "jp" }, headers: auth_headers)
      end
    end
    assert_equal 302, auth.response.status
    auth.follow_redirect!
    auth.follow_redirect!

    signup = SignUpCycleLocator.new(auth.session, surface: :app).current

    assert_equal [200, true, nil], [auth.response.status, signup.present?, signup&.principal_id]
    fb = SignFlowBindingCodec.encode(flow: signup, surface: :app)
    auth.patch(
      auth_app_sign_up_check_google_confirmation_path(ri: "jp", fb:),
      params: { :confirm_new_social_identity => "1",
                :checkpoint_version => signup.checkpoint_version,
                "cf-turnstile-response" => "fixture", },
      headers: auth_headers.merge("X-CSRF-Token" => csrf),
    )

    assert_equal 302, auth.response.status
    fb = Rack::Utils.parse_query(URI.parse(auth.response.location).query).fetch("fb")
    assert_no_difference("Client.count") do
      auth.patch(
        auth_app_sign_up_check_google_birthdate_path(ri: "jp", fb:),
        params: { requirement: "birthdate",
                  birthdate: "2000-02-03",
                  checkpoint_version: signup.reload.checkpoint_version, },
        headers: auth_headers.merge("X-CSRF-Token" => csrf),
      )
    end
    result_receiver = URI.parse(auth.response.location)

    assert_equal [303, base_host], [auth.response.status, result_receiver.host]
    base.get(result_receiver.request_uri)

    assert_equal 200, base.response.status
    form = Nokogiri::HTML(base.response.body).at_css("form")
    fields = form.css("input[name]").to_h { |input| [input["name"], input["value"]] }
    assert_no_difference("ClientToken.count") do
      assert_difference("Client.count", 1) do
        assert_difference("ClientExternalIdentity.count", 1) do
          base.post(form["action"], params: fields, headers: base_headers)
        end
      end
    end
    completion_destination = base.response.location

    original_completion_status = base.response.status
    base.get(base_app_root_url(ri: "jp", host: base_host))
    csrf = response.parsed_body.at_css('meta[name="csrf-token"]')["content"]
    assert_no_difference(["Client.count", "ClientExternalIdentity.count", "ClientToken.count"]) do
      base.post(
        form["action"], params: fields.merge("authenticity_token" => csrf), headers: base_headers,
      )
    end
    assert_equal [303, 303, completion_destination],
                 [original_completion_status, base.response.status, base.response.location]
    identity = ClientExternalIdentity.find_by!(provider: "google", subject:)
    actor = Client.find(identity.client_id)

    assert_equal [actor.id, true, true, nil],
                 [signup.reload.principal_id, signup.completed?, ClientIdentity.exists?(source_record_id: actor.id),
                  base.cookies[AuthenticationBase::ACCESS_COOKIE_KEY],]
    ceremony = ClientAuthCeremonySession.find(binding.reload.admitted_auth_ceremony_session_id)
    evidence_time = ceremony.authentication_event_at

    assert_equal [true, "google"], [binding.redeemed?, ceremony.authentication_method]
    base.get(URI.parse(base.response.location).request_uri)

    result_status = base.response.status
    form = Nokogiri::HTML(base.response.body).at_css("form")
    fields = form.css("input[name]").to_h { |input| [input["name"], input["value"]] }
    assert_difference(-> { ClientToken.where(user_id: actor.id).count }, 1) do
      base.post(form["action"], params: fields, headers: base_headers)
    end
    assert_equal [200, 303], [result_status, base.response.status]
    token = ClientToken.find_by!(user_id: actor.id)

    assert_equal [evidence_time, "google", true, token.public_id, true],
                 [token.authentication_event_at, token.established_authentication_method,
                  token.root_login_established_at.present?,
                  ClientOidcAuthorizationTransaction.find(
                    binding.authorization_transaction_id,
                  ).reload.browser_session_ref,
                  ClientOidcAuthorizationTransaction.find(binding.authorization_transaction_id).consumed?,]
  end
  test "a local signup receipt resumes the exact completed Source and Root without another issuance" do
    subject = "new-social-#{SecureRandom.hex(8)}"
    base = self
    auth = open_session
    base_host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    auth_host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    base_headers = { "Origin" => "https://#{base_host}", "Sec-Fetch-Site" => "same-origin" }
    auth_headers = { "Origin" => "https://#{auth_host}", "Sec-Fetch-Site" => "same-origin" }
    base.host!(base_host)
    base.https!
    base.get("/sign", params: { ri: "jp" })

    assert_equal 200, base.response.status
    entry_form = Nokogiri::HTML(base.response.body).at_css("form")
    entry_fields = entry_form.css("input[name]").to_h { |input| [input["name"], input["value"]] }
    base.post(entry_form["action"], params: entry_fields, headers: base_headers)

    assert_equal 303, base.response.status
    # The initiating Base POST owns its nonce; the public coordinator supplies the local parent.
    # The authorize endpoint shares this origin, so the start moves by path without a Jump rt.
    authorization = URI.parse(base.response.location)

    assert_equal base_host, authorization.host
    assert_nil Rack::Utils.parse_query(authorization.query)["rt"]
    base.get(authorization.request_uri)
    form = Nokogiri::HTML(base.response.body).at_css("form")
    fields = form.css("input[name]").to_h { |input| [input["name"], input["value"]] }
    base.post(form["action"], params: fields, headers: base_headers)
    nonce = base.request.session.fetch(BaseAdmissionBrowserBinding::BROWSER_NONCE_SESSION_KEY)
    local = BaseAuthAdmissionCoordinator.issue_local_entry!(
      surface: "app", intent: "sign_up", base_browser_nonce: nonce, base_token: nil,
    )
    entry_reference = local.reference
    binding = BaseAuthAdmissionCoordinator.find_admission_binding!(surface: "app", reference: entry_reference)
    auth.host!(auth_host)
    auth.https!
    auth.get(auth_app_sign_up_path, params: { entry_ref: entry_reference, ri: "jp" })

    assert_equal 200, auth.response.status
    csrf = nil
    3.times do |admission_index|
      browser = (admission_index == 1) ? base : auth
      form = Nokogiri::HTML(browser.response.body).at_css("form")

      assert_not_nil form, "Admission step #{admission_index} must render its real continuation"
      fields = form.css("input[name]").to_h { |input| [input["name"], input["value"]] }
      csrf = fields.fetch("authenticity_token") if admission_index == 2
      assert_nil binding.reload.base_confirmed_at if admission_index == 1
      browser.post(form["action"], params: fields, headers: (admission_index == 1) ? base_headers : auth_headers)

      assert_equal 303, browser.response.status
      assert_not_nil binding.reload.base_confirmed_at if admission_index == 1
      next if admission_index == 2

      target = URI.parse(browser.response.location)
      receiver = admission_index.zero? ? base : auth

      assert_equal(admission_index.zero? ? base_host : auth_host, target.host)
      receiver.get(target.request_uri)
    end

    binding.reload
    OmniAuth.config.mock_auth[:google] = OmniAuth::AuthHash.new(
      provider: "google", uid: subject, info: { name: "Provider fixture" },
      credentials: { token: "provider-fixture", expires_at: 1.hour.from_now.to_i },
    )
    auth.post(
      auth_app_social_google_registration_path, params: { ri: "jp" },
                                                headers: auth_headers.merge("X-CSRF-Token" => csrf),
    )

    assert_equal 307, auth.response.status
    state = auth.session.fetch(SocialCallbackGuard::SOCIAL_STATE_SESSION_KEY)
    assert_no_difference("Client.count") do
      assert_no_difference("ClientExternalIdentity.count") do
        auth.get(auth_app_social_google_callback_path, params: { state:, ri: "jp" }, headers: auth_headers)
      end
    end
    assert_equal 302, auth.response.status
    auth.follow_redirect!
    auth.follow_redirect!

    signup = SignUpCycleLocator.new(auth.session, surface: :app).current

    assert_equal [200, true, nil], [auth.response.status, signup.present?, signup&.principal_id]
    fb = SignFlowBindingCodec.encode(flow: signup, surface: :app)
    auth.patch(
      auth_app_sign_up_check_google_confirmation_path(ri: "jp", fb:),
      params: { :confirm_new_social_identity => "1",
                :checkpoint_version => signup.checkpoint_version,
                "cf-turnstile-response" => "fixture", },
      headers: auth_headers.merge("X-CSRF-Token" => csrf),
    )

    assert_equal 302, auth.response.status
    fb = Rack::Utils.parse_query(URI.parse(auth.response.location).query).fetch("fb")
    assert_no_difference("Client.count") do
      auth.patch(
        auth_app_sign_up_check_google_birthdate_path(ri: "jp", fb:),
        params: { requirement: "birthdate",
                  birthdate: "2000-02-03",
                  checkpoint_version: signup.reload.checkpoint_version, },
        headers: auth_headers.merge("X-CSRF-Token" => csrf),
      )
    end
    result_receiver = URI.parse(auth.response.location)

    assert_equal [303, base_host], [auth.response.status, result_receiver.host]
    base.get(result_receiver.request_uri)

    assert_equal 200, base.response.status
    form = Nokogiri::HTML(base.response.body).at_css("form")
    fields = form.css("input[name]").to_h { |input| [input["name"], input["value"]] }
    # Commit the real Source result first to reproduce a stop before the separate Root commit.
    result_token = SocialCeremonyResultAdapter.new.read(reference: fields.fetch("result_ref"))
    assert_no_difference("ClientToken.count") do
      assert_difference(["Client.count", "ClientExternalIdentity.count"], 1) do
        IdentitySocialCeremonyFinalCommitter.call!(
          result_token: result_token, actor: nil, session_ref: binding.entry_ref, surface: "app",
        )
      end
    end
    flow = ClientSignInFlow.find(binding.sign_in_flow_id)

    assert_equal [true, nil], [signup.reload.completed?, flow.reload.principal_id]
    assert_difference("ClientToken.count", 1) do
      assert_no_difference(["Client.count", "ClientExternalIdentity.count"]) do
        base.post(form["action"], params: fields, headers: base_headers)
      end
    end
    completion_destination = base.response.location

    original_completion_status = base.response.status
    base.get(base_app_root_url(ri: "jp", host: base_host))
    csrf = response.parsed_body.at_css('meta[name="csrf-token"]')["content"]
    assert_no_difference(["Client.count", "ClientExternalIdentity.count", "ClientToken.count"]) do
      base.post(
        form["action"], params: fields.merge("authenticity_token" => csrf), headers: base_headers,
      )
    end
    assert_equal [303, 303, completion_destination],
                 [original_completion_status, base.response.status, base.response.location]
    identity = ClientExternalIdentity.find_by!(provider: "google", subject:)
    actor = Client.find(identity.client_id)

    token = ClientToken.find_by!(user_id: actor.id)
    ceremony = ClientAuthCeremonySession.find(binding.reload.admitted_auth_ceremony_session_id)

    assert_equal [actor.id, true, true, true, true],
                 [signup.reload.principal_id, signup.completed?, ClientIdentity.exists?(source_record_id: actor.id),
                  token.currently_usable?, ceremony.completed?,]
    assert_equal [ceremony.authentication_event_at, "google", token.id],
                 [token.authentication_event_at, token.established_authentication_method,
                  ClientSignInFlow.find(binding.sign_in_flow_id).reload.token_id,]
    token.revoke!
    base.get(base_app_root_url(ri: "jp", host: base_host))
    csrf = response.parsed_body.at_css('meta[name="csrf-token"]')["content"]
    assert_no_difference(["Client.count", "ClientExternalIdentity.count", "ClientToken.count"]) do
      base.post(
        form["action"], params: fields.merge("authenticity_token" => csrf), headers: base_headers,
      )
    end
    assert_equal [422, true, true], [base.response.status, token.reload.revoked?, signup.reload.completed?]
  end

  test "completion retains the actual Auth authentication event time through the Base Root boundary" do
    actor = Client.create!(status_id: ClientStatus::ACTIVE, birthdate: "2000-01-01")
    subject = "ordinary-social-#{SecureRandom.hex(8)}"
    ClientGoogleIdentity.create!(
      user: actor,
      uid: subject,
      provider: "google",
      status_id: ClientGoogleIdentityStatus::ACTIVE,
    )
    BaseSelectorBootstrapAuthority.call(surface: :app, principal: actor)
    base = self
    auth = open_session
    base_host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    auth_host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    base_headers = { "Origin" => "https://#{base_host}", "Sec-Fetch-Site" => "same-origin" }
    auth_headers = { "Origin" => "https://#{auth_host}", "Sec-Fetch-Site" => "same-origin" }
    base.host!(base_host)
    base.https!
    base.get("/sign", params: { ri: "jp" })

    assert_equal 200, base.response.status
    entry_form = Nokogiri::HTML(base.response.body).at_css("form")
    entry_fields = entry_form.css("input[name]").to_h { |input| [input["name"], input["value"]] }
    base.post(entry_form["action"], params: entry_fields, headers: base_headers)

    assert_equal 303, base.response.status
    issuer = JitSecurityJwtRegistry.surface("BASE_APP")
    target = URI.parse(base.response.location)
    # A same-origin hop moves by path; only a cross-origin hop carries a Jump rt.
    unless target.host == base_host
      target = target
      # A same-origin hop moves by path; only a cross-origin hop carries a Jump rt.
      unless target.host == base_host
        rt = Rack::Utils.parse_query(target.query).fetch("rt")
        payload, = JWT.decode(
          rt, JitSecurityJwtRegistry.public_key_for(issuer.id, issuer.current_kid), true,
          algorithms: ["ES384"], verify_iss: true, iss: "https://#{base_host}",
          verify_aud: true, aud: Rails.configuration.x.boot_config.fetch(:jump).audience,
        )
        target = URI.parse(payload.fetch("url"))
      end
    end

    assert_equal base_host, target.host
    base.get(target.request_uri)
    authorization_form = Nokogiri::HTML(base.response.body).at_css("form#base-authorization-ceremony-start-form")
    authorization_fields = authorization_form.css("input[name]").to_h { |input| [input["name"], input["value"]] }
    base.post(authorization_form["action"], params: authorization_fields, headers: base_headers)

    assert_equal 303, base.response.status
    auth_target = URI.parse(base.response.location)
    # A same-origin hop moves by path; only a cross-origin hop carries a Jump rt.
    unless auth_target.host == base_host
      auth_target = auth_target
      # A same-origin hop moves by path; only a cross-origin hop carries a Jump rt.
      unless auth_target.host == base_host
        handoff_rt = Rack::Utils.parse_query(auth_target.query).fetch("rt")
        handoff_payload, = JWT.decode(
          handoff_rt, JitSecurityJwtRegistry.public_key_for(issuer.id, issuer.current_kid), true,
          algorithms: ["ES384"], verify_iss: true, iss: "https://#{base_host}",
          verify_aud: true, aud: Rails.configuration.x.boot_config.fetch(:jump).audience,
        )
        auth_target = URI.parse(handoff_payload.fetch("url"))
      end
    end

    assert_equal auth_host, auth_target.host
    entry_reference = Rack::Utils.parse_query(auth_target.query).fetch("entry_ref")
    binding = BaseAuthAdmissionCoordinator.find_admission_binding!(surface: "app", reference: entry_reference)
    auth.host!(auth_host)
    auth.https!
    auth.get(auth_app_sign_in_path, params: { entry_ref: entry_reference, ri: "jp" })

    assert_equal 200, auth.response.status
    csrf = nil
    3.times do |admission_index|
      browser = (admission_index == 1) ? base : auth
      form = Nokogiri::HTML(browser.response.body).at_css("form")

      assert_not_nil form, "Admission step #{admission_index} must render its real continuation"
      fields = form.css("input[name]").to_h { |input| [input["name"], input["value"]] }
      csrf = fields.fetch("authenticity_token") if admission_index == 2
      assert_nil binding.reload.base_confirmed_at if admission_index == 1
      browser.post(form["action"], params: fields, headers: (admission_index == 1) ? base_headers : auth_headers)

      assert_equal 303, browser.response.status
      assert_not_nil binding.reload.base_confirmed_at if admission_index == 1
      next if admission_index == 2

      target = URI.parse(browser.response.location)
      receiver = admission_index.zero? ? base : auth

      assert_equal(admission_index.zero? ? base_host : auth_host, target.host)
      receiver.get(target.request_uri)
    end

    assert_predicate binding.reload, :redeemed?
    OmniAuth.config.mock_auth[:google] = OmniAuth::AuthHash.new(
      provider: "google", uid: subject, info: { name: "Provider fixture" },
      credentials: { token: "provider-fixture", expires_at: 1.hour.from_now.to_i },
    )
    auth.post(
      auth_app_social_google_session_path, params: { ri: "jp" },
                                           headers: auth_headers.merge("X-CSRF-Token" => csrf),
    )

    assert_equal 307, auth.response.status
    state = auth.session.fetch(SocialCallbackGuard::SOCIAL_STATE_SESSION_KEY)
    assert_no_difference("ClientToken.count") do
      auth.get(auth_app_social_google_callback_path, params: { state:, ri: "jp" }, headers: auth_headers)
    end
    assert_equal 303, auth.response.status
    ceremony = ClientAuthCeremonySession.find(binding.reload.admitted_auth_ceremony_session_id)

    assert_predicate ceremony, :authentication_evidence_recorded?
    assert_equal "google", ceremony.authentication_method
    assert_equal [true, true], [auth.cookies[AuthenticationBase::ACCESS_COOKIE_KEY].nil?,
                                auth.cookies[AuthenticationBase::REFRESH_COOKIE_KEY].nil?,]
    assert_equal "pending", ClientOidcAuthorizationTransaction.find(binding.authorization_transaction_id).reload.status

    auth.get(auth_app_sign_oidc_handoff_path, params: { ri: "jp" })

    assert_equal 200, auth.response.status
    form = Nokogiri::HTML(auth.response.body).at_css("form")
    fields = form.css("input[name]").to_h { |input| [input["name"], input["value"]] }
    auth.post(form["action"], params: fields, headers: auth_headers)

    assert_equal 303, auth.response.status
    receiver = URI.parse(auth.response.location)

    assert_equal base_host, receiver.host
    base.get(receiver.request_uri)

    assert_equal 200, base.response.status
    form = Nokogiri::HTML(base.response.body).at_css("form")
    fields = form.css("input[name]").to_h { |input| [input["name"], input["value"]] }
    assert_difference(-> { ClientToken.where(user_id: actor.id).count }, 1) do
      base.post(form["action"], params: fields, headers: base_headers)
    end
    assert_equal 303, base.response.status
    token = ClientToken.find_by!(user_id: actor.id)

    assert_equal [ceremony.authentication_event_at, "google"],
                 [token.authentication_event_at, token.established_authentication_method]
    assert_not_nil token.root_login_established_at
    transaction = ClientOidcAuthorizationTransaction.find(binding.authorization_transaction_id)

    assert_equal token.public_id, transaction.reload.browser_session_ref
    assert_predicate transaction, :consumed?
    assert_equal 0, ClientRpSession.where(client_token_id: token.id).count
  end
  test "a result-delivery outage resumes the exact committed signup without another Source or Root" do
    subject = "new-social-#{SecureRandom.hex(8)}"
    base = self
    auth = open_session
    base_host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    auth_host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    base_headers = { "Origin" => "https://#{base_host}", "Sec-Fetch-Site" => "same-origin" }
    auth_headers = { "Origin" => "https://#{auth_host}", "Sec-Fetch-Site" => "same-origin" }
    base.host!(base_host)
    base.https!
    base.get("/sign", params: { ri: "jp" })

    assert_equal 200, base.response.status
    entry_form = Nokogiri::HTML(base.response.body).at_css("form")
    entry_fields = entry_form.css("input[name]").to_h { |input| [input["name"], input["value"]] }
    base.post(entry_form["action"], params: entry_fields, headers: base_headers)

    assert_equal 303, base.response.status
    issuer = JitSecurityJwtRegistry.surface("BASE_APP")
    target = URI.parse(base.response.location)
    # A same-origin hop moves by path; only a cross-origin hop carries a Jump rt.
    unless target.host == base_host
      target = target
      # A same-origin hop moves by path; only a cross-origin hop carries a Jump rt.
      unless target.host == base_host
        rt = Rack::Utils.parse_query(target.query).fetch("rt")
        payload, = JWT.decode(
          rt, JitSecurityJwtRegistry.public_key_for(issuer.id, issuer.current_kid), true,
          algorithms: ["ES384"], verify_iss: true, iss: "https://#{base_host}",
          verify_aud: true, aud: Rails.configuration.x.boot_config.fetch(:jump).audience,
        )
        target = URI.parse(payload.fetch("url"))
      end
    end

    assert_equal base_host, target.host
    base.get(target.request_uri)
    authorization_form = Nokogiri::HTML(base.response.body).at_css("form#base-authorization-ceremony-start-form")
    authorization_fields = authorization_form.css("input[name]").to_h { |input| [input["name"], input["value"]] }
    base.post(authorization_form["action"], params: authorization_fields, headers: base_headers)

    assert_equal 303, base.response.status
    auth_target = URI.parse(base.response.location)
    # A same-origin hop moves by path; only a cross-origin hop carries a Jump rt.
    unless auth_target.host == base_host
      auth_target = auth_target
      # A same-origin hop moves by path; only a cross-origin hop carries a Jump rt.
      unless auth_target.host == base_host
        handoff_rt = Rack::Utils.parse_query(auth_target.query).fetch("rt")
        handoff_payload, = JWT.decode(
          handoff_rt, JitSecurityJwtRegistry.public_key_for(issuer.id, issuer.current_kid), true,
          algorithms: ["ES384"], verify_iss: true, iss: "https://#{base_host}",
          verify_aud: true, aud: Rails.configuration.x.boot_config.fetch(:jump).audience,
        )
        auth_target = URI.parse(handoff_payload.fetch("url"))
      end
    end

    assert_equal auth_host, auth_target.host
    entry_reference = Rack::Utils.parse_query(auth_target.query).fetch("entry_ref")
    binding = BaseAuthAdmissionCoordinator.find_admission_binding!(surface: "app", reference: entry_reference)
    auth.host!(auth_host)
    auth.https!
    auth.get(auth_app_sign_in_path, params: { entry_ref: entry_reference, ri: "jp" })

    assert_equal 200, auth.response.status
    csrf = nil
    3.times do |admission_index|
      browser = (admission_index == 1) ? base : auth
      form = Nokogiri::HTML(browser.response.body).at_css("form")

      assert_not_nil form, "Admission step #{admission_index} must render its real continuation"
      fields = form.css("input[name]").to_h { |input| [input["name"], input["value"]] }
      csrf = fields.fetch("authenticity_token") if admission_index == 2
      assert_nil binding.reload.base_confirmed_at if admission_index == 1
      browser.post(form["action"], params: fields, headers: (admission_index == 1) ? base_headers : auth_headers)

      assert_equal 303, browser.response.status
      assert_not_nil binding.reload.base_confirmed_at if admission_index == 1
      next if admission_index == 2

      target = URI.parse(browser.response.location)
      receiver = admission_index.zero? ? base : auth

      assert_equal(admission_index.zero? ? base_host : auth_host, target.host)
      receiver.get(target.request_uri)
    end

    binding.reload
    OmniAuth.config.mock_auth[:google] = OmniAuth::AuthHash.new(
      provider: "google", uid: subject, info: { name: "Provider fixture" },
      credentials: { token: "provider-fixture", expires_at: 1.hour.from_now.to_i },
    )
    auth.post(
      auth_app_social_google_registration_path, params: { ri: "jp" },
                                                headers: auth_headers.merge("X-CSRF-Token" => csrf),
    )

    assert_equal 307, auth.response.status
    state = auth.session.fetch(SocialCallbackGuard::SOCIAL_STATE_SESSION_KEY)
    assert_no_difference("Client.count") do
      assert_no_difference("ClientExternalIdentity.count") do
        auth.get(auth_app_social_google_callback_path, params: { state:, ri: "jp" }, headers: auth_headers)
      end
    end
    assert_equal 302, auth.response.status
    auth.follow_redirect!
    auth.follow_redirect!

    signup = SignUpCycleLocator.new(auth.session, surface: :app).current

    assert_equal [200, true, nil], [auth.response.status, signup.present?, signup&.principal_id]
    fb = SignFlowBindingCodec.encode(flow: signup, surface: :app)
    auth.patch(
      auth_app_sign_up_check_google_confirmation_path(ri: "jp", fb:),
      params: { :confirm_new_social_identity => "1",
                :checkpoint_version => signup.checkpoint_version,
                "cf-turnstile-response" => "fixture", },
      headers: auth_headers.merge("X-CSRF-Token" => csrf),
    )

    assert_equal 302, auth.response.status
    fb = Rack::Utils.parse_query(URI.parse(auth.response.location).query).fetch("fb")
    assert_no_difference("Client.count") do
      auth.patch(
        auth_app_sign_up_check_google_birthdate_path(ri: "jp", fb:),
        params: { requirement: "birthdate",
                  birthdate: "2000-02-03",
                  checkpoint_version: signup.reload.checkpoint_version, },
        headers: auth_headers.merge("X-CSRF-Token" => csrf),
      )
    end
    result_receiver = URI.parse(auth.response.location)

    assert_equal [303, base_host], [auth.response.status, result_receiver.host]
    base.get(result_receiver.request_uri)

    assert_equal 200, base.response.status
    form = Nokogiri::HTML(base.response.body).at_css("form")
    fields = form.css("input[name]").to_h { |input| [input["name"], input["value"]] }
    transaction = ClientSocialCeremonyTransaction.find_by!(actor_ref: signup.public_id)
    candidate = IdentitySocialCeremonyCandidate.find_by!(transaction_id: transaction.transaction_id)
    transport = Redis.new(
      url: Umaxica::Valkey::Settings.current.auth_state.url,
      **Umaxica::Valkey::Connection::AUTH_STATE_CLIENT_OPTIONS,
    )
    delivery_outage =
      lambda do |command, *arguments|
        case command.to_s.upcase
        when "GET"
          transport.get(arguments.fetch(0))
        when "EVAL"
          if arguments.fetch(0) == Valkey::AuthState::OpaqueAdmissionStore::ISSUE_SCRIPT
            raise Redis::CannotConnectError, "simulated admission delivery transport outage"
          end

          count = Integer(arguments.fetch(1))
          transport.eval(arguments.fetch(0), keys: arguments.drop(2).take(count), argv: arguments.drop(2 + count))
        else
          raise RuntimeError, "Unexpected external transport command: #{command}"
        end
      end
    assert_difference("Client.count", 1) do
      assert_no_difference("ClientToken.count") do
        Redis.stub(:new, ->(**) { transport }) do
          transport.stub(:call, delivery_outage) do
            base.post(form["action"], params: fields, headers: base_headers)
          end
        end
      end
    end
    assert_equal [503, nil, true, true, true],
                 [base.response.status, base.response.headers["Location"], signup.reload.completed?,
                  transaction.reload.consumed_at.present?, candidate.reload.consumed_at.present?,]
    assert_equal [true, true], [base.cookies[AuthenticationBase::ACCESS_COOKIE_KEY].nil?,
                                base.cookies[AuthenticationBase::REFRESH_COOKIE_KEY].nil?,]
    assert_no_difference(["Client.count", "ClientExternalIdentity.count", "ClientToken.count"]) do
      base.post(form["action"], params: fields, headers: base_headers)
    end
    assert_equal 303, base.response.status
    target = URI.parse(base.response.location)
    base.get(target.request_uri)
    root_form = Nokogiri::HTML(base.response.body).at_css("form")
    root_fields = root_form.css("input[name]").to_h { |input| [input["name"], input["value"]] }
    assert_difference("ClientToken.count", 1) do
      base.post(root_form["action"], params: root_fields, headers: base_headers)
    end
    assert_equal 303, base.response.status
  ensure
    transport&.close
  end

  test "an Avatar database transport failure preserves the pending signup result and creates no Root" do
    subject = "new-social-#{SecureRandom.hex(8)}"
    base = self
    auth = open_session
    base_host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    auth_host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    base_headers = { "Origin" => "https://#{base_host}", "Sec-Fetch-Site" => "same-origin" }
    auth_headers = { "Origin" => "https://#{auth_host}", "Sec-Fetch-Site" => "same-origin" }
    base.host!(base_host)
    base.https!
    base.get("/sign", params: { ri: "jp" })

    assert_equal 200, base.response.status
    entry_form = Nokogiri::HTML(base.response.body).at_css("form")
    entry_fields = entry_form.css("input[name]").to_h { |input| [input["name"], input["value"]] }
    base.post(entry_form["action"], params: entry_fields, headers: base_headers)

    assert_equal 303, base.response.status
    issuer = JitSecurityJwtRegistry.surface("BASE_APP")
    target = URI.parse(base.response.location)
    # A same-origin hop moves by path; only a cross-origin hop carries a Jump rt.
    unless target.host == base_host
      target = target
      # A same-origin hop moves by path; only a cross-origin hop carries a Jump rt.
      unless target.host == base_host
        rt = Rack::Utils.parse_query(target.query).fetch("rt")
        payload, = JWT.decode(
          rt, JitSecurityJwtRegistry.public_key_for(issuer.id, issuer.current_kid), true,
          algorithms: ["ES384"], verify_iss: true, iss: "https://#{base_host}",
          verify_aud: true, aud: Rails.configuration.x.boot_config.fetch(:jump).audience,
        )
        target = URI.parse(payload.fetch("url"))
      end
    end

    assert_equal base_host, target.host
    base.get(target.request_uri)
    authorization_form = Nokogiri::HTML(base.response.body).at_css("form#base-authorization-ceremony-start-form")
    authorization_fields = authorization_form.css("input[name]").to_h { |input| [input["name"], input["value"]] }
    base.post(authorization_form["action"], params: authorization_fields, headers: base_headers)

    assert_equal 303, base.response.status
    auth_target = URI.parse(base.response.location)
    # A same-origin hop moves by path; only a cross-origin hop carries a Jump rt.
    unless auth_target.host == base_host
      auth_target = auth_target
      # A same-origin hop moves by path; only a cross-origin hop carries a Jump rt.
      unless auth_target.host == base_host
        handoff_rt = Rack::Utils.parse_query(auth_target.query).fetch("rt")
        handoff_payload, = JWT.decode(
          handoff_rt, JitSecurityJwtRegistry.public_key_for(issuer.id, issuer.current_kid), true,
          algorithms: ["ES384"], verify_iss: true, iss: "https://#{base_host}",
          verify_aud: true, aud: Rails.configuration.x.boot_config.fetch(:jump).audience,
        )
        auth_target = URI.parse(handoff_payload.fetch("url"))
      end
    end

    assert_equal auth_host, auth_target.host
    entry_reference = Rack::Utils.parse_query(auth_target.query).fetch("entry_ref")
    binding = BaseAuthAdmissionCoordinator.find_admission_binding!(surface: "app", reference: entry_reference)
    auth.host!(auth_host)
    auth.https!
    auth.get(auth_app_sign_in_path, params: { entry_ref: entry_reference, ri: "jp" })

    assert_equal 200, auth.response.status
    csrf = nil
    3.times do |admission_index|
      browser = (admission_index == 1) ? base : auth
      form = Nokogiri::HTML(browser.response.body).at_css("form")

      assert_not_nil form, "Admission step #{admission_index} must render its real continuation"
      fields = form.css("input[name]").to_h { |input| [input["name"], input["value"]] }
      csrf = fields.fetch("authenticity_token") if admission_index == 2
      assert_nil binding.reload.base_confirmed_at if admission_index == 1
      browser.post(form["action"], params: fields, headers: (admission_index == 1) ? base_headers : auth_headers)

      assert_equal 303, browser.response.status
      assert_not_nil binding.reload.base_confirmed_at if admission_index == 1
      next if admission_index == 2

      target = URI.parse(browser.response.location)
      receiver = admission_index.zero? ? base : auth

      assert_equal(admission_index.zero? ? base_host : auth_host, target.host)
      receiver.get(target.request_uri)
    end

    binding.reload
    OmniAuth.config.mock_auth[:google] = OmniAuth::AuthHash.new(
      provider: "google", uid: subject, info: { name: "Provider fixture" },
      credentials: { token: "provider-fixture", expires_at: 1.hour.from_now.to_i },
    )
    auth.post(
      auth_app_social_google_registration_path, params: { ri: "jp" },
                                                headers: auth_headers.merge("X-CSRF-Token" => csrf),
    )

    assert_equal 307, auth.response.status
    state = auth.session.fetch(SocialCallbackGuard::SOCIAL_STATE_SESSION_KEY)
    assert_no_difference("Client.count") do
      assert_no_difference("ClientExternalIdentity.count") do
        auth.get(auth_app_social_google_callback_path, params: { state:, ri: "jp" }, headers: auth_headers)
      end
    end
    assert_equal 302, auth.response.status
    auth.follow_redirect!
    auth.follow_redirect!

    signup = SignUpCycleLocator.new(auth.session, surface: :app).current

    assert_equal [200, true, nil], [auth.response.status, signup.present?, signup&.principal_id]
    fb = SignFlowBindingCodec.encode(flow: signup, surface: :app)
    auth.patch(
      auth_app_sign_up_check_google_confirmation_path(ri: "jp", fb:),
      params: { :confirm_new_social_identity => "1",
                :checkpoint_version => signup.checkpoint_version,
                "cf-turnstile-response" => "fixture", },
      headers: auth_headers.merge("X-CSRF-Token" => csrf),
    )

    assert_equal 302, auth.response.status
    fb = Rack::Utils.parse_query(URI.parse(auth.response.location).query).fetch("fb")
    assert_no_difference("Client.count") do
      auth.patch(
        auth_app_sign_up_check_google_birthdate_path(ri: "jp", fb:),
        params: { requirement: "birthdate",
                  birthdate: "2000-02-03",
                  checkpoint_version: signup.reload.checkpoint_version, },
        headers: auth_headers.merge("X-CSRF-Token" => csrf),
      )
    end
    result_receiver = URI.parse(auth.response.location)

    assert_equal [303, base_host], [auth.response.status, result_receiver.host]
    base.get(result_receiver.request_uri)

    assert_equal 200, base.response.status
    form = Nokogiri::HTML(base.response.body).at_css("form")
    fields = form.css("input[name]").to_h { |input| [input["name"], input["value"]] }
    transaction = ClientSocialCeremonyTransaction.find_by!(actor_ref: signup.public_id)
    candidate = IdentitySocialCeremonyCandidate.find_by!(transaction_id: transaction.transaction_id)
    Avatar.connection_class_for_self.connected_to(role: :writing) do
      wire = Avatar.lease_connection.raw_connection
      unavailable_query = ->(*) { raise PG::UnableToSend, "simulated Avatar database transport outage" }
      assert_no_difference(["Client.count", "ClientExternalIdentity.count", "ClientToken.count"]) do
        wire.stub(:send_query, unavailable_query) do
          wire.stub(:send_query_params, unavailable_query) do
            wire.stub(:send_query_prepared, unavailable_query) do
              assert_raises(ActiveRecord::StatementInvalid) do
                base.post(form["action"], params: fields, headers: base_headers)
              end
            end
          end
        end
      end
    end
    # The transport failure makes Active Record reset the Avatar connection, which discards the
    # fixture transaction on that database. Reopen it so the retry below is rolled back at teardown
    # instead of committing an Avatar graph that breaks later fixture loads.
    avatar_connection = Avatar.lease_connection

    assert_not avatar_connection.transaction_open?
    avatar_connection.begin_transaction(joinable: false, _lazy: false)

    assert_equal [nil, nil, nil, false],
                 [transaction.reload.consumed_at, candidate.reload.consumed_at,
                  signup.reload.principal_id, signup.completed?,]
    assert_nil base.cookies[AuthenticationBase::ACCESS_COOKIE_KEY]
    assert_nil base.cookies[AuthenticationBase::REFRESH_COOKIE_KEY]
    assert_difference("Client.count", 1) do
      base.post(form["action"], params: fields, headers: base_headers)
    end
    assert_equal 303, base.response.status
    assert_predicate signup.reload, :completed?
  end
  test "signup completion redirects without writing a notice or alert" do
    subject = "new-social-#{SecureRandom.hex(8)}"
    base = self
    auth = open_session
    base_host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    auth_host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    base_headers = { "Origin" => "https://#{base_host}", "Sec-Fetch-Site" => "same-origin" }
    auth_headers = { "Origin" => "https://#{auth_host}", "Sec-Fetch-Site" => "same-origin" }
    base.host!(base_host)
    base.https!
    base.get("/sign", params: { ri: "jp" })

    assert_equal 200, base.response.status
    entry_form = Nokogiri::HTML(base.response.body).at_css("form")
    entry_fields = entry_form.css("input[name]").to_h { |input| [input["name"], input["value"]] }
    base.post(entry_form["action"], params: entry_fields, headers: base_headers)

    assert_equal 303, base.response.status
    issuer = JitSecurityJwtRegistry.surface("BASE_APP")
    target = URI.parse(base.response.location)
    # A same-origin hop moves by path; only a cross-origin hop carries a Jump rt.
    unless target.host == base_host
      target = target
      # A same-origin hop moves by path; only a cross-origin hop carries a Jump rt.
      unless target.host == base_host
        rt = Rack::Utils.parse_query(target.query).fetch("rt")
        payload, = JWT.decode(
          rt, JitSecurityJwtRegistry.public_key_for(issuer.id, issuer.current_kid), true,
          algorithms: ["ES384"], verify_iss: true, iss: "https://#{base_host}",
          verify_aud: true, aud: Rails.configuration.x.boot_config.fetch(:jump).audience,
        )
        target = URI.parse(payload.fetch("url"))
      end
    end

    assert_equal base_host, target.host
    base.get(target.request_uri)
    authorization_form = Nokogiri::HTML(base.response.body).at_css("form#base-authorization-ceremony-start-form")
    authorization_fields = authorization_form.css("input[name]").to_h { |input| [input["name"], input["value"]] }
    base.post(authorization_form["action"], params: authorization_fields, headers: base_headers)

    assert_equal 303, base.response.status
    auth_target = URI.parse(base.response.location)
    # A same-origin hop moves by path; only a cross-origin hop carries a Jump rt.
    unless auth_target.host == base_host
      auth_target = auth_target
      # A same-origin hop moves by path; only a cross-origin hop carries a Jump rt.
      unless auth_target.host == base_host
        handoff_rt = Rack::Utils.parse_query(auth_target.query).fetch("rt")
        handoff_payload, = JWT.decode(
          handoff_rt, JitSecurityJwtRegistry.public_key_for(issuer.id, issuer.current_kid), true,
          algorithms: ["ES384"], verify_iss: true, iss: "https://#{base_host}",
          verify_aud: true, aud: Rails.configuration.x.boot_config.fetch(:jump).audience,
        )
        auth_target = URI.parse(handoff_payload.fetch("url"))
      end
    end

    assert_equal auth_host, auth_target.host
    entry_reference = Rack::Utils.parse_query(auth_target.query).fetch("entry_ref")
    binding = BaseAuthAdmissionCoordinator.find_admission_binding!(surface: "app", reference: entry_reference)
    auth.host!(auth_host)
    auth.https!
    auth.get(auth_app_sign_in_path, params: { entry_ref: entry_reference, ri: "jp" })

    assert_equal 200, auth.response.status
    csrf = nil
    3.times do |admission_index|
      browser = (admission_index == 1) ? base : auth
      form = Nokogiri::HTML(browser.response.body).at_css("form")

      assert_not_nil form, "Admission step #{admission_index} must render its real continuation"
      fields = form.css("input[name]").to_h { |input| [input["name"], input["value"]] }
      csrf = fields.fetch("authenticity_token") if admission_index == 2
      assert_nil binding.reload.base_confirmed_at if admission_index == 1
      browser.post(form["action"], params: fields, headers: (admission_index == 1) ? base_headers : auth_headers)

      assert_equal 303, browser.response.status
      assert_not_nil binding.reload.base_confirmed_at if admission_index == 1
      next if admission_index == 2

      target = URI.parse(browser.response.location)
      receiver = admission_index.zero? ? base : auth

      assert_equal(admission_index.zero? ? base_host : auth_host, target.host)
      receiver.get(target.request_uri)
    end

    binding.reload
    OmniAuth.config.mock_auth[:google] = OmniAuth::AuthHash.new(
      provider: "google", uid: subject, info: { name: "Provider fixture" },
      credentials: { token: "provider-fixture", expires_at: 1.hour.from_now.to_i },
    )
    auth.post(
      auth_app_social_google_registration_path, params: { ri: "jp" },
                                                headers: auth_headers.merge("X-CSRF-Token" => csrf),
    )

    assert_equal 307, auth.response.status
    state = auth.session.fetch(SocialCallbackGuard::SOCIAL_STATE_SESSION_KEY)
    assert_no_difference("Client.count") do
      assert_no_difference("ClientExternalIdentity.count") do
        auth.get(auth_app_social_google_callback_path, params: { state:, ri: "jp" }, headers: auth_headers)
      end
    end
    assert_equal 302, auth.response.status
    auth.follow_redirect!
    auth.follow_redirect!

    signup = SignUpCycleLocator.new(auth.session, surface: :app).current

    assert_equal [200, true, nil], [auth.response.status, signup.present?, signup&.principal_id]
    fb = SignFlowBindingCodec.encode(flow: signup, surface: :app)
    auth.patch(
      auth_app_sign_up_check_google_confirmation_path(ri: "jp", fb:),
      params: { :confirm_new_social_identity => "1",
                :checkpoint_version => signup.checkpoint_version,
                "cf-turnstile-response" => "fixture", },
      headers: auth_headers.merge("X-CSRF-Token" => csrf),
    )

    assert_equal 302, auth.response.status
    fb = Rack::Utils.parse_query(URI.parse(auth.response.location).query).fetch("fb")
    assert_no_difference("Client.count") do
      auth.patch(
        auth_app_sign_up_check_google_birthdate_path(ri: "jp", fb:),
        params: { requirement: "birthdate",
                  birthdate: "2000-02-03",
                  checkpoint_version: signup.reload.checkpoint_version, },
        headers: auth_headers.merge("X-CSRF-Token" => csrf),
      )
    end
    result_receiver = URI.parse(auth.response.location)

    assert_equal [303, base_host], [auth.response.status, result_receiver.host]
    base.get(result_receiver.request_uri)

    assert_equal 200, base.response.status
    form = Nokogiri::HTML(base.response.body).at_css("form")
    fields = form.css("input[name]").to_h { |input| [input["name"], input["value"]] }
    assert_no_difference("ClientToken.count") do
      assert_difference("Client.count", 1) do
        assert_difference("ClientExternalIdentity.count", 1) do
          base.post(form["action"], params: fields, headers: base_headers)
        end
      end
    end
    completion_destination = base.response.location

    original_completion_status = base.response.status
    assert_no_difference(["Client.count", "ClientExternalIdentity.count", "ClientToken.count"]) do
      base.post(form["action"], params: fields, headers: base_headers)
    end
    assert_equal [303, 303, completion_destination, true],
                 [original_completion_status, base.response.status, base.response.location, base.flash.empty?]
    identity = ClientExternalIdentity.find_by!(provider: "google", subject:)
    actor = Client.find(identity.client_id)

    assert_equal [actor.id, true, true, nil],
                 [signup.reload.principal_id, signup.completed?, ClientIdentity.exists?(source_record_id: actor.id),
                  base.cookies[AuthenticationBase::ACCESS_COOKIE_KEY],]
    ceremony = ClientAuthCeremonySession.find(binding.reload.admitted_auth_ceremony_session_id)
    evidence_time = ceremony.authentication_event_at

    assert_equal [true, "google"], [binding.redeemed?, ceremony.authentication_method]
    base.get(URI.parse(base.response.location).request_uri)

    result_status = base.response.status
    form = Nokogiri::HTML(base.response.body).at_css("form")
    fields = form.css("input[name]").to_h { |input| [input["name"], input["value"]] }
    assert_difference(-> { ClientToken.where(user_id: actor.id).count }, 1) do
      base.post(form["action"], params: fields, headers: base_headers)
    end
    assert_equal [200, 303], [result_status, base.response.status]
    token = ClientToken.find_by!(user_id: actor.id)

    assert_equal [evidence_time, "google", true, token.public_id, true],
                 [token.authentication_event_at, token.established_authentication_method,
                  token.root_login_established_at.present?,
                  ClientOidcAuthorizationTransaction.find(
                    binding.authorization_transaction_id,
                  ).reload.browser_session_ref,
                  ClientOidcAuthorizationTransaction.find(binding.authorization_transaction_id).consumed?,]
  end
  test "a cancelled provider candidate yields a terminal refusal without Source or Root writes" do
    subject = "new-social-#{SecureRandom.hex(8)}"
    base = self
    auth = open_session
    base_host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    auth_host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    base_headers = { "Origin" => "https://#{base_host}", "Sec-Fetch-Site" => "same-origin" }
    auth_headers = { "Origin" => "https://#{auth_host}", "Sec-Fetch-Site" => "same-origin" }
    base.host!(base_host)
    base.https!
    base.get("/sign", params: { ri: "jp" })

    assert_equal 200, base.response.status
    entry_form = Nokogiri::HTML(base.response.body).at_css("form")
    entry_fields = entry_form.css("input[name]").to_h { |input| [input["name"], input["value"]] }
    base.post(entry_form["action"], params: entry_fields, headers: base_headers)

    assert_equal 303, base.response.status
    issuer = JitSecurityJwtRegistry.surface("BASE_APP")
    target = URI.parse(base.response.location)
    # A same-origin hop moves by path; only a cross-origin hop carries a Jump rt.
    unless target.host == base_host
      target = target
      # A same-origin hop moves by path; only a cross-origin hop carries a Jump rt.
      unless target.host == base_host
        rt = Rack::Utils.parse_query(target.query).fetch("rt")
        payload, = JWT.decode(
          rt, JitSecurityJwtRegistry.public_key_for(issuer.id, issuer.current_kid), true,
          algorithms: ["ES384"], verify_iss: true, iss: "https://#{base_host}",
          verify_aud: true, aud: Rails.configuration.x.boot_config.fetch(:jump).audience,
        )
        target = URI.parse(payload.fetch("url"))
      end
    end

    assert_equal base_host, target.host
    base.get(target.request_uri)
    authorization_form = Nokogiri::HTML(base.response.body).at_css("form#base-authorization-ceremony-start-form")
    authorization_fields = authorization_form.css("input[name]").to_h { |input| [input["name"], input["value"]] }
    base.post(authorization_form["action"], params: authorization_fields, headers: base_headers)

    assert_equal 303, base.response.status
    auth_target = URI.parse(base.response.location)
    # A same-origin hop moves by path; only a cross-origin hop carries a Jump rt.
    unless auth_target.host == base_host
      auth_target = auth_target
      # A same-origin hop moves by path; only a cross-origin hop carries a Jump rt.
      unless auth_target.host == base_host
        handoff_rt = Rack::Utils.parse_query(auth_target.query).fetch("rt")
        handoff_payload, = JWT.decode(
          handoff_rt, JitSecurityJwtRegistry.public_key_for(issuer.id, issuer.current_kid), true,
          algorithms: ["ES384"], verify_iss: true, iss: "https://#{base_host}",
          verify_aud: true, aud: Rails.configuration.x.boot_config.fetch(:jump).audience,
        )
        auth_target = URI.parse(handoff_payload.fetch("url"))
      end
    end

    assert_equal auth_host, auth_target.host
    entry_reference = Rack::Utils.parse_query(auth_target.query).fetch("entry_ref")
    binding = BaseAuthAdmissionCoordinator.find_admission_binding!(surface: "app", reference: entry_reference)
    auth.host!(auth_host)
    auth.https!
    auth.get(auth_app_sign_in_path, params: { entry_ref: entry_reference, ri: "jp" })

    assert_equal 200, auth.response.status
    csrf = nil
    3.times do |admission_index|
      browser = (admission_index == 1) ? base : auth
      form = Nokogiri::HTML(browser.response.body).at_css("form")

      assert_not_nil form, "Admission step #{admission_index} must render its real continuation"
      fields = form.css("input[name]").to_h { |input| [input["name"], input["value"]] }
      csrf = fields.fetch("authenticity_token") if admission_index == 2
      assert_nil binding.reload.base_confirmed_at if admission_index == 1
      browser.post(form["action"], params: fields, headers: (admission_index == 1) ? base_headers : auth_headers)

      assert_equal 303, browser.response.status
      assert_not_nil binding.reload.base_confirmed_at if admission_index == 1
      next if admission_index == 2

      target = URI.parse(browser.response.location)
      receiver = admission_index.zero? ? base : auth

      assert_equal(admission_index.zero? ? base_host : auth_host, target.host)
      receiver.get(target.request_uri)
    end

    binding.reload
    OmniAuth.config.mock_auth[:google] = OmniAuth::AuthHash.new(
      provider: "google", uid: subject, info: { name: "Provider fixture" },
      credentials: { token: "provider-fixture", expires_at: 1.hour.from_now.to_i },
    )
    auth.post(
      auth_app_social_google_registration_path, params: { ri: "jp" },
                                                headers: auth_headers.merge("X-CSRF-Token" => csrf),
    )

    assert_equal 307, auth.response.status
    state = auth.session.fetch(SocialCallbackGuard::SOCIAL_STATE_SESSION_KEY)
    assert_no_difference("Client.count") do
      assert_no_difference("ClientExternalIdentity.count") do
        auth.get(auth_app_social_google_callback_path, params: { state:, ri: "jp" }, headers: auth_headers)
      end
    end
    assert_equal 302, auth.response.status
    auth.follow_redirect!
    auth.follow_redirect!

    signup = SignUpCycleLocator.new(auth.session, surface: :app).current

    assert_equal [200, true, nil], [auth.response.status, signup.present?, signup&.principal_id]
    fb = SignFlowBindingCodec.encode(flow: signup, surface: :app)
    auth.patch(
      auth_app_sign_up_check_google_confirmation_path(ri: "jp", fb:),
      params: { :confirm_new_social_identity => "1",
                :checkpoint_version => signup.checkpoint_version,
                "cf-turnstile-response" => "fixture", },
      headers: auth_headers.merge("X-CSRF-Token" => csrf),
    )

    assert_equal 302, auth.response.status
    fb = Rack::Utils.parse_query(URI.parse(auth.response.location).query).fetch("fb")
    assert_no_difference("Client.count") do
      auth.patch(
        auth_app_sign_up_check_google_birthdate_path(ri: "jp", fb:),
        params: { requirement: "birthdate",
                  birthdate: "2000-02-03",
                  checkpoint_version: signup.reload.checkpoint_version, },
        headers: auth_headers.merge("X-CSRF-Token" => csrf),
      )
    end
    result_receiver = URI.parse(auth.response.location)

    assert_equal [303, base_host], [auth.response.status, result_receiver.host]
    base.get(result_receiver.request_uri)

    assert_equal 200, base.response.status
    form = Nokogiri::HTML(base.response.body).at_css("form")
    fields = form.css("input[name]").to_h { |input| [input["name"], input["value"]] }
    transaction = ClientSocialCeremonyTransaction.find_by!(actor_ref: signup.public_id)
    candidate = IdentitySocialCeremonyCandidate.find_by!(transaction_id: transaction.transaction_id)
    candidate.expire!
    assert_no_difference(["Client.count", "ClientExternalIdentity.count", "ClientToken.count"]) do
      base.post(form["action"], params: fields, headers: base_headers)
    end
    assert_equal [422, nil, nil, nil, nil],
                 [base.response.status, base.response.headers["Location"], signup.reload.principal_id,
                  base.cookies[AuthenticationBase::ACCESS_COOKIE_KEY], transaction.reload.consumed_at,]
    assert_not_predicate signup, :completed?
  end
  test "a competing Root login after Social verification makes the original Base completion refuse cooldown" do
    Rails.application.config.x.authentication.login_cooldown = 60.seconds
    actor = Client.create!(status_id: ClientStatus::ACTIVE, birthdate: "2000-01-01")
    subject = "cooldown-social-#{SecureRandom.hex(8)}"
    ClientGoogleIdentity.create!(
      user: actor,
      uid: subject,
      provider: "google",
      status_id: ClientGoogleIdentityStatus::ACTIVE,
    )
    BaseSelectorBootstrapAuthority.call(surface: :app, principal: actor)
    base_host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    auth_host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    base_headers = { "Origin" => "https://#{base_host}", "Sec-Fetch-Site" => "same-origin" }
    auth_headers = { "Origin" => "https://#{auth_host}", "Sec-Fetch-Site" => "same-origin" }
    issuer = JitSecurityJwtRegistry.surface("BASE_APP")
    OmniAuth.config.mock_auth[:google] = OmniAuth::AuthHash.new(
      provider: "google", uid: subject, info: {}, credentials: { token: "external-provider-fixture" },
    )
    pending_action = nil
    pending_fields = nil
    original_parent = nil
    [[self, open_session], [open_session, open_session]].each_with_index do |(base, auth), index|
      base.host!(base_host)
      base.https!
      auth.host!(auth_host)
      auth.https!
      base.get("/sign", params: { ri: "jp" })
      form = Nokogiri::HTML(base.response.body).at_css("form")
      fields = form.css("input[name]").to_h { |input| [input["name"], input["value"]] }
      base.post(form["action"], params: fields, headers: base_headers)
      2.times do |phase|
        target = URI.parse(base.response.location)
        # A same-origin hop moves by path; only a cross-origin hop carries a Jump rt.
        unless target.host == base_host
          target = target
          # A same-origin hop moves by path; only a cross-origin hop carries a Jump rt.
          unless target.host == base_host
            rt = Rack::Utils.parse_query(target.query).fetch("rt")
            payload, = JWT.decode(
              rt, JitSecurityJwtRegistry.public_key_for(issuer.id, issuer.current_kid), true,
              algorithms: ["ES384"], verify_iss: true, iss: "https://#{base_host}",
              verify_aud: true, aud: Rails.configuration.x.boot_config.fetch(:jump).audience,
            )
            target = URI.parse(payload.fetch("url"))
          end
        end
        if phase.zero?
          base.get(target.request_uri)
          form = Nokogiri::HTML(base.response.body).at_css("form")
          fields = form.css("input[name]").to_h { |input| [input["name"], input["value"]] }
          base.post(form["action"], params: fields, headers: base_headers)
        else
          reference = Rack::Utils.parse_query(target.query).fetch("entry_ref")
          binding = BaseAuthAdmissionCoordinator.find_admission_binding!(surface: "app", reference:)
          if index.zero?
            original_parent = ClientOidcAuthorizationTransaction.find(binding.authorization_transaction_id)
          end
          auth.get(target.request_uri)
        end
      end
      csrf = nil
      3.times do |phase|
        sender = (phase == 1) ? base : auth
        form = Nokogiri::HTML(sender.response.body).at_css("form")
        fields = form.css("input[name]").to_h { |input| [input["name"], input["value"]] }
        csrf = fields.fetch("authenticity_token") if phase == 2
        sender.post(form["action"], params: fields, headers: (phase == 1) ? base_headers : auth_headers)
        raise RuntimeError, "Admission failed" unless sender.response.status == 303
        next if phase == 2

        (phase.zero? ? base : auth).get(URI.parse(sender.response.location).request_uri)
      end
      auth.post(auth_app_social_google_session_path(ri: "jp"), headers: auth_headers.merge("X-CSRF-Token" => csrf))
      state = auth.session.fetch(SocialCallbackGuard::SOCIAL_STATE_SESSION_KEY)
      auth.get(auth_app_social_google_callback_path(ri: "jp"), params: { state: }, headers: auth_headers)
      auth.get(auth_app_sign_oidc_handoff_path(ri: "jp"))
      form = Nokogiri::HTML(auth.response.body).at_css("form")
      fields = form.css("input[name]").to_h { |input| [input["name"], input["value"]] }
      auth.post(form["action"], params: fields, headers: auth_headers)
      base.get(URI.parse(auth.response.location).request_uri)
      form = Nokogiri::HTML(base.response.body).at_css("form")
      fields = form.css("input[name]").to_h { |input| [input["name"], input["value"]] }
      if index.zero?
        pending_action = form["action"]
        pending_fields = fields
      else
        assert_difference(-> { ClientToken.where(user_id: actor.id).count }, 1) do
          base.post(form["action"], params: fields, headers: base_headers)
        end
        assert_equal 303, base.response.status
      end
    end
    root = ClientToken.find_by!(user_id: actor.id)
    anchor = root.root_login_established_at
    assert_no_difference(["ClientToken.count", "ClientDeviceSession.count"]) do
      post(pending_action, params: pending_fields, headers: base_headers)
    end
    assert_equal [429, "60", nil], [response.status, response.headers["Retry-After"], response.headers["Location"]]
    assert_equal [anchor, nil, "authenticated"],
                 [root.reload.root_login_established_at, original_parent.reload.base_finalized_at,
                  original_parent.status,]
    assert_nil cookies[AuthenticationBase::ACCESS_COOKIE_KEY]
    assert_nil cookies[AuthenticationBase::REFRESH_COOKIE_KEY]
  end
end
