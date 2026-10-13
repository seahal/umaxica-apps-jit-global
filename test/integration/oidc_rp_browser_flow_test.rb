# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class OidcRpBrowserFlowTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  COOKIE_NAME = AuthenticationBase::ACCESS_COOKIE_KEY

  SURFACES = [
    { host: ENV.fetch("PUBLIC_BASE_SERVICE_URL"),
      client_id: "core-app",
      acme_host: ENV.fetch("PUBLIC_BASE_SERVICE_URL"),
      resource: -> {
        clients(:one)
      }, },
    { host: ENV.fetch("PUBLIC_BASE_STAFF_URL"),
      client_id: "core-org",
      acme_host: ENV.fetch("PUBLIC_BASE_STAFF_URL"),
      resource: -> {
        operators(:one)
      }, },
    { host: ENV.fetch("PUBLIC_BASE_CORPORATE_URL"),
      client_id: "core-com",
      acme_host: ENV.fetch("PUBLIC_BASE_CORPORATE_URL"),
      resource: -> {
        create_visitor!
      }, },
  ].freeze

  setup do
    ClientSignOutFlowKind.ensure_defaults!
    ClientSignOutFlowStatus.ensure_defaults!
    ClientSessionLimitResolutionState::DEFAULTS.each do |id|
      ClientSessionLimitResolutionState.find_or_create_by!(id: id) do |state|
        state.created_at = Time.current
        state.updated_at = Time.current
      end
    end
    load_jump_rt_env!
    # Base RP surfaces resolve to the PUBLIC host family (https origins), so the
    # integration session must speak https for scheme/redirect_uri to line up.
    https!
    ClientIdentityState.ensure_defaults!
    VisitorIdentityState.ensure_defaults!
    OperatorIdentityState.ensure_defaults!
  end

  test "legacy RP authorize and callback paths are unroutable" do
    SURFACES.each do |surface|
      ["/oidc/authorization", "/sign/callback"].each do |path|
        assert_raises(ActionController::RoutingError) do
          Rails.application.routes.recognize_path("http://#{surface[:host]}#{path}", method: :get)
        end
      end
    end
  end

  test "acme app session-limit limitation revokes one session and resumes authorization" do
    with_core_oidc_client_key do
      acme_host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
      client = OidcClientRegistry.find!("core-app")
      code_verifier = SecureRandom.urlsafe_base64(48)
      user = clients(:one)
      ClientToken.where(user_id: user.id).delete_all

      # The account is at its limit and the waiting browser holds no session of its own: the
      # OIDC resume issued nothing and left only the resolution challenge.
      tokens =
        ClientToken::MAX_SESSIONS_PER_USER.times.map do
          ClientToken.create!(
            user: user,
            user_token_kind_id: ClientTokenKind::BROWSER_WEB,
            user_token_status_id: ClientTokenStatus::ACTIVE,
            authentication_event_at: Time.current,
          )
        end
      issuance = issue_authenticated_app_oidc_transaction(user, auth_method: "email", code_verifier: code_verifier)
      host!(acme_host)
      get "/sign", params: { ri: "jp" }
      flow_nonce = SecureRandom.urlsafe_base64(32)
      now = ClientSignInFlow.database_now
      pending_flow = ClientSignInFlow.create!(
        principal_id: user.id, state_id: ClientSignInFlow.state_id_for("SESSION_ISSUANCE_PENDING"),
        nonce_digest: ClientSignInFlow.digest_nonce(flow_nonce), issued_at: now, expires_at: now + 5.minutes,
        authentication_method: "email", authentication_event_at: now,
        authentication_context: AuthenticationContextValue::NORMAL_KEY,
      )
      browser_binding = SecureRandom.urlsafe_base64(32)
      resolution = ClientSessionLimitResolutionTransaction.issue!(
        actor: user, sign_in_flow: pending_flow, oidc_authorization_transaction: issuance.transaction,
        browser_binding_digest: ClientSessionLimitResolutionTransaction.digest_challenge(browser_binding),
      )
      gate = {
        "nonce" => SecureRandom.hex(16),
        "issued_at" => now.to_i,
        "pt" => "/sign/in",
        "flow" => pending_flow.public_id,
        "resolution_challenge" => resolution.challenge,
        "resolution_binding" => browser_binding,
        "actor_type" => "Client",
      }
      session_key = Rails.application.config.session_options.fetch(:key)
      # CookieStore treats a cookie without a session id as no session at all.
      sealed_state = { "session_id" => SecureRandom.hex(16) }.merge(request.session.to_hash).merge(
        "session_limit_gate" => gate,
        "app_sign_in_flow_locator" => { "public_id" => pending_flow.public_id, "nonce" => flow_nonce },
      )
      request.cookie_jar.signed_or_encrypted[session_key] = { value: sealed_state }
      sealed_session = request.cookie_jar[session_key]
      cookies.delete(session_key)
      cookie_installed = cookies.merge(
        "#{session_key}=#{Rack::Utils.escape(sealed_session)}",
        URI.parse("https://#{acme_host}/"),
      ).any?

      assert cookie_installed, "The gate cookie must be installed on the original Base host"

      get acme_app_sign_in_limitation_path(ri: "jp"), params: { resolution_challenge: resolution.challenge },
                                                      headers: browser_headers
      received_gate = request.session[:session_limit_gate]
      decision_time = ClientSignInFlow.database_now
      gate_flags = {
        cookie_sent: request.cookies[session_key] == sealed_session,
        present: received_gate.is_a?(Hash),
        challenge_bound: received_gate.is_a?(Hash) && received_gate["resolution_challenge"] == resolution.challenge,
        browser_bound: received_gate.is_a?(Hash) && received_gate["resolution_binding"] == browser_binding,
        child_open: resolution.transaction.reload.open?,
        child_live: resolution.transaction.expires_at > decision_time,
        child_parent_bound: resolution.transaction.sign_in_flow_id == pending_flow.id,
        child_oidc_bound: resolution.transaction.oidc_authorization_transaction_id == issuance.transaction.id,
        child_browser_bound: resolution.transaction.browser_binding_digest ==
          ClientSessionLimitResolutionTransaction.digest_challenge(browser_binding),
        parent_nonce_bound: pending_flow.reload.nonce_matches?(flow_nonce),
        parent_actor_bound: pending_flow.principal_id == user.id,
        parent_live: !pending_flow.expired?(decision_time),
        oidc_actor_bound: issuance.transaction.reload.actor_ref == user.public_id,
        oidc_authenticated: issuance.transaction.authenticated?,
        oidc_live: !issuance.transaction.expired?(now: decision_time) &&
          !issuance.transaction.login_challenge_expired?(now: decision_time),
        oidc_not_finalized: issuance.transaction.base_finalized_at.nil?,
      }

      gate_flags.each do |condition, satisfied|
        assert satisfied, "Resolution admission #{condition} must hold"
      end
      assert_equal 200, response.status
      selected = tokens.first

      active_session_count = ClientToken.not_revoked.where(user_id: user.id, rotated_at: nil).count
      host! acme_host
      patch acme_app_sign_in_limitation_path,
            params: {
              resolution_challenge: resolution.challenge,
              session_ref: SessionLimitResolutionTokenRef.issue(selected),
            },
            headers: browser_headers

      assert_response :redirect
      assert_predicate selected.reload, :revoked?
      # One revoked, one newly committed root login: still exactly at the limit.
      assert_equal active_session_count, ClientToken.not_revoked.where(user_id: user.id, rotated_at: nil).count
      assert_not_nil ClientToken.where(user_id: user.id).order(:id).last.root_login_established_at
      callback_uri = URI.parse(jump_rt_url_from_location(response.location))
      callback_query = Rack::Utils.parse_nested_query(callback_uri.query.to_s)

      assert_equal "/oidc/callback", callback_uri.path
      assert_predicate callback_query["code"], :present?
      assert_predicate issuance.transaction.reload, :consumed?
      assert_predicate resolution.transaction.reload, :resolved?
      assert_not_nil resolution.transaction.finalized_at
      assert_equal 2, ClientToken.not_revoked.where(user_id: user.id, rotated_at: nil).count

      token_url = acme_app_oauth_token_url(host: acme_host)
      client_assertion = OidcClientAssertionJwt.issue(client_id: "core-app", token_url: token_url)
      post token_url,
           params: {
             grant_type: "authorization_code",
             code: callback_query.fetch("code"),
             redirect_uri: client.redirect_uris.first,
             client_id: "core-app",
             code_verifier: code_verifier,
             client_assertion_type: OidcClientAssertionJwt::ASSERTION_TYPE,
             client_assertion: client_assertion,
           },
           headers: browser_headers

      assert_response :ok
      assert_predicate response.parsed_body["id_token"], :present?
      assert_predicate response.parsed_body["access_token"], :present?
      assert_equal 2, ClientToken.not_revoked.where(user_id: user.id, rotated_at: nil).count
    end
  end

  test "app email sign-in session-limit handoff completes Core RP callback without a root session" do # rubocop:disable Minitest/MultipleAssertions
    previous_core_browser_jwt_cookie_enabled = ENV["CORE_BROWSER_JWT_COOKIE_ENABLED"]
    ENV["CORE_BROWSER_JWT_COOKIE_ENABLED"] = "1"

    with_core_oidc_client_key do
      TurnstileVerifierStub.challenge_enabled = true
      acme_host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
      sign_host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
      core_host = ENV.fetch("PUBLIC_CORE_SERVICE_URL")
      user = clients(:one)
      ClientToken.where(user_id: user.id).delete_all
      email = user.client_emails.create!(address: "oidc_email_limit_#{SecureRandom.hex(4)}@example.com")
      email.finalize_binding!
      # Sign-up provisions the canonical identity an RP binds to; the fixture actor never signed up.
      IdentityGraphProvisioner.call!(surface: :app, principal: user)

      first_active = ClientToken.create!(
        user: user,
        user_token_status_id: ClientTokenStatus::ACTIVE,
        authentication_event_at: Time.current,
      )
      first_active.rotate_refresh_token!
      second_active = ClientToken.create!(
        user: user,
        user_token_status_id: ClientTokenStatus::ACTIVE,
        authentication_event_at: Time.current,
      )
      second_active.rotate_refresh_token!

      host!(core_host)
      get("/sign", headers: browser_headers)
      post("/sign", params: { pt: "/", ri: "jp" }, headers: browser_headers)

      assert_response :redirect
      authorize_uri = URI.parse(jump_rt_url_from_location(response.location))
      authorize_query = Rack::Utils.parse_nested_query(authorize_uri.query.to_s)

      assert_equal acme_host, authorize_uri.host
      assert_equal "/oauth/authorize", authorize_uri.path
      assert_equal "core-app", authorize_query.fetch("client_id")
      assert_equal redirect_uri_for_core_app(core_host), authorize_query.fetch("redirect_uri")
      assert_nil authorize_query["screen_hint"]

      # Production uses host-only __Host-session cookies. Test's shared-domain session cookie
      # needs explicit per-host transport while this browser visits the public Base/Auth hosts.
      core_continuity_cookies = cookies.to_hash

      assert_predicate core_continuity_cookies["session"], :present?
      host!(acme_host)
      get(authorize_uri.request_uri, headers: browser_headers)

      assert_response :success
      form = response.parsed_body.at_css("form#base-authorization-ceremony-start-form")

      assert_not_nil form
      fields = form.css("input[name]").to_h { |input| [input["name"], input["value"]] }
      post(
        form["action"], params: fields, headers: {
          "Origin" => "https://#{acme_host}", "Sec-Fetch-Site" => "same-origin",
        },
      )

      assert_response :redirect
      sign_uri = URI.parse(jump_rt_url_from_location(response.location))
      sign_query = Rack::Utils.parse_nested_query(sign_uri.query.to_s)
      binding = BaseAuthAdmissionCoordinator.find_admission_binding!(
        surface: "app", reference: sign_query.fetch("entry_ref"),
      )
      transaction = binding.authorization_transaction
      original_transaction_id = transaction.id

      host!(sign_host)
      get(sign_uri.request_uri, params: { ri: "jp" })
      3.times do |index|
        assert_equal 200, response.status, "Admission continuation #{index} must render successfully"
        html_response = response.media_type == "text/html"

        assert html_response, "Admission continuation must render an HTML form"
        form = response.parsed_body.at_css("form")

        assert_not_nil form
        fields = form.css("input[name]").to_h { |input| [input["name"], input["value"]] }
        post(
          form["action"], params: fields, headers: {
            "Origin" => "https://#{host}", "Sec-Fetch-Site" => "same-origin",
          },
        )

        assert_response :see_other
        next if index == 2

        target = URI.parse(response.location)
        host!(target.host)
        get(target.request_uri, params: { ri: "jp" })
      end

      assert_predicate binding.reload, :redeemed?
      assert_equal original_transaction_id, binding.authorization_transaction_id

      assert_response :see_other
      follow_redirect!

      assert_response :success

      original_login_cooldown = login_cooldown
      self.login_cooldown = 0.seconds
      begin
        post(
          sign_app_sign_in_email_path(ri: "jp"),
          params: {
            :user_email => { address: email.address },
            "cf-turnstile-response" => "test_token",
          },
          headers: browser_headers,
        )

        assert_response :redirect

        ceremony = ClientAuthCeremonySession.find(binding.admitted_auth_ceremony_session_id)
        delivery_job =
          enqueued_jobs.reverse.find do |job|
            next false unless job.fetch(:job) == OtpNotifierEmailDeliveryJob

            delivery = ActiveJob::Arguments.deserialize(job.fetch(:args)).last.fetch(:params)
            delivery.fetch(:auth_ceremony_session_ref) == ceremony.id.to_s
          end

        assert_not_nil delivery_job
        delivery = ActiveJob::Arguments.deserialize(delivery_job.fetch(:args)).last.fetch(:params)
        context = ceremony.email_otp_context
        pass_code = OutboundSensitivePayload.decrypt_email_otp(delivery.fetch(:encrypted_hotp_token))
        correct_contact = context.fetch("contact_ref") == email.public_id
        correct_owner = context.fetch("owner_ref") == user.public_id
        correct_generation = context.fetch("generation") == delivery.fetch(:auth_email_otp_generation)
        correct_parent = context.fetch("parent_ref") == transaction.transaction_id
        plaintext_queued = delivery_job.fetch(:args).to_s.include?(pass_code)

        assert correct_contact, "Delivery must bind the actual Contact"
        assert correct_owner, "Delivery must bind the actual owner"
        assert correct_generation, "Delivery must bind the current ceremony generation"
        assert correct_parent, "Delivery must bind the original OIDC Parent"
        assert_not plaintext_queued, "Delivery must not queue plaintext code"
        assert_equal "sign_in", delivery.fetch(:purpose)
        assert_equal "oidc", context.fetch("parent_kind")
        patch(
          sign_app_sign_in_email_path(ri: "jp"),
          params: { :user_email => { pass_code: pass_code }, "cf-turnstile-response" => "test_token" },
          headers: browser_headers,
        )
      ensure
        self.login_cooldown = original_login_cooldown
      end

      assert_equal URI.parse(auth_app_sign_in_check_path(ri: "jp")).path, URI.parse(response.location).path
      follow_redirect!
      follow_redirect!

      assert_response :success

      auth_token_count_before_handoff =
        ClientToken.not_revoked.where(user_id: user.id, rotated_at: nil).count
      post(auth_app_sign_oidc_handoff_path(ri: "jp"), headers: browser_headers)

      # The result travels as an opaque reference: Auth redirects to Base, whose own document posts it.
      assert_response :see_other
      handoff_uri = URI.parse(response.location)

      assert_equal acme_host, handoff_uri.host
      assert_equal "/oauth/authorize", handoff_uri.path
      assert_equal auth_token_count_before_handoff,
                   ClientToken.not_revoked.where(user_id: user.id, rotated_at: nil).count,
                   "Auth must hand off authentication evidence without creating a Base Browser Session"

      # Keep the integration session's cookie jar aligned with the actual Base host. A manual
      # Host header alone does not update the jar's host context, so Base-issued host-only
      # credentials would be omitted from the subsequent resolution request.
      host!(acme_host)
      get(handoff_uri.request_uri, headers: browser_headers)

      assert_response :success
      result_form = css_select("form#oidc-authorization-result-form").first
      result_ref = result_form.at_css(%(input[name="result_ref"]))["value"]
      transaction_ref = result_form.at_css(%(input[name="transaction_ref"]))["value"]

      assert_predicate result_ref, :present?
      assert_predicate transaction_ref, :present?

      post(
        result_form["action"],
        params: { result_ref: result_ref, transaction_ref: transaction_ref, ri: "jp" },
        headers: browser_headers.merge(
          "Origin" => "https://#{acme_host}",
          "Sec-Fetch-Site" => "same-origin",
        ),
      )

      assert_response :see_other
      resume_uri = URI.parse(response.location)
      resume_query = Rack::Utils.parse_nested_query(resume_uri.query.to_s)

      assert_equal acme_host, resume_uri.host
      assert_equal "/sign/in/limitation", resume_uri.path
      # The challenge stays in the browser session; the URL carries no grant.
      assert_not resume_query.key?("resolution_challenge")
      resolution_challenge = session.fetch(:session_limit_gate).fetch("resolution_challenge")

      assert_predicate resolution_challenge, :present?

      transaction = ClientOidcAuthorizationTransaction.find_by!(transaction_id: transaction_ref)

      assert_predicate transaction, :authenticated?
      assert_nil transaction.session_ref
      # Waiting on the limit issues nothing: no restricted placeholder, no third row.
      assert_equal 2, ClientToken.not_revoked.where(user_id: user.id, rotated_at: nil).count

      resolution = ClientSessionLimitResolutionTransaction.find_active_by_challenge(resolution_challenge)

      assert_predicate resolution, :present?
      assert_not_predicate ClientToken.restricted_status.where(user_id: user.id), :exists?

      host!(acme_host)
      get(resume_uri.request_uri, headers: browser_headers)

      assert_response :success

      patch(
        resume_uri.request_uri,
        params: { session_ref: SessionLimitResolutionTokenRef.issue(first_active) },
        headers: browser_headers,
      )

      assert_response :redirect
      callback_uri = URI.parse(jump_rt_url_from_location(response.location))
      callback_query = Rack::Utils.parse_nested_query(callback_uri.query.to_s)

      assert_equal core_host, callback_uri.host
      assert_equal "/oidc/callback", callback_uri.path
      assert_predicate callback_query["code"], :present?
      assert_predicate transaction.reload, :consumed?

      # The RP's code-for-token exchange is a real outbound HTTP request to the
      # OP's token endpoint, so it must be replaced at the boundary here as it is
      # in the other callback tests.
      id_token = OidcIdTokenIssuer.call(
        resource: user,
        client: OidcClientRegistry.find!("core-app"),
        nonce: authorize_query.fetch("nonce"),
        auth_time: transaction.authenticated_at,
      )
      core_client = OidcClientRegistry.find!("core-app")
      rp_root_token = ClientToken.not_revoked.where(user_id: user.id, rotated_at: nil).order(created_at: :desc).first
      rp_session = ClientRpSession.create!(
        client_token: rp_root_token,
        oidc_client_id: core_client.client_id,
        oidc_scope: "openid profile",
        oidc_jti: SecureRandom.uuid,
        oidc_auth_time: transaction.authenticated_at,
        refresh_token_expires_at: 10.minutes.from_now,
      )
      rp_access_token = AuthenticationTokenService.encode(
        user,
        host: acme_host,
        resource_type: "client",
        session_public_id: rp_root_token.public_id,
        base_session_public_id: rp_root_token.public_id,
        oidc_sid: rp_session.public_id,
        oidc_jti: rp_session.oidc_jti,
        expires_at: 10.minutes.from_now,
        scopes: %w(openid profile),
        issuer: OidcIssuer.for_client(core_client),
        audiences: [core_client.aud],
        jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(core_client),
        subject: OidcSubject.for(user, resource_type: "client"),
        client_id: core_client.client_id,
      )
      token_result = OidcRpTokenClient::Result.new(
        success: true,
        token_response: {
          access_token: rp_access_token,
          refresh_token: rp_session.issue_refresh_token!,
          id_token: id_token,
          expires_in: 600,
          refresh_token_expires_in: 600,
        },
        error: nil,
      )

      userinfo_result = OidcRpUserInfoClient::Result.new(
        success: true,
        claims: { "sub" => OidcSubject.for(user, resource_type: "client") },
        error: nil,
        dependency_failure: false,
      )

      OidcRpTokenClient.stub(:call, token_result) do
        host!(callback_uri.host)
        cookies.delete("session")
        # Rack::Test::CookieJar#merge mutates the jar and has no #merge! form; Lint/Void would
        # autocorrect this into a NoMethodError.
        store_raw_cookies(
          cookies,
          "session=#{Rack::Utils.escape(core_continuity_cookies.fetch("session"))}",
          URI.parse("https://#{core_host}/"),
        )
        OidcRpUserInfoClient.stub(:call, userinfo_result) do
          get(callback_uri.request_uri, headers: browser_headers)
        end
      end

      assert_response :redirect
      assert_equal 2, ClientToken.not_revoked.where(user_id: user.id, rotated_at: nil).count

      host!(core_host)
      get(
        "/api/v0/session",
        headers: {
          "Accept" => "application/json",
          "Content-Type" => "application/json",
          "Client-Agent" => self.class::TEST_BROWSER_USER_AGENT,
        },
      )

      assert_response :success
      assert(response.parsed_body.fetch("authenticated"))
      assert_equal user.public_id, response.parsed_body.dig("actor", "id")
    ensure
      TurnstileVerifierStub.challenge_enabled = false
      TurnstileVerifierStub.challenge_response = nil
      if previous_core_browser_jwt_cookie_enabled.nil?
        ENV.delete("CORE_BROWSER_JWT_COOKIE_ENABLED")
      else
        ENV["CORE_BROWSER_JWT_COOKIE_ENABLED"] = previous_core_browser_jwt_cookie_enabled
      end
    end
  end

  test "acme app session-limit limitation rejects another actor session" do
    acme_host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    user = clients(:one)
    other = clients(:two)
    ClientToken.where(user_id: [user.id, other.id]).delete_all
    own_token = ClientToken.create!(
      user: user,
      user_token_status_id: ClientTokenStatus::ACTIVE,
      authentication_event_at: Time.current,
    )
    other_token = ClientToken.create!(
      user: other,
      user_token_status_id: ClientTokenStatus::ACTIVE,
      authentication_event_at: Time.current,
    )
    issuance = issue_authenticated_app_oidc_transaction(user, auth_method: "email")
    host!(acme_host)
    get "/sign", params: { ri: "jp" }
    flow_nonce = SecureRandom.urlsafe_base64(32)
    now = ClientSignInFlow.database_now
    pending_flow = ClientSignInFlow.create!(
      principal_id: user.id, state_id: ClientSignInFlow.state_id_for("SESSION_ISSUANCE_PENDING"),
      nonce_digest: ClientSignInFlow.digest_nonce(flow_nonce), issued_at: now, expires_at: now + 5.minutes,
      authentication_method: "email", authentication_event_at: now,
      authentication_context: AuthenticationContextValue::NORMAL_KEY,
    )
    browser_binding = SecureRandom.urlsafe_base64(32)
    resolution = ClientSessionLimitResolutionTransaction.issue!(
      actor: user, sign_in_flow: pending_flow, oidc_authorization_transaction: issuance.transaction,
      browser_binding_digest: ClientSessionLimitResolutionTransaction.digest_challenge(browser_binding),
    )
    gate = {
      "nonce" => SecureRandom.hex(16),
      "issued_at" => now.to_i,
      "pt" => "/sign/in",
      "flow" => pending_flow.public_id,
      "resolution_challenge" => resolution.challenge,
      "resolution_binding" => browser_binding,
      "actor_type" => "Client",
    }
    session_key = Rails.application.config.session_options.fetch(:key)
    # CookieStore treats a cookie without a session id as no session at all.
    sealed_state = { "session_id" => SecureRandom.hex(16) }.merge(request.session.to_hash).merge(
      "session_limit_gate" => gate,
      "app_sign_in_flow_locator" => { "public_id" => pending_flow.public_id, "nonce" => flow_nonce },
    )
    request.cookie_jar.signed_or_encrypted[session_key] = { value: sealed_state }
    sealed_session = request.cookie_jar[session_key]
    cookies.delete(session_key)
    cookie_installed = cookies.merge(
      "#{session_key}=#{Rack::Utils.escape(sealed_session)}",
      URI.parse("https://#{acme_host}/"),
    ).any?

    assert cookie_installed, "The gate cookie must be installed on the original Base host"

    get acme_app_sign_in_limitation_path(ri: "jp"), params: { resolution_challenge: resolution.challenge },
                                                    headers: browser_headers
    received_gate = request.session[:session_limit_gate]
    decision_time = ClientSignInFlow.database_now
    gate_flags = {
      cookie_sent: request.cookies[session_key] == sealed_session,
      present: received_gate.is_a?(Hash),
      challenge_bound: received_gate.is_a?(Hash) && received_gate["resolution_challenge"] == resolution.challenge,
      browser_bound: received_gate.is_a?(Hash) && received_gate["resolution_binding"] == browser_binding,
      child_open: resolution.transaction.reload.open?,
      child_live: resolution.transaction.expires_at > decision_time,
      child_parent_bound: resolution.transaction.sign_in_flow_id == pending_flow.id,
      child_oidc_bound: resolution.transaction.oidc_authorization_transaction_id == issuance.transaction.id,
      child_browser_bound: resolution.transaction.browser_binding_digest ==
        ClientSessionLimitResolutionTransaction.digest_challenge(browser_binding),
      parent_nonce_bound: pending_flow.reload.nonce_matches?(flow_nonce),
      parent_actor_bound: pending_flow.principal_id == user.id,
      parent_live: !pending_flow.expired?(decision_time),
      oidc_actor_bound: issuance.transaction.reload.actor_ref == user.public_id,
      oidc_authenticated: issuance.transaction.authenticated?,
      oidc_live: !issuance.transaction.expired?(now: decision_time) &&
        !issuance.transaction.login_challenge_expired?(now: decision_time),
      oidc_not_finalized: issuance.transaction.base_finalized_at.nil?,
    }

    gate_flags.each do |condition, satisfied|
      assert satisfied, "Resolution admission #{condition} must hold"
    end
    assert_equal 200, response.status

    host! acme_host
    patch acme_app_sign_in_limitation_path,
          params: {
            resolution_challenge: resolution.challenge,
            session_ref: SessionLimitResolutionTokenRef.issue(other_token),
          },
          headers: browser_headers

    assert_response :unprocessable_content
    assert_not other_token.reload.revoked?
    assert_not own_token.reload.revoked?
    assert_not_predicate issuance.transaction.reload, :consumed?
  end

  test "acme app session-limit limitation stays on page when capacity is still full after revoke" do
    acme_host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    user = clients(:one)
    ClientToken.where(user_id: user.id).delete_all
    token = ClientToken.create!(
      user: user,
      user_token_status_id: ClientTokenStatus::ACTIVE,
      authentication_event_at: Time.current,
    )
    Array.new(ClientToken::MAX_TOTAL_SESSIONS_PER_USER - 1) { ClientToken.create!(user: user) }
    issuance = issue_authenticated_app_oidc_transaction(user, auth_method: "email")
    host!(acme_host)
    get("/sign", params: { ri: "jp" })
    flow_nonce = SecureRandom.urlsafe_base64(32)
    now = ClientSignInFlow.database_now
    pending_flow = ClientSignInFlow.create!(
      principal_id: user.id, state_id: ClientSignInFlow.state_id_for("SESSION_ISSUANCE_PENDING"),
      nonce_digest: ClientSignInFlow.digest_nonce(flow_nonce), issued_at: now, expires_at: now + 5.minutes,
      authentication_method: "email", authentication_event_at: now,
      authentication_context: AuthenticationContextValue::NORMAL_KEY,
    )
    browser_binding = SecureRandom.urlsafe_base64(32)
    resolution = ClientSessionLimitResolutionTransaction.issue!(
      actor: user, sign_in_flow: pending_flow, oidc_authorization_transaction: issuance.transaction,
      browser_binding_digest: ClientSessionLimitResolutionTransaction.digest_challenge(browser_binding),
    )
    gate = {
      "nonce" => SecureRandom.hex(16),
      "issued_at" => now.to_i,
      "pt" => "/sign/in",
      "flow" => pending_flow.public_id,
      "resolution_challenge" => resolution.challenge,
      "resolution_binding" => browser_binding,
      "actor_type" => "Client",
    }
    session_key = Rails.application.config.session_options.fetch(:key)
    # CookieStore treats a cookie without a session id as no session at all.
    sealed_state = { "session_id" => SecureRandom.hex(16) }.merge(request.session.to_hash).merge(
      "session_limit_gate" => gate,
      "app_sign_in_flow_locator" => { "public_id" => pending_flow.public_id, "nonce" => flow_nonce },
    )
    request.cookie_jar.signed_or_encrypted[session_key] = { value: sealed_state }
    sealed_session = request.cookie_jar[session_key]
    cookies.delete(session_key)
    cookie_installed = cookies.merge(
      "#{session_key}=#{Rack::Utils.escape(sealed_session)}",
      URI.parse("https://#{acme_host}/"),
    ).any?

    assert cookie_installed, "The gate cookie must be installed on the original Base host"

    get acme_app_sign_in_limitation_path(ri: "jp"), params: { resolution_challenge: resolution.challenge },
                                                    headers: browser_headers
    received_gate = request.session[:session_limit_gate]
    decision_time = ClientSignInFlow.database_now
    gate_flags = {
      cookie_sent: request.cookies[session_key] == sealed_session,
      present: received_gate.is_a?(Hash),
      challenge_bound: received_gate.is_a?(Hash) && received_gate["resolution_challenge"] == resolution.challenge,
      browser_bound: received_gate.is_a?(Hash) && received_gate["resolution_binding"] == browser_binding,
      child_open: resolution.transaction.reload.open?,
      child_live: resolution.transaction.expires_at > decision_time,
      child_parent_bound: resolution.transaction.sign_in_flow_id == pending_flow.id,
      child_oidc_bound: resolution.transaction.oidc_authorization_transaction_id == issuance.transaction.id,
      child_browser_bound: resolution.transaction.browser_binding_digest ==
        ClientSessionLimitResolutionTransaction.digest_challenge(browser_binding),
      parent_nonce_bound: pending_flow.reload.nonce_matches?(flow_nonce),
      parent_actor_bound: pending_flow.principal_id == user.id,
      parent_live: !pending_flow.expired?(decision_time),
      oidc_actor_bound: issuance.transaction.reload.actor_ref == user.public_id,
      oidc_authenticated: issuance.transaction.authenticated?,
      oidc_live: !issuance.transaction.expired?(now: decision_time) &&
        !issuance.transaction.login_challenge_expired?(now: decision_time),
      oidc_not_finalized: issuance.transaction.base_finalized_at.nil?,
    }

    gate_flags.each do |condition, satisfied|
      assert satisfied, "Resolution admission #{condition} must hold"
    end
    assert_equal 200, response.status
    host!(acme_host)
    assert_no_difference -> { ClientToken.where(user_id: user.id).count } do
      patch(
        acme_app_sign_in_limitation_path,
        params: {
          resolution_challenge: resolution.challenge,
          session_ref: SessionLimitResolutionTokenRef.issue(token),
        },
        headers: browser_headers,
      )
    end

    assert_response :unprocessable_content
    assert_includes response.body, I18n.t("base.app.sign.in.limitations.capacity_still_full")
    assert_predicate token.reload, :revoked?
    assert_not_predicate issuance.transaction.reload, :consumed?
  end

  test "acme app session-limit limitation rejects tampered challenge without revoking" do
    acme_host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    user = clients(:one)
    ClientToken.where(user_id: user.id).delete_all
    token = ClientToken.create!(
      user: user,
      user_token_status_id: ClientTokenStatus::ACTIVE,
      authentication_event_at: Time.current,
    )

    host! acme_host
    patch acme_app_sign_in_limitation_path,
          params: {
            resolution_challenge: "tampered",
            session_ref: SessionLimitResolutionTokenRef.issue(token),
          },
          headers: browser_headers

    assert_response :gone
    assert_not token.reload.revoked?
  end

  # The retired signed social_resolution URL token is not a grant: without this browser's pending
  # flow or an OIDC resolution challenge, nothing is listed, revoked, or issued.
  test "acme app session-limit limitation ignores a social_resolution token in the request" do
    acme_host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    user = clients(:one)
    ClientToken.where(user_id: user.id).delete_all
    token = ClientToken.create!(user: user, user_token_status_id: ClientTokenStatus::ACTIVE)
    social_token = Rails.application.message_verifier(:social_session_limit_limitation).generate(
      { "actor_ref" => user.public_id, "expires_at" => 15.minutes.from_now.iso8601 },
    )

    host! acme_host
    assert_no_difference(-> { ClientToken.where(user_id: user.id).count }) do
      patch acme_app_sign_in_limitation_path,
            params: { social_resolution: social_token, session_ref: SessionLimitResolutionTokenRef.issue(token) },
            headers: browser_headers
    end

    assert_response :gone
    assert_not token.reload.revoked?

    delete acme_app_sign_in_limitation_path,
           params: { social_resolution: social_token },
           headers: browser_headers.merge("X-Inertia" => "true")

    assert_response :gone
  end

  test "acme app session-limit limitation rejects missing payload" do
    host! ENV.fetch("PUBLIC_BASE_SERVICE_URL")

    get acme_app_sign_in_limitation_path(ri: "jp"), headers: browser_headers

    assert_response :gone
  end

  test "acme app session-limit limitation cancel does not issue login or consume oidc transaction" do
    acme_host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    user = clients(:one)
    ClientToken.where(user_id: user.id).delete_all
    issuance = issue_authenticated_app_oidc_transaction(user, auth_method: "email")
    host!(acme_host)
    get "/sign", params: { ri: "jp" }
    flow_nonce = SecureRandom.urlsafe_base64(32)
    now = ClientSignInFlow.database_now
    pending_flow = ClientSignInFlow.create!(
      principal_id: user.id, state_id: ClientSignInFlow.state_id_for("SESSION_ISSUANCE_PENDING"),
      nonce_digest: ClientSignInFlow.digest_nonce(flow_nonce), issued_at: now, expires_at: now + 5.minutes,
      authentication_method: "email", authentication_event_at: now,
      authentication_context: AuthenticationContextValue::NORMAL_KEY,
    )
    browser_binding = SecureRandom.urlsafe_base64(32)
    resolution = ClientSessionLimitResolutionTransaction.issue!(
      actor: user, sign_in_flow: pending_flow, oidc_authorization_transaction: issuance.transaction,
      browser_binding_digest: ClientSessionLimitResolutionTransaction.digest_challenge(browser_binding),
    )
    gate = {
      "nonce" => SecureRandom.hex(16),
      "issued_at" => now.to_i,
      "pt" => "/sign/in",
      "flow" => pending_flow.public_id,
      "resolution_challenge" => resolution.challenge,
      "resolution_binding" => browser_binding,
      "actor_type" => "Client",
    }
    session_key = Rails.application.config.session_options.fetch(:key)
    # CookieStore treats a cookie without a session id as no session at all.
    sealed_state = { "session_id" => SecureRandom.hex(16) }.merge(request.session.to_hash).merge(
      "session_limit_gate" => gate,
      "app_sign_in_flow_locator" => { "public_id" => pending_flow.public_id, "nonce" => flow_nonce },
    )
    request.cookie_jar.signed_or_encrypted[session_key] = { value: sealed_state }
    sealed_session = request.cookie_jar[session_key]
    cookies.delete(session_key)
    cookie_installed = cookies.merge(
      "#{session_key}=#{Rack::Utils.escape(sealed_session)}",
      URI.parse("https://#{acme_host}/"),
    ).any?

    assert cookie_installed, "The gate cookie must be installed on the original Base host"

    get acme_app_sign_in_limitation_path(ri: "jp"), params: { resolution_challenge: resolution.challenge },
                                                    headers: browser_headers
    received_gate = request.session[:session_limit_gate]
    decision_time = ClientSignInFlow.database_now
    gate_flags = {
      cookie_sent: request.cookies[session_key] == sealed_session,
      present: received_gate.is_a?(Hash),
      challenge_bound: received_gate.is_a?(Hash) && received_gate["resolution_challenge"] == resolution.challenge,
      browser_bound: received_gate.is_a?(Hash) && received_gate["resolution_binding"] == browser_binding,
      child_open: resolution.transaction.reload.open?,
      child_live: resolution.transaction.expires_at > decision_time,
      child_parent_bound: resolution.transaction.sign_in_flow_id == pending_flow.id,
      child_oidc_bound: resolution.transaction.oidc_authorization_transaction_id == issuance.transaction.id,
      child_browser_bound: resolution.transaction.browser_binding_digest ==
        ClientSessionLimitResolutionTransaction.digest_challenge(browser_binding),
      parent_nonce_bound: pending_flow.reload.nonce_matches?(flow_nonce),
      parent_actor_bound: pending_flow.principal_id == user.id,
      parent_live: !pending_flow.expired?(decision_time),
      oidc_actor_bound: issuance.transaction.reload.actor_ref == user.public_id,
      oidc_authenticated: issuance.transaction.authenticated?,
      oidc_live: !issuance.transaction.expired?(now: decision_time) &&
        !issuance.transaction.login_challenge_expired?(now: decision_time),
      oidc_not_finalized: issuance.transaction.base_finalized_at.nil?,
    }

    gate_flags.each do |condition, satisfied|
      assert satisfied, "Resolution admission #{condition} must hold"
    end
    assert_equal 200, response.status

    host! acme_host
    assert_no_difference -> { ClientToken.where(user_id: user.id).count } do
      delete acme_app_sign_in_limitation_path,
             params: { resolution_challenge: resolution.challenge },
             headers: browser_headers
    end

    assert_response :see_other
    assert_predicate resolution.transaction.reload, :cancelled?
    assert_not_predicate issuance.transaction.reload, :consumed?
  end

  test "acme app session-limit limitation cancel from an inertia visit leaves the app via inertia location" do
    acme_host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    user = clients(:one)
    ClientToken.where(user_id: user.id).delete_all
    issuance = issue_authenticated_app_oidc_transaction(user, auth_method: "email")
    host!(acme_host)
    get "/sign", params: { ri: "jp" }
    flow_nonce = SecureRandom.urlsafe_base64(32)
    now = ClientSignInFlow.database_now
    pending_flow = ClientSignInFlow.create!(
      principal_id: user.id, state_id: ClientSignInFlow.state_id_for("SESSION_ISSUANCE_PENDING"),
      nonce_digest: ClientSignInFlow.digest_nonce(flow_nonce), issued_at: now, expires_at: now + 5.minutes,
      authentication_method: "email", authentication_event_at: now,
      authentication_context: AuthenticationContextValue::NORMAL_KEY,
    )
    browser_binding = SecureRandom.urlsafe_base64(32)
    resolution = ClientSessionLimitResolutionTransaction.issue!(
      actor: user, sign_in_flow: pending_flow, oidc_authorization_transaction: issuance.transaction,
      browser_binding_digest: ClientSessionLimitResolutionTransaction.digest_challenge(browser_binding),
    )
    gate = {
      "nonce" => SecureRandom.hex(16),
      "issued_at" => now.to_i,
      "pt" => "/sign/in",
      "flow" => pending_flow.public_id,
      "resolution_challenge" => resolution.challenge,
      "resolution_binding" => browser_binding,
      "actor_type" => "Client",
    }
    session_key = Rails.application.config.session_options.fetch(:key)
    # CookieStore treats a cookie without a session id as no session at all.
    sealed_state = { "session_id" => SecureRandom.hex(16) }.merge(request.session.to_hash).merge(
      "session_limit_gate" => gate,
      "app_sign_in_flow_locator" => { "public_id" => pending_flow.public_id, "nonce" => flow_nonce },
    )
    request.cookie_jar.signed_or_encrypted[session_key] = { value: sealed_state }
    sealed_session = request.cookie_jar[session_key]
    cookies.delete(session_key)
    cookie_installed = cookies.merge(
      "#{session_key}=#{Rack::Utils.escape(sealed_session)}",
      URI.parse("https://#{acme_host}/"),
    ).any?

    assert cookie_installed, "The gate cookie must be installed on the original Base host"

    get acme_app_sign_in_limitation_path(ri: "jp"), params: { resolution_challenge: resolution.challenge },
                                                    headers: browser_headers
    received_gate = request.session[:session_limit_gate]
    decision_time = ClientSignInFlow.database_now
    gate_flags = {
      cookie_sent: request.cookies[session_key] == sealed_session,
      present: received_gate.is_a?(Hash),
      challenge_bound: received_gate.is_a?(Hash) && received_gate["resolution_challenge"] == resolution.challenge,
      browser_bound: received_gate.is_a?(Hash) && received_gate["resolution_binding"] == browser_binding,
      child_open: resolution.transaction.reload.open?,
      child_live: resolution.transaction.expires_at > decision_time,
      child_parent_bound: resolution.transaction.sign_in_flow_id == pending_flow.id,
      child_oidc_bound: resolution.transaction.oidc_authorization_transaction_id == issuance.transaction.id,
      child_browser_bound: resolution.transaction.browser_binding_digest ==
        ClientSessionLimitResolutionTransaction.digest_challenge(browser_binding),
      parent_nonce_bound: pending_flow.reload.nonce_matches?(flow_nonce),
      parent_actor_bound: pending_flow.principal_id == user.id,
      parent_live: !pending_flow.expired?(decision_time),
      oidc_actor_bound: issuance.transaction.reload.actor_ref == user.public_id,
      oidc_authenticated: issuance.transaction.authenticated?,
      oidc_live: !issuance.transaction.expired?(now: decision_time) &&
        !issuance.transaction.login_challenge_expired?(now: decision_time),
      oidc_not_finalized: issuance.transaction.base_finalized_at.nil?,
    }

    gate_flags.each do |condition, satisfied|
      assert satisfied, "Resolution admission #{condition} must hold"
    end
    assert_equal 200, response.status

    host! acme_host
    delete acme_app_sign_in_limitation_path,
           params: { resolution_challenge: resolution.challenge },
           headers: browser_headers.merge("X-Inertia" => "true")

    assert_response :conflict
    # The neutral Base entry is on this host, so the visit needs no Jump gateway.
    location = URI.parse(response.headers["X-Inertia-Location"])

    assert_equal URI.parse("https://#{ENV.fetch("PUBLIC_BASE_SERVICE_URL")}").host, location.host
    assert_equal "/sign", location.path
    assert_nil response.headers["Location"]
    assert_predicate resolution.transaction.reload, :cancelled?
  end

  test "app com and org authorization endpoints are exposed at Acme oauth authorize" do
    SURFACES.each do |surface|
      open_session do |session|
        session.host!(surface[:acme_host])
        # https, as a browser would: the jump token issuer refuses to wrap an http URL for
        # a public host, so an http request here fails for a reason production never has.
        session.https!(true)

        session.get(
          "/oauth/authorize", params: {
            response_type: "code",
            client_id: surface[:client_id],
            redirect_uri: redirect_uri_for(surface),
            code_challenge: SecureRandom.urlsafe_base64(32),
            code_challenge_method: "S256",
            state: "state",
            nonce: "nonce",
            scope: "openid profile",
          }, headers: browser_headers,
        )

        # Each surface has its own registered RP identity and exact callback.
        assert_equal 200, session.response.status, surface[:client_id]
        form = session.response.parsed_body.at_css("form#base-authorization-ceremony-start-form")

        assert_not_nil form
        fields = form.css("input[name]").to_h { |input| [input["name"], input["value"]] }
        session.post(
          form["action"], params: fields, headers: {
            "Origin" => "https://#{surface[:acme_host]}", "Sec-Fetch-Site" => "same-origin",
          },
        )

        # A POST that hands the browser on to a GET answers 303.
        assert_equal 303, session.response.status, surface[:client_id]

        session.get("/oauth/authorization", headers: browser_headers)

        assert_equal 404, session.response.status, surface[:client_id]
      end
    end
  end

  test "app com and org old sign entry routes are not exposed" do
    SURFACES.each do |surface|
      host! surface[:host]

      get "/sign/in", headers: browser_headers

      assert_response :not_found

      get "/sign/up", headers: browser_headers

      assert_response :not_found
    end
  end

  test "logout clears only RP session and redirects locally with Acme session-management guidance" do
    SURFACES.each do |surface|
      host! surface[:host]

      post "/oidc/logout", headers: browser_headers

      # Without an id_token_hint the endpoint renders a confirmation page
      # (per OIDC end session spec) rather than performing logout immediately.
      assert_response :success
    end
  end

  test "RP only logout route does not exist" do
    post "/logout", headers: browser_headers.merge("Host" => "www.app.localhost")

    assert_response :not_found

    delete "/logout", headers: browser_headers.merge("Host" => "www.app.localhost")

    assert_response :not_found
  end

  private

  def oidc_resource_type_for(resource)
    case resource
    when Client then "client"
    when Operator then "operator"
    when Visitor then "visitor"
    end
  end

  def redirect_uri_for(surface)
    OidcClientRegistry.find!(surface[:client_id]).redirect_uris.first
  end

  def redirect_uri_for_core_app(host)
    OidcClientRegistry.find!("core-app").redirect_uris.find do |uri|
      URI.parse(uri).host == host
    end
  end

  def create_visitor!
    VisitorStatus.find_or_create_by!(id: VisitorStatus::NOTHING)
    VisitorVisibility.find_or_create_by!(id: VisitorVisibility::VISITOR)
    VisitorMfaLevel.find_or_create_by!(id: VisitorMfaLevel::NOTHING)
    VisitorTokenBindingMethod.find_or_create_by!(id: VisitorTokenBindingMethod::NOTHING)
    VisitorTokenDbscStatus.find_or_create_by!(id: VisitorTokenDbscStatus::NOTHING)
    VisitorTokenKind.find_or_create_by!(id: VisitorTokenKind::BROWSER_WEB)
    VisitorTokenStatus.find_or_create_by!(id: VisitorTokenStatus::ACTIVE)
    Visitor.create!
  end

  def issue_authenticated_app_oidc_transaction(user, auth_method:, code_verifier: nil)
    code_challenge =
      if code_verifier.present?
        Base64.urlsafe_encode64(Digest::SHA256.digest(code_verifier), padding: false)
      else
        SecureRandom.urlsafe_base64(32)
      end

    OidcAuthorizationTransactionCoordinator.issue!(
      surface: "app",
      intent: "sign_in",
      params: {
        response_type: "code",
        client_id: "core-app",
        redirect_uri: redirect_uri_for(SURFACES.first),
        scope: "openid profile",
        state: SecureRandom.hex(16),
        nonce: SecureRandom.hex(16),
        code_challenge: code_challenge,
        code_challenge_method: "S256",
      },
    ).transaction.then do |transaction|
      OidcAuthorizationTransactionCoordinator.register_result!(
        surface: "app",
        login_challenge: transaction.login_challenge,
        actor: user,
        session_ref: nil,
        auth_method: auth_method,
        authentication_event_at: Time.current,
      )
    end
  end

  def clear_existing_tokens_for(resource)
    case resource
    when Client
      ClientToken.where(user_id: resource.id).delete_all
    when Operator
      OperatorToken.where(staff_id: resource.id).delete_all
    when Visitor
      VisitorToken.where(visitor_id: resource.id).delete_all
    end
  end

  def assert_response_has_auth_cookie
    assert_includes response.headers["Set-Cookie"].to_s, "#{COOKIE_NAME}=",
                    "expected callback response to set #{COOKIE_NAME}"
  end

  def with_core_oidc_client_key
    original_issuers = JitSecurityJwtRegistry.instance_variable_get(:@issuers)
    original_active_kid = ENV["OIDC_CLIENT_CORE_APP_ACTIVE_KID"]
    original_private_key = ENV["OIDC_CLIENT_CORE_APP_PRIVATE_KEY"]
    key = OpenSSL::PKey::EC.generate("secp384r1")
    ENV["OIDC_CLIENT_CORE_APP_ACTIVE_KID"] = "core-app-oidc-test"
    ENV["OIDC_CLIENT_CORE_APP_PRIVATE_KEY"] = Base64.strict_encode64(key.to_der)
    JitSecurityJwtRegistry.reload!
    yield
  ensure
    if original_active_kid.nil?
      ENV.delete("OIDC_CLIENT_CORE_APP_ACTIVE_KID")
    else
      ENV["OIDC_CLIENT_CORE_APP_ACTIVE_KID"] = original_active_kid
    end
    if original_private_key.nil?
      ENV.delete("OIDC_CLIENT_CORE_APP_PRIVATE_KEY")
    else
      ENV["OIDC_CLIENT_CORE_APP_PRIVATE_KEY"] = original_private_key
    end
    JitSecurityJwtRegistry.instance_variable_set(:@issuers, original_issuers)
  end
  private

  def bearer_headers(token, host: nil, headers: {})
    host_headers(host).merge(headers).merge("Authorization" => "Bearer #{token}")
  end
