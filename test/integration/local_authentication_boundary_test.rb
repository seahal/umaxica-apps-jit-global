# frozen_string_literal: true

require "test_helper"
require "webauthn/fake_client"

class LocalAuthenticationBoundaryTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  fixtures :clients, :client_statuses, :client_email_statuses, :visitors, :visitor_statuses, :visitor_email_statuses,
           :visitor_passkey_statuses

  setup do
    clear_enqueued_jobs
    @previous_forgery_protection = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
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
    TurnstileVerifierStub.challenge_enabled = true
    TurnstileVerifierStub.challenge_response = { "success" => true }
  end

  teardown do
    ActionController::Base.allow_forgery_protection = @previous_forgery_protection
    TurnstileVerifierStub.challenge_enabled = false
    TurnstileVerifierStub.challenge_response = nil
    TurnstileVerifierStub.enabled = false
    TurnstileVerifierStub.response = nil
  end

  test "primary Passkey admission rejects APP and COM credentials at and after writer expiry" do
    %i(app com).each do |surface|
      [-1, 0, 1, :unbounded].each_with_index do |microseconds, index|
        reset!
        auth_host = (surface == :app) ? ENV.fetch("PUBLIC_AUTH_SERVICE_URL") : ENV.fetch("PUBLIC_AUTH_CORPORATE_URL")
        host!(auth_host)
        origin = "https://#{auth_host}"
        fake = WebAuthn::FakeClient.new(origin, encoding: :base64url)
        registration = fake.create(challenge: SecureRandom.urlsafe_base64(32), user_verified: true)
        relying_party = WebAuthn::RelyingParty.new(id: auth_host, allowed_origins: [origin], encoding: :base64url)
        credential = WebAuthn::Credential.from_create(registration, relying_party: relying_party)
        deadline = Time.current.change(usec: 0)
        unbounded = microseconds == :unbounded
        eligible = unbounded || microseconds < 0
        _, passkey, sign_in_path, options_path, verification_path =
          if surface == :app
            actor = Client.create!(id: 9_114_000_000_000 + index)
            actor.client_emails.create!(
              address: "primary-app-#{SecureRandom.hex(8)}@example.com",
              user_email_status_id: ClientEmailStatus::VERIFIED, binding_finalized_at: Time.current,
            )
            passkey = actor.client_passkeys.create!(
              webauthn_id: credential.id, public_key: credential.public_key, sign_count: 0,
              created_at: deadline - 1.minute, discard_at: unbounded ? Float::INFINITY : deadline,
              purge_eligible_at: unbounded ? Float::INFINITY : deadline + 1.hour,
            )
            [actor, passkey, auth_app_sign_in_path, auth_app_sign_in_passkey_options_path,
             auth_app_sign_in_passkey_verification_path,]
          else
            actor = Visitor.create!(id: 9_114_000_000_000 + index)
            actor.visitor_emails.create!(
              address: "primary-com-#{SecureRandom.hex(8)}@example.com",
              visitor_email_status_id: VisitorEmailStatus::VERIFIED, binding_finalized_at: Time.current,
            )
            passkey = actor.visitor_passkeys.create!(
              webauthn_id: credential.id, public_key: credential.public_key, sign_count: 0,
              created_at: deadline - 1.minute, discard_at: unbounded ? Float::INFINITY : deadline,
              purge_eligible_at: unbounded ? Float::INFINITY : deadline + 1.hour,
            )
            [actor, passkey, auth_com_sign_in_path, auth_com_sign_in_passkey_options_path,
             auth_com_sign_in_passkey_verification_path,]
          end
        # Public Base issuance isolates admission from the separately tested Base redirect transport.
        base = open_session
        auth = self
        base_host = ((surface == :app) ? ENV.fetch("PUBLIC_BASE_SERVICE_URL") : ENV.fetch("PUBLIC_BASE_CORPORATE_URL"))
        auth_host = auth_host
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
        issuer = JitSecurityJwtRegistry.surface(((surface == :app) ? "BASE_APP" : "BASE_COM"))
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
          surface: surface.to_s, intent: "sign_in",
          base_browser_nonce: base.session.fetch(BaseAdmissionBrowserBinding::BROWSER_NONCE_SESSION_KEY),
          base_token: nil, nonce_digest: ((surface == :app) ? ClientSignInFlow : VisitorSignInFlow).digest_nonce(nonce),
        )
        flow = issuance.transaction
        primary_binding = SignInFlowBindingCodec.encode(
          flow: flow, surface: surface.to_s, phase: "PRIMARY_PENDING",
        )
        SignInCycleLocator.new(base.session, surface: surface.to_s).issue!(flow, nonce: nonce)
        session_key = JitSessionCookieConfig.cookie_key(force_secure: JitSessionCookieConfig.force_secure?)
        session_cookie_jar = ActionDispatch::Cookies::CookieJar.build(base.request, base.request.cookies)
        session_cookie_jar.encrypted[session_key] = { value: base.session.to_hash.stringify_keys }
        encoded_session = session_cookie_jar[session_key]
        base.cookies.delete(session_key)
        store_raw_cookies(
          base.cookies,
          "#{session_key}=#{Rack::Utils.escape(encoded_session)}", URI.parse("https://#{base_host}/"),
        )
        binding = BaseAuthAdmissionCoordinator.find_admission_binding!(
          surface: surface.to_s,
          reference: issuance.reference,
        )
        auth.host!(auth_host)
        auth.https!
        auth.get(sign_in_path, params: { entry_ref: issuance.reference, ri: "jp" })

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

        assert_response :see_other
        post options_path,
             params: { "cf-turnstile-response" => "test-only", :ri => "jp", :fb => primary_binding },
             headers: auth_headers,
             as: :json

        assert_response :success
        options = response.parsed_body
        assertion = fake.get(challenge: options.fetch("options").fetch("challenge"), user_verified: true, sign_count: 3)
        passkey.class.stub(:database_now, unbounded ? deadline : deadline + Rational(microseconds, 1_000_000)) do
          post verification_path,
               params: {
                 challenge_id: options.fetch("challenge_id"),
                 credential: assertion,
                 ri: "jp",
                 fb: primary_binding,
               }, headers: auth_headers, as: :json
        end

        assert_response(eligible ? :success : :unauthorized)
        if eligible
          assert_equal "passkey", issuance.transaction.reload.authentication_method
        else
          assert_nil issuance.transaction.reload.authentication_method
        end

        assert_equal(eligible ? 3 : 0, passkey.reload.sign_count)
        assert_nil cookies[AuthenticationBase::ACCESS_COOKIE_KEY]
        assert_nil cookies[AuthenticationBase::REFRESH_COOKIE_KEY]
      end
    end
  end

  # rubocop:disable Minitest/MultipleAssertions
  test "APP and COM MFA recheck Passkey revocation and writer expiry after issuing a challenge" do
    %i(app com).each do |surface|
      [-1, 0, 1, :revoked].each_with_index do |state, index|
        reset!
        auth_host = (surface == :app) ? ENV.fetch("PUBLIC_AUTH_SERVICE_URL") : ENV.fetch("PUBLIC_AUTH_CORPORATE_URL")
        host!(auth_host)
        fake = WebAuthn::FakeClient.new("https://#{auth_host}", encoding: :base64url)
        registration = fake.create(challenge: SecureRandom.urlsafe_base64(32), user_verified: true)
        relying_party = WebAuthn::RelyingParty.new(id: auth_host, allowed_origins: [fake.origin], encoding: :base64url)
        credential = WebAuthn::Credential.from_create(registration, relying_party: relying_party)
        deadline = Time.current.change(usec: 0) + 1.minute
        actor, email, passkey, sign_in_path, email_path, new_path, verification_path, chooser_path =
          if surface == :app
            actor = Client.create!(id: 9_115_000_000_000 + index)
            email = actor.client_emails.create!(
              address: "mfa-app-#{SecureRandom.hex(8)}@example.com",
              user_email_status_id: ClientEmailStatus::VERIFIED, binding_finalized_at: Time.current,
            )
            passkey = actor.client_passkeys.create!(
              webauthn_id: credential.id, public_key: credential.public_key,
              sign_count: 0, discard_at: deadline,
            )
            [actor, email, passkey, auth_app_sign_in_path, auth_app_sign_in_email_path,
             new_auth_app_sign_in_challenge_passkey_path, auth_app_sign_in_challenge_passkey_path,
             auth_app_sign_in_challenge_path,]
          else
            actor = Visitor.create!(id: 9_115_000_000_000 + index)
            email = actor.visitor_emails.create!(
              address: "mfa-com-#{SecureRandom.hex(8)}@example.com",
              visitor_email_status_id: VisitorEmailStatus::VERIFIED, binding_finalized_at: Time.current,
            )
            passkey = actor.visitor_passkeys.create!(
              webauthn_id: credential.id, public_key: credential.public_key,
              sign_count: 0, discard_at: deadline,
            )
            [actor, email, passkey, auth_com_sign_in_path, auth_com_sign_in_email_path,
             new_auth_com_sign_in_challenge_passkey_path, auth_com_sign_in_challenge_passkey_path,
             auth_com_sign_in_challenge_path,]
          end
        actor.reload.update!(mfa_level_enabled: true)
        base = open_session
        auth = self
        base_host = ((surface == :app) ? ENV.fetch("PUBLIC_BASE_SERVICE_URL") : ENV.fetch("PUBLIC_BASE_CORPORATE_URL"))
        auth_host = auth_host
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
        issuer = JitSecurityJwtRegistry.surface(((surface == :app) ? "BASE_APP" : "BASE_COM"))
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
          surface: surface.to_s, intent: "sign_in",
          base_browser_nonce: base.session.fetch(BaseAdmissionBrowserBinding::BROWSER_NONCE_SESSION_KEY),
          base_token: nil, nonce_digest: ((surface == :app) ? ClientSignInFlow : VisitorSignInFlow).digest_nonce(nonce),
        )
        flow = issuance.transaction
        primary_binding = SignInFlowBindingCodec.encode(
          flow: flow, surface: surface.to_s, phase: "PRIMARY_PENDING",
        )
        SignInCycleLocator.new(base.session, surface: surface.to_s).issue!(flow, nonce: nonce)
        session_key = JitSessionCookieConfig.cookie_key(force_secure: JitSessionCookieConfig.force_secure?)
        session_cookie_jar = ActionDispatch::Cookies::CookieJar.build(base.request, base.request.cookies)
        session_cookie_jar.encrypted[session_key] = { value: base.session.to_hash.stringify_keys }
        encoded_session = session_cookie_jar[session_key]
        base.cookies.delete(session_key)
        store_raw_cookies(
          base.cookies,
          "#{session_key}=#{Rack::Utils.escape(encoded_session)}", URI.parse("https://#{base_host}/"),
        )
        binding = BaseAuthAdmissionCoordinator.find_admission_binding!(
          surface: surface.to_s,
          reference: issuance.reference,
        )
        auth.host!(auth_host)
        auth.https!
        auth.get(sign_in_path, params: { entry_ref: issuance.reference, ri: "jp" })

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
        post email_path,
             params: { :user_email => { address: email.address },
                       "cf-turnstile-response" => "test-only",
                       :ri => "jp",
                       :fb => primary_binding, },
             headers: auth_headers
        delivery_job = enqueued_jobs.reverse.find { |job| job.fetch(:job) == OtpNotifierEmailDeliveryJob }

        assert_not_nil delivery_job
        delivery = ActiveJob::Arguments.deserialize(delivery_job.fetch(:args)).last.fetch(:params).symbolize_keys
        ceremony_class = (surface == :app) ? ClientAuthCeremonySession : VisitorAuthCeremonySession
        ceremony = ceremony_class.find(delivery.fetch(:auth_ceremony_session_ref))
        context = ceremony.email_otp_context
        code = OutboundSensitivePayload.decrypt_email_otp(delivery.fetch(:encrypted_hotp_token))

        # assert_match would disclose the delivered secret on failure.
        assert_withheld("Delivery must contain one six-digit code") { code.match?(/\A[0-9]{6}\z/) }
        assert_equal "sign_in", delivery.fetch(:purpose)
        assert_equal surface.to_s, context.fetch("surface")
        assert_equal "authentication", context.fetch("purpose")
        assert_equal "local_sign_in", context.fetch("parent_kind")
        assert_equal "real", context.fetch("mode")
        # Boolean comparisons keep ceremony bindings and keyed proof out of failure output.
        assert_withheld { context.fetch("parent_ref") == issuance.transaction.public_id }
        assert_withheld { context.fetch("contact_ref") == email.public_id }
        assert_withheld { context.fetch("owner_ref") == actor.public_id }
        assert_withheld { context.fetch("sid_digest") == ceremony.sid_digest }
        assert_withheld { context.fetch("generation") == delivery.fetch(:auth_email_otp_generation) }
        assert_nil context.fetch("verified_at")
        assert_not delivery_job.fetch(:args).to_s.include?(code), "Delivery must not queue the plaintext code"
        patch email_path,
              params: { :user_email => { pass_code: code },
                        "cf-turnstile-response" => "test-only",
                        :ri => "jp",
                        :fb => primary_binding, },
              headers: auth_headers

        assert_response :redirect
        assert_predicate issuance.transaction.reload, :sign_in_mfa_pending?
        mfa_binding = Rack::Utils.parse_query(URI.parse(response.location).query).fetch("fb")
        get new_path, params: { ri: "jp", fb: mfa_binding }

        assert_response :success
        page = JSON.parse(response.parsed_body.at_css("script[data-page='app']").text)
        form = page.fetch("props").fetch("form")
        assertion = fake.get(
          challenge: form.fetch("request_options").fetch("challenge"), user_verified: true,
          sign_count: 3,
        )
        if state == :revoked
          passkey.update!(status_id: (surface == :app) ? ClientPasskeyStatus::REVOKED : VisitorPasskeyStatus::REVOKED)
        end
        now = (state == :revoked) ? deadline - 1.second : deadline + Rational(state, 1_000_000)
        passkey.class.stub(:database_now, now) do
          post verification_path, params: {
            :mfa_passkey_form => { challenge_id: form.fetch("challenge_id"),
                                   credential_json: JSON.generate(assertion), },
            "cf-turnstile-response" => "test-only",
            :ri => "jp",
            :fb => mfa_binding,
          }, headers: auth_headers
        end

        assert_response :redirect
        if state == -1
          assert_equal 3, passkey.reload.sign_count
          assert_not issuance.transaction.reload.sign_in_mfa_pending?
        else
          assert_equal URI.parse(chooser_path).path, URI.parse(response.location).path
          assert_equal 0, passkey.reload.sign_count
          assert_predicate issuance.transaction.reload, :sign_in_mfa_pending?
          assert_nil issuance.transaction.authentication_event_at
        end

        assert_nil cookies[AuthenticationBase::ACCESS_COOKIE_KEY]
        assert_nil cookies[AuthenticationBase::REFRESH_COOKIE_KEY]
      end
    end
  end

  # rubocop:enable Minitest/MultipleAssertions

  test "a redeemed local sign in admission cannot open the sign up ceremony" do
    base = open_session
    auth = self
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
    store_raw_cookies(
      base.cookies,
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

    assert_response :see_other
    get auth_app_sign_up_path, params: { ri: "jp" }

    assert_response :bad_request
    assert_nil issuance.transaction.reload.principal_id
  end

  test "email delivery refuses missing admission before changing the credential" do
    actor = clients(:one)
    email = actor.client_emails.create!(
      address: "missing-admission@example.com", user_email_status_id: ClientEmailStatus::VERIFIED,
      binding_finalized_at: Time.current,
    )
    source_before = email.reload.attributes
    ceremonies_before = ClientAuthCeremonySession.order(:id).map(&:attributes)
    deliveries_before = enqueued_jobs.length
    host! ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    https!
    get auth_app_root_path, params: { ri: "jp" }
    csrf = response.parsed_body.at_css('meta[name="csrf-token"]')["content"]
    post auth_app_sign_in_email_path,
         params: { :user_email => { address: email.address }, "cf-turnstile-response" => "t", :ri => "jp" },
         headers: { "Origin" => "https://#{ENV.fetch("PUBLIC_AUTH_SERVICE_URL")}",
                    "Sec-Fetch-Site" => "same-origin",
                    "X-CSRF-Token" => csrf, }

    assert_response :bad_request
    # Boolean snapshots avoid exposing credential or ceremony material on refusal.
    assert_withheld { source_before == email.reload.attributes }
    assert_withheld { ceremonies_before == ClientAuthCeremonySession.order(:id).map(&:attributes) }
    assert_equal deliveries_before, enqueued_jobs.length
    assert_nil session[:user_email_authentication_id]
  end

  test "local sign up admission refuses a direct sign in credential endpoint" do
    base = open_session
    auth = self
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
      surface: "app", intent: "sign_up",
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
    store_raw_cookies(
      base.cookies,
      "#{session_key}=#{Rack::Utils.escape(encoded_session)}", URI.parse("https://#{base_host}/"),
    )
    binding = BaseAuthAdmissionCoordinator.find_admission_binding!(surface: "app", reference: issuance.reference)
    auth.host!(auth_host)
    auth.https!
    auth.get(auth_app_sign_up_path, params: { entry_ref: issuance.reference, ri: "jp" })

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

    assert_response :see_other
    post auth_app_sign_in_email_path,
         params: { :user_email => { address: "unexpected@example.com" }, "cf-turnstile-response" => "t", :ri => "jp" },
         headers: auth_headers

    assert_response :bad_request
    assert_nil issuance.transaction.reload.principal_id
  end

  # rubocop:disable Minitest/MultipleAssertions
  test "Auth records local email evidence on the admitted Base flow and issues no root credential" do
    actor = clients(:one)
    email = actor.client_emails.create!(
      address: "local-boundary@example.com", user_email_status_id: ClientEmailStatus::VERIFIED,
      binding_finalized_at: Time.current,
    )
    base = open_session
    auth = self
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
    primary_binding = SignInFlowBindingCodec.encode(flow: flow, surface: "app", phase: "PRIMARY_PENDING")
    SignInCycleLocator.new(base.session, surface: "app").issue!(flow, nonce: nonce)
    session_key = JitSessionCookieConfig.cookie_key(force_secure: JitSessionCookieConfig.force_secure?)
    session_cookie_jar = ActionDispatch::Cookies::CookieJar.build(base.request, base.request.cookies)
    session_cookie_jar.encrypted[session_key] = { value: base.session.to_hash.stringify_keys }
    encoded_session = session_cookie_jar[session_key]
    base.cookies.delete(session_key)
    store_raw_cookies(
      base.cookies,
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

    assert_response :see_other

    post auth_app_sign_in_email_path,
         params: { :user_email => { address: email.address }, "cf-turnstile-response" => "t", :fb => primary_binding },
         headers: auth_headers

    assert_response :redirect
    delivery_job = enqueued_jobs.reverse.find { |job| job.fetch(:job) == OtpNotifierEmailDeliveryJob }

    assert_not_nil delivery_job
    delivery = ActiveJob::Arguments.deserialize(delivery_job.fetch(:args)).last.fetch(:params).symbolize_keys
    ceremony = ClientAuthCeremonySession.find(delivery.fetch(:auth_ceremony_session_ref))
    context = ceremony.email_otp_context
    code = OutboundSensitivePayload.decrypt_email_otp(delivery.fetch(:encrypted_hotp_token))

    # assert_match would disclose the delivered secret on failure.
    assert_withheld("Delivery must contain one six-digit code") { code.match?(/\A[0-9]{6}\z/) }
    assert_equal "sign_in", delivery.fetch(:purpose)
    assert_equal "app", context.fetch("surface")
    assert_equal "authentication", context.fetch("purpose")
    assert_equal "local_sign_in", context.fetch("parent_kind")
    assert_equal "real", context.fetch("mode")
    # Boolean comparisons keep ceremony bindings and keyed proof out of failure output.
    assert_withheld { context.fetch("parent_ref") == issuance.transaction.public_id }
    assert_withheld { context.fetch("contact_ref") == email.public_id }
    assert_withheld { context.fetch("owner_ref") == actor.public_id }
    assert_withheld { context.fetch("sid_digest") == ceremony.sid_digest }
    assert_withheld { context.fetch("generation") == delivery.fetch(:auth_email_otp_generation) }
    assert_nil context.fetch("verified_at")
    assert_not delivery_job.fetch(:args).to_s.include?(code), "Delivery must not queue the plaintext code"
    original_nonce_digest = issuance.transaction.reload.nonce_digest
    before_count = ClientSignInFlow.count
    assert_no_difference("ClientToken.count") do
      patch auth_app_sign_in_email_path,
            params: { :user_email => { pass_code: code }, "cf-turnstile-response" => "t", :fb => primary_binding },
            headers: auth_headers
    end
    assert_response :redirect
    assert_equal before_count, ClientSignInFlow.count
    flow = issuance.transaction.reload

    assert_equal actor.id, flow.principal_id
    assert_equal "email", flow.authentication_method
    assert_not_nil flow.authentication_event_at
    assert_equal original_nonce_digest, flow.nonce_digest
    assert_nil flow.token_id
    assert_nil cookies[AuthenticationBase::ACCESS_COOKIE_KEY]
    assert_nil cookies[AuthenticationBase::REFRESH_COOKIE_KEY]
  end

  # One journey must retain separate Base/Auth cookie jars and verify both issuance boundaries.
  # rubocop:enable Minitest/MultipleAssertions

  # rubocop:disable Minitest/MultipleAssertions
  test "Base finalizes a local email ceremony once and rejects its result in another browser" do
    actor = Client.create!(status_id: ClientStatus::ACTIVE, birthdate: "2000-01-01")
    bootstrap = BaseSelectorBootstrapAuthority.call(surface: :app, principal: actor)

    assert_instance_of ClientIdentity, bootstrap.identity
    assert_equal actor.id, bootstrap.identity.source_record_id
    email = actor.client_emails.create!(
      address: "local-roundtrip@example.com", user_email_status_id: ClientEmailStatus::VERIFIED,
      binding_finalized_at: Time.current,
    )
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
    primary_binding = SignInFlowBindingCodec.encode(flow: flow, surface: "app", phase: "PRIMARY_PENDING")
    SignInCycleLocator.new(base.session, surface: "app").issue!(flow, nonce: nonce)
    session_key = JitSessionCookieConfig.cookie_key(force_secure: JitSessionCookieConfig.force_secure?)
    session_cookie_jar = ActionDispatch::Cookies::CookieJar.build(base.request, base.request.cookies)
    session_cookie_jar.encrypted[session_key] = { value: base.session.to_hash.stringify_keys }
    encoded_session = session_cookie_jar[session_key]
    base.cookies.delete(session_key)
    store_raw_cookies(
      base.cookies,
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
    browser = auth
    browser.post(
      auth_app_sign_in_email_path,
      params: { :ri => "jp",
                :user_email => { address: email.address },
                "cf-turnstile-response" => "t",
                :fb => primary_binding, },
      headers: auth_headers,
    )

    assert_equal 302, browser.response.status
    delivery_job = enqueued_jobs.reverse.find { |job| job.fetch(:job) == OtpNotifierEmailDeliveryJob }

    assert_not_nil delivery_job
    delivery = ActiveJob::Arguments.deserialize(delivery_job.fetch(:args)).last.fetch(:params).symbolize_keys
    ceremony = ClientAuthCeremonySession.find(delivery.fetch(:auth_ceremony_session_ref))
    context = ceremony.email_otp_context
    code = OutboundSensitivePayload.decrypt_email_otp(delivery.fetch(:encrypted_hotp_token))

    # assert_match would disclose the delivered secret on failure.
    assert_withheld("Delivery must contain one six-digit code") { code.match?(/\A[0-9]{6}\z/) }
    assert_equal "sign_in", delivery.fetch(:purpose)
    assert_equal "app", context.fetch("surface")
    assert_equal "authentication", context.fetch("purpose")
    assert_equal "local_sign_in", context.fetch("parent_kind")
    assert_equal "real", context.fetch("mode")
    # Boolean comparisons keep ceremony bindings and keyed proof out of failure output.
    assert_withheld { context.fetch("parent_ref") == flow.public_id }
    assert_withheld { context.fetch("contact_ref") == email.public_id }
    assert_withheld { context.fetch("owner_ref") == actor.public_id }
    assert_withheld { context.fetch("sid_digest") == ceremony.sid_digest }
    assert_withheld { context.fetch("generation") == delivery.fetch(:auth_email_otp_generation) }
    assert_nil context.fetch("verified_at")
    assert_not delivery_job.fetch(:args).to_s.include?(code), "Delivery must not queue the plaintext code"
    assert_no_difference("ClientToken.count") do
      browser.patch(
        auth_app_sign_in_email_path,
        params: { :ri => "jp",
                  :user_email => { pass_code: code },
                  "cf-turnstile-response" => "t",
                  :fb => primary_binding, },
        headers: auth_headers,
      )
      browser.follow_redirect!

      assert_equal 303, browser.response.status
      assert_equal "/sign/handoff", URI.parse(browser.response.location).path
      browser.follow_redirect!

      assert_equal 200, browser.response.status
      browser.post(auth_app_sign_handoff_path, params: { ri: "jp" }, headers: auth_headers)

      assert_equal 303, browser.response.status
    end
    completion_uri = URI.parse(browser.response.location).request_uri
    get completion_uri

    assert_response :success
    completion_form = response.parsed_body.at_css("form")
    completion_params = completion_form.css("input[name]").to_h { |field| [field["name"], field["value"]] }
    headers = base_headers
    other_browser = open_session
    other_browser.host!(ENV.fetch("PUBLIC_BASE_SERVICE_URL"))
    other_browser.https!
    other_browser.get(completion_uri)
    other_form = Nokogiri::HTML(other_browser.response.body).at_css("form")
    other_params = other_form.css("input[name]").to_h { |field| [field["name"], field["value"]] }
    assert_no_difference("ClientToken.count") do
      other_browser.post(base_app_sign_completion_path, params: other_params, headers: headers)
    end
    assert_equal 400, other_browser.response.status

    assert_difference("ClientToken.count", 1) do
      post base_app_sign_completion_path, params: completion_params, headers: headers
    end
    assert_response :see_other
    assert_not_nil flow.reload.base_finalized_at
    token = ClientToken.find(flow.token_id)

    assert_equal "email", token.established_authentication_method
    assert_equal flow.authentication_event_at, token.authentication_event_at
    assert_not_nil token.root_login_established_at
    assert_not_nil cookies[AuthenticationBase::ACCESS_COOKIE_KEY]
    assert_nil browser.cookies[AuthenticationBase::ACCESS_COOKIE_KEY]
    assert_nil browser.cookies[AuthenticationBase::REFRESH_COOKIE_KEY]
    get completion_uri
    completion_form = response.parsed_body.at_css("form")
    completion_params = completion_form.css("input[name]").to_h { |field| [field["name"], field["value"]] }
    assert_no_difference("ClientToken.count") do
      post base_app_sign_completion_path, params: completion_params, headers: headers
    end
    assert_response :see_other

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

            assert_withheld { ActiveSupport::ExecutionContext.to_h.fetch(:controller).equal?(outer_controller) }
            assert_withheld { Actor.context.equal?(outer_actor) }
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

            assert_withheld { ActiveSupport::ExecutionContext.to_h.fetch(:controller).equal?(outer_controller) }
            assert_withheld { Actor.context.equal?(outer_actor) }
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
    # Continue from the root session actually established on Base. Only the external Jump
    # transport and Turnstile service are substituted; the Passkey assertion uses real crypto.
    origin = "https://#{ENV.fetch("PUBLIC_AUTH_SERVICE_URL")}"
    fake = WebAuthn::FakeClient.new(origin, encoding: :base64url)
    registration = fake.create(
      challenge: Base64.urlsafe_encode64(SecureRandom.random_bytes(32), padding: false), user_verified: true,
    )
    relying_party = WebAuthn::RelyingParty.new(
      id: URI.parse(origin).host, allowed_origins: [origin], encoding: :base64url,
    )
    credential = WebAuthn::Credential.from_create(registration, relying_party: relying_party)
    actor.client_passkeys.create!(webauthn_id: credential.id, public_key: credential.public_key, sign_count: 0)
    token = ClientToken.find(flow.token_id)
    path = base_app_identity_birthdate_path(ri: "jp")
    verifier = ActiveSupport::MessageVerifier.new(
      Rails.application.key_generator.generate_key("path_target_token", 32),
      digest: "SHA256", serializer: JSON, url_safe: true,
    )
    pt = verifier.generate(
      { "flow" => "step_up.bootstrap",
        "surface" => "app",
        "session_nonce" => token.public_id,
        "pt" => path, },
      purpose: :path_target, expires_in: 15.minutes,
    )
    get base_app_verification_path(ri: "jp", scope: "settings_birthdate", pt: pt)

    assert_response :success
    base_csrf = response.body[/<meta name="csrf-token" content="([^"]+)"/, 1]

    assert_predicate base_csrf, :present?
    post base_app_verification_path(ri: "jp"), params: { scope: "settings_birthdate", pt: pt },
                                               headers: base_headers.merge("X-CSRF-Token" => base_csrf)

    assert_response :see_other
    step_up_rt = Rack::Utils.parse_query(URI.parse(response.location).query).fetch("rt")
    step_up_payload, = JWT.decode(
      step_up_rt, JitSecurityJwtRegistry.public_key_for(issuer.id, issuer.current_kid), true,
      algorithms: ["ES384"], verify_iss: true, iss: "https://#{base_host}",
      verify_aud: true, aud: Rails.configuration.x.boot_config.fetch(:jump).audience,
    )
    destination = URI.parse(step_up_payload.fetch("url"))

    assert_equal auth_host, destination.host
    entry = Rack::Utils.parse_query(destination.query).fetch("entry_ref")
    step_up_binding = BaseAuthAdmissionCoordinator.find_admission_binding!(surface: "app", reference: entry)
    browser.get(destination.request_uri)

    assert_equal 200, browser.response.status
    3.times do |admission_index|
      receiver = (admission_index == 1) ? self : browser
      continuation = Nokogiri::HTML(receiver.response.body).at_css("form")
      continuation_fields = continuation.css("input[name]").to_h { |field| [field["name"], field["value"]] }
      receiver.post(
        continuation["action"], params: continuation_fields,
                                headers: (admission_index == 1) ? base_headers : auth_headers,
      )

      assert_equal 303, receiver.response.status
      csrf = continuation_fields.fetch("authenticity_token") if admission_index == 2
      next if admission_index == 2

      next_uri = URI.parse(receiver.response.location)

      assert_equal(admission_index.zero? ? base_host : auth_host, next_uri.host)
      next_receiver = admission_index.zero? ? self : browser
      next_receiver.get(next_uri.request_uri)
    end

    assert_predicate step_up_binding.reload, :redeemed?
    auth_headers = auth_headers.merge("X-CSRF-Token" => csrf)
    TurnstileVerifierStub.enabled = true
    TurnstileVerifierStub.response = { "success" => true }
    browser.post(
      auth_app_verification_passkey_options_path(ri: "jp"),
      params: { "cf-turnstile-response" => "test-only" }, headers: auth_headers, as: :json,
    )

    assert_equal 200, browser.response.status
    reference = browser.response.parsed_body.fetch("challenge_id")
    record = ClientStepUpSession.find_by!(passkey_challenge_ref: reference)
    assertion = fake.get(challenge: record.passkey_challenge, user_present: true, user_verified: true, sign_count: 3)
    browser.post(
      auth_app_verification_passkey_path(ri: "jp"),
      params: { challenge_id: reference, credential: assertion },
      headers: auth_headers, as: :json,
    )

    assert_equal 200, browser.response.status
    assert_nil token.reload.last_step_up_at
    browser.get(browser.response.parsed_body.fetch("redirect_url"))

    assert_equal 200, browser.response.status
    browser.post(
      auth_app_verification_handoff_path(ri: "jp"), params: { authenticity_token: csrf },
                                                    headers: auth_headers,
    )

    assert_equal 303, browser.response.status
    result_uri = URI.parse(browser.response.location)

    assert_equal base_host, result_uri.host
    get result_uri.request_uri

    assert_response :success
    result_form = response.parsed_body.at_css("form")
    result_fields = result_form.css("input[name]").to_h { |field| [field["name"], field["value"]] }
    post result_form["action"], params: result_fields, headers: base_headers

    assert_response :see_other
    assert_equal path, URI.parse(response.location).request_uri
    assert_equal "consumed", ClientStepUpCeremonyTransaction.find_by!(
      transaction_id: record.step_up_ceremony_transaction_ref,
    ).status
    assert_equal "passkey", token.reload.last_step_up_method
    assert_nil browser.cookies[AuthenticationBase::ACCESS_COOKIE_KEY]
    follow_redirect!

    assert_response :success
  end

  test "COM Base finalizes a local email ceremony once and rejects its result in another browser" do
    actor = Visitor.create!(status_id: VisitorStatus::ACTIVE, birthdate: "2000-01-01")
    bootstrap = BaseSelectorBootstrapAuthority.call(surface: :com, principal: actor)

    assert_instance_of VisitorIdentity, bootstrap.identity
    assert_equal actor.id, bootstrap.identity.source_record_id
    email = actor.visitor_emails.create!(
      address: "com-local-roundtrip@example.com", visitor_email_status_id: VisitorEmailStatus::VERIFIED,
      binding_finalized_at: Time.current,
    )
    base = self
    auth = open_session
    base_host = ENV.fetch("PUBLIC_BASE_CORPORATE_URL")
    auth_host = ENV.fetch("PUBLIC_AUTH_CORPORATE_URL")
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
    issuer = JitSecurityJwtRegistry.surface("BASE_COM")
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
      surface: "com", intent: "sign_in",
      base_browser_nonce: base.session.fetch(BaseAdmissionBrowserBinding::BROWSER_NONCE_SESSION_KEY),
      base_token: nil, nonce_digest: VisitorSignInFlow.digest_nonce(nonce),
    )
    flow = issuance.transaction
    primary_binding = SignInFlowBindingCodec.encode(flow: flow, surface: "com", phase: "PRIMARY_PENDING")
    SignInCycleLocator.new(base.session, surface: "com").issue!(flow, nonce: nonce)
    session_key = JitSessionCookieConfig.cookie_key(force_secure: JitSessionCookieConfig.force_secure?)
    session_cookie_jar = ActionDispatch::Cookies::CookieJar.build(base.request, base.request.cookies)
    session_cookie_jar.encrypted[session_key] = { value: base.session.to_hash.stringify_keys }
    encoded_session = session_cookie_jar[session_key]
    base.cookies.delete(session_key)
    store_raw_cookies(
      base.cookies,
      "#{session_key}=#{Rack::Utils.escape(encoded_session)}", URI.parse("https://#{base_host}/"),
    )
    binding = BaseAuthAdmissionCoordinator.find_admission_binding!(surface: "com", reference: issuance.reference)
    auth.host!(auth_host)
    auth.https!
    auth.get(auth_com_sign_in_path, params: { entry_ref: issuance.reference, ri: "jp" })

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
    browser = auth
    browser.post(
      auth_com_sign_in_email_path,
      params: { :ri => "jp",
                :user_email => { address: email.address },
                "cf-turnstile-response" => "t",
                :fb => primary_binding, },
      headers: auth_headers,
    )

    assert_equal 302, browser.response.status
    delivery_job = enqueued_jobs.reverse.find { |job| job.fetch(:job) == OtpNotifierEmailDeliveryJob }

    assert_not_nil delivery_job
    delivery = ActiveJob::Arguments.deserialize(delivery_job.fetch(:args)).last.fetch(:params).symbolize_keys
    ceremony = VisitorAuthCeremonySession.find(delivery.fetch(:auth_ceremony_session_ref))
    context = ceremony.email_otp_context
    code = OutboundSensitivePayload.decrypt_email_otp(delivery.fetch(:encrypted_hotp_token))

    # assert_match would disclose the delivered secret on failure.
    assert_withheld("Delivery must contain one six-digit code") { code.match?(/\A[0-9]{6}\z/) }
    assert_equal "sign_in", delivery.fetch(:purpose)
    assert_equal "com", context.fetch("surface")
    assert_equal "authentication", context.fetch("purpose")
    assert_equal "local_sign_in", context.fetch("parent_kind")
    assert_equal "real", context.fetch("mode")
    # Boolean comparisons keep ceremony bindings and keyed proof out of failure output.
    assert_withheld { context.fetch("parent_ref") == flow.public_id }
    assert_withheld { context.fetch("contact_ref") == email.public_id }
    assert_withheld { context.fetch("owner_ref") == actor.public_id }
    assert_withheld { context.fetch("sid_digest") == ceremony.sid_digest }
    assert_withheld { context.fetch("generation") == delivery.fetch(:auth_email_otp_generation) }
    assert_nil context.fetch("verified_at")
    assert_not delivery_job.fetch(:args).to_s.include?(code), "Delivery must not queue the plaintext code"
    assert_no_difference("VisitorToken.count") do
      browser.patch(
        auth_com_sign_in_email_path,
        params: { :ri => "jp",
                  :user_email => { pass_code: code },
                  "cf-turnstile-response" => "t",
                  :fb => primary_binding, },
        headers: auth_headers,
      )

      assert_equal "/sign/in/check", URI.parse(browser.response.location).path
      assert_equal "jp", Rack::Utils.parse_nested_query(URI.parse(browser.response.location).query)["ri"]
      browser.follow_redirect!

      assert_equal 303, browser.response.status
      assert_equal "/sign/handoff", URI.parse(browser.response.location).path
      browser.follow_redirect!

      assert_equal 200, browser.response.status
      browser.post(auth_com_sign_handoff_path, params: { ri: "jp" }, headers: auth_headers)

      assert_equal 303, browser.response.status
    end
    completion_uri = URI.parse(browser.response.location).request_uri
    get completion_uri

    assert_response :success
    completion_form = response.parsed_body.at_css("form")
    completion_params = completion_form.css("input[name]").to_h { |field| [field["name"], field["value"]] }
    headers = base_headers
    other_browser = open_session
    other_browser.host!(ENV.fetch("PUBLIC_BASE_CORPORATE_URL"))
    other_browser.https!
    other_browser.get(completion_uri)
    other_form = Nokogiri::HTML(other_browser.response.body).at_css("form")
    other_params = other_form.css("input[name]").to_h { |field| [field["name"], field["value"]] }
    assert_no_difference("VisitorToken.count") do
      other_browser.post(base_com_sign_completion_path, params: other_params, headers: headers)
    end
    assert_equal 400, other_browser.response.status

    assert_difference("VisitorToken.count", 1) do
      post base_com_sign_completion_path, params: completion_params, headers: headers
    end
    assert_response :see_other
    assert_not_nil flow.reload.base_finalized_at
    token = VisitorToken.find(flow.token_id)

    assert_equal "email", token.established_authentication_method
    assert_equal flow.authentication_event_at, token.authentication_event_at
    assert_not_nil token.root_login_established_at
    assert_not_nil cookies[AuthenticationBase::ACCESS_COOKIE_KEY]
    assert_nil browser.cookies[AuthenticationBase::ACCESS_COOKIE_KEY]
    assert_nil browser.cookies[AuthenticationBase::REFRESH_COOKIE_KEY]
    get completion_uri
    completion_form = response.parsed_body.at_css("form")
    completion_params = completion_form.css("input[name]").to_h { |field| [field["name"], field["value"]] }
    assert_no_difference("VisitorToken.count") do
      post base_com_sign_completion_path, params: completion_params, headers: headers
    end
    assert_response :see_other

    # A Root is OP authority, not a Browser-RP credential. Complete the real self-RP
    # callback before continuing into Base's protected browser operations.
    assert_no_difference("VisitorToken.count") do
      get "/sign", params: { ri: "jp", pt: base_com_dashboard_path(ri: "jp") }
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

            assert_withheld { ActiveSupport::ExecutionContext.to_h.fetch(:controller).equal?(outer_controller) }
            assert_withheld { Actor.context.equal?(outer_actor) }
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

            assert_withheld { ActiveSupport::ExecutionContext.to_h.fetch(:controller).equal?(outer_controller) }
            assert_withheld { Actor.context.equal?(outer_actor) }
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
    origin = "https://#{ENV.fetch("PUBLIC_AUTH_CORPORATE_URL")}"
    fake = WebAuthn::FakeClient.new(origin, encoding: :base64url)
    registration = fake.create(
      challenge: Base64.urlsafe_encode64(SecureRandom.random_bytes(32), padding: false), user_verified: true,
    )
    relying_party = WebAuthn::RelyingParty.new(
      id: URI.parse(origin).host, allowed_origins: [origin], encoding: :base64url,
    )
    credential = WebAuthn::Credential.from_create(registration, relying_party: relying_party)
    actor.visitor_passkeys.create!(
      webauthn_id: credential.id, public_key: credential.public_key, sign_count: 0, status_id: VisitorPasskeyStatus::ACTIVE,
    )
    token = VisitorToken.find(flow.token_id)
    path = base_com_identity_birthdate_path(ri: "jp")
    verifier = ActiveSupport::MessageVerifier.new(
      Rails.application.key_generator.generate_key("path_target_token", 32),
      digest: "SHA256", serializer: JSON, url_safe: true,
    )
    pt = verifier.generate(
      { "flow" => "step_up.bootstrap",
        "surface" => "com",
        "session_nonce" => token.public_id,
        "pt" => path, },
      purpose: :path_target, expires_in: 15.minutes,
    )
    get base_com_verification_path(ri: "jp", scope: "settings_birthdate", pt: pt)

    assert_response :success
    base_csrf = response.body[/<meta name="csrf-token" content="([^"]+)"/, 1]

    assert_predicate base_csrf, :present?
    post base_com_verification_path(ri: "jp"), params: { scope: "settings_birthdate", pt: pt },
                                               headers: base_headers.merge("X-CSRF-Token" => base_csrf)

    assert_response :see_other
    step_up_rt = Rack::Utils.parse_query(URI.parse(response.location).query).fetch("rt")
    step_up_payload, = JWT.decode(
      step_up_rt, JitSecurityJwtRegistry.public_key_for(issuer.id, issuer.current_kid), true,
      algorithms: ["ES384"], verify_iss: true, iss: "https://#{base_host}",
      verify_aud: true, aud: Rails.configuration.x.boot_config.fetch(:jump).audience,
    )
    destination = URI.parse(step_up_payload.fetch("url"))

    assert_equal auth_host, destination.host
    entry = Rack::Utils.parse_query(destination.query).fetch("entry_ref")
    step_up_binding = BaseAuthAdmissionCoordinator.find_admission_binding!(surface: "com", reference: entry)
    browser.get(destination.request_uri)

    assert_equal 200, browser.response.status
    3.times do |admission_index|
      receiver = (admission_index == 1) ? self : browser
      continuation = Nokogiri::HTML(receiver.response.body).at_css("form")
      continuation_fields = continuation.css("input[name]").to_h { |field| [field["name"], field["value"]] }
      receiver.post(
        continuation["action"], params: continuation_fields,
                                headers: (admission_index == 1) ? base_headers : auth_headers,
      )

      assert_equal 303, receiver.response.status
      csrf = continuation_fields.fetch("authenticity_token") if admission_index == 2
      next if admission_index == 2

      next_uri = URI.parse(receiver.response.location)

      assert_equal(admission_index.zero? ? base_host : auth_host, next_uri.host)
      next_receiver = admission_index.zero? ? self : browser
      next_receiver.get(next_uri.request_uri)
    end

    assert_predicate step_up_binding.reload, :redeemed?
    auth_headers = auth_headers.merge("X-CSRF-Token" => csrf)
    TurnstileVerifierStub.enabled = true
    TurnstileVerifierStub.response = { "success" => true }
    browser.post(
      auth_com_verification_passkey_options_path(ri: "jp"),
      params: { "cf-turnstile-response" => "test-only" }, headers: auth_headers, as: :json,
    )

    assert_equal 200, browser.response.status
    reference = browser.response.parsed_body.fetch("challenge_id")
    record = VisitorStepUpSession.find_by!(passkey_challenge_ref: reference)
    assertion = fake.get(challenge: record.passkey_challenge, user_present: true, user_verified: true, sign_count: 3)
    browser.post(
      auth_com_verification_passkey_path(ri: "jp"),
      params: { challenge_id: reference, credential: assertion },
      headers: auth_headers, as: :json,
    )

    assert_equal 200, browser.response.status
    assert_nil token.reload.last_step_up_at
    browser.get(browser.response.parsed_body.fetch("redirect_url"))

    assert_equal 200, browser.response.status
    browser.post(
      auth_com_verification_handoff_path(ri: "jp"), params: { authenticity_token: csrf },
                                                    headers: auth_headers,
    )

    assert_equal 303, browser.response.status
    result_uri = URI.parse(browser.response.location)

    assert_equal base_host, result_uri.host
    get result_uri.request_uri

    assert_response :success
    result_form = response.parsed_body.at_css("form")
    result_fields = result_form.css("input[name]").to_h { |field| [field["name"], field["value"]] }
    post result_form["action"], params: result_fields, headers: base_headers

    assert_response :see_other
    assert_equal path, URI.parse(response.location).request_uri
    assert_equal "consumed", VisitorStepUpCeremonyTransaction.find_by!(
      transaction_id: record.step_up_ceremony_transaction_ref,
    ).status
    assert_equal "passkey", token.reload.last_step_up_method
    assert_nil browser.cookies[AuthenticationBase::ACCESS_COOKIE_KEY]
    assert_nil browser.cookies[AuthenticationBase::REFRESH_COOKIE_KEY]
    follow_redirect!

    assert_response :success
  end
  # rubocop:enable Minitest/MultipleAssertions
end
