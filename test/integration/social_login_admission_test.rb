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
    actor = Client.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE,
      birthdate: "2000-01-01",
    )
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
    binding = bootstrap_social_admission!(base:, auth:, base_host:, auth_host:)

    assert_equal 200, auth.response.status
    csrf = auth.response.parsed_body.at_css('meta[name="csrf-token"]')["content"]

    assert_predicate binding.reload.base_confirmed_at, :present?

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

    auth.get(auth_app_sign_oidc_handoff_path, params: { ri: "jp" }, headers: navigation_headers)

    assert_equal 303, auth.response.status
    result = URI.parse(jump_rt_url_from_location_for_test(auth.response.location))

    assert_equal ENV.fetch("PUBLIC_VISA_SERVICE_URL"), result.host
    assert_equal "/oidc/result", result.path
    result_query = Rack::Utils.parse_nested_query(result.query.to_s)

    assert_includes result_query.keys, "result_ref"
    assert_includes result_query.keys, "transaction_ref"
    assert_match AuthAdmissionBinding::REFERENCE_PATTERN, result_query.fetch("result_ref")
    assert_predicate result_query.fetch("transaction_ref"), :present?
    before_root_count = ClientToken.where(user_id: actor.id).count
    auth.host!(result.host)
    auth.https!
    auth.get(result.request_uri, headers: base_result_headers(base, result.host))

    assert_equal before_root_count + 1, ClientToken.where(user_id: actor.id).count,
                 "Visa result did not issue the root: #{auth.response.status} #{auth.response.location}"

    assert_equal 303, auth.response.status
    receiver = URI.parse(jump_rt_url_from_location_for_test(auth.response.location))

    assert_equal base_host, receiver.host
    base.host!(base_host)
    OidcOpUserInfoClient.stub(:call, oidc_userinfo_result(actor)) do
      base.get(receiver.request_uri, headers: base_headers)
    end

    assert_response :redirect
    token = ClientToken.find_by!(user_id: actor.id)

    assert_equal [ceremony.authentication_event_at, "google"],
                 [token.authentication_event_at, token.established_authentication_method]
    assert_not_nil token.root_login_established_at
    assert_equal token.public_id, authorization_transaction_for_test(binding).reload.browser_session_ref
    assert_predicate authorization_transaction_for_test(binding), :consumed?
    grant = OpAppGrant.find_by!(client_token_id: token.id)

    assert_equal "base-app-ww", grant.oidc_client_id
  end
  test "an admitted Apple callback records Auth evidence and Base issues the original OIDC root" do
    actor = Client.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE,
      birthdate: "2000-01-01",
    )
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

    binding = bootstrap_social_admission!(base:, auth:, base_host:, auth_host:)

    assert_equal 200, auth.response.status
    csrf = auth.response.parsed_body.at_css('meta[name="csrf-token"]')["content"]

    assert_predicate binding.reload.base_confirmed_at, :present?

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

    auth.get(auth_app_sign_oidc_handoff_path, params: { ri: "jp" }, headers: navigation_headers)

    assert_equal 303, auth.response.status
    result = URI.parse(jump_rt_url_from_location_for_test(auth.response.location))

    assert_equal ENV.fetch("PUBLIC_VISA_SERVICE_URL"), result.host
    assert_equal "/oidc/result", result.path
    assert_difference(-> { ClientToken.where(user_id: actor.id).count }, 1) do
      auth.host!(result.host)
      auth.https!
      auth.get(result.request_uri, headers: base_result_headers(base, result.host))
    end

    assert_equal 303, auth.response.status
    receiver = URI.parse(jump_rt_url_from_location_for_test(auth.response.location))

    assert_equal base_host, receiver.host
    base.host!(base_host)
    OidcOpUserInfoClient.stub(:call, oidc_userinfo_result(actor)) do
      base.get(receiver.request_uri, headers: base_headers)
    end

    assert_response :redirect
    token = ClientToken.find_by!(user_id: actor.id)

    assert_equal [ceremony.authentication_event_at, "apple"],
                 [token.authentication_event_at, token.established_authentication_method]
    assert_not_nil token.root_login_established_at
    assert_equal token.public_id, authorization_transaction_for_test(binding).reload.browser_session_ref
    assert_predicate authorization_transaction_for_test(binding), :consumed?
    grant = OpAppGrant.find_by!(client_token_id: token.id)

    assert_equal "base-app-ww", grant.oidc_client_id
  end
  test "an existing Google subject started at signup is refused without Auth evidence or Root" do
    actor = Client.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE,
      birthdate: "2000-01-01",
    )
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

    binding = bootstrap_social_admission!(base:, auth:, base_host:, auth_host:)

    assert_equal 200, auth.response.status
    csrf = auth.response.parsed_body.at_css('meta[name="csrf-token"]')["content"]

    assert_predicate binding.reload.base_confirmed_at, :present?

    assert_predicate binding.reload, :redeemed?
    OmniAuth.config.mock_auth[:google] = OmniAuth::AuthHash.new(
      provider: "google", uid: subject, info: { name: "Provider fixture" },
      credentials: { token: "provider-fixture", expires_at: 1.hour.from_now.to_i },
    )
    switch_browser_to_sign_up!(auth, base_browser: base)
    # The Switch admits the browser again on a new Sign Up Binding of the same parent.
    binding = binding.class.where(
      authorization_transaction_id: binding.authorization_transaction_id, entry_intent: "sign_up",
    ).order(:id).last
    auth.host!(auth_host)
    csrf = auth.response.parsed_body.at_css(%q(meta[name="csrf-token"]))&.[]("content") || csrf
    auth.post(
      auth_app_social_google_registration_path, params: { ri: "jp" },
                                                headers: auth_headers.merge("X-CSRF-Token" => csrf),
    )

    assert_equal 307, auth.response.status
    state = auth.session.fetch(SocialCallbackGuard::SOCIAL_STATE_SESSION_KEY)
    assert_no_difference("ClientToken.count") do
      auth.get(auth_app_social_google_callback_path, params: { state:, ri: "jp" }, headers: auth_headers)
    end
    # D-48 L2: a registered subject under a sign-up intent is refused; it never signs in from here.
    assert_predicate auth.response, :redirect?
    assert_equal "/sign/in", URI.parse(auth.response.location).path
    ceremony = admitted_auth_ceremony_session_for_test(binding.reload)

    assert_not_predicate ceremony, :authentication_evidence_recorded?
    assert_equal "pending", authorization_transaction_for_test(binding).reload.status
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

    binding = bootstrap_social_admission!(base:, auth:, base_host:, auth_host:)

    assert_equal 200, auth.response.status
    csrf = auth.response.parsed_body.at_css('meta[name="csrf-token"]')["content"]

    assert_predicate binding.reload.base_confirmed_at, :present?

    binding.reload
    OmniAuth.config.mock_auth[:google] = OmniAuth::AuthHash.new(
      provider: "google", uid: subject, info: { name: "Provider fixture" },
      credentials: { token: "provider-fixture", expires_at: 1.hour.from_now.to_i },
    )
    switch_browser_to_sign_up!(auth, base_browser: base)
    # The Switch admits the browser again on a new Sign Up Binding of the same parent.
    binding = binding.class.where(
      authorization_transaction_id: binding.authorization_transaction_id, entry_intent: "sign_up",
    ).order(:id).last
    auth.host!(auth_host)
    csrf = auth.response.parsed_body.at_css(%q(meta[name="csrf-token"]))&.[]("content") || csrf
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

    signup = session_sign_up_flow(auth.session, surface: :app)

    assert_equal [200, true, nil], [auth.response.status, signup.present?, signup&.principal_id]
    fb = SignFlowBindingCodec.encode(flow: signup, surface: :app)
    # WU-05d P1: the confirmation creates the Flow's one pending Client.
    assert_difference("Client.count", 1) do
      auth.patch(
        auth_app_sign_up_check_google_confirmation_path(ri: "jp", fb:),
        params: { :confirm_new_social_identity => "1",
                  :checkpoint_version => signup.checkpoint_version,
                  "cf-turnstile-response" => "fixture", },
        headers: auth_headers.merge("X-CSRF-Token" => csrf),
      )
    end

    assert_equal 302, auth.response.status
    fb = Rack::Utils.parse_query(URI.parse(auth.response.location).query).fetch("fb")
    # F3/F4: Auth finalizes; Auth issues no Root.
    assert_no_difference(["Client.count", "ClientToken.count"]) do
      assert_difference("ClientExternalIdentity.count", 1) do
        auth.patch(
          auth_app_sign_up_check_google_birthdate_path(ri: "jp", fb:),
          params: { requirement: "birthdate",
                    birthdate: "2000-02-03",
                    checkpoint_version: signup.reload.checkpoint_version, },
          headers: auth_headers.merge("X-CSRF-Token" => csrf),
        )
      end
    end
    identity = ClientExternalIdentity.find_by!(provider: "google", subject:)
    actor = Client.find(identity.client_id)

    assert_equal [actor.id, true, true, nil],
                 [signup.reload.principal_id, signup.completed?, ClientIdentity.exists?(source_record_id: actor.id),
                  base.cookies[AuthenticationBase::ACCESS_COOKIE_KEY],]
    ceremony = admitted_auth_ceremony_session_for_test(binding.reload)
    evidence_time = ceremony.authentication_event_at

    assert_equal [true, "google"], [binding.redeemed?, ceremony.authentication_method]
    # S1/S2: the canonical Sign In continues to the original OIDC authorization, where Base issues
    # the one Root for the provider evidence (S3).
    OidcOpUserInfoClient.stub(:call, oidc_userinfo_result(actor)) do
      assert_difference(-> { ClientToken.where(user_id: actor.id).count }, 1) do
        drive_browser_through_continuations!(auth, base_browser: base)
      end
    end
    token = ClientToken.find_by!(user_id: actor.id)

    assert_equal [evidence_time, "google", true, token.public_id, true],
                 [token.authentication_event_at, token.established_authentication_method,
                  token.root_login_established_at.present?,
                  authorization_transaction_for_test(binding).reload.browser_session_ref,
                  authorization_transaction_for_test(binding).consumed?,]
  end

  test "a reserved existing social actor receives a terminal refusal without Auth evidence or Root" do
    actor = Client.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::RESERVED,
      birthdate: "2000-01-01",
    )
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

    binding = bootstrap_social_admission!(base:, auth:, base_host:, auth_host:)

    assert_equal 200, auth.response.status
    csrf = auth.response.parsed_body.at_css('meta[name="csrf-token"]')["content"]

    assert_predicate binding.reload.base_confirmed_at, :present?

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

  private

  def bootstrap_social_admission!(base:, auth:, base_host:, auth_host:)
    assert_equal 303, base.response.status

    visa_host = ENV.fetch("PUBLIC_VISA_SERVICE_URL")
    visa = open_session
    authorization_uri = social_authorization_uri!(base:, visa_host:)
    visa.host!(visa_host)
    visa.https!
    visa.get(authorization_uri.request_uri, headers: navigation_headers)

    sentry_uri, binding = social_sentry_and_binding!(visa:, auth_host:)
    auth.host!(auth_host)
    auth.https!
    auth.get(sentry_uri.request_uri, headers: navigation_headers)

    settle_social_admission!(auth:, base:, visa:, base_host:, visa_host:)
    @visa_browser = visa
    binding
  end

  def social_authorization_uri!(base:, visa_host:)
    authorization_uri = URI.parse(jump_rt_url_from_location_for_test(base.response.location))

    assert_equal visa_host, authorization_uri.host
    assert_equal "/oauth/authorize", authorization_uri.path
    authorization_uri
  end

  def social_sentry_and_binding!(visa:, auth_host:)
    assert_equal 303, visa.response.status
    sentry_uri = URI.parse(jump_rt_url_from_location_for_test(visa.response.location))

    assert_equal auth_host, sentry_uri.host
    entry_reference = Rack::Utils.parse_query(sentry_uri.query).fetch("entry_ref")
    binding = BaseAuthAdmissionCoordinator.find_admission_binding!(surface: "app", reference: entry_reference)
    [sentry_uri, binding]
  end

  def settle_social_admission!(auth:, base:, visa:, base_host:, visa_host:)
    current = auth
    8.times do
      break unless current.response.redirect?

      target = URI.parse(jump_rt_url_from_location_for_test(current.response.location))
      receiver = social_admission_receiver(target:, base:, visa:, auth:, base_host:, visa_host:)
      receiver.host!(target.host)
      receiver.get(target.request_uri, headers: navigation_headers)
      current = receiver
    end

    assert_equal auth, current
    assert_equal 200, current.response.status
  end

  def social_admission_receiver(target:, base:, visa:, auth:, base_host:, visa_host:)
    return base if target.host == base_host
    return visa if target.host == visa_host

    auth
  end

  def navigation_headers
    {
      "Sec-Fetch-Mode" => "navigate",
      "Sec-Fetch-Dest" => "document",
      "Sec-Fetch-Site" => "cross-site",
    }
  end

  def base_result_headers(base, visa_host)
    cookie_header = cookie_header_for(@visa_browser || base)
    navigation_headers.merge(
      "Origin" => "https://#{visa_host}",
      "Cookie" => cookie_header,
      "HTTP_COOKIE" => cookie_header,
    )
  end

  def cookie_header_for(browser)
    browser.cookies.to_hash.map { |name, value| "#{name}=#{Rack::Utils.escape(value)}" }.join("; ")
  end

  def oidc_userinfo_result(actor)
    OidcOpUserInfoClient::Result.new(
      success: true,
      claims: { "sub" => OidcSubject.for(actor, resource_type: "client") },
      error: nil,
      dependency_failure: false,
    )
  end
end