end

# DAMP auth header helpers for this test class.
class OidcRpBrowserFlowTest
  private
end

# DAMP local helper copy for former shared test support.
class OidcRpBrowserFlowTest
  TEST_BROWSER_USER_AGENT =
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 " \
    "(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
  TEST_VERIFICATION_COOKIE_PREFIX = "test_verified:"

  private

  def configured_host(surface_name)
    Rails.configuration.x.boot_config.fetch(:hosts).public_send(surface_name).host
  end

  def jwt_issuer_id_for_test_host(host, resource_type)
    normalized = host.to_s
    service =
      if normalized.include?("acme")
        "ACME"
      elsif normalized.include?("core")
        "CORE"
      elsif normalized.start_with?("base.") || normalized.start_with?("www.umaxica.")
        "BASE"
      else
        "AUTH"
      end
    surface =
      if service == "AUTH"
        case resource_type
        when "operator" then "ORG"
        when "visitor" then "COM"
        else "APP"
        end
      elsif normalized.include?(".org") || normalized.include?("org.")
        "ORG"
      elsif normalized.include?(".com") || normalized.include?("com.")
        "COM"
      else
        "APP"
      end
    "surface:#{service}_#{surface}"
  end

  def ensure_user_reference_records!
    ClientStatus.find_or_create_by!(id: ClientStatus::NOTHING)
    ClientVisibility.find_or_create_by!(id: ClientVisibility::USER)
    ClientMfaLevel.find_or_create_by!(id: ClientMfaLevel::NOTHING)
    ClientMfaStatus.find_or_create_by!(id: ClientMfaStatus::NOTHING)
    ClientMfaStatus.find_or_create_by!(id: ClientMfaStatus::ACTIVE)
    ClientMfaStatus.find_or_create_by!(id: ClientMfaStatus::UNCONFIGURED)
    ClientEmailStatus.find_or_create_by!(id: ClientEmailStatus::VERIFIED)
    ClientTelephoneStatus.find_or_create_by!(id: ClientTelephoneStatus::VERIFIED)
    ClientPasskeyStatus.find_or_create_by!(id: ClientPasskeyStatus::ACTIVE)
  end

  def ensure_user_token_reference_records!
    ClientTokenKind.find_or_create_by!(id: ClientTokenKind::BROWSER_WEB)
    ClientTokenStatus.find_or_create_by!(id: ClientTokenStatus::ACTIVE)
    ClientTokenBindingMethod.find_or_create_by!(id: ClientTokenBindingMethod::LEGACY)
    ClientTokenDbscStatus.find_or_create_by!(id: ClientTokenDbscStatus::NOTHING)
  end

  def ensure_staff_token_reference_records!
    OperatorTokenKind.find_or_create_by!(id: OperatorTokenKind::BROWSER_WEB)
    OperatorTokenStatus.find_or_create_by!(id: OperatorTokenStatus::ACTIVE)
    OperatorTokenBindingMethod.find_or_create_by!(id: OperatorTokenBindingMethod::LEGACY)
    OperatorTokenDbscStatus.find_or_create_by!(id: OperatorTokenDbscStatus::NOTHING)
  end

  def ensure_visitor_token_reference_records!
    VisitorTokenKind.find_or_create_by!(id: VisitorTokenKind::BROWSER_WEB)
    VisitorTokenStatus.find_or_create_by!(id: VisitorTokenStatus::ACTIVE)
    VisitorTokenBindingMethod.find_or_create_by!(id: VisitorTokenBindingMethod::LEGACY)
    VisitorTokenDbscStatus.find_or_create_by!(id: VisitorTokenDbscStatus::NOTHING)
  end

  def create_verified_user_with_email(email_address: "user-#{SecureRandom.hex(4)}@example.com")
    ensure_user_reference_records!
    user = Client.create!(status_id: ClientStatus::NOTHING, visibility_id: ClientVisibility::USER)
    insert_verified_user_email!(user_id: user.id, address: email_address)
    user.reload
  end

  def insert_verified_user_email!(user_id:, address:)
    ClientEmail.create!(
      user_id: user_id,
      address: address,
      address_digest: IdentifierBlindIndex.bidx_for_email(address, realm: :app),
      user_email_status_id: ClientEmailStatus::VERIFIED,
      otp_attempts_count: 0,
      public_id: SecureRandom.alphanumeric(21),
    )
  end

  def insert_verified_visitor_email!(visitor_id:, address:)
    VisitorEmail.insert_all(
      [
        {
          visitor_id: visitor_id,
          address: address,
          address_digest: IdentifierBlindIndex.bidx_for_email(address, realm: :com),
          visitor_email_status_id: VisitorEmailStatus::VERIFIED,
          otp_attempts_count: 0,
          public_id: SecureRandom.alphanumeric(21),
          created_at: Time.current,
          updated_at: Time.current,
        },
      ],
    )
  end

  def satisfy_user_verification(token, scope: nil)
    _verification, raw_token = ClientVerification.issue_for_token!(token: token)
    cookies[ClientVerification.cookie_name] = raw_token
    mark_token_step_up_satisfied_for_test(token, scope: scope)
    true
  end

  def satisfy_staff_verification(token, scope: nil)
    _verification, raw_token = OperatorVerification.issue_for_token!(token: token)
    cookies[OperatorVerification.cookie_name] = raw_token
    mark_token_step_up_satisfied_for_test(token, scope: scope)
    true
  end

  def satisfy_visitor_verification(token, scope: nil)
    _verification, raw_token = VisitorVerification.issue_for_token!(token: token)
    cookies[VisitorVerification.cookie_name] = raw_token
    mark_token_step_up_satisfied_for_test(token, scope: scope)
    true
  end

  def step_up_test_audience_for_token(token)
    case token.class.name
    when "OperatorToken" then "step_up:org"
    when "VisitorToken" then "step_up:com"
    else "step_up:app"
    end
  end

  def signed_step_up_pt_for(path, surface:, session_nonce:)
    safe_path = path.to_s
    return nil if safe_path.blank? || !safe_path.start_with?("/") || safe_path.match?(/[\x00-\x1F\x7F]/)

    verifier = ActiveSupport::MessageVerifier.new(
      Rails.application.key_generator.generate_key("path_target_token", 32),
      digest: "SHA256",
      serializer: JSON,
      url_safe: true,
    )
    verifier.generate(
      { "flow" => "step_up.bootstrap",
        "surface" => surface.to_s,
        "session_nonce" => session_nonce.to_s,
        "pt" => safe_path, },
      purpose: :path_target,
      expires_in: 15.minutes,
    )
  end

  def signed_step_up_grant_for(actor:, token:, scope:, return_to:, surface:, methods: %i(email_otp totp passkey),
                               aal: "aal2")
    IdentityStepUpCeremonyGrantIssuer.issue!(
      surface: surface.to_s,
      actor_ref: actor.public_id,
      session_ref: token.public_id,
      required_scope: scope.to_s,
      required_aal: aal,
      allowed_methods: methods,
      return_to: return_to,
      expires_at: 15.minutes.from_now,
    ).grant
  end

  def with_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    yield
  ensure
    # Restore the environment default, not the value observed on entry: if the flag was
    # already leaked as true, restoring the observation would pin the leak for the rest
    # of the process and every later test expecting protection off would fail.
    ActionController::Base.allow_forgery_protection =
      Rails.configuration.action_controller.allow_forgery_protection
  end

  def csrf_token_value
    "test-csrf-token"
  end

  def csrf_headers(token)
    { "X-CSRF-Token" => token }
  end

  def fetch_csrf_token(path)
    get(path)
    response.body[/name="authenticity_token" value="([^"]+)"/, 1] || response.body
  end

  def social_callback_headers(host)
    scheme = host.to_s.include?("localhost") ? "http" : "https"
    origin = "#{scheme}://#{host}"
    cookies["csrf_token"] = csrf_token_value if respond_to?(:cookies)
    {
      "Host" => host,
      "Origin" => origin,
      "Referer" => "#{origin}/",
      "Sec-Fetch-Site" => "same-origin",
      "X-STRICT-SOCIAL-STATE" => "1",
      "X-CSRF-Token" => csrf_token_value,
    }
  end

  def social_auth_state_from_response
    session[:social_auth_state].presence || begin
      uri = URI.parse(response.location.to_s)
      Rack::Utils.parse_nested_query(uri.query.to_s)["state"].presence
    rescue URI::InvalidURIError
      nil
    end
  end

  def seed_social_auth_session(provider:, intent: "login", user: nil, entry: nil, ri: "jp", rt: nil, referer: nil)
    host = configured_host(:sign_service)
    host!(host) if respond_to?(:host!)
    normalized_provider = SocialIdentifiable.normalize_provider(provider)
    continue_path =
      if intent.to_s == "link"
        public_send(:"auth_app_settings_#{normalized_provider}_path", ri: ri)
      elsif entry.to_s == "sign_up"
        public_send(:"auth_app_social_#{normalized_provider}_registration_path", ri: ri, rt: rt)
      else
        public_send(:"auth_app_social_#{normalized_provider}_session_path", ri: ri, rt: rt)
      end
    headers = social_callback_headers(host)
    headers["Referer"] = referer if referer.present?
    if user
      user_headers =
        as_user_headers(user, host: host)
      token = ClientToken.find_by(public_id: user_headers["X-TEST-SESSION-PUBLIC-ID"])
      mark_token_step_up_satisfied_for_test(
        token,
        scope: SocialAuth::SOCIAL_LINK_SCOPE,
      ) if intent.to_s == "link" && token
      headers = headers.merge(user_headers)
    end
    post(continue_path, headers: headers)
    social_auth_state_from_response
  end

  def assert_oidc_authorize_redirect(location, host:, client_id: "core-app")
    uri = URI.parse(location)
    query = Rack::Utils.parse_nested_query(uri.query.to_s)

    assert_equal host, uri.host
    assert_equal "/oauth/authorize", uri.path
    assert_equal client_id, query["client_id"]
    assert_predicate query["state"], :present?
  end
