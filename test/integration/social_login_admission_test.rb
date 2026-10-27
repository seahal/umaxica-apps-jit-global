# typed: false
# frozen_string_literal: true

require "test_helper"

class SocialLoginAdmissionTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

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
    # D-47 / D-198: the refusal ends the attempt in place instead of redirecting to /sign/in.
    assert_equal [400, nil, I18n.t("errors.messages.invalid_request")],
                 [auth.response.status, auth.response.location, auth.response.body]
    ceremony = admitted_auth_ceremony_session_for_test(binding.reload)

    assert_not_predicate ceremony, :authentication_evidence_recorded?
    assert_equal "pending", authorization_transaction_for_test(binding).reload.status
  end

  test "A29-6: Sign Up completes while Sign In is blocked without issuing a session" do
    sign_in_feature = FeatureFlags::REGISTRY.fetch(:sign_in_available_app).name
    previous_sign_in_availability = Flipper.enabled?(sign_in_feature)
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
    # The form posts to the action the page itself carries; a hand-built URL would hide a missing
    # flow binding, which the step gate refuses as `flow_binding`.
    page = JSON.parse(Nokogiri::HTML(auth.response.body).at_css("script[data-page='app']").text)
    confirmation_action = page.fetch("props").fetch("action")
    action_query = Rack::Utils.parse_query(URI.parse(confirmation_action).query)

    assert_equal SignFlowBindingCodec.encode(flow: signup, surface: :app), action_query["fb"]
    verifier = Minitest::Mock.new
    verifier.expect(:verify_for_ceremony, { "success" => true }) do |**arguments|
      assert_equal "fixture", arguments.fetch(:token)
      assert_equal signup.public_id, arguments.fetch(:ceremony_id)
      assert_equal "social_signup_confirmation", arguments.fetch(:expected_action)
      assert_equal auth_host, arguments.fetch(:expected_hostname)
      assert_equal signup.public_id, arguments.fetch(:expected_cdata)
      assert_equal :visible, arguments.fetch(:mode)
      true
    end
    # WU-05d P1: the confirmation creates the Flow's one pending Client.
    assert_difference("Client.count", 1) do
      Turnstile::VerifierFactory.stub(:current, verifier) do
        auth.patch(
          confirmation_action,
          params: { :confirm_new_social_identity => "1",
                    :checkpoint_version => signup.checkpoint_version,
                    "cf-turnstile-response" => "fixture", },
          headers: auth_headers.merge("X-CSRF-Token" => csrf),
        )
      end
    end
    verifier.verify

    assert_equal 302, auth.response.status
    fb = Rack::Utils.parse_query(URI.parse(auth.response.location).query).fetch("fb")
    # F3/F4: Auth finalizes; Auth issues no Root.
    Flipper.disable(sign_in_feature)
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
    assert_equal 0, ClientToken.where(user_id: actor.id).count
    assert_nil auth.cookies[AuthenticationBase::ACCESS_COOKIE_KEY]
    assert_nil auth.cookies[AuthenticationBase::REFRESH_COOKIE_KEY]
    ceremony = admitted_auth_ceremony_session_for_test(binding.reload)
    evidence_time = ceremony.authentication_event_at

    assert_equal [true, "google"], [binding.redeemed?, ceremony.authentication_method]
    # S1/S2: the canonical Sign In continues to the original OIDC authorization, where Base issues
    # the one Root for the provider evidence (S3).
    Flipper.enable(sign_in_feature)

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
  ensure
    previous_sign_in_availability ? Flipper.enable(sign_in_feature) : Flipper.disable(sign_in_feature)
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
    # D-47 / D-198: a sign-path refusal ends in place with the uniform response, not a redirect.
    assert_equal [400, I18n.t("errors.messages.invalid_request")], [response.status, response.body]
    assert_predicate session["flash"], :blank?
    assert_equal [true, true], [cookies[AuthenticationBase::ACCESS_COOKIE_KEY].nil?,
                                session[SocialCallbackGuard::SOCIAL_STATE_SESSION_KEY].nil?,]
  end

  # Wedge before the D-47 controller change: whatever the refusal response becomes, a social intent
  # crossing (D-48 L1 at sign-in, L2 at sign-up) never creates an account, identity, Sign-up Flow,
  # session or Auth evidence, and ends the social intent.
  test "D-48 L1: an unknown Google subject started at sign-in creates nothing and records no evidence" do
    outcome = google_intent_crossing!(registered: false, sign_up: false)

    assert_equal [0, 0, 0, 0], outcome.fetch(:created)
    assert_not_predicate outcome.fetch(:ceremony), :authentication_evidence_recorded?
    assert_equal "pending", outcome.fetch(:transaction_status)
    assert_not outcome.fetch(:social_state_remaining)
  end

  test "D-48 L2: a registered Google subject started at sign-up creates nothing and ends the social intent" do
    outcome = google_intent_crossing!(registered: true, sign_up: true)

    assert_equal [0, 0, 0, 0], outcome.fetch(:created)
    assert_not_predicate outcome.fetch(:ceremony), :authentication_evidence_recorded?
    assert_equal "pending", outcome.fetch(:transaction_status)
    assert_not outcome.fetch(:social_state_remaining)
  end

  # D-47: one uniform refusal, so the response cannot reveal whether a provider account is registered.
  test "D-47: the sign-in/unknown and sign-up/registered crossings return the same response" do
    unknown = google_intent_crossing!(registered: false, sign_up: false)
    registered = google_intent_crossing!(registered: true, sign_up: true)

    assert_equal unknown.fetch(:response), registered.fetch(:response)
  end

  # D-198 (2): a provider failure on the sign path ends the attempt, so the browser cannot start a
  # second social ceremony inside the same admission.
  test "D-198: an OmniAuth state failure on the sign path ends the attempt with the uniform refusal" do
    auth, _binding, csrf = admitted_social_browser!(sign_up: true)
    auth.post(
      auth_app_social_google_registration_path, params: { ri: "jp" },
                                                headers: auth_origin_headers.merge("X-CSRF-Token" => csrf),
    )

    assert_equal 307, auth.response.status
    auth.get(auth_app_social_failure_path(message: "csrf_detected", strategy: "google"), headers: auth_origin_headers)

    assert_equal [400, nil, I18n.t("errors.messages.invalid_request")],
                 [auth.response.status, auth.response.location, auth.response.body]
    assert_not auth.session.key?(SocialCallbackGuard::SOCIAL_STATE_SESSION_KEY)
    assert_predicate auth.cookies["auth_sid"].to_s, :empty?
  end

  # D-198 (3): one Sign-up Flow per admission; a second social start is refused before the insert.
  test "D-198: a second social start inside one sign-up admission is refused without a new Flow" do
    auth, binding, csrf = admitted_social_browser!(sign_up: true)
    headers = auth_origin_headers.merge("X-CSRF-Token" => csrf)
    auth.post(auth_app_social_google_registration_path, params: { ri: "jp" }, headers:)

    assert_equal 307, auth.response.status
    assert_no_difference("ClientSignUpFlow.count") do
      auth.post(auth_app_social_google_registration_path, params: { ri: "jp" }, headers:)
    end
    assert_equal [400, nil, I18n.t("errors.messages.invalid_request")],
                 [auth.response.status, auth.response.location, auth.response.body]
    assert_equal 1, ClientSignUpFlow.where(auth_admission_binding_id: binding.id).count
  end

  private

  def google_intent_crossing!(registered:, sign_up:)
    subject = "crossing-social-#{SecureRandom.hex(8)}"
    register_google_subject!(subject) if registered
    auth, binding, csrf = admitted_social_browser!(sign_up:)
    OmniAuth.config.mock_auth[:google] = OmniAuth::AuthHash.new(
      provider: "google", uid: subject, info: { name: "Provider fixture" },
      credentials: { token: "provider-fixture", expires_at: 1.hour.from_now.to_i },
    )
    start_path = sign_up ? auth_app_social_google_registration_path : auth_app_social_google_session_path
    auth.post(start_path, params: { ri: "jp" }, headers: auth_origin_headers.merge("X-CSRF-Token" => csrf))

    assert_equal 307, auth.response.status
    state = auth.session.fetch(SocialCallbackGuard::SOCIAL_STATE_SESSION_KEY)
    counted = [Client, ClientGoogleIdentity, ClientSignUpFlow, ClientToken]
    before = counted.map(&:count)
    auth.get(auth_app_social_google_callback_path, params: { state:, ri: "jp" }, headers: auth_origin_headers)

    {
      created: counted.map(&:count).zip(before).map { |after, earlier| after - earlier },
      ceremony: admitted_auth_ceremony_session_for_test(binding.reload),
      transaction_status: authorization_transaction_for_test(binding).reload.status,
      social_state_remaining: auth.session.key?(SocialCallbackGuard::SOCIAL_STATE_SESSION_KEY),
      response: [auth.response.status, auth.response.location && URI.parse(auth.response.location).path,
                 auth.response.body,],
    }
  end

  def register_google_subject!(subject)
    actor = Client.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE,
      birthdate: "2000-01-01",
    )
    ClientGoogleIdentity.create!(
      user: actor, uid: subject, provider: "google", status_id: ClientGoogleIdentityStatus::ACTIVE,
    )
  end

  # Returns the Auth browser admitted on the requested entry intent, its binding and CSRF token.
  def admitted_social_browser!(sign_up:)
    base = open_session
    auth = open_session
    base_host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    auth_host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    base.host!(base_host)
    base.https!
    base.get("/sign", params: { ri: "jp" })
    entry_form = Nokogiri::HTML(base.response.body).at_css("form")
    entry_fields = entry_form.css("input[name]").to_h { |input| [input["name"], input["value"]] }
    base.post(
      entry_form["action"], params: entry_fields,
                            headers: { "Origin" => "https://#{base_host}", "Sec-Fetch-Site" => "same-origin" },
    )
    binding = bootstrap_social_admission!(base:, auth:, base_host:, auth_host:)
    csrf = auth.response.parsed_body.at_css('meta[name="csrf-token"]')["content"]
    return [auth, binding, csrf] unless sign_up

    switch_browser_to_sign_up!(auth, base_browser: base)
    binding = binding.class.where(
      authorization_transaction_id: binding.authorization_transaction_id, entry_intent: "sign_up",
    ).order(:id).last
    auth.host!(auth_host)
    [auth, binding, auth.response.parsed_body.at_css(%q(meta[name="csrf-token"]))&.[]("content") || csrf]
  end

  def auth_origin_headers
    { "Origin" => "https://#{ENV.fetch("PUBLIC_AUTH_SERVICE_URL")}", "Sec-Fetch-Site" => "same-origin" }
  end

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
