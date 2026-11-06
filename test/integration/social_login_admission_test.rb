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
    assert_nil auth.session[SocialAuth::SOCIAL_ADMISSION_CEREMONY_SESSION_ID_SESSION_KEY]
    ceremony = admitted_auth_ceremony_session_for_test(binding.reload)

    assert_predicate ceremony, :authentication_evidence_recorded?
    assert_equal "google", ceremony.authentication_method
    assert_equal [true, true], [auth.cookies[AuthenticationBase::ACCESS_COOKIE_KEY].nil?,
                                auth.cookies[AuthenticationBase::REFRESH_COOKIE_KEY].nil?,]
    assert_equal "pending", authorization_transaction_for_test(binding).reload.status_name

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

    assert_equal 200, auth.response.status
    form = auth.response.parsed_body.at_css("form#visa-authorization-continuation-form")

    assert form, "Visa result GET must render a POST continuation"
    fields = form.css("input[name]").to_h { |input| [input["name"], input["value"]] }
    auth.post(
      form["action"], params: fields, headers: {
        "Origin" => "https://#{result.host}",
        "Sec-Fetch-Site" => "same-origin",
        "Sec-Fetch-Mode" => "navigate",
        "Sec-Fetch-Dest" => "document",
      },
    )

    assert_equal before_root_count + 1, ClientToken.where(user_id: actor.id).count,
                 "Visa result did not issue the root: #{auth.response.status} #{auth.response.location}"

    assert_equal 303, auth.response.status
    receiver = URI.parse(jump_rt_url_from_location_for_test(auth.response.location))

    assert_equal base_host, receiver.host
    base.host!(base_host)
    base.get(receiver.request_uri, headers: base_headers)

    assert_response :redirect
    token = ClientToken.find_by!(user_id: actor.id)

    assert_equal [ceremony.authentication_event_at, "google"],
                 [token.authentication_event_at, token.established_authentication_method]
    assert_equal [true, token.public_id, true],
                 [token.root_login_established_at.present?,
                  authorization_transaction_for_test(binding).reload.browser_session_ref,
                  authorization_transaction_for_test(binding).consumed?,]
    grant = OpAppGrant.find_by!(client_token_id: token.id)

    assert_equal "base-app-ww", grant.oidc_client_id
    assert_social_rp_dashboard(base)
  end

  test "AC-53: a Google callback for another auth_sid is refused before state or ceremony writes" do
    subject = "sid-conflict-social-#{SecureRandom.hex(8)}"
    actor = Client.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE,
      birthdate: "2000-01-01",
    )
    ClientGoogleIdentity.create!(user: actor, uid: subject, provider: "google", status_id: ClientGoogleIdentityStatus::ACTIVE)
    auth_host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    auth_headers = {
      "Origin" => "https://#{auth_host}",
      "Sec-Fetch-Site" => "same-origin",
    }
    navigation_headers = {
      "Sec-Fetch-Mode" => "navigate",
      "Sec-Fetch-Dest" => "document",
      "Sec-Fetch-Site" => "cross-site",
    }
    oidc_client = OidcClientRegistry.find!("core-app-jp")
    redirect_uri = oidc_client.redirect_uris_by_realm.fetch("client").first
    code_challenge = "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM"
    oidc_params_a = {
      client_id: "core-app-jp",
      response_type: "code",
      scope: "openid profile",
      redirect_uri:,
      state: SecureRandom.hex(8),
      nonce: SecureRandom.hex(8),
      code_challenge:,
      code_challenge_method: "S256",
      prompt: nil,
    }
    transaction_a = OidcAuthorizationTransactionCoordinator.issue!(
      surface: "app", intent: "sign_in", params: oidc_params_a,
    ).transaction
    handoff_a = BaseAuthAdmissionCoordinator.issue_handoff!(
      transaction: transaction_a, base_browser_nonce: SecureRandom.urlsafe_base64(32), base_token: nil,
    )
    auth_a = open_session
    auth_a.host!(auth_host)
    auth_a.https!
    admission_statuses_a = []
    auth_a.get("/sign/in", params: { entry_ref: handoff_a.reference, ri: "jp" }, headers: navigation_headers)
    admission_statuses_a << auth_a.response.status
    auth_a.get(auth_a.response.location, headers: navigation_headers)
    admission_statuses_a << auth_a.response.status
    binding_a = ClientAuthAdmissionBinding.find_by!(authorization_transaction_id: transaction_a.id)
    binding_a.confirm_base!(base_token: nil, browser_digest: binding_a.base_browser_digest)
    auth_a.host!(auth_host)
    auth_a.https!
    auth_a.get("/sign/in", params: { entry_ref: handoff_a.reference, ri: "jp" }, headers: navigation_headers)
    admission_statuses_a << auth_a.response.status
    auth_a.get("/sign/in", params: { ri: "jp" }, headers: navigation_headers)
    admission_statuses_a << auth_a.response.status
    csrf = Nokogiri::HTML(auth_a.response.body).at_css('meta[name="csrf-token"]')["content"]

    oidc_params_b = {
      client_id: "core-app-jp",
      response_type: "code",
      scope: "openid profile",
      redirect_uri:,
      state: SecureRandom.hex(8),
      nonce: SecureRandom.hex(8),
      code_challenge:,
      code_challenge_method: "S256",
      prompt: nil,
    }
    transaction_b = OidcAuthorizationTransactionCoordinator.issue!(
      surface: "app", intent: "sign_in", params: oidc_params_b,
    ).transaction
    handoff_b = BaseAuthAdmissionCoordinator.issue_handoff!(
      transaction: transaction_b, base_browser_nonce: SecureRandom.urlsafe_base64(32), base_token: nil,
    )
    auth_b = open_session
    auth_b.host!(auth_host)
    auth_b.https!
    admission_statuses_b = []
    auth_b.get("/sign/in", params: { entry_ref: handoff_b.reference, ri: "jp" }, headers: navigation_headers)
    admission_statuses_b << auth_b.response.status
    auth_b.get(auth_b.response.location, headers: navigation_headers)
    admission_statuses_b << auth_b.response.status
    binding_b = ClientAuthAdmissionBinding.find_by!(authorization_transaction_id: transaction_b.id)
    binding_b.confirm_base!(base_token: nil, browser_digest: binding_b.base_browser_digest)
    auth_b.host!(auth_host)
    auth_b.https!
    auth_b.get("/sign/in", params: { entry_ref: handoff_b.reference, ri: "jp" }, headers: navigation_headers)
    admission_statuses_b << auth_b.response.status
    auth_b.get("/sign/in", params: { ri: "jp" }, headers: navigation_headers)
    admission_statuses_b << auth_b.response.status

    ceremony_a = ClientAuthCeremonySession.find(binding_a.reload.admitted_auth_ceremony_session_id)
    ceremony_b = ClientAuthCeremonySession.find(binding_b.reload.admitted_auth_ceremony_session_id)

    assert_equal [303, 303, 303, 200], admission_statuses_a
    assert_equal [303, 303, 303, 200], admission_statuses_b
    assert_not_equal ceremony_a.id, ceremony_b.id

    OmniAuth.config.mock_auth[:google] = OmniAuth::AuthHash.new(
      provider: "google", uid: subject, info: { name: "Provider fixture" },
      credentials: { token: "provider-fixture", expires_at: 1.hour.from_now.to_i },
    )
    auth_a.post(
      auth_app_social_google_session_path,
      params: { ri: "jp" },
      headers: auth_headers.merge("X-CSRF-Token" => csrf),
    )

    assert_equal 307, auth_a.response.status
    state = auth_a.session.fetch(SocialCallbackGuard::SOCIAL_STATE_SESSION_KEY)
    callback_state = ClientOauthCallbackState.find_by!(
      state_digest: ClientOauthCallbackState.digest_state(state),
    )

    cookie_name = JitSessionCookieConfig.force_secure? ? "__Host-auth_sid" : "auth_sid"
    auth_sid_b = auth_b.cookies[cookie_name]
    expected_cookie_line = "#{cookie_name}=#{Rack::Utils.escape(auth_sid_b)}"

    assert_equal [nil, [expected_cookie_line], auth_sid_b], [callback_state.consumed_at,
                                                             auth_a.cookies.merge(
                                                               expected_cookie_line,
                                                               URI.parse("https://#{auth_host}/"),
                                                             ),
                                                             auth_a.cookies[cookie_name],]
    ceremony_a_before = ceremony_a.reload.attributes
    ceremony_b_before = ceremony_b.reload.attributes
    client_tokens_before = ClientToken.count
    forbidden_response_names =
      (AuthPhaseRefusalResponseBoundary::COOKIE_NAMES + AuthPhaseRefusalResponseBoundary::DBSC_HEADERS).map(&:downcase)

    auth_a.get(
      auth_app_social_failure_path(message: "access_denied", strategy: "google"),
      headers: auth_headers,
    )

    assert_equal [
      409, nil, I18n.t("errors.messages.phase_violation_refused"), "private, no-store",
    ], [auth_a.response.status, auth_a.response.location, auth_a.response.body,
        auth_a.response.headers["Cache-Control"],]
    failure_cookie_names =
      Array(auth_a.response.headers["Set-Cookie"]).flat_map { |header| header.to_s.split("\n") }
        .map { |header| header.split("=", 2).first }
    failure_response_names = failure_cookie_names + auth_a.response.headers.to_h.keys.map(&:downcase)

    assert_empty forbidden_response_names & failure_response_names
    assert_equal [nil, ceremony_a_before, ceremony_b_before, client_tokens_before, state, ceremony_a.id.to_s], [
      callback_state.reload.consumed_at,
      ceremony_a.reload.attributes,
      ceremony_b.reload.attributes,
      ClientToken.count,
      auth_a.session[SocialCallbackGuard::SOCIAL_STATE_SESSION_KEY],
      auth_a.session[SocialAuth::SOCIAL_ADMISSION_CEREMONY_SESSION_ID_SESSION_KEY],
    ]

    auth_a.get(auth_app_social_google_callback_path, params: { state:, ri: "jp" }, headers: auth_headers)

    assert_equal [
      409, nil, I18n.t("errors.messages.phase_violation_refused"), "private, no-store",
    ], [auth_a.response.status, auth_a.response.location, auth_a.response.body,
        auth_a.response.headers["Cache-Control"],]
    callback_cookie_names =
      Array(auth_a.response.headers["Set-Cookie"]).flat_map { |header| header.to_s.split("\n") }
        .map { |header| header.split("=", 2).first }
    callback_response_names = callback_cookie_names + auth_a.response.headers.to_h.keys.map(&:downcase)

    assert_empty forbidden_response_names & callback_response_names
    assert_equal [nil, ceremony_a_before, ceremony_b_before, client_tokens_before, state, ceremony_a.id.to_s], [
      callback_state.reload.consumed_at,
      ceremony_a.reload.attributes,
      ceremony_b.reload.attributes,
      ClientToken.count,
      auth_a.session[SocialCallbackGuard::SOCIAL_STATE_SESSION_KEY],
      auth_a.session[SocialAuth::SOCIAL_ADMISSION_CEREMONY_SESSION_ID_SESSION_KEY],
    ]
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
    assert_equal "pending", authorization_transaction_for_test(binding).reload.status_name

    auth.get(auth_app_sign_oidc_handoff_path, params: { ri: "jp" }, headers: navigation_headers)

    assert_equal 303, auth.response.status
    result = URI.parse(jump_rt_url_from_location_for_test(auth.response.location))

    assert_equal ENV.fetch("PUBLIC_VISA_SERVICE_URL"), result.host
    assert_equal "/oidc/result", result.path
    assert_difference(-> { ClientToken.where(user_id: actor.id).count }, 1) do
      auth.host!(result.host)
      auth.https!
      auth.get(result.request_uri, headers: base_result_headers(base, result.host))

      assert_equal 200, auth.response.status
      form = auth.response.parsed_body.at_css("form#visa-authorization-continuation-form")

      assert form, "Visa result GET must render a POST continuation"
      fields = form.css("input[name]").to_h { |input| [input["name"], input["value"]] }
      auth.post(
        form["action"], params: fields, headers: {
          "Origin" => "https://#{result.host}",
          "Sec-Fetch-Site" => "same-origin",
          "Sec-Fetch-Mode" => "navigate",
          "Sec-Fetch-Dest" => "document",
        },
      )
    end

    assert_equal 303, auth.response.status
    receiver = URI.parse(jump_rt_url_from_location_for_test(auth.response.location))

    assert_equal base_host, receiver.host
    base.host!(base_host)
    base.get(receiver.request_uri, headers: base_headers)

    assert_response :redirect
    token = ClientToken.find_by!(user_id: actor.id)

    assert_equal [ceremony.authentication_event_at, "apple"],
                 [token.authentication_event_at, token.established_authentication_method]
    assert_equal [true, token.public_id, true],
                 [token.root_login_established_at.present?,
                  authorization_transaction_for_test(binding).reload.browser_session_ref,
                  authorization_transaction_for_test(binding).consumed?,]
    grant = OpAppGrant.find_by!(client_token_id: token.id)

    assert_equal "base-app-ww", grant.oidc_client_id
    assert_social_rp_dashboard(base)
  end
  test "an existing Google subject started at signup is refused without Auth evidence or Root" do
    actor = Client.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE,
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
    # D-48 L2: a verified registered subject under a sign-up intent gets only a fresh RP entry.
    assert_equal 400, auth.response.status
    assert_nil auth.response.location
    assert_equal "private, no-store", auth.response.headers["Cache-Control"]
    assert_equal "strict-origin", auth.response.headers["Referrer-Policy"]
    guidance = Nokogiri::HTML(auth.response.body)

    assert_equal I18n.t("sign.app.social.verified_subject_guidance.registered.title"), guidance.at_css("h1").text
    assert_includes guidance.text, I18n.t("sign.app.social.verified_subject_guidance.registered.body")
    fresh_start = URI.parse(guidance.at_css("a")["href"])

    assert_equal [base_host, "/sign", { "ri" => "jp" }],
                 [fresh_start.host, fresh_start.path, Rack::Utils.parse_query(fresh_start.query)]
    assert_nil auth.session[SocialCallbackGuard::SOCIAL_STATE_SESSION_KEY]
    assert_nil auth.session[SocialAuth::SOCIAL_ENTRY_SESSION_KEY]
    ceremony = ClientAuthCeremonySession.find(binding.reload.admitted_auth_ceremony_session_id)

    assert_not_predicate ceremony, :authentication_evidence_recorded?
    assert_equal "pending",
                 ClientOidcAuthorizationTransaction.find(binding.reload.authorization_transaction_id).status_name
  end

  test "a verified unregistered Google subject at sign-in receives only a fresh sign-up entry" do
    subject = "unregistered-social-#{SecureRandom.hex(8)}"
    base = self
    auth = open_session
    auth_host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    base_host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    visa_host = ENV.fetch("PUBLIC_VISA_SERVICE_URL")
    auth_headers = { "Origin" => "https://#{auth_host}", "Sec-Fetch-Site" => "same-origin" }
    navigation = {
      "Sec-Fetch-Mode" => "navigate",
      "Sec-Fetch-Dest" => "document",
      "Sec-Fetch-Site" => "cross-site",
    }

    base.host!(base_host)
    base.https!
    base.get("/sign", params: { ri: "jp" })
    entry_form = Nokogiri::HTML(base.response.body).at_css("form")
    entry_fields = entry_form.css("input[name]").to_h { |input| [input["name"], input["value"]] }
    base.post(
      entry_form["action"], params: entry_fields,
                            headers: { "Origin" => "https://#{base_host}", "Sec-Fetch-Site" => "same-origin" },
    )

    base_jump = URI.parse(base.response.location)
    base_target =
      if base_jump.host == visa_host
        base_jump
      else
        base_rt = Rack::Utils.parse_query(base_jump.query).fetch("rt")
        URI.parse(JWT.decode(base_rt, nil, false).first.fetch("url"))
      end

    assert_equal [visa_host, "/oauth/authorize"], [base_target.host, base_target.path]
    visa = open_session
    visa.host!(visa_host)
    visa.https!
    visa.get(base_target.request_uri, headers: navigation)

    visa_jump = URI.parse(visa.response.location)
    sentry_uri =
      if visa_jump.host == auth_host
        visa_jump
      else
        visa_rt = Rack::Utils.parse_query(visa_jump.query).fetch("rt")
        URI.parse(JWT.decode(visa_rt, nil, false).first.fetch("url"))
      end

    assert_equal auth_host, sentry_uri.host
    entry_ref = Rack::Utils.parse_query(sentry_uri.query).fetch("entry_ref")
    binding = BaseAuthAdmissionCoordinator.find_admission_binding!(surface: "app", reference: entry_ref)

    auth.host!(auth_host)
    auth.https!
    auth.get(sentry_uri.request_uri, headers: navigation)
    current = auth
    8.times do
      break unless current.response.redirect?

      location = URI.parse(current.response.location)
      target =
        if [base_host, visa_host, auth_host].include?(location.host)
          location
        else
          jump_rt = Rack::Utils.parse_query(location.query).fetch("rt")
          URI.parse(JWT.decode(jump_rt, nil, false).first.fetch("url"))
        end
      receiver =
        case target.host
        when base_host then base
        when visa_host then visa
        when auth_host then auth
        else raise ArgumentError, "unexpected social admission host"
        end
      receiver.host!(target.host)
      receiver.get(target.request_uri, headers: navigation)
      current = receiver
    end

    assert_equal auth, current
    assert_equal 200, auth.response.status
    assert_predicate binding.reload.base_confirmed_at, :present?
    assert_predicate binding.reload, :redeemed?
    csrf = auth.response.parsed_body.at_css('meta[name="csrf-token"]')["content"]

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
    assert_no_difference(
      ["Client.count", "ClientGoogleIdentity.count", "ClientSignUpFlow.count",
       "ClientToken.count",],
    ) do
      auth.get(auth_app_social_google_callback_path, params: { state:, ri: "jp" }, headers: auth_headers)
    end

    assert_equal 400, auth.response.status
    assert_nil auth.response.location
    guidance = Nokogiri::HTML(auth.response.body)

    assert_equal I18n.t("sign.app.social.verified_subject_guidance.unregistered.title"),
                 guidance.at_css("h1").text
    assert_includes guidance.text, I18n.t("sign.app.social.verified_subject_guidance.unregistered.body")
    fresh_start = URI.parse(guidance.at_css("a")["href"])

    assert_equal [base_host, "/sign", { "ri" => "jp" }],
                 [fresh_start.host, fresh_start.path, Rack::Utils.parse_query(fresh_start.query)]
    assert_nil auth.session[SocialCallbackGuard::SOCIAL_STATE_SESSION_KEY]
    assert_nil auth.session[SocialAuth::SOCIAL_ENTRY_SESSION_KEY]
    admitted_ceremony = ClientAuthCeremonySession.find(binding.reload.admitted_auth_ceremony_session_id)

    assert_not_predicate admitted_ceremony, :authentication_evidence_recorded?
  end

  %w(google apple).each do |provider|
    test "A29-6: #{provider} Sign Up completes and then signs in to the original RP" do
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
      OmniAuth.config.mock_auth[provider.to_sym] = OmniAuth::AuthHash.new(
        provider: provider, uid: subject, info: { name: "Provider fixture" },
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
        "/social/#{provider}/registration", params: { ri: "jp" },
                                            headers: auth_headers.merge("X-CSRF-Token" => csrf),
      )

      assert_equal 307, auth.response.status
      state = auth.session.fetch(SocialCallbackGuard::SOCIAL_STATE_SESSION_KEY)
      assert_no_difference("Client.count") do
        assert_no_difference("ClientExternalIdentity.count") do
          auth.get("/social/#{provider}/callback", params: { state:, ri: "jp" }, headers: auth_headers)
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

      pending_actor = Client.find(signup.reload.principal_id)

      assert_equal [ClientStatus::UNVERIFIED_WITH_SIGN_UP, false, false, 0],
                   [pending_actor.status_id, pending_actor.sign_in_allowed?,
                    ClientExternalIdentity.exists?(client_id: pending_actor.id),
                    ClientToken.where(user_id: pending_actor.id).count,]

      assert_equal 302, auth.response.status
      fb = Rack::Utils.parse_query(URI.parse(auth.response.location).query).fetch("fb")
      # F3/F4: Auth finalizes; Auth issues no Root.
      Flipper.disable(sign_in_feature)
      assert_no_difference(["Client.count", "ClientToken.count"]) do
        assert_difference("ClientExternalIdentity.count", 1) do
          auth.patch(
            "/sign/up/check/#{provider}/birthdate?#{{ ri: "jp", fb: }.to_query}",
            params: { requirement: "birthdate",
                      birthdate: "2000-02-03",
                      checkpoint_version: signup.reload.checkpoint_version, },
            headers: auth_headers.merge("X-CSRF-Token" => csrf),
          )
        end
      end
      identity = ClientExternalIdentity.find_by!(provider: provider, subject:)
      actor = Client.find(identity.client_id)

      assert_equal [actor.id, true, true, nil],
                   [signup.reload.principal_id, signup.completed?, ClientIdentity.exists?(source_record_id: actor.id),
                    base.cookies[AuthenticationBase::ACCESS_COOKIE_KEY],]
      assert_equal 0, ClientToken.where(user_id: actor.id).count
      assert_nil auth.cookies[AuthenticationBase::ACCESS_COOKIE_KEY]
      assert_nil auth.cookies[AuthenticationBase::REFRESH_COOKIE_KEY]
      ceremony = admitted_auth_ceremony_session_for_test(binding.reload)
      evidence_time = ceremony.authentication_event_at

      assert_equal [true, provider], [binding.redeemed?, ceremony.authentication_method]
      # S1/S2: the canonical Sign In continues to the original OIDC authorization, where Base issues
      # the one Root for the provider evidence (S3).
      Flipper.enable(sign_in_feature)

      assert_difference(-> { ClientToken.where(user_id: actor.id).count }, 1) do
        drive_browser_through_continuations!(auth, base_browser: base)
      end
      token = ClientToken.find_by!(user_id: actor.id)

      assert_equal [true, true, 200, "/dashboard"],
                   [base.cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE].present?,
                    base.cookies[OidcRpBrowserCredentialContract::REFRESH_COOKIE].present?,
                    base.response.status, base.request.path,]

      assert_equal [evidence_time, provider, true, token.public_id, true],
                   [token.authentication_event_at, token.established_authentication_method,
                    token.root_login_established_at.present?,
                    authorization_transaction_for_test(binding).reload.browser_session_ref,
                    authorization_transaction_for_test(binding).consumed?,]
    ensure
      previous_sign_in_availability ? Flipper.enable(sign_in_feature) : Flipper.disable(sign_in_feature)
    end
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
                  authorization_transaction_for_test(binding).reload.status_name,]
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
    outcome = social_intent_crossing!(provider: "google", registered: false, sign_up: false)

    assert_equal [0, 0, 0, 0], outcome.fetch(:created)
    assert_not_predicate outcome.fetch(:ceremony), :authentication_evidence_recorded?
    assert_equal "pending", outcome.fetch(:transaction_status)
    assert_not outcome.fetch(:social_state_remaining)
  end

  test "D-48 L2: a registered Google subject started at sign-up creates nothing and ends the social intent" do
    outcome = social_intent_crossing!(provider: "google", registered: true, sign_up: true)

    assert_equal [0, 0, 0, 0], outcome.fetch(:created)
    assert_not_predicate outcome.fetch(:ceremony), :authentication_evidence_recorded?
    assert_equal "pending", outcome.fetch(:transaction_status)
    assert_not outcome.fetch(:social_state_remaining)
  end

  # R-AU-23: a verified provider subject gets guidance for the correct entry without reusing the attempt.
  test "R-AU-23: verified social subject crossings receive the correct fresh-entry guidance" do
    unknown = social_intent_crossing!(provider: "google", registered: false, sign_up: false)
    registered = social_intent_crossing!(provider: "google", registered: true, sign_up: true)

    unknown_response = unknown.fetch(:response)
    registered_response = registered.fetch(:response)

    assert_equal [400, nil], unknown_response.first(2)
    assert_equal [400, nil], registered_response.first(2)
    assert_equal I18n.t("sign.app.social.verified_subject_guidance.unregistered.title"),
                 Nokogiri::HTML(unknown_response.last).at_css("h1").text
    assert_equal I18n.t("sign.app.social.verified_subject_guidance.registered.title"),
                 Nokogiri::HTML(registered_response.last).at_css("h1").text
    assert_not_equal unknown_response.last, registered_response.last
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

  test "R-AU-49: Back after a social dispatch keeps the first page and permits Switch before callback" do
    auth, binding, csrf = admitted_social_browser!(sign_up: true)
    headers = auth_origin_headers.merge("X-CSRF-Token" => csrf)
    assert_no_difference("ClientSignUpFlow.count") do
      auth.post(auth_app_social_google_registration_path, params: { ri: "jp" }, headers:)
    end

    assert_equal 307, auth.response.status
    state = auth.session.fetch(SocialCallbackGuard::SOCIAL_STATE_SESSION_KEY)

    auth.get(auth_app_sign_up_path(ri: "jp"), headers: navigation_headers)

    assert_equal 200, auth.response.status
    props = JSON.parse(Nokogiri::HTML(auth.response.body).at_css("script[data-page='app']").text).fetch("props")

    assert_equal "sign_in", props.fetch("switch_form").fetch("to")
    assert_equal "/sign/cancellation?ri=jp", props.fetch("cancel_form").fetch("action")
    switch_form = props.fetch("switch_form")

    auth.post(
      switch_form.fetch("action"), params: { to: switch_form.fetch("to"),
                                             authenticity_token: switch_form.fetch("authenticity_token"), },
                                   headers: auth_origin_headers.merge(
                                     "X-CSRF-Token" => switch_form.fetch("authenticity_token"),
                                   ),
    )

    assert_equal 303, auth.response.status
    assert_equal 0, ClientSignUpFlow.where(auth_admission_binding_id: binding.id).count
    assert_no_difference("ClientSignUpFlow.count") do
      auth.get(auth_app_social_google_callback_path, params: { state:, ri: "jp" }, headers: auth_origin_headers)
    end
    assert_equal 409, auth.response.status
  end

  test "R-AU-49: a fresh social dispatch replaces state and a stale callback leaves it usable" do
    auth, binding, csrf = admitted_social_browser!(sign_up: true)
    headers = auth_origin_headers.merge("X-CSRF-Token" => csrf)
    auth.post(auth_app_social_google_registration_path, params: { ri: "jp" }, headers:)

    assert_equal 307, auth.response.status
    old_state = auth.session.fetch(SocialCallbackGuard::SOCIAL_STATE_SESSION_KEY)

    assert_equal "google", auth.session[SocialCallbackGuard::SOCIAL_STATE_PROVIDER_SESSION_KEY]
    assert_equal 0, ClientSignUpFlow.where(auth_admission_binding_id: binding.id).count

    auth.get(auth_app_sign_up_path(ri: "jp"), headers: navigation_headers)

    assert_equal 200, auth.response.status
    retry_csrf = Nokogiri::HTML(auth.response.body).at_css('meta[name="csrf-token"]')["content"]
    assert_no_difference("ClientSignUpFlow.count") do
      auth.post(
        auth_app_social_google_registration_path, params: { ri: "jp" },
                                                  headers: auth_origin_headers.merge("X-CSRF-Token" => retry_csrf),
      )
    end

    assert_equal 307, auth.response.status
    current_state = auth.session.fetch(SocialCallbackGuard::SOCIAL_STATE_SESSION_KEY)

    assert_not_equal old_state, current_state
    assert_equal "google", auth.session[SocialCallbackGuard::SOCIAL_STATE_PROVIDER_SESSION_KEY]
    old_callback_state = ClientOauthCallbackState.find_by!(
      state_digest: ClientOauthCallbackState.digest_state(old_state),
    )

    assert_predicate old_callback_state.reload.consumed_at, :present?

    assert_no_difference("ClientSignUpFlow.count") do
      auth.get(
        auth_app_social_google_callback_path, params: { state: old_state, ri: "jp" },
                                              headers: auth_origin_headers,
      )
    end
    assert_equal 403, auth.response.status
    assert_equal current_state, auth.session[SocialCallbackGuard::SOCIAL_STATE_SESSION_KEY]
    assert_equal "google", auth.session[SocialCallbackGuard::SOCIAL_STATE_PROVIDER_SESSION_KEY]

    OmniAuth.config.mock_auth[:google] = OmniAuth::AuthHash.new(
      provider: "google", uid: "restart-social-#{SecureRandom.hex(8)}", info: { name: "Provider fixture" },
      credentials: { token: "provider-fixture", expires_at: 1.hour.from_now.to_i },
    )
    assert_difference("ClientSignUpFlow.count", 1) do
      auth.get(
        auth_app_social_google_callback_path, params: { state: current_state, ri: "jp" },
                                              headers: auth_origin_headers,
      )
    end

    assert_equal 302, auth.response.status
    flow = ClientSignUpFlow.find_by!(auth_admission_binding_id: binding.id)

    assert_equal "google", flow.social_provider
    assert_equal ClientSignUpFlowStatus::CHECKPOINT_PENDING, flow.status_id
  end

  test "R-AU-49: replay from a pre-restart cookie cannot overwrite the replacement session" do
    auth, _binding, csrf = admitted_social_browser!(sign_up: true)
    auth_uri = URI.parse("https://#{ENV.fetch("PUBLIC_AUTH_SERVICE_URL")}/")
    headers = auth_origin_headers.merge("X-CSRF-Token" => csrf)

    auth.post(auth_app_social_google_registration_path, params: { ri: "jp" }, headers:)

    assert_equal 307, auth.response.status
    stale_cookie = auth.cookies.for(auth_uri)
    stale_state = auth.session.fetch(SocialCallbackGuard::SOCIAL_STATE_SESSION_KEY)

    auth.get(auth_app_sign_up_path(ri: "jp"), headers: navigation_headers)
    retry_csrf = Nokogiri::HTML(auth.response.body).at_css('meta[name="csrf-token"]')["content"]
    auth.post(
      auth_app_social_google_registration_path, params: { ri: "jp" },
                                                headers: auth_origin_headers.merge("X-CSRF-Token" => retry_csrf),
    )

    assert_equal 307, auth.response.status
    current_cookie = auth.cookies.for(auth_uri)
    current_state = auth.session.fetch(SocialCallbackGuard::SOCIAL_STATE_SESSION_KEY)

    assert_not_equal stale_state, current_state

    auth.get(
      auth_app_social_google_callback_path, params: { state: stale_state, ri: "jp" },
                                            headers: auth_origin_headers.merge("Cookie" => stale_cookie),
    )

    assert_equal 403, auth.response.status
    assert_equal current_cookie, auth.cookies.for(auth_uri),
                 "a stale callback response must not replace the browser's newer session cookie"

    auth.get(auth_app_sign_up_path(ri: "jp"), headers: navigation_headers)

    assert_equal 200, auth.response.status
    assert_equal current_state, auth.session[SocialCallbackGuard::SOCIAL_STATE_SESSION_KEY]
  end

  test "R-AU-49: a verified callback cannot replace an Email or Telephone Flow on admission" do
    prior_test_mode = OmniAuth.config.test_mode
    prior_mock = OmniAuth.config.mock_auth[:google]
    OmniAuth.config.test_mode = true
    OmniAuth.config.mock_auth[:google] = OmniAuth::AuthHash.new(
      provider: "google", uid: "existing-local-flow-#{SecureRandom.hex(8)}", info: { name: "Provider fixture" },
      credentials: { token: "provider-fixture", expires_at: 1.hour.from_now.to_i },
    )
    %w(email telephone).each do |entry_method|
      auth, binding, csrf = admitted_social_browser!(sign_up: true)
      auth.post(
        auth_app_social_google_registration_path, params: { ri: "jp" },
                                                  headers: auth_origin_headers.merge("X-CSRF-Token" => csrf),
      )

      assert_equal 307, auth.response.status
      state = auth.session.fetch(SocialCallbackGuard::SOCIAL_STATE_SESSION_KEY)
      ceremony = ClientAuthCeremonySession.find(binding.admitted_auth_ceremony_session_id)
      local_flow = SignUpCycleLocator.new(auth.session, surface: :app, cycle_class: ClientSignUpFlow)
        .create_for_admission!(
          admission_binding: binding,
          ceremony_session: ceremony,
          entry_method: entry_method,
          social_provider: nil,
          return_to: nil,
          reject_prior_flow: false,
        )

      assert_no_difference("ClientSignUpFlow.count") do
        auth.get(auth_app_social_google_callback_path, params: { state:, ri: "jp" }, headers: auth_origin_headers)
      end

      assert_equal 400, auth.response.status
      assert_equal "start", local_flow.reload.step
      assert_nil local_flow.principal_id
      assert_not_predicate ceremony.reload, :authentication_evidence_recorded?
    end
  ensure
    OmniAuth.config.mock_auth[:google] = prior_mock
    OmniAuth.config.test_mode = prior_test_mode
  end

  test "R-AU-49: Cancel before the verified callback closes the social attempt" do
    auth, binding, csrf = admitted_social_browser!(sign_up: true)
    auth.post(
      auth_app_social_google_registration_path, params: { ri: "jp" },
                                                headers: auth_origin_headers.merge("X-CSRF-Token" => csrf),
    )

    assert_equal 307, auth.response.status
    state = auth.session.fetch(SocialCallbackGuard::SOCIAL_STATE_SESSION_KEY)
    assert_no_difference("ClientSignUpFlow.count") do
      auth.get(auth_app_sign_up_path(ri: "jp"), headers: navigation_headers)
    end
    props = JSON.parse(Nokogiri::HTML(auth.response.body).at_css("script[data-page='app']").text).fetch("props")
    cancel_form = props.fetch("cancel_form")
    auth.post(
      cancel_form.fetch("action"), params: { authenticity_token: cancel_form.fetch("authenticity_token") },
                                   headers: auth_origin_headers.merge(
                                     "X-CSRF-Token" => cancel_form.fetch("authenticity_token"),
                                   ),
    )

    assert_equal 303, auth.response.status
    ceremony = ClientAuthCeremonySession.find(binding.admitted_auth_ceremony_session_id)

    assert_equal AuthCeremonySession::STATUS_CANCELLED_BEFORE_PROGRESS, ceremony.reload.status_id
    assert_no_difference("ClientSignUpFlow.count") do
      auth.get(auth_app_social_google_callback_path, params: { state:, ri: "jp" }, headers: auth_origin_headers)
    end

    # Cancel clears Auth continuity; this callback has no admission, rather than an old owned phase.
    assert_equal 403, auth.response.status
    assert_not_predicate ceremony.reload, :authentication_evidence_recorded?
  end

  test "R-AU-49: switching providers replaces the provider nonce and consumes prior callback state" do
    auth, binding, csrf = admitted_social_browser!(sign_up: true)
    headers = auth_origin_headers.merge("X-CSRF-Token" => csrf)
    auth.post(auth_app_social_apple_registration_path, params: { ri: "jp" }, headers:)

    assert_equal 307, auth.response.status
    apple_state = auth.session.fetch(SocialCallbackGuard::SOCIAL_STATE_SESSION_KEY)
    apple_nonce = auth.session.fetch(:social_auth_nonce)
    apple_row = ClientOauthCallbackState.find_by!(
      state_digest: ClientOauthCallbackState.digest_state(apple_state),
    )

    auth.get(auth_app_sign_up_path(ri: "jp"), headers: navigation_headers)
    google_csrf = Nokogiri::HTML(auth.response.body).at_css('meta[name="csrf-token"]')["content"]
    auth.post(
      auth_app_social_google_registration_path, params: { ri: "jp" },
                                                headers: auth_origin_headers.merge("X-CSRF-Token" => google_csrf),
    )

    assert_equal 307, auth.response.status
    google_state = auth.session.fetch(SocialCallbackGuard::SOCIAL_STATE_SESSION_KEY)

    assert_equal "google", auth.session[SocialCallbackGuard::SOCIAL_STATE_PROVIDER_SESSION_KEY]
    assert_nil auth.session[:social_auth_nonce]
    assert_predicate apple_row.reload.consumed_at, :present?

    auth.get(auth_app_sign_up_path(ri: "jp"), headers: navigation_headers)
    apple_retry_csrf = Nokogiri::HTML(auth.response.body).at_css('meta[name="csrf-token"]')["content"]
    auth.post(
      auth_app_social_apple_registration_path, params: { ri: "jp" },
                                               headers: auth_origin_headers.merge("X-CSRF-Token" => apple_retry_csrf),
    )

    assert_equal 307, auth.response.status
    assert_not_equal google_state, auth.session.fetch(SocialCallbackGuard::SOCIAL_STATE_SESSION_KEY)
    assert_equal "apple", auth.session[SocialCallbackGuard::SOCIAL_STATE_PROVIDER_SESSION_KEY]
    assert_not_equal apple_nonce, auth.session.fetch(:social_auth_nonce)
    assert_equal 0, ClientSignUpFlow.where(auth_admission_binding_id: binding.id).count
  end

  [
    [true, true, "registered"],
    [false, false, "unregistered"],
  ].each do |registered, sign_up, guidance_kind|
    test "Apple verified #{guidance_kind} subject crossing refuses with fresh-entry guidance and no authority" do
      outcome = social_intent_crossing!(provider: "apple", registered:, sign_up:)
      status, location, body = outcome.fetch(:response)
      page = Nokogiri::HTML(body)

      assert_equal [400, nil], [status, location]
      assert_equal [0, 0, 0, 0], outcome.fetch(:created)
      assert_equal I18n.t("sign.app.social.verified_subject_guidance.#{guidance_kind}.title"), page.at_css("h1").text
      assert_includes page.text, I18n.t("sign.app.social.verified_subject_guidance.#{guidance_kind}.body")
      target = URI.parse(page.at_css("a")["href"])

      assert_equal [ENV.fetch("PUBLIC_BASE_SERVICE_URL"), "/sign", { "ri" => "jp" }],
                   [target.host, target.path, Rack::Utils.parse_query(target.query)]
      assert_equal [true, false, false, false, "pending", false],
                   [outcome.fetch(:apple_nonce_present), outcome.fetch(:nonce_remaining),
                    outcome.fetch(:social_state_remaining), outcome.fetch(:entry_remaining),
                    outcome.fetch(:transaction_status), outcome.fetch(:ceremony).authentication_evidence_recorded?,]
      assert_equal [nil, nil], [outcome.fetch(:browser).cookies[AuthenticationBase::ACCESS_COOKIE_KEY],
                                outcome.fetch(:browser).cookies[AuthenticationBase::REFRESH_COOKIE_KEY],]
    end
  end

  # Suspicion is refused: after the guidance page ends the attempt, Back cannot resume it, either by
  # replaying the provider callback or by starting the provider again with the other kind of account.
  [
    ["google", "sign-in", false], ["google", "sign-up", true],
    ["apple", "sign-in", false], ["apple", "sign-up", true],
  ].each do |provider, entry, sign_up|
    test "Back after #{provider} #{entry} guidance cannot replay the callback or restart the provider" do
      outcome = social_intent_crossing!(provider:, registered: sign_up, sign_up:)
      auth = outcome.fetch(:browser)
      retry_subject = "back-retry-#{SecureRandom.hex(8)}"
      # Retry with the account that the original entry would have accepted.
      register_social_subject!(retry_subject, provider:) unless sign_up
      OmniAuth.config.mock_auth[provider.to_sym] = OmniAuth::AuthHash.new(
        provider:, uid: retry_subject, info: { name: "Provider fixture" },
        credentials: { token: "provider-fixture", expires_at: 1.hour.from_now.to_i },
      )
      counted = [Client, ClientExternalIdentity, ClientSignUpFlow, ClientToken]
      before = counted.map(&:count)

      auth.get(
        "/social/#{provider}/callback", params: { state: outcome.fetch(:state), ri: "jp" },
                                        headers: auth_origin_headers,
      )
      replay = auth.response.status
      auth.get(
        sign_up ? "/sign/up" : "/sign/in", params: { ri: "jp" },
                                           headers: auth_origin_headers.merge(
                                             "Sec-Fetch-Mode" => "navigate", "Sec-Fetch-Dest" => "document",
                                           ),
      )
      first_page = auth.response.status
      auth.post(
        "/social/#{provider}/#{sign_up ? "registration" : "session"}",
        params: { ri: "jp" }, headers: auth_origin_headers.merge("X-CSRF-Token" => outcome.fetch(:csrf)),
      )
      restart = [auth.response.status, auth.response.location]

      assert_equal [400, nil], outcome.fetch(:response).first(2)
      assert_equal [403, 400, [400, nil]], [replay, first_page, restart]
      assert_equal [0, 0, 0, 0], counted.map(&:count).zip(before).map { |after, earlier| after - earlier }
      assert_equal ["pending", nil],
                   [authorization_transaction_for_test(outcome.fetch(:binding)).reload.status_name,
                    auth.cookies[AuthenticationBase::ACCESS_COOKIE_KEY],]
    end
  end

  test "an unregistered Apple subject at signup reaches confirmation with provider evidence and no account" do
    outcome = social_intent_crossing!(provider: "apple", registered: false, sign_up: true)
    auth = outcome.fetch(:browser)

    assert_equal [302, "/sign/up/guard/apple"], outcome.fetch(:response).first(2)
    assert_equal [0, 0, 1, 0], outcome.fetch(:created)
    assert_equal [true, false, false, "pending", true],
                 [outcome.fetch(:apple_nonce_present), outcome.fetch(:nonce_remaining),
                  outcome.fetch(:social_state_remaining), outcome.fetch(:transaction_status),
                  outcome.fetch(:ceremony).authentication_evidence_recorded?,]
    auth.follow_redirect!
    auth.follow_redirect!

    assert_equal 200, auth.response.status
    flow = ClientSignUpFlow.find_by!(auth_admission_binding_id: outcome.fetch(:binding).id)

    assert_equal ["apple", "apple", nil, false],
                 [flow.entry_method, flow.social_provider, flow.principal_id, flow.requirement_cleared?(:confirmation)]
  end

  test "a registered Apple subject at signin records only the admitted Apple evidence before Base handoff" do
    outcome = social_intent_crossing!(provider: "apple", registered: true, sign_up: false)

    assert_equal 303, outcome.fetch(:response).first
    assert_equal [0, 0, 0, 0], outcome.fetch(:created)
    assert_equal [true, "apple", true, false, false, "pending"],
                 [outcome.fetch(:ceremony).authentication_evidence_recorded?,
                  outcome.fetch(:ceremony).authentication_method, outcome.fetch(:apple_nonce_present),
                  outcome.fetch(:nonce_remaining), outcome.fetch(:social_state_remaining),
                  outcome.fetch(:transaction_status),]
    auth = outcome.fetch(:browser)

    assert_equal [nil, nil], [auth.cookies[AuthenticationBase::ACCESS_COOKIE_KEY],
                              auth.cookies[AuthenticationBase::REFRESH_COOKIE_KEY],]
  end

  test "Apple form POST callback is refused by the current GET callback contract without authority" do
    outcome = social_intent_crossing!(provider: "apple", registered: false, sign_up: true, callback_method: :post)

    assert_equal 404, outcome.fetch(:response).first
    assert_equal [0, 0, 0, 0], outcome.fetch(:created)
    assert_not_predicate outcome.fetch(:ceremony), :authentication_evidence_recorded?
    assert_equal "pending", outcome.fetch(:transaction_status)
  end

  %w(google apple).each do |provider|
    test "SOC-7: #{provider} signup permits return to the first page after an abandoned provider start" do
      auth, binding, csrf = admitted_social_browser!(sign_up: true)
      auth.post(
        "/social/#{provider}/registration", params: { ri: "jp" },
                                            headers: auth_origin_headers.merge("X-CSRF-Token" => csrf),
      )

      assert_equal 307, auth.response.status
      assert_equal 0, ClientSignUpFlow.where(auth_admission_binding_id: binding.id).count

      auth.get(auth_app_sign_up_path(ri: "jp"), headers: navigation_headers)

      assert_equal 200, auth.response.status
      props = JSON.parse(Nokogiri::HTML(auth.response.body).at_css("script[data-page='app']").text).fetch("props")

      assert_equal "sign_in", props.fetch("switch_form").fetch("to")
      assert_equal 0, ClientSignUpFlow.where(auth_admission_binding_id: binding.id).count
    end
  end

  private

  def social_intent_crossing!(provider:, registered:, sign_up:, callback_method: :get)
    subject = "crossing-social-#{SecureRandom.hex(8)}"
    register_social_subject!(subject, provider:) if registered
    auth, binding, csrf = admitted_social_browser!(sign_up:)
    start_path = "/social/#{provider}/#{sign_up ? "registration" : "session"}"
    auth.post(start_path, params: { ri: "jp" }, headers: auth_origin_headers.merge("X-CSRF-Token" => csrf))

    assert_equal 307, auth.response.status
    state = auth.session.fetch(SocialCallbackGuard::SOCIAL_STATE_SESSION_KEY)
    nonce = (provider == "apple") ? auth.session.fetch(:social_auth_nonce) : nil
    OmniAuth.config.mock_auth[provider.to_sym] = OmniAuth::AuthHash.new(
      provider: provider, uid: subject, info: { name: "Provider fixture" },
      credentials: { token: "provider-fixture", expires_at: 1.hour.from_now.to_i },
      extra: { id_info: { nonce: nonce } },
    )
    counted = [Client, ClientExternalIdentity, ClientSignUpFlow, ClientToken]
    before = counted.map(&:count)
    if callback_method == :post
      auth.post("/social/#{provider}/callback", params: { state:, ri: "jp" }, headers: auth_origin_headers)
    else
      auth.get("/social/#{provider}/callback", params: { state:, ri: "jp" }, headers: auth_origin_headers)
    end

    {
      created: counted.map(&:count).zip(before).map { |after, earlier| after - earlier },
      ceremony: admitted_auth_ceremony_session_for_test(binding.reload),
      transaction_status: authorization_transaction_for_test(binding).reload.status_name,
      social_state_remaining: auth.session.key?(SocialCallbackGuard::SOCIAL_STATE_SESSION_KEY),
      browser: auth,
      binding: binding,
      csrf: csrf,
      state: state,
      apple_nonce_present: nonce.is_a?(String) && nonce.present?,
      nonce_remaining: auth.session.key?(:social_auth_nonce),
      entry_remaining: auth.session.key?(SocialAuth::SOCIAL_ENTRY_SESSION_KEY),
      response: [auth.response.status, auth.response.location && URI.parse(auth.response.location).path,
                 auth.response.body,],
    }
  end

  def register_social_subject!(subject, provider:)
    actor = Client.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE,
      birthdate: "2000-01-01",
    )
    case provider
    when "google"
      ClientGoogleIdentity.create!(
        user: actor, uid: subject, provider: "google", status_id: ClientGoogleIdentityStatus::ACTIVE,
      )
    when "apple"
      ClientAppleIdentity.create!(
        user: actor, uid: subject, provider: "apple", status_id: ClientAppleIdentityStatus::ACTIVE,
      )
    else raise ArgumentError, "unsupported crossing provider"
    end
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

  def assert_social_rp_dashboard(base)
    drive_browser_through_continuations!(base, base_browser: base)

    assert_equal [true, true, 200, "/dashboard"],
                 [base.cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE].present?,
                  base.cookies[OidcRpBrowserCredentialContract::REFRESH_COOKIE].present?,
                  base.response.status, base.request.path,]
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