end

# DAMP local route helper aliases for former shared test support.
class OidcRpBrowserFlowTest
  SURFACE_ROUTE_PREFIX_MAP = {
    "sign_app_" => "auth_app_",
    "sign_org_" => "auth_org_",
    "sign_com_" => "auth_com_",
    "acme_app_" => "base_app_",
    "acme_org_" => "base_org_",
    "acme_com_" => "base_com_",
  }.freeze unless const_defined?(:SURFACE_ROUTE_PREFIX_MAP, false)

  private

  def method_missing(name, ...)
    aliased_name = aliased_surface_route_helper_name(name)
    return public_send(aliased_name, ...) if aliased_name && respond_to?(aliased_name, true)

    super
  end

  def respond_to_missing?(name, include_private = false)
    aliased_name = aliased_surface_route_helper_name(name)
    (aliased_name && respond_to?(aliased_name, include_private)) || super
  end

  def aliased_surface_route_helper_name(name)
    helper_name = name.to_s
    self.class::SURFACE_ROUTE_PREFIX_MAP.each do |source_prefix, target_prefix|
      return helper_name.sub(source_prefix, target_prefix).to_sym if helper_name.start_with?(source_prefix)
    end
    nil
  end
end

# DAMP local helper copy on the test class.
class OidcRpBrowserFlowTest
  TEST_BROWSER_USER_AGENT =
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 " \
    "(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36" unless const_defined?(
      :TEST_BROWSER_USER_AGENT, false,
    )
  PREFERENCE_JWT_KEY = OpenSSL::PKey::EC.generate("secp384r1") unless const_defined?(:PREFERENCE_JWT_KEY, false)

  private

  def set_access_cookie(token)
    cookies[AuthenticationBase::ACCESS_COOKIE_KEY] = token
  end

  def set_refresh_cookie(token)
    cookies[AuthenticationBase::REFRESH_COOKIE_KEY] = token
  end

  def jump_rt_url_from_location(location)
    uri = URI.parse(location.to_s)
    return location unless uri.host == "jump.umaxica.net"

    token = Rack::Utils.parse_nested_query(uri.query.to_s)["rt"]
    return location if token.blank?

    payload, = JWT.decode(token, nil, false)
    payload["url"].presence || location
  rescue JWT::DecodeError, URI::InvalidURIError
    location
  end

  def with_preference_jwt_keys(host: nil)
    audiences = host ? [host] : PreferenceJwtConfiguration.audiences
    pub_key_for_stub = ->(_kid, **_options) { self.class::PREFERENCE_JWT_KEY }
    PreferenceJwtConfiguration.stub(:private_key, self.class::PREFERENCE_JWT_KEY) do
      PreferenceJwtConfiguration.stub(:public_key, self.class::PREFERENCE_JWT_KEY) do
        PreferenceJwtConfiguration.stub(:private_key_for_active, self.class::PREFERENCE_JWT_KEY) do
          PreferenceJwtConfiguration.stub(:public_key_for, pub_key_for_stub) do
            PreferenceJwtConfiguration.stub(:active_kid, "default") do
              PreferenceJwtConfiguration.stub(:issuer, "jit-preference") do
                PreferenceJwtConfiguration.stub(:audiences, audiences) { yield }
              end
            end
          end
        end
      end
    end
  end

  def host_headers(host = nil)
    host_value = host || (respond_to?(:request, true) ? request&.host : nil) || ENV["DEFAULT_URL_HOST"]
    headers = { "Client-Agent" => self.class::TEST_BROWSER_USER_AGENT }
    headers["Host"] = host_value if host_value.present?
    headers
  end

  def browser_headers
    csrf_token = csrf_token_value
    cookies["csrf_token"] = csrf_token if respond_to?(:cookies, true)
    # Do NOT pin a Host header here. host_headers defaults Host to the *previous*
    # request's host, which would override host! and pin every request in a
    # multi-host flow (SURFACES loops, RP->OP->Sign hops) to the first host.
    # Let host! govern the request host instead.
    { "Client-Agent" => self.class::TEST_BROWSER_USER_AGENT, "X-CSRF-Token" => csrf_token }
  end

  def ensure_visitor_reference_records!
    VisitorStatus.find_or_create_by!(id: VisitorStatus::NOTHING)
    VisitorVisibility.find_or_create_by!(id: VisitorVisibility::VISITOR)
    VisitorMfaLevel.find_or_create_by!(id: VisitorMfaLevel::NOTHING)
    VisitorMfaStatus.find_or_create_by!(id: VisitorMfaStatus::UNCONFIGURED)
    VisitorEmailStatus.find_or_create_by!(id: VisitorEmailStatus::VERIFIED)
    VisitorTelephoneStatus.find_or_create_by!(id: VisitorTelephoneStatus::VERIFIED)
    VisitorPasskeyStatus.find_or_create_by!(id: VisitorPasskeyStatus::ACTIVE)
  end

  def create_verified_visitor_with_email(email_address: "visitor-#{SecureRandom.hex(4)}@example.com")
    ensure_visitor_reference_records!
    visitor = Visitor.create!(status_id: VisitorStatus::NOTHING, visibility_id: VisitorVisibility::VISITOR)
    VisitorEmail.create!(
      visitor_id: visitor.id, address: email_address,
      address_digest: IdentifierBlindIndex.bidx_for_email(email_address, realm: :com),
      visitor_email_status_id: VisitorEmailStatus::VERIFIED,
      otp_attempts_count: 0,
      public_id: SecureRandom.alphanumeric(21),
    )
    visitor.reload
  end

  def mark_token_step_up_satisfied_for_test(token, scope: nil, at: Time.current)
    return unless token.respond_to?(:update_columns)

    token.update_columns(
      { last_step_up_at: at,
        last_step_up_scope: scope.presence || token.try(:last_step_up_scope).presence || "verification",
        updated_at: Time.current, }.compact,
    )
  end

  def load_jump_rt_env!
    @jump_rt_env_originals ||= {}
    jump_rt_key = Base64.strict_encode64(OpenSSL::PKey::EC.generate("secp384r1").to_der)
    %w(AUTH_APP AUTH_ORG AUTH_COM ACME_APP ACME_ORG ACME_COM CORE_APP CORE_ORG CORE_COM BASE_APP BASE_ORG
       BASE_COM).each do |namespace|
      ENV["JWT_#{namespace}_ACTIVE_KID"] = "#{namespace.downcase.tr("_", "-")}-test"
      ENV["JWT_#{namespace}_PRIVATE_KEY"] = jump_rt_key
    end
    ENV["PUBLIC_JUMP_GATEWAY_URL"] = "https://jump.umaxica.net"
    JitSecurityJwtRegistry.reload! if defined?(JitSecurityJwtRegistry)
  end

  def response_set_cookie_lines
    raw = response.headers["Set-Cookie"] || response.headers["set-cookie"]
    lines = raw.is_a?(Array) ? raw : raw.to_s.split("\n")
    lines.flat_map { |line| line.to_s.split("\n") }.compact_blank
  end

  def extract_cookies_from_response
    response_set_cookie_lines.each_with_object({}) do |line, parsed|
      pair = line.to_s.split(";", 2).first
      name, value = pair.to_s.split("=", 2)
      parsed[name] = CGI.unescape(value.to_s) if name.present?
    end
  end

  def state_changing_application_route_targets
    Rails.application.routes.routes.filter_map do |route|
      verbs = route.verb.to_s.delete("^A-Z|").split("|")
      next if verbs.empty? || (verbs - %w(GET HEAD)).empty?

      controller = route.required_defaults[:controller].to_s
      action = route.required_defaults[:action].to_s
      next if controller.blank? || action.blank?

      controller_class_name = "#{controller.camelize}Controller"
      next unless Rails.root.join("app/controllers/#{controller}_controller.rb").exist?

      { verb: verbs.join("|"),
        path: route.path.spec.to_s,
        controller: controller,
        action: action,
        controller_class: Object.const_get(controller_class_name), }
    rescue NameError
      nil
    end
  end

  def setup_google_mock_auth(uid: "google_uid_123", email: "google@example.com")
    OmniAuth.config.mock_auth[:google_app] =
      OmniAuth::AuthHash.new(
        provider: "google_app", uid: uid, info: { email: email, name: "Google Client" },
        credentials: { token: "google_token", expires_at: 1.hour.from_now.to_i },
      )
  end
end
