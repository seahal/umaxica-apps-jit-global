# typed: false
# frozen_string_literal: true

require "test_helper"

class SocialLoginAdmissionTest < ActionDispatch::IntegrationTest
  setup do
    @previous_protection = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    OmniAuth.config.test_mode = true
    TurnstileVerifierStub.enabled = true
    TurnstileVerifierStub.challenge_enabled = true
    TurnstileVerifierStub.challenge_response = { "success" => true }
  end

  teardown do
    ActionController::Base.allow_forgery_protection = @previous_protection
    OmniAuth.config.mock_auth[:google] = nil
    OmniAuth.config.mock_auth[:apple] = nil
    TurnstileVerifierStub.enabled = false
    TurnstileVerifierStub.challenge_enabled = false
    TurnstileVerifierStub.challenge_response = nil
  end

  test "an admitted Google callback records Auth evidence and Base issues the original OIDC root" do
    actor = Client.create!(status_id: ClientStatus::ACTIVE, birthdate: "2000-01-01")
    subject = "ordinary-social-#{SecureRandom.hex(8)}"
    ClientGoogleIdentity.create!(user: actor, uid: subject, provider: "google", status_id: ClientGoogleIdentityStatus::ACTIVE)
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
      rt = Rack::Utils.parse_query(target.query).fetch("rt")
      payload, = JWT.decode(
        rt, JitSecurityJwtRegistry.public_key_for(issuer.id, issuer.current_kid), true,
        algorithms: ["ES384"], verify_iss: true, iss: "https://#{base_host}",
        verify_aud: true, aud: Rails.configuration.x.boot_config.fetch(:jump).audience,
      )
      target = URI.parse(payload.fetch("url"))
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
      handoff_rt = Rack::Utils.parse_query(auth_target.query).fetch("rt")
      handoff_payload, = JWT.decode(
        handoff_rt, JitSecurityJwtRegistry.public_key_for(issuer.id, issuer.current_kid), true,
        algorithms: ["ES384"], verify_iss: true, iss: "https://#{base_host}",
        verify_aud: true, aud: Rails.configuration.x.boot_config.fetch(:jump).audience,
      )
      auth_target = URI.parse(handoff_payload.fetch("url"))
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
    ceremony = admitted_auth_ceremony_session_for_test(binding.reload)

    assert_predicate ceremony, :authentication_evidence_recorded?
    assert_equal "google", ceremony.authentication_method
    assert_equal [true, true], [auth.cookies[AuthenticationBase::ACCESS_COOKIE_KEY].nil?,
                                auth.cookies[AuthenticationBase::REFRESH_COOKIE_KEY].nil?,]
    assert_equal "pending", authorization_transaction_for_test(binding).reload.status

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
    assert_equal token.public_id, authorization_transaction_for_test(binding).reload.browser_session_ref
    assert_predicate authorization_transaction_for_test(binding), :consumed?
    assert_equal 0, OpAppGrant.where(client_token_id: token.id).count
  end
  test "an admitted Apple callback records Auth evidence and Base issues the original OIDC root" do
    actor = Client.create!(status_id: ClientStatus::ACTIVE, birthdate: "2000-01-01")
    subject = "ordinary-social-#{SecureRandom.hex(8)}"
    ClientAppleIdentity.create!(user: actor, uid: subject, provider: "apple", status_id: ClientAppleIdentityStatus::ACTIVE)
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
      rt = Rack::Utils.parse_query(target.query).fetch("rt")
      payload, = JWT.decode(
        rt, JitSecurityJwtRegistry.public_key_for(issuer.id, issuer.current_kid), true,
        algorithms: ["ES384"], verify_iss: true, iss: "https://#{base_host}",
        verify_aud: true, aud: Rails.configuration.x.boot_config.fetch(:jump).audience,
      )
      target = URI.parse(payload.fetch("url"))
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
      handoff_rt = Rack::Utils.parse_query(auth_target.query).fetch("rt")
      handoff_payload, = JWT.decode(
        handoff_rt, JitSecurityJwtRegistry.public_key_for(issuer.id, issuer.current_kid), true,
        algorithms: ["ES384"], verify_iss: true, iss: "https://#{base_host}",
        verify_aud: true, aud: Rails.configuration.x.boot_config.fetch(:jump).audience,
      )
      auth_target = URI.parse(handoff_payload.fetch("url"))
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
    OmniAuth.config.mock_auth[:apple] = OmniAuth::AuthHash.new(
      provider: "apple", uid: subject, info: { name: "Provider fixture" },
      credentials: { token: "provider-fixture", expires_at: 1.hour.from_now.to_i },
    )
    auth.post(
      auth_app_social_apple_session_path, params: { ri: "jp" },
                                          headers: auth_headers.merge("X-CSRF-Token" => csrf),
    )

    assert_equal 307, auth.response.status
    state = auth.session.fetch(SocialCallbackGuard::SOCIAL_STATE_SESSION_KEY)
    assert_no_difference("ClientToken.count") do
      auth.get(auth_app_social_apple_callback_path, params: { state:, ri: "jp" }, headers: auth_headers)
    end
    assert_equal 303, auth.response.status
    ceremony = admitted_auth_ceremony_session_for_test(binding.reload)

    assert_predicate ceremony, :authentication_evidence_recorded?
    assert_equal "apple", ceremony.authentication_method
    assert_equal [true, true], [auth.cookies[AuthenticationBase::ACCESS_COOKIE_KEY].nil?,
                                auth.cookies[AuthenticationBase::REFRESH_COOKIE_KEY].nil?,]
    assert_equal "pending", authorization_transaction_for_test(binding).reload.status

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

    assert_equal [ceremony.authentication_event_at, "apple"],
                 [token.authentication_event_at, token.established_authentication_method]
    assert_not_nil token.root_login_established_at
    assert_equal token.public_id, authorization_transaction_for_test(binding).reload.browser_session_ref
    assert_predicate authorization_transaction_for_test(binding), :consumed?
    assert_equal 0, OpAppGrant.where(client_token_id: token.id).count
  end
  test "an existing Google subject started at signup records Auth evidence and Base issues the original OIDC root" do
    actor = Client.create!(status_id: ClientStatus::ACTIVE, birthdate: "2000-01-01")
    subject = "ordinary-social-#{SecureRandom.hex(8)}"
    ClientGoogleIdentity.create!(user: actor, uid: subject, provider: "google", status_id: ClientGoogleIdentityStatus::ACTIVE)
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
      rt = Rack::Utils.parse_query(target.query).fetch("rt")
      payload, = JWT.decode(
        rt, JitSecurityJwtRegistry.public_key_for(issuer.id, issuer.current_kid), true,
        algorithms: ["ES384"], verify_iss: true, iss: "https://#{base_host}",
        verify_aud: true, aud: Rails.configuration.x.boot_config.fetch(:jump).audience,
      )
      target = URI.parse(payload.fetch("url"))
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
      handoff_rt = Rack::Utils.parse_query(auth_target.query).fetch("rt")
      handoff_payload, = JWT.decode(
        handoff_rt, JitSecurityJwtRegistry.public_key_for(issuer.id, issuer.current_kid), true,
        algorithms: ["ES384"], verify_iss: true, iss: "https://#{base_host}",
        verify_aud: true, aud: Rails.configuration.x.boot_config.fetch(:jump).audience,
      )
      auth_target = URI.parse(handoff_payload.fetch("url"))
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
      auth_app_social_google_registration_path, params: { ri: "jp" },
                                                headers: auth_headers.merge("X-CSRF-Token" => csrf),
    )

    assert_equal 307, auth.response.status
    state = auth.session.fetch(SocialCallbackGuard::SOCIAL_STATE_SESSION_KEY)
    assert_no_difference("ClientToken.count") do
      auth.get(auth_app_social_google_callback_path, params: { state:, ri: "jp" }, headers: auth_headers)
    end
    assert_equal 303, auth.response.status
    ceremony = admitted_auth_ceremony_session_for_test(binding.reload)

    assert_predicate ceremony, :authentication_evidence_recorded?
    assert_equal "google", ceremony.authentication_method
    assert_equal [true, true], [auth.cookies[AuthenticationBase::ACCESS_COOKIE_KEY].nil?,
                                auth.cookies[AuthenticationBase::REFRESH_COOKIE_KEY].nil?,]
    assert_equal "pending", authorization_transaction_for_test(binding).reload.status

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
    assert_equal token.public_id, authorization_transaction_for_test(binding).reload.browser_session_ref
    assert_predicate authorization_transaction_for_test(binding), :consumed?
    assert_equal 0, OpAppGrant.where(client_token_id: token.id).count
  end
  test "an unknown signup completes its bound source graph before Base issues the original OIDC root" do
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
      rt = Rack::Utils.parse_query(target.query).fetch("rt")
      payload, = JWT.decode(
        rt, JitSecurityJwtRegistry.public_key_for(issuer.id, issuer.current_kid), true,
        algorithms: ["ES384"], verify_iss: true, iss: "https://#{base_host}",
        verify_aud: true, aud: Rails.configuration.x.boot_config.fetch(:jump).audience,
      )
      target = URI.parse(payload.fetch("url"))
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
      handoff_rt = Rack::Utils.parse_query(auth_target.query).fetch("rt")
      handoff_payload, = JWT.decode(
        handoff_rt, JitSecurityJwtRegistry.public_key_for(issuer.id, issuer.current_kid), true,
        algorithms: ["ES384"], verify_iss: true, iss: "https://#{base_host}",
        verify_aud: true, aud: Rails.configuration.x.boot_config.fetch(:jump).audience,
      )
      auth_target = URI.parse(handoff_payload.fetch("url"))
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
    assert_equal [303, 303, completion_destination],
                 [original_completion_status, base.response.status, base.response.location]
    identity = ClientExternalIdentity.find_by!(provider: "google", subject:)
    actor = Client.find(identity.client_id)

    assert_equal [actor.id, true, true, nil],
                 [signup.reload.principal_id, signup.completed?, ClientIdentity.exists?(source_record_id: actor.id),
                  base.cookies[AuthenticationBase::ACCESS_COOKIE_KEY],]
    ceremony = admitted_auth_ceremony_session_for_test(binding.reload)
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
                  authorization_transaction_for_test(binding).reload.browser_session_ref,
                  authorization_transaction_for_test(binding).consumed?,]
  end
  test "a reserved existing social actor receives a terminal refusal without Auth evidence or Root" do
    actor = Client.create!(status_id: ClientStatus::RESERVED, birthdate: "2000-01-01")
    subject = "ordinary-social-#{SecureRandom.hex(8)}"
    ClientGoogleIdentity.create!(user: actor, uid: subject, provider: "google", status_id: ClientGoogleIdentityStatus::ACTIVE)
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
      rt = Rack::Utils.parse_query(target.query).fetch("rt")
      payload, = JWT.decode(
        rt, JitSecurityJwtRegistry.public_key_for(issuer.id, issuer.current_kid), true,
        algorithms: ["ES384"], verify_iss: true, iss: "https://#{base_host}",
        verify_aud: true, aud: Rails.configuration.x.boot_config.fetch(:jump).audience,
      )
      target = URI.parse(payload.fetch("url"))
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
      handoff_rt = Rack::Utils.parse_query(auth_target.query).fetch("rt")
      handoff_payload, = JWT.decode(
        handoff_rt, JitSecurityJwtRegistry.public_key_for(issuer.id, issuer.current_kid), true,
        algorithms: ["ES384"], verify_iss: true, iss: "https://#{base_host}",
        verify_aud: true, aud: Rails.configuration.x.boot_config.fetch(:jump).audience,
      )
      auth_target = URI.parse(handoff_payload.fetch("url"))
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
    assert_equal 403, auth.response.status
    ceremony = admitted_auth_ceremony_session_for_test(binding.reload)

    assert_equal [false, nil, nil, "pending"],
                 [ceremony.authentication_evidence_recorded?,
                  auth.cookies[AuthenticationBase::ACCESS_COOKIE_KEY], auth.response.location,
                  authorization_transaction_for_test(binding).reload.status,]
  end

  test "a Social start without a redeemed Auth admission creates no security state or flash" do
    auth_host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    host! auth_host
    https!
    get auth_app_root_path(ri: "jp")
    csrf = response.parsed_body.at_css('meta[name="csrf-token"]')["content"]
    assert_no_difference(
      [
        "ClientToken.count", "ClientSignUpFlow.count", "ClientSocialCeremonyTransaction.count",
        "ClientAuthCeremonySession.count",
      ],
    ) do
      post auth_app_social_google_session_path, params: { ri: "jp" },
                                                headers: { "Origin" => "https://#{auth_host}",
                                                           "Sec-Fetch-Site" => "same-origin",
                                                           "X-CSRF-Token" => csrf, }
    end
    assert_response :redirect
    assert_predicate session["flash"], :blank?
    assert_equal [true, true], [cookies[AuthenticationBase::ACCESS_COOKIE_KEY].nil?,
                                session[SocialCallbackGuard::SOCIAL_STATE_SESSION_KEY].nil?,]
  end
end
