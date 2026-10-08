# typed: false
# frozen_string_literal: true

require "test_helper"

# Root issuance HTTP checks through the real middleware and databases. Migrated cases start on
# Base, redeem scoped Auth admission and return to Base completion; remaining cases still need migration.
# Each case
# checks what the database, the cookies, the next request, and the audit say -- not only the
# response code (adr/root-login-establishment-boundary.md).
class RootLoginEstablishmentFlowTest < ActionDispatch::IntegrationTest
  fixtures :clients, :client_statuses, :client_email_statuses

  setup do
    clear_enqueued_jobs
    @previous_forgery_protection = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    @notifier_app_enabled = Flipper.enabled?(:otp_email_notifier_app)
    @notifier_com_enabled = Flipper.enabled?(:otp_email_notifier_com)
    Flipper.enable(:otp_email_notifier_app)
    Flipper.enable(:otp_email_notifier_com)
    ClientSignInFlowState::DEFAULTS.each { |id| ClientSignInFlowState.find_or_create_by!(id: id) }
    VisitorSignInFlowState::DEFAULTS.each { |id| VisitorSignInFlowState.find_or_create_by!(id: id) }
    ClientSessionLimitResolutionState::DEFAULTS.each do |id|
      ClientSessionLimitResolutionState.find_or_create_by!(id: id) do |state|
        state.created_at = Time.current
        state.updated_at = Time.current
      end
    end
    ClientSignOutFlowKind::DEFAULTS.each { |id| ClientSignOutFlowKind.find_or_create_by!(id: id) }
    ClientSignOutFlowStatus::DEFAULTS.each { |id| ClientSignOutFlowStatus.find_or_create_by!(id: id) }
    ClientIdentityState::DEFAULTS.each { |id| ClientIdentityState.find_or_create_by!(id: id) }
    VisitorIdentityState::DEFAULTS.each { |id| VisitorIdentityState.find_or_create_by!(id: id) }
    VisitorSecretCredentialKind::DEFAULTS.each { |id| VisitorSecretCredentialKind.find_or_create_by!(id: id) }
    VisitorSecretCredentialStatus::DEFAULTS.each { |id| VisitorSecretCredentialStatus.find_or_create_by!(id: id) }
    host! ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    TurnstileVerifierStub.challenge_enabled = true
    TurnstileVerifierStub.challenge_response = { "success" => true }
    @user = clients(:one)
    ClientToken.where(user_id: @user.id).delete_all
    @email = @user.client_emails.create!(
      address: "root_#{SecureRandom.hex(4)}@example.com",
      user_email_status_id: ClientEmailStatus::VERIFIED, binding_finalized_at: Time.current,
    )
  end

  teardown do
    ActionController::Base.allow_forgery_protection = @previous_forgery_protection
    Flipper.disable(:otp_email_notifier_app) unless @notifier_app_enabled
    Flipper.disable(:otp_email_notifier_com) unless @notifier_com_enabled
    TurnstileVerifierStub.challenge_enabled = false
    TurnstileVerifierStub.challenge_response = nil
  end

  # Separate browser cookie jars exercise the actual Base issuance boundary.
  # rubocop:disable Minitest/MultipleAssertions
  test "a normal sign-in establishes exactly one root login with its anchor, cookie, and audit" do
    # Existing sign-in actors need their canonical identity graph; Root issuance
    # must not silently provision a missing RP identity during callback resolution.
    @user = Client.create!(status_id: ClientStatus::ACTIVE, birthdate: "2000-01-01")
    @email = @user.client_emails.create!(
      address: "root-owner-#{SecureRandom.hex(4)}@example.com",
      user_email_status_id: ClientEmailStatus::VERIFIED, binding_finalized_at: Time.current,
    )
    bootstrap = BaseSelectorBootstrapAuthority.call(surface: :app, principal: @user)

    assert_instance_of ClientIdentity, bootstrap.identity
    assert_equal @user.id, bootstrap.identity.source_record_id
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
    rt = Rack::Utils.parse_query(URI.parse(base.response.location).query).fetch("rt")
    payload, = JWT.decode(
      rt, JitSecurityJwtRegistry.public_key_for(issuer.id, issuer.current_kid), true,
      algorithms: ["ES384"], verify_iss: true, iss: "https://#{base_host}",
      verify_aud: true, aud: Rails.configuration.x.boot_config.fetch(:jump).audience,
    )
    target = URI.parse(payload.fetch("url"))

    assert_equal base_host, target.host
    base.get(target.request_uri)
    authorization_form = Nokogiri::HTML(base.response.body).at_css("form#base-authorization-ceremony-start-form")
    authorization_fields = authorization_form.css("input[name]").to_h { |input| [input["name"], input["value"]] }
    base.post(authorization_form["action"], params: authorization_fields, headers: base_headers)

    assert_equal 303, base.response.status
    # There is no local-parent HTTP issuer; its public API remains the fixture seam,
    # while attachment, Base confirmation and redemption retain all browser protections.
    nonce = SecureRandom.urlsafe_base64(SignInCycleLocator::NONCE_BYTES)
    issuance = BaseAuthAdmissionCoordinator.issue_local_entry!(
      surface: "app", intent: "sign_in",
      base_browser_nonce: base.session.fetch(BaseAdmissionBrowserBinding::BROWSER_NONCE_SESSION_KEY),
      base_token: nil, nonce_digest: ClientSignInFlow.digest_nonce(nonce),
    )
    flow = issuance.transaction
    SignInCycleLocator.new(base.session, surface: "app").issue!(flow, nonce: nonce)
    session_key = JitSessionCookieConfig.cookie_key(force_secure: JitSessionCookieConfig.force_secure?)
    session_cookie_jar = ActionDispatch::Cookies::CookieJar.build(base.request, base.request.cookies)
    session_cookie_jar.encrypted[session_key] = { value: base.session.to_hash.stringify_keys }
    encoded_session = session_cookie_jar[session_key]
    base.cookies.delete(session_key)
    base.cookies.merge( # rubocop:disable Lint/Void
      "#{session_key}=#{Rack::Utils.escape(encoded_session)}", URI.parse("https://#{base_host}/"),
    )
    binding = BaseAuthAdmissionCoordinator.find_admission_binding!(surface: "app", reference: issuance.reference)
    auth.host!(auth_host)
    auth.https!
    auth.get(auth_app_sign_in_path, params: { entry_ref: issuance.reference, ri: "jp" })

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
    auth_headers = auth_headers.merge("X-CSRF-Token" => csrf)
    auth_browser = auth
    auth_browser.post(
      auth_app_sign_in_email_path,
      params: { :user_email => { address: @email.address }, "cf-turnstile-response" => "t", :ri => "jp" },
      headers: auth_headers,
    )
    delivery_job = enqueued_jobs.reverse.find { |job| job.fetch(:job) == OtpNotifierEmailDeliveryJob }

    assert_not_nil delivery_job
    delivery = ActiveJob::Arguments.deserialize(delivery_job.fetch(:args)).last.fetch(:params).symbolize_keys
    ceremony = ClientAuthCeremonySession.find(delivery.fetch(:auth_ceremony_session_ref))
    context = ceremony.email_otp_context
    code = OutboundSensitivePayload.decrypt_email_otp(delivery.fetch(:encrypted_hotp_token))

    # assert_match would disclose the delivered secret on failure.
    # rubocop:disable Minitest/AssertMatch
    assert code.match?(/\A[0-9]{6}\z/), "Delivery must contain one six-digit code"
    # rubocop:enable Minitest/AssertMatch
    assert_equal "sign_in", delivery.fetch(:purpose)
    assert_equal "app", context.fetch("surface")
    assert_equal "authentication", context.fetch("purpose")
    assert_equal "local_sign_in", context.fetch("parent_kind")
    assert_equal "real", context.fetch("mode")
    # Boolean comparisons keep ceremony bindings and keyed proof out of failure output.
    # rubocop:disable Minitest/AssertEqual, Minitest/AssertOperator
    assert context.fetch("parent_ref") == flow.public_id
    assert context.fetch("contact_ref") == @email.public_id
    assert context.fetch("owner_ref") == @user.public_id
    assert context.fetch("sid_digest") == ceremony.sid_digest
    assert context.fetch("generation") == delivery.fetch(:auth_email_otp_generation)
    # rubocop:enable Minitest/AssertEqual, Minitest/AssertOperator
    assert_nil context.fetch("verified_at")
    assert_not delivery_job.fetch(:args).to_s.include?(code), "Delivery must not queue the plaintext code"
    audit_count = ClientChronicle.where(subject_id: @user.id, event_id: ClientChronicleEvent::LOGGED_IN).count
    assert_no_difference(-> { ClientToken.where(user_id: @user.id).count }) do
      auth_browser.patch(
        auth_app_sign_in_email_path,
        params: { :user_email => { pass_code: code },
                  "cf-turnstile-response" => "t",
                  :ri => "jp", },
        headers: auth_headers,
      )
      auth_browser.follow_redirect!
      auth_browser.follow_redirect!
      auth_browser.post(auth_app_sign_handoff_path, params: { ri: "jp" }, headers: auth_headers)
    end

    assert_equal 303, auth_browser.response.status
    assert_nil auth_browser.cookies[AuthenticationBase::ACCESS_COOKIE_KEY]
    assert_nil auth_browser.cookies[AuthenticationBase::REFRESH_COOKIE_KEY]
    assert_equal audit_count,
                 ClientChronicle.where(subject_id: @user.id, event_id: ClientChronicleEvent::LOGGED_IN).count
    get URI.parse(auth_browser.response.redirect_url).request_uri

    assert_response :success
    completion_form = response.parsed_body.at_css("form")
    completion_params = completion_form.css("input[name]").to_h { |field| [field["name"], field["value"]] }
    assert_difference(-> { ClientToken.where(user_id: @user.id).count }, 1) do
      post base_app_sign_completion_path,
           params: completion_params,
           headers: base_headers
    end

    assert_response :see_other
    token = ClientToken.find_by!(user_id: @user.id)

    assert_predicate token, :active_status?
    assert_not_nil token.root_login_established_at
    assert_not_nil token.device_session_id
    assert_predicate cookies[AuthenticationBase::ACCESS_COOKIE_KEY].to_s, :present?
    assert_equal token.id, flow.reload.token_id
    assert_equal flow.authentication_event_at, token.authentication_event_at
    assert_equal audit_count + 1,
                 ClientChronicle.where(subject_id: @user.id, event_id: ClientChronicleEvent::LOGGED_IN).count
    assert_redirected_to base_app_dashboard_path(ri: "jp")

    # A Root is OP authority, not a Browser-RP credential. Complete the real self-RP
    # callback before continuing into Base's protected browser operations.
    assert_no_difference("ClientToken.count") do
      get "/sign", params: { ri: "jp", pt: base_app_dashboard_path(ri: "jp") }
      rp_form = response.parsed_body.at_css("form")
      rp_fields = rp_form.css("input[name]").to_h { |field| [field["name"], field["value"]] }
      post rp_form["action"], params: rp_fields, headers: base_headers

      assert_response :redirect
      rp_rt = Rack::Utils.parse_query(URI.parse(response.location).query).fetch("rt")
      rp_payload, = JWT.decode(
        rp_rt, JitSecurityJwtRegistry.public_key_for(issuer.id, issuer.current_kid), true,
        algorithms: ["ES384"], verify_iss: true, iss: "https://#{base_host}",
        verify_aud: true, aud: Rails.configuration.x.boot_config.fetch(:jump).audience,
      )
      authorize_uri = URI.parse(rp_payload.fetch("url"))

      assert_equal base_host, authorize_uri.host
      get authorize_uri.request_uri

      assert_response :redirect
      callback_rt = Rack::Utils.parse_query(URI.parse(response.location).query).fetch("rt")
      callback_payload, = JWT.decode(
        callback_rt, JitSecurityJwtRegistry.public_key_for(issuer.id, issuer.current_kid), true,
        algorithms: ["ES384"], verify_iss: true, iss: "https://#{base_host}",
        verify_aud: true, aud: Rails.configuration.x.boot_config.fetch(:jump).audience,
      )
      callback_uri = URI.parse(callback_payload.fetch("url"))

      assert_equal base_host, callback_uri.host
      protocol_browser = open_session
      protocol_browser.host!(base_host)
      protocol_browser.https!
      # Substitute network transport only: the token and UserInfo requests still run
      # through their real public controllers, including PKCE and client authentication.
      transport =
        Faraday::Adapter::Test::Stubs.new do |stub|
          stub.post(/.*/) do |env|
            # The nested Rack executor must not complete the in-flight callback.
            outer_controller = ActiveSupport::ExecutionContext.to_h.fetch(:controller)
            outer_actor = Actor.context
            executor_key = Rails.application.executor.active_key
            outer_execution = ActiveSupport::IsolatedExecutionState.delete(executor_key)
            begin
              protocol_browser.host!(env.url.authority)
              protocol_browser.https!(env.url.scheme == "https")
              protocol_browser.post(
                env.url.request_uri, params: Rack::Utils.parse_query(env.body),
                                     headers: { "Accept" => "application/json" },
              )
            ensure
              ActiveSupport::IsolatedExecutionState[executor_key] = outer_execution
            end

            # rubocop:disable Minitest/AssertSame -- Do not print the outer request or credentials on failure.
            assert ActiveSupport::ExecutionContext.to_h.fetch(:controller).equal?(outer_controller)
            assert Actor.context.equal?(outer_actor)
            # rubocop:enable Minitest/AssertSame
            assert_equal 200, protocol_browser.response.status
            [protocol_browser.response.status, { "Content-Type" => "application/json" },
             protocol_browser.response.body,]
          end
          stub.get(/.*/) do |env|
            outer_controller = ActiveSupport::ExecutionContext.to_h.fetch(:controller)
            outer_actor = Actor.context
            executor_key = Rails.application.executor.active_key
            outer_execution = ActiveSupport::IsolatedExecutionState.delete(executor_key)
            begin
              protocol_browser.host!(env.url.authority)
              protocol_browser.https!(env.url.scheme == "https")
              protocol_browser.get(
                env.url.request_uri, headers: { "Authorization" => env.request_headers.fetch("Authorization"),
                                                "Accept" => "application/json", },
              )
            ensure
              ActiveSupport::IsolatedExecutionState[executor_key] = outer_execution
            end

            # rubocop:disable Minitest/AssertSame -- Do not print the outer request or credentials on failure.
            assert ActiveSupport::ExecutionContext.to_h.fetch(:controller).equal?(outer_controller)
            assert Actor.context.equal?(outer_actor)
            # rubocop:enable Minitest/AssertSame
            assert_equal 200, protocol_browser.response.status
            [protocol_browser.response.status, { "Content-Type" => "application/json" },
             protocol_browser.response.body,]
          end
        end
      connection =
        Faraday.new do |builder|
          builder.request(:url_encoded)
          builder.adapter(:test, transport)
        end
      OutboundHttp::Connection.stub(
        :build, ->(**args) {
          assert_equal base_host, args.fetch(:url).host
          connection
        },
      ) do
        TestSupport::OutboundHttpGuard.allow do
          get callback_uri.request_uri
        end
      end

      assert_response :redirect
      assert_predicate cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE].to_s, :present?
      assert_predicate cookies[OidcRpBrowserCredentialContract::REFRESH_COOKIE].to_s, :present?
      transport.verify_stubbed_calls
    end
    get base_app_dashboard_path(ri: "jp")

    assert_response :success
  end
  # rubocop:enable Minitest/MultipleAssertions

  # rubocop:disable Minitest/MultipleAssertions
  test "credential change after Auth completion rejects the outstanding result at the Base root boundary" do
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
    rt = Rack::Utils.parse_query(URI.parse(base.response.location).query).fetch("rt")
    payload, = JWT.decode(
      rt, JitSecurityJwtRegistry.public_key_for(issuer.id, issuer.current_kid), true,
      algorithms: ["ES384"], verify_iss: true, iss: "https://#{base_host}",
      verify_aud: true, aud: Rails.configuration.x.boot_config.fetch(:jump).audience,
    )
    target = URI.parse(payload.fetch("url"))

    assert_equal base_host, target.host
    base.get(target.request_uri)
    authorization_form = Nokogiri::HTML(base.response.body).at_css("form#base-authorization-ceremony-start-form")
    authorization_fields = authorization_form.css("input[name]").to_h { |input| [input["name"], input["value"]] }
    base.post(authorization_form["action"], params: authorization_fields, headers: base_headers)

    assert_equal 303, base.response.status
    # There is no local-parent HTTP issuer; its public API remains the fixture seam,
    # while attachment, Base confirmation and redemption retain all browser protections.
    nonce = SecureRandom.urlsafe_base64(SignInCycleLocator::NONCE_BYTES)
    issuance = BaseAuthAdmissionCoordinator.issue_local_entry!(
      surface: "app", intent: "sign_in",
      base_browser_nonce: base.session.fetch(BaseAdmissionBrowserBinding::BROWSER_NONCE_SESSION_KEY),
      base_token: nil, nonce_digest: ClientSignInFlow.digest_nonce(nonce),
    )
    flow = issuance.transaction
    SignInCycleLocator.new(base.session, surface: "app").issue!(flow, nonce: nonce)
    session_key = JitSessionCookieConfig.cookie_key(force_secure: JitSessionCookieConfig.force_secure?)
    session_cookie_jar = ActionDispatch::Cookies::CookieJar.build(base.request, base.request.cookies)
    session_cookie_jar.encrypted[session_key] = { value: base.session.to_hash.stringify_keys }
    encoded_session = session_cookie_jar[session_key]
    base.cookies.delete(session_key)
    base.cookies.merge( # rubocop:disable Lint/Void
      "#{session_key}=#{Rack::Utils.escape(encoded_session)}", URI.parse("https://#{base_host}/"),
    )
    binding = BaseAuthAdmissionCoordinator.find_admission_binding!(surface: "app", reference: issuance.reference)
    auth.host!(auth_host)
    auth.https!
    auth.get(auth_app_sign_in_path, params: { entry_ref: issuance.reference, ri: "jp" })

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
    auth_headers = auth_headers.merge("X-CSRF-Token" => csrf)
    auth_browser = auth
    auth_browser.post(
      auth_app_sign_in_email_path,
      params: { :user_email => { address: @email.address }, "cf-turnstile-response" => "t", :ri => "jp" },
      headers: auth_headers,
    )
    delivery_job = enqueued_jobs.reverse.find { |job| job.fetch(:job) == OtpNotifierEmailDeliveryJob }

    assert_not_nil delivery_job
    delivery = ActiveJob::Arguments.deserialize(delivery_job.fetch(:args)).last.fetch(:params).symbolize_keys
    ceremony = ClientAuthCeremonySession.find(delivery.fetch(:auth_ceremony_session_ref))
    context = ceremony.email_otp_context
    code = OutboundSensitivePayload.decrypt_email_otp(delivery.fetch(:encrypted_hotp_token))

    # assert_match would disclose the delivered secret on failure.
    # rubocop:disable Minitest/AssertMatch
    assert code.match?(/\A[0-9]{6}\z/), "Delivery must contain one six-digit code"
    # rubocop:enable Minitest/AssertMatch
    assert_equal "sign_in", delivery.fetch(:purpose)
    assert_equal "app", context.fetch("surface")
    assert_equal "authentication", context.fetch("purpose")
    assert_equal "local_sign_in", context.fetch("parent_kind")
    assert_equal "real", context.fetch("mode")
    # Boolean comparisons keep ceremony bindings and keyed proof out of failure output.
    # rubocop:disable Minitest/AssertEqual, Minitest/AssertOperator
    assert context.fetch("parent_ref") == flow.public_id
    assert context.fetch("contact_ref") == @email.public_id
    assert context.fetch("owner_ref") == @user.public_id
    assert context.fetch("sid_digest") == ceremony.sid_digest
    assert context.fetch("generation") == delivery.fetch(:auth_email_otp_generation)
    # rubocop:enable Minitest/AssertEqual, Minitest/AssertOperator
    assert_nil context.fetch("verified_at")
    assert_not delivery_job.fetch(:args).to_s.include?(code), "Delivery must not queue the plaintext code"
    auth_browser.patch(
      auth_app_sign_in_email_path,
      params: { :user_email => { pass_code: code },
                "cf-turnstile-response" => "t",
                :ri => "jp", },
      headers: auth_headers,
    )
    auth_browser.follow_redirect!
    auth_browser.follow_redirect!
    auth_browser.post(auth_app_sign_handoff_path, params: { ri: "jp" }, headers: auth_headers)

    assert_equal 303, auth_browser.response.status
    get URI.parse(auth_browser.response.redirect_url).request_uri

    assert_response :success
    completion_form = response.parsed_body.at_css("form")
    completion_params = completion_form.css("input[name]").to_h { |field| [field["name"], field["value"]] }
    event = flow.reload.authentication_event_at
    generation = flow.result_generation
    CredentialSecurityTransition.call(
      actor: @user, current_session: nil, reason: :password_changed, affected_surface: :app,
      revoke_other_sessions: false,
    )
    audit_count = ClientChronicle.where(subject_id: @user.id, event_id: ClientChronicleEvent::LOGGED_IN).count
    host! ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    assert_no_difference(-> { ClientToken.where(user_id: @user.id).count }) do
      post base_app_sign_completion_path,
           params: completion_params,
           headers: base_headers
    end

    # Security invalidation halts the original flow; it cannot issue a new Root.
    assert_response :bad_request
    assert_nil cookies[AuthenticationBase::ACCESS_COOKIE_KEY]
    assert_nil cookies[AuthenticationBase::REFRESH_COOKIE_KEY]
    assert_predicate flow.reload, :sign_in_halted?
    assert_nil flow.base_finalized_at
    assert_equal event, flow.authentication_event_at
    assert_equal generation, flow.result_generation
    assert_equal audit_count,
                 ClientChronicle.where(subject_id: @user.id, event_id: ClientChronicleEvent::LOGGED_IN).count
  end

  # rubocop:enable Minitest/MultipleAssertions

  # rubocop:disable Minitest/MultipleAssertions
  test "at the session limit nothing is issued: no token, no cookie, no audit, and the flow waits" do
    existing = Array.new(ClientToken::MAX_SESSIONS_PER_USER) { ClientToken.create!(user: @user) }
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
    rt = Rack::Utils.parse_query(URI.parse(base.response.location).query).fetch("rt")
    payload, = JWT.decode(
      rt, JitSecurityJwtRegistry.public_key_for(issuer.id, issuer.current_kid), true,
      algorithms: ["ES384"], verify_iss: true, iss: "https://#{base_host}",
      verify_aud: true, aud: Rails.configuration.x.boot_config.fetch(:jump).audience,
    )
    target = URI.parse(payload.fetch("url"))

    assert_equal base_host, target.host
    base.get(target.request_uri)
    authorization_form = Nokogiri::HTML(base.response.body).at_css("form#base-authorization-ceremony-start-form")
    authorization_fields = authorization_form.css("input[name]").to_h { |input| [input["name"], input["value"]] }
    base.post(authorization_form["action"], params: authorization_fields, headers: base_headers)

    assert_equal 303, base.response.status
    # There is no local-parent HTTP issuer; its public API remains the fixture seam,
    # while attachment, Base confirmation and redemption retain all browser protections.
    nonce = SecureRandom.urlsafe_base64(SignInCycleLocator::NONCE_BYTES)
    issuance = BaseAuthAdmissionCoordinator.issue_local_entry!(
      surface: "app", intent: "sign_in",
      base_browser_nonce: base.session.fetch(BaseAdmissionBrowserBinding::BROWSER_NONCE_SESSION_KEY),
      base_token: nil, nonce_digest: ClientSignInFlow.digest_nonce(nonce),
    )
    flow = issuance.transaction
    SignInCycleLocator.new(base.session, surface: "app").issue!(flow, nonce: nonce)
    session_key = JitSessionCookieConfig.cookie_key(force_secure: JitSessionCookieConfig.force_secure?)
    session_cookie_jar = ActionDispatch::Cookies::CookieJar.build(base.request, base.request.cookies)
    session_cookie_jar.encrypted[session_key] = { value: base.session.to_hash.stringify_keys }
    encoded_session = session_cookie_jar[session_key]
    base.cookies.delete(session_key)
    base.cookies.merge( # rubocop:disable Lint/Void
      "#{session_key}=#{Rack::Utils.escape(encoded_session)}", URI.parse("https://#{base_host}/"),
    )
    binding = BaseAuthAdmissionCoordinator.find_admission_binding!(surface: "app", reference: issuance.reference)
    auth.host!(auth_host)
    auth.https!
    auth.get(auth_app_sign_in_path, params: { entry_ref: issuance.reference, ri: "jp" })

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
    auth_headers = auth_headers.merge("X-CSRF-Token" => csrf)
    auth_browser = auth
    auth_browser.post(
      auth_app_sign_in_email_path,
      params: { :user_email => { address: @email.address }, "cf-turnstile-response" => "t", :ri => "jp" },
      headers: auth_headers,
    )
    delivery_job = enqueued_jobs.reverse.find { |job| job.fetch(:job) == OtpNotifierEmailDeliveryJob }

    assert_not_nil delivery_job
    delivery = ActiveJob::Arguments.deserialize(delivery_job.fetch(:args)).last.fetch(:params).symbolize_keys
    ceremony = ClientAuthCeremonySession.find(delivery.fetch(:auth_ceremony_session_ref))
    context = ceremony.email_otp_context
    code = OutboundSensitivePayload.decrypt_email_otp(delivery.fetch(:encrypted_hotp_token))

    # assert_match would disclose the delivered secret on failure.
    # rubocop:disable Minitest/AssertMatch
    assert code.match?(/\A[0-9]{6}\z/), "Delivery must contain one six-digit code"
    # rubocop:enable Minitest/AssertMatch
    assert_equal "sign_in", delivery.fetch(:purpose)
    assert_equal "app", context.fetch("surface")
    assert_equal "authentication", context.fetch("purpose")
    assert_equal "local_sign_in", context.fetch("parent_kind")
    assert_equal "real", context.fetch("mode")
    # Boolean comparisons keep ceremony bindings and keyed proof out of failure output.
    # rubocop:disable Minitest/AssertEqual, Minitest/AssertOperator
    assert context.fetch("parent_ref") == flow.public_id
    assert context.fetch("contact_ref") == @email.public_id
    assert context.fetch("owner_ref") == @user.public_id
    assert context.fetch("sid_digest") == ceremony.sid_digest
    assert context.fetch("generation") == delivery.fetch(:auth_email_otp_generation)
    # rubocop:enable Minitest/AssertEqual, Minitest/AssertOperator
    assert_nil context.fetch("verified_at")
    assert_not delivery_job.fetch(:args).to_s.include?(code), "Delivery must not queue the plaintext code"
    audit_count = ClientChronicle.where(subject_id: @user.id, event_id: ClientChronicleEvent::LOGGED_IN).count
    assert_no_difference(-> { ClientToken.where(user_id: @user.id).count }) do
      auth_browser.patch(
        auth_app_sign_in_email_path,
        params: { :user_email => { pass_code: code },
                  "cf-turnstile-response" => "t",
                  :ri => "jp", },
        headers: auth_headers,
      )
      auth_browser.follow_redirect!
      auth_browser.follow_redirect!
      auth_browser.post(auth_app_sign_handoff_path, params: { ri: "jp" }, headers: auth_headers)
    end

    assert_equal 303, auth_browser.response.status
    assert_nil auth_browser.cookies[AuthenticationBase::ACCESS_COOKIE_KEY]
    assert_nil auth_browser.cookies[AuthenticationBase::REFRESH_COOKIE_KEY]
    assert_equal audit_count,
                 ClientChronicle.where(subject_id: @user.id, event_id: ClientChronicleEvent::LOGGED_IN).count
    get URI.parse(auth_browser.response.redirect_url).request_uri

    assert_response :success
    completion_form = response.parsed_body.at_css("form")
    completion_params = completion_form.css("input[name]").to_h { |field| [field["name"], field["value"]] }
    assert_no_difference(-> { ClientToken.where(user_id: @user.id).count }) do
      post base_app_sign_completion_path,
           params: completion_params,
           headers: base_headers
    end

    assert_redirected_to base_app_sign_in_limitation_path(ri: "jp")
    assert_nil cookies[AuthenticationBase::ACCESS_COOKIE_KEY]
    assert_nil cookies[AuthenticationBase::REFRESH_COOKIE_KEY]
    assert_predicate flow.reload, :sign_in_session_issuance_pending?
    assert_nil flow.token_id
    assert_nil flow.base_finalized_at
    assert(existing.all? { |token| token.reload.active_status? })
    assert_equal audit_count,
                 ClientChronicle.where(subject_id: @user.id, event_id: ClientChronicleEvent::LOGGED_IN).count
    assert_equal 0, ClientToken.where(user_id: @user.id, user_token_status_id: ClientTokenStatus::RESTRICTED).count
    follow_redirect!

    assert_response :success
    props = JSON.parse(response.parsed_body.at_css("script[data-page='app']").text).fetch("props")

    assert_equal ClientToken::MAX_SESSIONS_PER_USER, props.fetch("sessions").length
  end
  # rubocop:enable Minitest/MultipleAssertions

  # rubocop:disable Minitest/MultipleAssertions
  test "resolving the limit commits the waiting flow once; a repeated submit issues nothing more" do
    existing = Array.new(ClientToken::MAX_SESSIONS_PER_USER) { ClientToken.create!(user: @user) }
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
    rt = Rack::Utils.parse_query(URI.parse(base.response.location).query).fetch("rt")
    payload, = JWT.decode(
      rt, JitSecurityJwtRegistry.public_key_for(issuer.id, issuer.current_kid), true,
      algorithms: ["ES384"], verify_iss: true, iss: "https://#{base_host}",
      verify_aud: true, aud: Rails.configuration.x.boot_config.fetch(:jump).audience,
    )
    target = URI.parse(payload.fetch("url"))

    assert_equal base_host, target.host
    base.get(target.request_uri)
    authorization_form = Nokogiri::HTML(base.response.body).at_css("form#base-authorization-ceremony-start-form")
    authorization_fields = authorization_form.css("input[name]").to_h { |input| [input["name"], input["value"]] }
    base.post(authorization_form["action"], params: authorization_fields, headers: base_headers)

    assert_equal 303, base.response.status
    # There is no local-parent HTTP issuer; its public API remains the fixture seam,
    # while attachment, Base confirmation and redemption retain all browser protections.
    nonce = SecureRandom.urlsafe_base64(SignInCycleLocator::NONCE_BYTES)
    issuance = BaseAuthAdmissionCoordinator.issue_local_entry!(
      surface: "app", intent: "sign_in",
      base_browser_nonce: base.session.fetch(BaseAdmissionBrowserBinding::BROWSER_NONCE_SESSION_KEY),
      base_token: nil, nonce_digest: ClientSignInFlow.digest_nonce(nonce),
    )
    flow = issuance.transaction
    SignInCycleLocator.new(base.session, surface: "app").issue!(flow, nonce: nonce)
    session_key = JitSessionCookieConfig.cookie_key(force_secure: JitSessionCookieConfig.force_secure?)
    session_cookie_jar = ActionDispatch::Cookies::CookieJar.build(base.request, base.request.cookies)
    session_cookie_jar.encrypted[session_key] = { value: base.session.to_hash.stringify_keys }
    encoded_session = session_cookie_jar[session_key]
    base.cookies.delete(session_key)
    base.cookies.merge( # rubocop:disable Lint/Void
      "#{session_key}=#{Rack::Utils.escape(encoded_session)}", URI.parse("https://#{base_host}/"),
    )
    binding = BaseAuthAdmissionCoordinator.find_admission_binding!(surface: "app", reference: issuance.reference)
    auth.host!(auth_host)
    auth.https!
    auth.get(auth_app_sign_in_path, params: { entry_ref: issuance.reference, ri: "jp" })

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
    auth_headers = auth_headers.merge("X-CSRF-Token" => csrf)
    auth_browser = auth
    auth_browser.post(
      auth_app_sign_in_email_path,
      params: { :user_email => { address: @email.address }, "cf-turnstile-response" => "t", :ri => "jp" },
      headers: auth_headers,
    )
    delivery_job = enqueued_jobs.reverse.find { |job| job.fetch(:job) == OtpNotifierEmailDeliveryJob }

    assert_not_nil delivery_job
    delivery = ActiveJob::Arguments.deserialize(delivery_job.fetch(:args)).last.fetch(:params).symbolize_keys
    ceremony = ClientAuthCeremonySession.find(delivery.fetch(:auth_ceremony_session_ref))
    context = ceremony.email_otp_context
    code = OutboundSensitivePayload.decrypt_email_otp(delivery.fetch(:encrypted_hotp_token))

    # assert_match would disclose the delivered secret on failure.
    # rubocop:disable Minitest/AssertMatch
    assert code.match?(/\A[0-9]{6}\z/), "Delivery must contain one six-digit code"
    # rubocop:enable Minitest/AssertMatch
    assert_equal "sign_in", delivery.fetch(:purpose)
    assert_equal "app", context.fetch("surface")
    assert_equal "authentication", context.fetch("purpose")
    assert_equal "local_sign_in", context.fetch("parent_kind")
    assert_equal "real", context.fetch("mode")
    # Boolean comparisons keep ceremony bindings and keyed proof out of failure output.
    # rubocop:disable Minitest/AssertEqual, Minitest/AssertOperator
    assert context.fetch("parent_ref") == flow.public_id
    assert context.fetch("contact_ref") == @email.public_id
    assert context.fetch("owner_ref") == @user.public_id
    assert context.fetch("sid_digest") == ceremony.sid_digest
    assert context.fetch("generation") == delivery.fetch(:auth_email_otp_generation)
    # rubocop:enable Minitest/AssertEqual, Minitest/AssertOperator
    assert_nil context.fetch("verified_at")
    assert_not delivery_job.fetch(:args).to_s.include?(code), "Delivery must not queue the plaintext code"
    audit_count = ClientChronicle.where(subject_id: @user.id, event_id: ClientChronicleEvent::LOGGED_IN).count
    assert_no_difference(-> { ClientToken.where(user_id: @user.id).count }) do
      auth_browser.patch(
        auth_app_sign_in_email_path,
        params: { :user_email => { pass_code: code },
                  "cf-turnstile-response" => "t",
                  :ri => "jp", },
        headers: auth_headers,
      )
      auth_browser.follow_redirect!
      auth_browser.follow_redirect!
      auth_browser.post(auth_app_sign_handoff_path, params: { ri: "jp" }, headers: auth_headers)
    end

    assert_equal 303, auth_browser.response.status
    assert_nil auth_browser.cookies[AuthenticationBase::ACCESS_COOKIE_KEY]
    assert_nil auth_browser.cookies[AuthenticationBase::REFRESH_COOKIE_KEY]
    assert_equal audit_count,
                 ClientChronicle.where(subject_id: @user.id, event_id: ClientChronicleEvent::LOGGED_IN).count
    get URI.parse(auth_browser.response.redirect_url).request_uri

    assert_response :success
    completion_form = response.parsed_body.at_css("form")
    completion_params = completion_form.css("input[name]").to_h { |field| [field["name"], field["value"]] }
    assert_no_difference(-> { ClientToken.where(user_id: @user.id).count }) do
      post base_app_sign_completion_path,
           params: completion_params,
           headers: base_headers
    end

    assert_redirected_to base_app_sign_in_limitation_path(ri: "jp")
    event_at = flow.reload.authentication_event_at
    follow_redirect!
    props = JSON.parse(response.parsed_body.at_css("script[data-page='app']").text).fetch("props")
    ref = props.fetch("sessions").first.fetch("session_ref")
    limit_csrf = response.parsed_body.at_css('meta[name="csrf-token"]')["content"]
    assert_difference(-> { ClientToken.where(user_id: @user.id).count }, 1) do
      patch base_app_sign_in_limitation_path, params: { ri: "jp", session_ref: ref },
                                              headers: base_headers.merge("X-CSRF-Token" => limit_csrf)
    end

    assert_response :see_other
    issued = ClientToken.where(user_id: @user.id).order(:id).last

    assert_equal 1, existing.map(&:reload).count(&:revoked?)
    assert_equal issued.id, flow.reload.token_id
    assert_not_nil flow.base_finalized_at
    assert_not_nil issued.root_login_established_at
    assert_equal event_at, issued.authentication_event_at
    assert_predicate cookies[AuthenticationBase::ACCESS_COOKIE_KEY].to_s, :present?
    assert_nil auth_browser.cookies[AuthenticationBase::ACCESS_COOKIE_KEY]
    assert_equal audit_count + 1,
                 ClientChronicle.where(subject_id: @user.id, event_id: ClientChronicleEvent::LOGGED_IN).count
    get URI.parse(auth_browser.response.location).request_uri

    assert_response :success
    limit_csrf = response.parsed_body.at_css('input[name="authenticity_token"]')["value"]
    assert_no_difference(-> { ClientToken.where(user_id: @user.id).count }) do
      patch base_app_sign_in_limitation_path, params: { ri: "jp", session_ref: ref },
                                              headers: base_headers.merge("X-CSRF-Token" => limit_csrf)
    end
    assert_equal audit_count + 1,
                 ClientChronicle.where(subject_id: @user.id, event_id: ClientChronicleEvent::LOGGED_IN).count
  end
  # rubocop:enable Minitest/MultipleAssertions

  # rubocop:disable Minitest/MultipleAssertions
  test "cancelling at the limit ends only the waiting flow and keeps every existing session" do
    existing = Array.new(ClientToken::MAX_SESSIONS_PER_USER) { ClientToken.create!(user: @user) }
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
    rt = Rack::Utils.parse_query(URI.parse(base.response.location).query).fetch("rt")
    payload, = JWT.decode(
      rt, JitSecurityJwtRegistry.public_key_for(issuer.id, issuer.current_kid), true,
      algorithms: ["ES384"], verify_iss: true, iss: "https://#{base_host}",
      verify_aud: true, aud: Rails.configuration.x.boot_config.fetch(:jump).audience,
    )
    target = URI.parse(payload.fetch("url"))

    assert_equal base_host, target.host
    base.get(target.request_uri)
    authorization_form = Nokogiri::HTML(base.response.body).at_css("form#base-authorization-ceremony-start-form")
    authorization_fields = authorization_form.css("input[name]").to_h { |input| [input["name"], input["value"]] }
    base.post(authorization_form["action"], params: authorization_fields, headers: base_headers)

    assert_equal 303, base.response.status
    # There is no local-parent HTTP issuer; its public API remains the fixture seam,
    # while attachment, Base confirmation and redemption retain all browser protections.
    nonce = SecureRandom.urlsafe_base64(SignInCycleLocator::NONCE_BYTES)
    issuance = BaseAuthAdmissionCoordinator.issue_local_entry!(
      surface: "app", intent: "sign_in",
      base_browser_nonce: base.session.fetch(BaseAdmissionBrowserBinding::BROWSER_NONCE_SESSION_KEY),
      base_token: nil, nonce_digest: ClientSignInFlow.digest_nonce(nonce),
    )
    flow = issuance.transaction
    SignInCycleLocator.new(base.session, surface: "app").issue!(flow, nonce: nonce)
    session_key = JitSessionCookieConfig.cookie_key(force_secure: JitSessionCookieConfig.force_secure?)
    session_cookie_jar = ActionDispatch::Cookies::CookieJar.build(base.request, base.request.cookies)
    session_cookie_jar.encrypted[session_key] = { value: base.session.to_hash.stringify_keys }
    encoded_session = session_cookie_jar[session_key]
    base.cookies.delete(session_key)
    base.cookies.merge( # rubocop:disable Lint/Void
      "#{session_key}=#{Rack::Utils.escape(encoded_session)}", URI.parse("https://#{base_host}/"),
    )
    binding = BaseAuthAdmissionCoordinator.find_admission_binding!(surface: "app", reference: issuance.reference)
    auth.host!(auth_host)
    auth.https!
    auth.get(auth_app_sign_in_path, params: { entry_ref: issuance.reference, ri: "jp" })

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
    auth_headers = auth_headers.merge("X-CSRF-Token" => csrf)
    auth_browser = auth
    auth_browser.post(
      auth_app_sign_in_email_path,
      params: { :user_email => { address: @email.address }, "cf-turnstile-response" => "t", :ri => "jp" },
      headers: auth_headers,
    )
    delivery_job = enqueued_jobs.reverse.find { |job| job.fetch(:job) == OtpNotifierEmailDeliveryJob }

    assert_not_nil delivery_job
    delivery = ActiveJob::Arguments.deserialize(delivery_job.fetch(:args)).last.fetch(:params).symbolize_keys
    ceremony = ClientAuthCeremonySession.find(delivery.fetch(:auth_ceremony_session_ref))
    context = ceremony.email_otp_context
    code = OutboundSensitivePayload.decrypt_email_otp(delivery.fetch(:encrypted_hotp_token))

    # assert_match would disclose the delivered secret on failure.
    # rubocop:disable Minitest/AssertMatch
    assert code.match?(/\A[0-9]{6}\z/), "Delivery must contain one six-digit code"
    # rubocop:enable Minitest/AssertMatch
    assert_equal "sign_in", delivery.fetch(:purpose)
    assert_equal "app", context.fetch("surface")
    assert_equal "authentication", context.fetch("purpose")
    assert_equal "local_sign_in", context.fetch("parent_kind")
    assert_equal "real", context.fetch("mode")
    # Boolean comparisons keep ceremony bindings and keyed proof out of failure output.
    # rubocop:disable Minitest/AssertEqual, Minitest/AssertOperator
    assert context.fetch("parent_ref") == flow.public_id
    assert context.fetch("contact_ref") == @email.public_id
    assert context.fetch("owner_ref") == @user.public_id
    assert context.fetch("sid_digest") == ceremony.sid_digest
    assert context.fetch("generation") == delivery.fetch(:auth_email_otp_generation)
    # rubocop:enable Minitest/AssertEqual, Minitest/AssertOperator
    assert_nil context.fetch("verified_at")
    assert_not delivery_job.fetch(:args).to_s.include?(code), "Delivery must not queue the plaintext code"
    audit_count = ClientChronicle.where(subject_id: @user.id, event_id: ClientChronicleEvent::LOGGED_IN).count
    assert_no_difference(-> { ClientToken.where(user_id: @user.id).count }) do
      auth_browser.patch(
        auth_app_sign_in_email_path,
        params: { :user_email => { pass_code: code },
                  "cf-turnstile-response" => "t",
                  :ri => "jp", },
        headers: auth_headers,
      )
      auth_browser.follow_redirect!
      auth_browser.follow_redirect!
      auth_browser.post(auth_app_sign_handoff_path, params: { ri: "jp" }, headers: auth_headers)
    end

    assert_equal 303, auth_browser.response.status
    assert_nil auth_browser.cookies[AuthenticationBase::ACCESS_COOKIE_KEY]
    assert_nil auth_browser.cookies[AuthenticationBase::REFRESH_COOKIE_KEY]
    assert_equal audit_count,
                 ClientChronicle.where(subject_id: @user.id, event_id: ClientChronicleEvent::LOGGED_IN).count
    get URI.parse(auth_browser.response.redirect_url).request_uri

    assert_response :success
    completion_form = response.parsed_body.at_css("form")
    completion_params = completion_form.css("input[name]").to_h { |field| [field["name"], field["value"]] }
    assert_no_difference(-> { ClientToken.where(user_id: @user.id).count }) do
      post base_app_sign_completion_path,
           params: completion_params,
           headers: base_headers
    end

    assert_redirected_to base_app_sign_in_limitation_path(ri: "jp")
    follow_redirect!

    assert_response :success
    limit_csrf = response.parsed_body.at_css('meta[name="csrf-token"]')["content"]
    assert_no_difference(-> { ClientToken.where(user_id: @user.id).count }) do
      delete base_app_sign_in_limitation_path, params: { ri: "jp" },
                                               headers: base_headers.merge("X-CSRF-Token" => limit_csrf)
    end

    assert_redirected_to base_app_sign_show_path(ri: "jp")
    assert_predicate flow.reload, :sign_in_cancelled?
    assert_nil flow.token_id
    assert_nil flow.base_finalized_at
    assert(existing.all? { |token| token.reload.active_status? })
    assert_nil cookies[AuthenticationBase::ACCESS_COOKIE_KEY]
    assert_nil auth_browser.cookies[AuthenticationBase::ACCESS_COOKIE_KEY]
    assert_equal audit_count,
                 ClientChronicle.where(subject_id: @user.id, event_id: ClientChronicleEvent::LOGGED_IN).count
    get base_app_sign_in_limitation_path, params: { ri: "jp" }

    assert_response :gone
    assert_no_difference(-> { ClientToken.where(user_id: @user.id).count }) do
      post base_app_sign_completion_path,
           params: completion_params,
           headers: base_headers
    end

    assert_response :bad_request
  end
  # rubocop:enable Minitest/MultipleAssertions

  test "a principal id in the session alone does not open session-limit management" do
    Array.new(ClientToken::MAX_SESSIONS_PER_USER) { ClientToken.create!(user: @user) }
    host! ENV.fetch("PUBLIC_BASE_SERVICE_URL")

    get base_app_sign_in_limitation_path, params: { ri: "jp", principal_id: @user.id, actor_ref: @user.public_id }

    assert_response :gone
    assert_nil cookies[AuthenticationBase::ACCESS_COOKIE_KEY]
    assert_nil cookies[AuthenticationBase::REFRESH_COOKIE_KEY]
    assert_equal ClientToken::MAX_SESSIONS_PER_USER, ClientToken.where(user_id: @user.id).count
  end

  # Independent final attempts cover the exact cooldown and its nearest microsecond above.
  # rubocop:disable Minitest/MultipleAssertions
  [30, 30.000001].each do |final_elapsed|
    test "Base cooldown after logout preserves the anchor and admits at #{final_elapsed} seconds" do
      anchor = Time.current.change(usec: 0)
      first = nil
      previous_email = @email
      ClientSignInFlow.stub(:database_now, -> { Time.current }) do
        ClientAuthCeremonySession.stub(:database_now, -> { Time.current }) do
          [0, 10, 29.999999, final_elapsed].each do |elapsed|
            travel_to(anchor + elapsed, with_usec: true)
            # Independent contacts keep Email delivery cooldown from masking the Root
            # cooldown boundary; release does not reset the previous contact's OTP facts.
            attempt_email =
              if elapsed.zero?
                @email
              else
                previous_facts = previous_email.reload.attributes.except("binding_released_at", "updated_at")
                previous_email.release_binding!(at: Time.current)
                # rubocop:disable Minitest/AssertEqual, Minitest/AssertOperator -- Do not disclose retained contact proof.
                assert previous_email.reload.attributes.except("binding_released_at", "updated_at") == previous_facts
                # rubocop:enable Minitest/AssertEqual, Minitest/AssertOperator
                @user.client_emails.create!(
                  address: "cooldown-#{SecureRandom.hex(4)}@example.com",
                  user_email_status_id: ClientEmailStatus::VERIFIED, binding_finalized_at: Time.current,
                )
              end
            previous_email = attempt_email
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
            rt = Rack::Utils.parse_query(URI.parse(base.response.location).query).fetch("rt")
            payload, = JWT.decode(
              rt, JitSecurityJwtRegistry.public_key_for(issuer.id, issuer.current_kid), true,
              algorithms: ["ES384"], verify_iss: true, iss: "https://#{base_host}",
              verify_aud: true, aud: Rails.configuration.x.boot_config.fetch(:jump).audience,
            )
            target = URI.parse(payload.fetch("url"))

            assert_equal base_host, target.host
            base.get(target.request_uri)
            authorization_form = Nokogiri::HTML(base.response.body).at_css("form#base-authorization-ceremony-start-form")
            authorization_fields =
              authorization_form.css("input[name]").to_h { |input|
                [input["name"], input["value"]]
              }
            base.post(authorization_form["action"], params: authorization_fields, headers: base_headers)

            assert_equal 303, base.response.status
            # There is no local-parent HTTP issuer; its public API remains the fixture seam,
            # while attachment, Base confirmation and redemption retain all browser protections.
            nonce = SecureRandom.urlsafe_base64(SignInCycleLocator::NONCE_BYTES)
            issuance = BaseAuthAdmissionCoordinator.issue_local_entry!(
              surface: "app", intent: "sign_in",
              base_browser_nonce: base.session.fetch(BaseAdmissionBrowserBinding::BROWSER_NONCE_SESSION_KEY),
              base_token: nil, nonce_digest: ClientSignInFlow.digest_nonce(nonce),
            )
            flow = issuance.transaction
            SignInCycleLocator.new(base.session, surface: "app").issue!(flow, nonce: nonce)
            session_key = JitSessionCookieConfig.cookie_key(force_secure: JitSessionCookieConfig.force_secure?)
            session_cookie_jar = ActionDispatch::Cookies::CookieJar.build(base.request, base.request.cookies)
            session_cookie_jar.encrypted[session_key] = { value: base.session.to_hash.stringify_keys }
            encoded_session = session_cookie_jar[session_key]
            base.cookies.delete(session_key)
            base.cookies.merge( # rubocop:disable Lint/Void
              "#{session_key}=#{Rack::Utils.escape(encoded_session)}", URI.parse("https://#{base_host}/"),
            )
            binding = BaseAuthAdmissionCoordinator.find_admission_binding!(
              surface: "app",
              reference: issuance.reference,
            )
            auth.host!(auth_host)
            auth.https!
            auth.get(auth_app_sign_in_path, params: { entry_ref: issuance.reference, ri: "jp" })

            assert_equal 200, auth.response.status
            csrf = nil
            3.times do |admission_index|
              browser = (admission_index == 1) ? base : auth
              form = Nokogiri::HTML(browser.response.body).at_css("form")

              assert_not_nil form, "Admission step #{admission_index} must render its real continuation"
              fields = form.css("input[name]").to_h { |input| [input["name"], input["value"]] }
              csrf = fields.fetch("authenticity_token") if admission_index == 2
              assert_nil binding.reload.base_confirmed_at if admission_index == 1
              browser.post(
                form["action"], params: fields,
                                headers: (admission_index == 1) ? base_headers : auth_headers,
              )

              assert_equal 303, browser.response.status
              assert_not_nil binding.reload.base_confirmed_at if admission_index == 1
              next if admission_index == 2

              target = URI.parse(browser.response.location)
              receiver = admission_index.zero? ? base : auth

              assert_equal(admission_index.zero? ? base_host : auth_host, target.host)
              receiver.get(target.request_uri)
            end

            assert_predicate binding.reload, :redeemed?
            auth_headers = auth_headers.merge("X-CSRF-Token" => csrf)
            auth_browser = auth
            auth_browser.post(
              auth_app_sign_in_email_path,
              params: { :user_email => { address: attempt_email.address },
                        "cf-turnstile-response" => "t",
                        :ri => "jp", },
              headers: auth_headers,
            )
            delivery_job = enqueued_jobs.reverse.find { |job| job.fetch(:job) == OtpNotifierEmailDeliveryJob }

            assert_not_nil delivery_job
            delivery = ActiveJob::Arguments.deserialize(delivery_job.fetch(:args)).last.fetch(:params).symbolize_keys
            ceremony = ClientAuthCeremonySession.find(delivery.fetch(:auth_ceremony_session_ref))
            context = ceremony.email_otp_context
            code = OutboundSensitivePayload.decrypt_email_otp(delivery.fetch(:encrypted_hotp_token))

            # assert_match would disclose the delivered secret on failure.
            # rubocop:disable Minitest/AssertMatch
            assert code.match?(/\A[0-9]{6}\z/), "Delivery must contain one six-digit code"
            # rubocop:enable Minitest/AssertMatch
            assert_equal "sign_in", delivery.fetch(:purpose)
            assert_equal "app", context.fetch("surface")
            assert_equal "authentication", context.fetch("purpose")
            assert_equal "local_sign_in", context.fetch("parent_kind")
            assert_equal "real", context.fetch("mode")
            # Boolean comparisons keep ceremony bindings and keyed proof out of failure output.
            # rubocop:disable Minitest/AssertEqual, Minitest/AssertOperator
            assert context.fetch("parent_ref") == flow.public_id
            assert context.fetch("contact_ref") == attempt_email.public_id
            assert context.fetch("owner_ref") == @user.public_id
            assert context.fetch("sid_digest") == ceremony.sid_digest
            assert context.fetch("generation") == delivery.fetch(:auth_email_otp_generation)
            # rubocop:enable Minitest/AssertEqual, Minitest/AssertOperator
            assert_nil context.fetch("verified_at")
            assert_not delivery_job.fetch(:args).to_s.include?(code), "Delivery must not queue the plaintext code"
            audit_count = ClientChronicle.where(subject_id: @user.id, event_id: ClientChronicleEvent::LOGGED_IN).count
            assert_no_difference(-> { ClientToken.where(user_id: @user.id).count }) do
              auth_browser.patch(
                auth_app_sign_in_email_path,
                params: { :user_email => { pass_code: code },
                          "cf-turnstile-response" => "t",
                          :ri => "jp", },
                headers: auth_headers,
              )
              auth_browser.follow_redirect!
              auth_browser.follow_redirect!
              auth_browser.post(auth_app_sign_handoff_path, params: { ri: "jp" }, headers: auth_headers)
            end

            assert_equal 303, auth_browser.response.status
            assert_nil auth_browser.cookies[AuthenticationBase::ACCESS_COOKIE_KEY]
            assert_nil auth_browser.cookies[AuthenticationBase::REFRESH_COOKIE_KEY]
            assert_equal audit_count,
                         ClientChronicle.where(subject_id: @user.id, event_id: ClientChronicleEvent::LOGGED_IN).count
            get URI.parse(auth_browser.response.redirect_url).request_uri

            assert_response :success
            completion_form = response.parsed_body.at_css("form")
            completion_params = completion_form.css("input[name]").to_h { |field| [field["name"], field["value"]] }
            count_before = ClientToken.where(user_id: @user.id).count
            post base_app_sign_completion_path,
                 params: completion_params,
                 headers: base_headers
            if elapsed.zero?
              assert_response :see_other
              first = flow.reload.token

              assert_equal anchor, first.root_login_established_at
              AuthenticationLogoutCurrentSession.call(resource: @user, token: first, reason: "user_logout")
              cookies.delete(AuthenticationBase::ACCESS_COOKIE_KEY)
              cookies.delete(AuthenticationBase::REFRESH_COOKIE_KEY)
            elsif elapsed < 30
              assert_response :too_many_requests
              assert_equal "30", response.headers["Retry-After"]
              assert_equal "no-store", response.headers["Cache-Control"]
              assert_equal count_before, ClientToken.where(user_id: @user.id).count
              assert_nil cookies[AuthenticationBase::ACCESS_COOKIE_KEY]
              assert_nil flow.reload.token_id
              assert_equal anchor, first.reload.root_login_established_at
              assert_equal anchor, ClientToken.where(user_id: @user.id).maximum(:root_login_established_at)
            else
              assert_response :see_other
              assert_equal count_before + 1, ClientToken.where(user_id: @user.id).count
              assert_equal (anchor + elapsed).iso8601(6), flow.reload.token.root_login_established_at.iso8601(6)
              assert_predicate first.reload, :revoked?
            end
          end
        end
      end
    end
  end
  # rubocop:enable Minitest/MultipleAssertions

  # rubocop:disable Minitest/MultipleAssertions
  test "a legacy RESTRICTED token does not authenticate even with a valid access token" do
    legacy = ClientToken.create!(user: @user, user_token_status_id: ClientTokenStatus::RESTRICTED)
    base_host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    host! base_host
    https!
    issuer = JitSecurityJwtRegistry.surface("BASE_APP")
    access_token = AuthenticationToken.encode(
      @user, host: base_host, session_public_id: legacy.public_id, resource_type: "client",
             jwt_issuer_id: issuer.id,
    )
    source_before = @email.reload.attributes
    token_before = legacy.reload.attributes
    client = OidcClientRegistry.find!("base-app-ww")
    callback = client.redirect_uris.find { |uri| URI.parse(uri).host == base_host }

    assert_not_nil callback
    # The public landing page is not an authorization decision. Test the protected
    # OP SSO operation instead: a restricted Root cannot produce an authorization code.
    assert_no_difference(["ClientToken.count", "ClientRpSession.count", "ClientChronicle.count"]) do
      get "/oauth/authorize", params: {
        response_type: "code",
        client_id: client.client_id,
        redirect_uri: callback,
        scope: "openid profile",
        state: SecureRandom.urlsafe_base64(32),
        nonce: SecureRandom.urlsafe_base64(32),
        code_challenge: Base64.urlsafe_encode64(Digest::SHA256.digest(SecureRandom.urlsafe_base64(48)), padding: false),
        code_challenge_method: "S256",
        prompt: "none",
        ri: "jp",
      }, headers: { "Authorization" => "Bearer #{access_token}" }
    end

    assert_response :locked
    assert_nil response.location
    assert_nil cookies[AuthenticationBase::ACCESS_COOKIE_KEY]
    assert_nil cookies[AuthenticationBase::REFRESH_COOKIE_KEY]
    assert_nil cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE]
    assert_nil cookies[OidcRpBrowserCredentialContract::REFRESH_COOKIE]
    # rubocop:disable Minitest/AssertEqual, Minitest/AssertOperator -- Do not print credential or token fields on failure.
    assert @email.reload.attributes == source_before, "Rejected SSO must not rewrite Source"
    assert legacy.reload.attributes == token_before, "Rejected SSO must not change the restricted Root"
    # rubocop:enable Minitest/AssertEqual, Minitest/AssertOperator
  end
  # rubocop:enable Minitest/MultipleAssertions
end
