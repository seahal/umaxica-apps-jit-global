# typed: false
# frozen_string_literal: true

require "test_helper"

# Per-IP burst limiters declared on the unauthenticated auth endpoints. Each
# endpoint declares its own `rate_limit(..., with: -> { render_rate_limited })`
# handler; these exercise that handler through the real routing and controller
# stack so a limiter that is declared but never wired is a failing test rather
# than silent absence of protection.
class AuthEndpointBurstRateLimitTest < ActionDispatch::IntegrationTest
  NAVIGATION_HEADERS = { "Sec-Fetch-Mode" => "navigate", "Sec-Fetch-Dest" => "document" }.freeze

  # Rate-limit counters are a NullStore by default in test so unrelated tests
  # cannot accumulate them; this file asserts real limiting behavior, so it
  # opts into a deterministic MemoryStore.
  rate_limit_counters!

  include ActiveSupport::Testing::TimeHelpers

  BURST_ALLOWANCE = 5
  SUSTAINED_ALLOWANCE = 20

  setup do
    # Counters are keyed by scope and source address, and several cases below
    # share both, so a leftover count from the previous case would decide where
    # the limit falls.
    Rails.configuration.x.rate_limit.fetch(:store).clear
    TurnstileVerifierStub.enabled = true
    TurnstileVerifierStub.response = { "success" => true }
    TurnstileVerifierStub.challenge_enabled = true
    TurnstileVerifierStub.challenge_response = { "success" => true }
  end

  teardown do
    Rails.configuration.x.rate_limit.fetch(:store).clear
    TurnstileVerifierStub.enabled = false
    TurnstileVerifierStub.response = nil
    TurnstileVerifierStub.challenge_enabled = false
    TurnstileVerifierStub.challenge_response = nil
  end

  test "app passkey options answers 429 once the per-IP burst allowance is spent" do
    host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    host! host
    https!
    issuance = OidcTestEntry.issue!(
      surface: "app", intent: "sign_in", base_browser_nonce: SecureRandom.hex(32), base_token: nil,
    )
    get "/sign/in", params: { entry_ref: issuance.reference, ri: "jp" }, headers: NAVIGATION_HEADERS
    get response.location, headers: NAVIGATION_HEADERS
    binding = ClientAuthAdmissionBinding.find_by!(entry_ref: issuance.reference)
    binding.confirm_base!(base_token: nil, browser_digest: binding.base_browser_digest)
    get "/sign/in", params: { entry_ref: issuance.reference, ri: "jp" }, headers: NAVIGATION_HEADERS
    get response.location, headers: NAVIGATION_HEADERS

    assert_response :success

    BURST_ALLOWANCE.times do
      post auth_app_sign_in_passkey_options_url(ri: "jp", host: host),
           params: { identifier: "burst_app@example.com" }, as: :json

      assert_not_includes [400, 429], response.status
    end

    post auth_app_sign_in_passkey_options_url(ri: "jp", host: host),
         params: { identifier: "burst_app@example.com" }, as: :json

    assert_response :too_many_requests
    assert_equal "60", response.headers["Retry-After"]
  end

  test "app passkey verification answers 429 once the per-IP burst allowance is spent" do
    host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    host! host
    https!
    client = OidcClientRegistry.find!("core-app-jp")
    transaction = OidcAuthorizationTransactionCoordinator.issue!(
      surface: "app", intent: "sign_in", params: {
        response_type: "code",
        client_id: client.client_id,
        redirect_uri: client.redirect_uris.first,
        code_challenge: "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM",
        code_challenge_method: "S256",
        state: SecureRandom.urlsafe_base64(16),
        nonce: SecureRandom.urlsafe_base64(16),
        scope: "openid profile",
      },
    ).transaction
    handoff = BaseAuthAdmissionCoordinator.issue_handoff!(
      transaction: transaction, base_browser_nonce: SecureRandom.urlsafe_base64(32), base_token: nil,
    )
    binding = ClientAuthAdmissionBinding.find_by!(entry_ref: handoff.reference)
    headers = {
      "Sec-Fetch-Mode" => "navigate",
      "Sec-Fetch-Dest" => "document",
      "Sec-Fetch-Site" => "cross-site",
    }
    get auth_app_sign_in_path, params: { entry_ref: handoff.reference, ri: "jp" }, headers: headers

    assert_response :see_other
    get response.location, headers: headers

    assert_response :see_other
    binding.confirm_base!(base_token: nil, browser_digest: binding.base_browser_digest)
    get auth_app_sign_in_path, params: { entry_ref: handoff.reference, ri: "jp" }, headers: headers

    assert_response :see_other
    get response.location, headers: NAVIGATION_HEADERS

    assert_response :success

    BURST_ALLOWANCE.times do
      post auth_app_sign_in_passkey_verification_url(ri: "jp", host: host),
           params: { challenge_id: "missing", credential: { id: "x" } }, as: :json

      assert_response :bad_request
    end

    post auth_app_sign_in_passkey_verification_url(ri: "jp", host: host),
         params: { challenge_id: "missing", credential: { id: "x" } }, as: :json

    assert_response :too_many_requests
  end

  test "org passkey options answers 429 once the per-IP burst allowance is spent" do
    host = ENV.fetch("PUBLIC_AUTH_STAFF_URL")
    host! host
    https!
    client = OidcClientRegistry.find!("core-org-jp")
    transaction = OidcAuthorizationTransactionCoordinator.issue!(
      surface: "org", intent: "sign_in", params: {
        response_type: "code",
        client_id: client.client_id,
        redirect_uri: client.redirect_uris.first,
        code_challenge: "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM",
        code_challenge_method: "S256",
        state: SecureRandom.urlsafe_base64(16),
        nonce: SecureRandom.urlsafe_base64(16),
        scope: "openid profile",
      },
    ).transaction
    handoff = BaseAuthAdmissionCoordinator.issue_handoff!(
      transaction: transaction, base_browser_nonce: SecureRandom.urlsafe_base64(32), base_token: nil,
    )
    binding = OperatorAuthAdmissionBinding.find_by!(entry_ref: handoff.reference)
    headers = {
      "Sec-Fetch-Mode" => "navigate",
      "Sec-Fetch-Dest" => "document",
      "Sec-Fetch-Site" => "cross-site",
    }
    get auth_org_sign_in_path, params: { entry_ref: handoff.reference, ri: "jp" }, headers: headers

    assert_response :see_other
    get response.location, headers: headers

    assert_response :see_other
    binding.confirm_base!(base_token: nil, browser_digest: binding.base_browser_digest)
    get auth_org_sign_in_path, params: { entry_ref: handoff.reference, ri: "jp" }, headers: headers

    assert_response :see_other
    get response.location, headers: NAVIGATION_HEADERS

    assert_response :success

    BURST_ALLOWANCE.times do
      post auth_org_sign_in_passkey_options_url(ri: "jp", host: host),
           params: { identifier: "0123456789ABCDEF" }, as: :json

      assert_response :unprocessable_content
    end

    post auth_org_sign_in_passkey_options_url(ri: "jp", host: host),
         params: { identifier: "0123456789ABCDEF" }, as: :json

    assert_response :too_many_requests
  end

  test "org passkey verification answers 429 once the per-IP burst allowance is spent" do
    host = ENV.fetch("PUBLIC_AUTH_STAFF_URL")
    host! host
    https!
    client = OidcClientRegistry.find!("core-org-jp")
    transaction = OidcAuthorizationTransactionCoordinator.issue!(
      surface: "org", intent: "sign_in", params: {
        response_type: "code",
        client_id: client.client_id,
        redirect_uri: client.redirect_uris.first,
        code_challenge: "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM",
        code_challenge_method: "S256",
        state: SecureRandom.urlsafe_base64(16),
        nonce: SecureRandom.urlsafe_base64(16),
        scope: "openid profile",
      },
    ).transaction
    handoff = BaseAuthAdmissionCoordinator.issue_handoff!(
      transaction: transaction, base_browser_nonce: SecureRandom.urlsafe_base64(32), base_token: nil,
    )
    binding = OperatorAuthAdmissionBinding.find_by!(entry_ref: handoff.reference)
    headers = {
      "Sec-Fetch-Mode" => "navigate",
      "Sec-Fetch-Dest" => "document",
      "Sec-Fetch-Site" => "cross-site",
    }
    get auth_org_sign_in_path, params: { entry_ref: handoff.reference, ri: "jp" }, headers: headers

    assert_response :see_other
    get response.location, headers: headers

    assert_response :see_other
    binding.confirm_base!(base_token: nil, browser_digest: binding.base_browser_digest)
    get auth_org_sign_in_path, params: { entry_ref: handoff.reference, ri: "jp" }, headers: headers

    assert_response :see_other
    get response.location, headers: NAVIGATION_HEADERS

    assert_response :success

    BURST_ALLOWANCE.times do
      post auth_org_sign_in_passkey_verification_url(ri: "jp", host: host),
           params: { challenge_id: "missing", credential: { id: "x" } }, as: :json

      assert_response :unprocessable_content
    end

    post auth_org_sign_in_passkey_verification_url(ri: "jp", host: host),
         params: { challenge_id: "missing", credential: { id: "x" } }, as: :json

    assert_response :too_many_requests
  end

  test "app MFA passkey challenge answers 429 once the per-IP burst allowance is spent" do
    host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    host! host
    https!
    client = OidcClientRegistry.find!("core-app-jp")
    transaction = OidcAuthorizationTransactionCoordinator.issue!(
      surface: "app", intent: "sign_in", params: {
        response_type: "code",
        client_id: client.client_id,
        redirect_uri: client.redirect_uris.first,
        code_challenge: "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM",
        code_challenge_method: "S256",
        state: SecureRandom.urlsafe_base64(16),
        nonce: SecureRandom.urlsafe_base64(16),
        scope: "openid profile",
      },
    ).transaction
    issuance = BaseAuthAdmissionCoordinator.issue_handoff!(
      transaction: transaction, base_browser_nonce: SecureRandom.urlsafe_base64(32), base_token: nil,
    )
    get "/sign/in", params: { entry_ref: issuance.reference, ri: "jp" }, headers: NAVIGATION_HEADERS
    get response.location, headers: NAVIGATION_HEADERS
    binding = ClientAuthAdmissionBinding.find_by!(entry_ref: issuance.reference)
    binding.confirm_base!(base_token: nil, browser_digest: binding.base_browser_digest)
    get "/sign/in", params: { entry_ref: issuance.reference, ri: "jp" }, headers: NAVIGATION_HEADERS
    get response.location, headers: NAVIGATION_HEADERS

    assert_response :success

    BURST_ALLOWANCE.times do
      post auth_app_sign_in_challenge_passkey_url(ri: "jp", host: host),
           params: { challenge_id: "missing" }, as: :json

      assert_response :see_other
    end

    post auth_app_sign_in_challenge_passkey_url(ri: "jp", host: host),
         params: { challenge_id: "missing" }, as: :json

    assert_response :too_many_requests
    assert_equal "60", response.headers["Retry-After"]
  end

  test "app MFA passkey burst limit applies to a pending MFA ceremony" do
    host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    host! host
    https!
    actor = Client.create!(security_mode_id: SecurityModeConfigurable::ADVANCED)
    email = actor.client_emails.create!(
      address: "mfa-limit-#{SecureRandom.hex(8)}@example.com", user_email_status_id: ClientEmailStatus::VERIFIED,
    )
    email.finalize_binding!
    ClientTotpCredential.create!(
      user: actor, private_key: ROTP::Base32.random_base32,
      user_totp_credential_status_id: ClientTotpCredentialStatus::ACTIVE, title: "MFA TOTP",
    )
    actor.client_passkeys.create!(webauthn_id: SecureRandom.uuid, public_key: "mfa-limit-key")
    client = OidcClientRegistry.find!("core-app-jp")
    transaction = OidcAuthorizationTransactionCoordinator.issue!(
      surface: "app", intent: "sign_in", params: {
        response_type: "code",
        client_id: client.client_id,
        redirect_uri: client.redirect_uris.first,
        code_challenge: "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM",
        code_challenge_method: "S256",
        state: SecureRandom.urlsafe_base64(16),
        nonce: SecureRandom.urlsafe_base64(16),
        scope: "openid profile",
      },
    ).transaction
    issuance = BaseAuthAdmissionCoordinator.issue_handoff!(
      transaction: transaction, base_browser_nonce: SecureRandom.urlsafe_base64(32), base_token: nil,
    )
    get "/sign/in", params: { entry_ref: issuance.reference, ri: "jp" }, headers: NAVIGATION_HEADERS
    get response.location, headers: NAVIGATION_HEADERS
    binding = ClientAuthAdmissionBinding.find_by!(entry_ref: issuance.reference)
    binding.confirm_base!(base_token: nil, browser_digest: binding.base_browser_digest)
    get "/sign/in", params: { entry_ref: issuance.reference, ri: "jp" }, headers: NAVIGATION_HEADERS
    get response.location, headers: NAVIGATION_HEADERS

    assert_response :success
    post auth_app_sign_in_email_path(ri: "jp"),
         params: { :user_email => { address: email.address }, "cf-turnstile-response" => "test-only" }
    delivery = ActiveJob::Base.queue_adapter.enqueued_jobs.reverse.find { |entry| entry.fetch(:job) == OtpNotifierEmailDeliveryJob }
    payload = ActiveJob::Arguments.deserialize(delivery.fetch(:args)).last.fetch(:params)
    code = OutboundSensitivePayload.decrypt_email_otp(payload.fetch(:encrypted_hotp_token))
    patch auth_app_sign_in_email_path(ri: "jp"),
          params: { :user_email => { pass_code: code }, "cf-turnstile-response" => "test-only" }

    flow = ClientSignInFlow.where(principal_id: actor.id).recent_first.first

    assert_predicate flow, :sign_in_mfa_pending?
    phase_binding = SignInFlowBindingCodec.encode(flow: flow, surface: "app", phase: "MFA_PENDING")
    get new_auth_app_sign_in_challenge_passkey_path(ri: "jp", fb: phase_binding)

    assert_response :success
    BURST_ALLOWANCE.times do
      post auth_app_sign_in_challenge_passkey_url(ri: "jp", host: host, fb: phase_binding),
           params: { challenge_id: "missing" }, as: :json

      assert_response :see_other
      assert_equal auth_app_sign_in_challenge_path(ri: "jp").split("?").first, URI.parse(response.location).path
    end
    post auth_app_sign_in_challenge_passkey_url(ri: "jp", host: host, fb: phase_binding),
         params: { challenge_id: "missing" }, as: :json

    assert_response :too_many_requests
    assert_equal "60", response.headers["Retry-After"]
  end

  test "app MFA passkey sustained limit applies to a pending MFA ceremony" do
    host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    host! host
    https!
    actor = Client.create!(security_mode_id: SecurityModeConfigurable::ADVANCED)
    email = actor.client_emails.create!(
      address: "mfa-limit-#{SecureRandom.hex(8)}@example.com", user_email_status_id: ClientEmailStatus::VERIFIED,
    )
    email.finalize_binding!
    ClientTotpCredential.create!(
      user: actor, private_key: ROTP::Base32.random_base32,
      user_totp_credential_status_id: ClientTotpCredentialStatus::ACTIVE, title: "MFA TOTP",
    )
    actor.client_passkeys.create!(webauthn_id: SecureRandom.uuid, public_key: "mfa-limit-key")
    client = OidcClientRegistry.find!("core-app-jp")
    transaction = OidcAuthorizationTransactionCoordinator.issue!(
      surface: "app", intent: "sign_in", params: {
        response_type: "code",
        client_id: client.client_id,
        redirect_uri: client.redirect_uris.first,
        code_challenge: "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM",
        code_challenge_method: "S256",
        state: SecureRandom.urlsafe_base64(16),
        nonce: SecureRandom.urlsafe_base64(16),
        scope: "openid profile",
      },
    ).transaction
    issuance = BaseAuthAdmissionCoordinator.issue_handoff!(
      transaction: transaction, base_browser_nonce: SecureRandom.urlsafe_base64(32), base_token: nil,
    )
    get "/sign/in", params: { entry_ref: issuance.reference, ri: "jp" }, headers: NAVIGATION_HEADERS
    get response.location, headers: NAVIGATION_HEADERS
    binding = ClientAuthAdmissionBinding.find_by!(entry_ref: issuance.reference)
    binding.confirm_base!(base_token: nil, browser_digest: binding.base_browser_digest)
    get "/sign/in", params: { entry_ref: issuance.reference, ri: "jp" }, headers: NAVIGATION_HEADERS
    get response.location, headers: NAVIGATION_HEADERS

    assert_response :success
    post auth_app_sign_in_email_path(ri: "jp"),
         params: { :user_email => { address: email.address }, "cf-turnstile-response" => "test-only" }
    delivery = ActiveJob::Base.queue_adapter.enqueued_jobs.reverse.find { |entry| entry.fetch(:job) == OtpNotifierEmailDeliveryJob }
    payload = ActiveJob::Arguments.deserialize(delivery.fetch(:args)).last.fetch(:params)
    code = OutboundSensitivePayload.decrypt_email_otp(payload.fetch(:encrypted_hotp_token))
    patch auth_app_sign_in_email_path(ri: "jp"),
          params: { :user_email => { pass_code: code }, "cf-turnstile-response" => "test-only" }

    flow = ClientSignInFlow.where(principal_id: actor.id).recent_first.first

    assert_predicate flow, :sign_in_mfa_pending?
    phase_binding = SignInFlowBindingCodec.encode(flow: flow, surface: "app", phase: "MFA_PENDING")
    get new_auth_app_sign_in_challenge_passkey_path(ri: "jp", fb: phase_binding)

    assert_response :success
    (SUSTAINED_ALLOWANCE / BURST_ALLOWANCE).times do |burst|
      travel((burst * 61).seconds) do
        BURST_ALLOWANCE.times do
          post auth_app_sign_in_challenge_passkey_url(ri: "jp", host: host, fb: phase_binding),
               params: { challenge_id: "missing" }, as: :json

          assert_response :see_other
          assert_equal auth_app_sign_in_challenge_path(ri: "jp").split("?").first, URI.parse(response.location).path
        end
      end
    end
    travel((SUSTAINED_ALLOWANCE / BURST_ALLOWANCE * 61).seconds) do
      post auth_app_sign_in_challenge_passkey_url(ri: "jp", host: host, fb: phase_binding),
           params: { challenge_id: "missing" }, as: :json
    end

    assert_response :too_many_requests
    assert_equal "900", response.headers["Retry-After"]
    assert_predicate flow.reload, :sign_in_mfa_pending?
  end

  test "app email sign-in answers 429 once the per-IP burst allowance is spent" do
    host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    host! host
    https!
    client = OidcClientRegistry.find!("core-app-jp")
    transaction = OidcAuthorizationTransactionCoordinator.issue!(
      surface: "app", intent: "sign_in", params: {
        response_type: "code",
        client_id: client.client_id,
        redirect_uri: client.redirect_uris.first,
        code_challenge: "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM",
        code_challenge_method: "S256",
        state: SecureRandom.urlsafe_base64(16),
        nonce: SecureRandom.urlsafe_base64(16),
        scope: "openid profile",
      },
    ).transaction
    issuance = BaseAuthAdmissionCoordinator.issue_handoff!(
      transaction: transaction, base_browser_nonce: SecureRandom.urlsafe_base64(32), base_token: nil,
    )
    get "/sign/in", params: { entry_ref: issuance.reference, ri: "jp" }, headers: NAVIGATION_HEADERS
    get response.location, headers: NAVIGATION_HEADERS
    binding = ClientAuthAdmissionBinding.find_by!(entry_ref: issuance.reference)
    binding.confirm_base!(base_token: nil, browser_digest: binding.base_browser_digest)
    get "/sign/in", params: { entry_ref: issuance.reference, ri: "jp" }, headers: NAVIGATION_HEADERS
    get response.location, headers: NAVIGATION_HEADERS

    assert_response :success

    BURST_ALLOWANCE.times do |index|
      post auth_app_sign_in_email_url(ri: "jp", host: host),
           params: { user_email: { address: "burst_signin_#{index}@example.com" } }

      assert_response :redirect
    end

    post auth_app_sign_in_email_url(ri: "jp", host: host),
         params: { user_email: { address: "burst_signin@example.com" } }

    assert_response :too_many_requests
    assert_equal "60", response.headers["Retry-After"]
  end

  # Email sign-in declares a sustained limiter alongside the burst one, with a
  # longer retry hint. A sustained limiter that stopped firing would go unnoticed.
  {
    "app email sign-in" => [
      :auth_app_sign_in_email_url, "PUBLIC_AUTH_SERVICE_URL",
      { user_email: { address: "sustained@example.com" } },
    ],
  }.each do |label, (helper, host_env, request_params)|
    test "#{label} answers 429 with the sustained retry hint once the 15-minute allowance is spent" do
      host = ENV.fetch(host_env)
      host! host
      https!
      client = OidcClientRegistry.find!("core-app-jp")
      transaction = OidcAuthorizationTransactionCoordinator.issue!(
        surface: "app", intent: "sign_in", params: {
          response_type: "code",
          client_id: client.client_id,
          redirect_uri: client.redirect_uris.first,
          code_challenge: "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM",
          code_challenge_method: "S256",
          state: SecureRandom.urlsafe_base64(16),
          nonce: SecureRandom.urlsafe_base64(16),
          scope: "openid profile",
        },
      ).transaction
      issuance = BaseAuthAdmissionCoordinator.issue_handoff!(
        transaction: transaction, base_browser_nonce: SecureRandom.urlsafe_base64(32), base_token: nil,
      )
      get "/sign/in", params: { entry_ref: issuance.reference, ri: "jp" }, headers: NAVIGATION_HEADERS
      get response.location, headers: NAVIGATION_HEADERS
      binding = ClientAuthAdmissionBinding.find_by!(entry_ref: issuance.reference)
      binding.confirm_base!(base_token: nil, browser_digest: binding.base_browser_digest)
      get "/sign/in", params: { entry_ref: issuance.reference, ri: "jp" }, headers: NAVIGATION_HEADERS
      get response.location, headers: NAVIGATION_HEADERS

      assert_response :success

      (SUSTAINED_ALLOWANCE / BURST_ALLOWANCE).times do |burst|
        travel((burst * 61).seconds) do
          BURST_ALLOWANCE.times do |index|
            address = "sustained_#{burst}_#{index}@example.com"
            post public_send(helper, ri: "jp", host: host), params: { user_email: { address: address } }

            assert_response :redirect
          end
        end
      end

      travel((SUSTAINED_ALLOWANCE / BURST_ALLOWANCE * 61).seconds) do
        post public_send(helper, ri: "jp", host: host), params: request_params
      end

      assert_response :too_many_requests
      assert_equal "900", response.headers["Retry-After"]
    end
  end

  test "app passkey options answers 429 with the sustained retry hint once the 15-minute allowance is spent" do
    host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    host! host
    https!
    client = OidcClientRegistry.find!("core-app-jp")
    transaction = OidcAuthorizationTransactionCoordinator.issue!(
      surface: "app", intent: "sign_in", params: {
        response_type: "code",
        client_id: client.client_id,
        redirect_uri: client.redirect_uris.first,
        code_challenge: "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM",
        code_challenge_method: "S256",
        state: SecureRandom.urlsafe_base64(16),
        nonce: SecureRandom.urlsafe_base64(16),
        scope: "openid profile",
      },
    ).transaction
    issuance = BaseAuthAdmissionCoordinator.issue_handoff!(
      transaction: transaction, base_browser_nonce: SecureRandom.urlsafe_base64(32), base_token: nil,
    )
    get "/sign/in", params: { entry_ref: issuance.reference, ri: "jp" }, headers: NAVIGATION_HEADERS
    get response.location, headers: NAVIGATION_HEADERS
    binding = ClientAuthAdmissionBinding.find_by!(entry_ref: issuance.reference)
    binding.confirm_base!(base_token: nil, browser_digest: binding.base_browser_digest)
    get "/sign/in", params: { entry_ref: issuance.reference, ri: "jp" }, headers: NAVIGATION_HEADERS
    get response.location, headers: NAVIGATION_HEADERS

    assert_response :success

    # Four bursts of five, each after the one-minute burst window has rolled
    # over, spend the sustained allowance without ever tripping the burst rule.
    (SUSTAINED_ALLOWANCE / BURST_ALLOWANCE).times do |burst|
      travel((burst * 61).seconds) do
        BURST_ALLOWANCE.times do
          post auth_app_sign_in_passkey_options_url(ri: "jp", host: host),
               params: { identifier: "sustained_app@example.com" }, as: :json

          assert_response :success
        end
      end
    end

    travel((SUSTAINED_ALLOWANCE / BURST_ALLOWANCE * 61).seconds) do
      post auth_app_sign_in_passkey_options_url(ri: "jp", host: host),
           params: { identifier: "sustained_app@example.com" }, as: :json
    end

    assert_response :too_many_requests
    assert_equal "900", response.headers["Retry-After"]
  end

  test "org passkey options answers 429 with the sustained retry hint once the 15-minute allowance is spent" do
    host = ENV.fetch("PUBLIC_AUTH_STAFF_URL")
    host! host
    https!
    client = OidcClientRegistry.find!("core-org-jp")
    transaction = OidcAuthorizationTransactionCoordinator.issue!(
      surface: "org", intent: "sign_in", params: {
        response_type: "code",
        client_id: client.client_id,
        redirect_uri: client.redirect_uris.first,
        code_challenge: "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM",
        code_challenge_method: "S256",
        state: SecureRandom.urlsafe_base64(16),
        nonce: SecureRandom.urlsafe_base64(16),
        scope: "openid profile",
      },
    ).transaction
    handoff = BaseAuthAdmissionCoordinator.issue_handoff!(
      transaction: transaction, base_browser_nonce: SecureRandom.urlsafe_base64(32), base_token: nil,
    )
    binding = OperatorAuthAdmissionBinding.find_by!(entry_ref: handoff.reference)
    headers = {
      "Sec-Fetch-Mode" => "navigate",
      "Sec-Fetch-Dest" => "document",
      "Sec-Fetch-Site" => "cross-site",
    }
    get auth_org_sign_in_path, params: { entry_ref: handoff.reference, ri: "jp" }, headers: headers

    assert_response :see_other
    get response.location, headers: headers

    assert_response :see_other
    binding.confirm_base!(base_token: nil, browser_digest: binding.base_browser_digest)
    get auth_org_sign_in_path, params: { entry_ref: handoff.reference, ri: "jp" }, headers: headers

    assert_response :see_other
    get response.location, headers: NAVIGATION_HEADERS

    assert_response :success

    (SUSTAINED_ALLOWANCE / BURST_ALLOWANCE).times do |burst|
      travel((burst * 61).seconds) do
        BURST_ALLOWANCE.times do
          post auth_org_sign_in_passkey_options_url(ri: "jp", host: host),
               params: { identifier: "0123456789ABCDEF" }, as: :json

          assert_response :unprocessable_content
        end
      end
    end

    travel((SUSTAINED_ALLOWANCE / BURST_ALLOWANCE * 61).seconds) do
      post auth_org_sign_in_passkey_options_url(ri: "jp", host: host),
           params: { identifier: "0123456789ABCDEF" }, as: :json
    end

    assert_response :too_many_requests
    assert_equal "900", response.headers["Retry-After"]
  end

  test "app passkey verification answers 429 with the sustained retry hint once the 15-minute allowance is spent" do
    host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    host! host
    https!
    client = OidcClientRegistry.find!("core-app-jp")
    transaction = OidcAuthorizationTransactionCoordinator.issue!(
      surface: "app", intent: "sign_in", params: {
        response_type: "code",
        client_id: client.client_id,
        redirect_uri: client.redirect_uris.first,
        code_challenge: "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM",
        code_challenge_method: "S256",
        state: SecureRandom.urlsafe_base64(16),
        nonce: SecureRandom.urlsafe_base64(16),
        scope: "openid profile",
      },
    ).transaction
    handoff = BaseAuthAdmissionCoordinator.issue_handoff!(
      transaction: transaction, base_browser_nonce: SecureRandom.urlsafe_base64(32), base_token: nil,
    )
    binding = ClientAuthAdmissionBinding.find_by!(entry_ref: handoff.reference)
    headers = {
      "Sec-Fetch-Mode" => "navigate",
      "Sec-Fetch-Dest" => "document",
      "Sec-Fetch-Site" => "cross-site",
    }
    get auth_app_sign_in_path, params: { entry_ref: handoff.reference, ri: "jp" }, headers: headers

    assert_response :see_other
    get response.location, headers: headers

    assert_response :see_other
    binding.confirm_base!(base_token: nil, browser_digest: binding.base_browser_digest)
    get auth_app_sign_in_path, params: { entry_ref: handoff.reference, ri: "jp" }, headers: headers

    assert_response :see_other
    get response.location, headers: NAVIGATION_HEADERS

    assert_response :success

    (SUSTAINED_ALLOWANCE / BURST_ALLOWANCE).times do |burst|
      travel((burst * 61).seconds) do
        BURST_ALLOWANCE.times do
          post auth_app_sign_in_passkey_verification_url(ri: "jp", host: host),
               params: { challenge_id: "missing", credential: { id: "x" } }, as: :json

          assert_response :bad_request
        end
      end
    end

    travel((SUSTAINED_ALLOWANCE / BURST_ALLOWANCE * 61).seconds) do
      post auth_app_sign_in_passkey_verification_url(ri: "jp", host: host),
           params: { challenge_id: "missing", credential: { id: "x" } }, as: :json
    end

    assert_response :too_many_requests
    assert_equal "900", response.headers["Retry-After"]
  end

  test "org passkey verification answers 429 with the sustained retry hint once the 15-minute allowance is spent" do
    host = ENV.fetch("PUBLIC_AUTH_STAFF_URL")
    host! host
    https!
    client = OidcClientRegistry.find!("core-org-jp")
    transaction = OidcAuthorizationTransactionCoordinator.issue!(
      surface: "org", intent: "sign_in", params: {
        response_type: "code",
        client_id: client.client_id,
        redirect_uri: client.redirect_uris.first,
        code_challenge: "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM",
        code_challenge_method: "S256",
        state: SecureRandom.urlsafe_base64(16),
        nonce: SecureRandom.urlsafe_base64(16),
        scope: "openid profile",
      },
    ).transaction
    handoff = BaseAuthAdmissionCoordinator.issue_handoff!(
      transaction: transaction, base_browser_nonce: SecureRandom.urlsafe_base64(32), base_token: nil,
    )
    binding = OperatorAuthAdmissionBinding.find_by!(entry_ref: handoff.reference)
    headers = {
      "Sec-Fetch-Mode" => "navigate",
      "Sec-Fetch-Dest" => "document",
      "Sec-Fetch-Site" => "cross-site",
    }
    get auth_org_sign_in_path, params: { entry_ref: handoff.reference, ri: "jp" }, headers: headers

    assert_response :see_other
    get response.location, headers: headers

    assert_response :see_other
    binding.confirm_base!(base_token: nil, browser_digest: binding.base_browser_digest)
    get auth_org_sign_in_path, params: { entry_ref: handoff.reference, ri: "jp" }, headers: headers

    assert_response :see_other
    get response.location, headers: NAVIGATION_HEADERS

    assert_response :success

    (SUSTAINED_ALLOWANCE / BURST_ALLOWANCE).times do |burst|
      travel((burst * 61).seconds) do
        BURST_ALLOWANCE.times do
          post auth_org_sign_in_passkey_verification_url(ri: "jp", host: host),
               params: { challenge_id: "missing", credential: { id: "x" } }, as: :json

          assert_response :unprocessable_content
        end
      end
    end

    travel((SUSTAINED_ALLOWANCE / BURST_ALLOWANCE * 61).seconds) do
      post auth_org_sign_in_passkey_verification_url(ri: "jp", host: host),
           params: { challenge_id: "missing", credential: { id: "x" } }, as: :json
    end

    assert_response :too_many_requests
    assert_equal "900", response.headers["Retry-After"]
  end

  # The MFA challenge endpoints carry the same burst-and-sustained pair as the
  # primary factors. Four bursts of five, each after the one-minute burst window
  # has rolled over, spend the sustained allowance without tripping the burst rule.
  test "app MFA passkey challenge answers 429 with the sustained hint once the 15-minute allowance is spent" do
    host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    host! host
    https!
    client = OidcClientRegistry.find!("core-app-jp")
    transaction = OidcAuthorizationTransactionCoordinator.issue!(
      surface: "app", intent: "sign_in", params: {
        response_type: "code",
        client_id: client.client_id,
        redirect_uri: client.redirect_uris.first,
        code_challenge: "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM",
        code_challenge_method: "S256",
        state: SecureRandom.urlsafe_base64(16),
        nonce: SecureRandom.urlsafe_base64(16),
        scope: "openid profile",
      },
    ).transaction
    issuance = BaseAuthAdmissionCoordinator.issue_handoff!(
      transaction: transaction, base_browser_nonce: SecureRandom.urlsafe_base64(32), base_token: nil,
    )
    get "/sign/in", params: { entry_ref: issuance.reference, ri: "jp" }, headers: NAVIGATION_HEADERS
    get response.location, headers: NAVIGATION_HEADERS
    binding = ClientAuthAdmissionBinding.find_by!(entry_ref: issuance.reference)
    binding.confirm_base!(base_token: nil, browser_digest: binding.base_browser_digest)
    get "/sign/in", params: { entry_ref: issuance.reference, ri: "jp" }, headers: NAVIGATION_HEADERS
    get response.location, headers: NAVIGATION_HEADERS

    assert_response :success

    (SUSTAINED_ALLOWANCE / BURST_ALLOWANCE).times do |burst|
      travel((burst * 61).seconds) do
        BURST_ALLOWANCE.times do
          post auth_app_sign_in_challenge_passkey_url(ri: "jp", host: host),
               params: { challenge_id: "missing" }, as: :json

          assert_response :see_other
        end
      end
    end

    travel((SUSTAINED_ALLOWANCE / BURST_ALLOWANCE * 61).seconds) do
      post auth_app_sign_in_challenge_passkey_url(ri: "jp", host: host),
           params: { challenge_id: "missing" }, as: :json
    end

    assert_response :too_many_requests
    assert_equal "900", response.headers["Retry-After"]
  end

  # The per-account rule is the only one that bounds a distributed attacker, who
  # spreads the guesses across enough source addresses that neither IP rule fires.
  # It is stricter than the sustained IP rule, so it is what answers first.
  ACCOUNT_ALLOWANCE = 10

  # Submitting the sign-in code is a separate action from requesting it, and
  # carries its own limiter pair; only the request side was exercised.
  test "app email sign-in code submission answers 429 once the per-IP burst allowance is spent" do
    host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    host! host
    https!
    client = OidcClientRegistry.find!("core-app-jp")
    transaction = OidcAuthorizationTransactionCoordinator.issue!(
      surface: "app", intent: "sign_in", params: {
        response_type: "code",
        client_id: client.client_id,
        redirect_uri: client.redirect_uris.first,
        code_challenge: "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM",
        code_challenge_method: "S256",
        state: SecureRandom.urlsafe_base64(16),
        nonce: SecureRandom.urlsafe_base64(16),
        scope: "openid profile",
      },
    ).transaction
    issuance = BaseAuthAdmissionCoordinator.issue_handoff!(
      transaction: transaction, base_browser_nonce: SecureRandom.urlsafe_base64(32), base_token: nil,
    )
    get "/sign/in", params: { entry_ref: issuance.reference, ri: "jp" }, headers: NAVIGATION_HEADERS
    get response.location, headers: NAVIGATION_HEADERS
    binding = ClientAuthAdmissionBinding.find_by!(entry_ref: issuance.reference)
    binding.confirm_base!(base_token: nil, browser_digest: binding.base_browser_digest)
    get "/sign/in", params: { entry_ref: issuance.reference, ri: "jp" }, headers: NAVIGATION_HEADERS
    get response.location, headers: NAVIGATION_HEADERS

    assert_response :success

    BURST_ALLOWANCE.times do
      patch auth_app_sign_in_email_url(ri: "jp", host: host),
            params: { client_email: { pass_code: "000000" } }

      assert_response :redirect
    end

    patch auth_app_sign_in_email_url(ri: "jp", host: host),
          params: { client_email: { pass_code: "000000" } }

    assert_response :too_many_requests
    assert_equal "60", response.headers["Retry-After"]
  end

  test "app email sign-in code submission answers 429 with the sustained hint once the 15-minute allowance is spent" do
    host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    host! host
    https!
    client = OidcClientRegistry.find!("core-app-jp")
    transaction = OidcAuthorizationTransactionCoordinator.issue!(
      surface: "app", intent: "sign_in", params: {
        response_type: "code",
        client_id: client.client_id,
        redirect_uri: client.redirect_uris.first,
        code_challenge: "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM",
        code_challenge_method: "S256",
        state: SecureRandom.urlsafe_base64(16),
        nonce: SecureRandom.urlsafe_base64(16),
        scope: "openid profile",
      },
    ).transaction
    issuance = BaseAuthAdmissionCoordinator.issue_handoff!(
      transaction: transaction, base_browser_nonce: SecureRandom.urlsafe_base64(32), base_token: nil,
    )
    get "/sign/in", params: { entry_ref: issuance.reference, ri: "jp" }, headers: NAVIGATION_HEADERS
    get response.location, headers: NAVIGATION_HEADERS
    binding = ClientAuthAdmissionBinding.find_by!(entry_ref: issuance.reference)
    binding.confirm_base!(base_token: nil, browser_digest: binding.base_browser_digest)
    get "/sign/in", params: { entry_ref: issuance.reference, ri: "jp" }, headers: NAVIGATION_HEADERS
    get response.location, headers: NAVIGATION_HEADERS

    assert_response :success
    params = { client_email: { pass_code: "000000" } }

    (SUSTAINED_ALLOWANCE / BURST_ALLOWANCE).times do |burst|
      travel((burst * 61).seconds) do
        BURST_ALLOWANCE.times do
          patch auth_app_sign_in_email_url(ri: "jp", host: host), params: params

          assert_response :redirect
        end
      end
    end

    travel((SUSTAINED_ALLOWANCE / BURST_ALLOWANCE * 61).seconds) do
      patch auth_app_sign_in_email_url(ri: "jp", host: host), params: params
    end

    assert_response :too_many_requests
    assert_equal "900", response.headers["Retry-After"]
  end

  # Sign-up entry is limited twice: once per source, and once per submitted
  # address so that OTP fanout to one mailbox is bounded even from many sources.
  {
    "app" => [:auth_app_sign_up_email_url, "PUBLIC_AUTH_SERVICE_URL", :client_email],
  }.each do |surface, (helper, host_env, param_key)|
    test "#{surface} sign-up email answers 429 once the per-source allowance is spent" do
      # The per-source quota is larger than the sign-up flow's own OTP cooldown, so
      # a run that clears the challenge is answered by the cooldown long before the
      # limiter. A failing challenge is refused before any OTP work, which is what
      # leaves the limiter as the only thing counting.
      TurnstileVerifierStub.response = { "success" => false }
      TurnstileVerifierStub.challenge_response = { "success" => false }
      host = ENV.fetch(host_env)
      host! host
      begin
        admission_browser = self
        admission_surface = surface
        admission_intent = "sign_up"
        admission_host = {
          "app" => ENV.fetch("PUBLIC_AUTH_SERVICE_URL"),
          "com" => ENV.fetch("PUBLIC_AUTH_CORPORATE_URL"),
          "org" => ENV.fetch("PUBLIC_AUTH_STAFF_URL"),
        }.fetch(admission_surface)
        admission_browser.host!(admission_host)
        admission_issuance = OidcTestEntry.issue!(
          surface: admission_surface, intent: admission_intent,
          base_browser_nonce: SecureRandom.hex(32), base_token: nil,
        )
        admission_path = "/sign/#{(admission_intent == "sign_up") ? "up" : "in"}"
        # An entry reference is accepted only on a top-level document navigation, and a live
        # reference never renders: it answers 303 to the ceremony binding action and redeems only
        # after Base confirmed the binding.
        admission_navigation = { "Sec-Fetch-Mode" => "navigate", "Sec-Fetch-Dest" => "document" }
        admission_browser.get(
          admission_path,
          params: { entry_ref: admission_issuance.reference, ri: "jp" },
          headers: admission_navigation,
        )

        assert_equal 303, admission_browser.response.status
        admission_browser.get(admission_browser.response.location, headers: admission_navigation)

        assert_equal 303, admission_browser.response.status
        admission_binding = BaseAuthAdmissionCoordinator.find_admission_binding!(
          surface: admission_surface, reference: admission_issuance.reference,
        )
        admission_binding.reload.confirm_base!(
          base_token: nil,
          browser_digest: admission_binding.base_browser_digest,
        )
        admission_browser.get(
          admission_path,
          params: { entry_ref: admission_issuance.reference, ri: "jp" },
          headers: admission_navigation,
        )

        assert_equal 303, admission_browser.response.status
        admission_browser.get(admission_browser.response.location, headers: admission_navigation)

        assert_equal 200, admission_browser.response.status
      end
      quota = RateLimitProfiles.interactive_post_ip.to

      quota.times do
        post public_send(helper, ri: "jp", host: host),
             params: { param_key => { address: "signup_ip_#{surface}@example.com", confirm_policy: "1" } }
      end

      assert_not_equal 429, response.status

      post public_send(helper, ri: "jp", host: host),
           params: { param_key => { address: "signup_ip_#{surface}@example.com", confirm_policy: "1" } }

      assert_response :too_many_requests
      assert_equal RateLimitProfiles.interactive_post_ip.retry_after.to_s, response.headers["Retry-After"]
    end

    test "#{surface} sign-up email answers 429 once one address has spent its allowance" do
      host = ENV.fetch(host_env)
      host! host
      begin
        admission_browser = self
        admission_surface = surface
        admission_intent = "sign_up"
        admission_host = {
          "app" => ENV.fetch("PUBLIC_AUTH_SERVICE_URL"),
          "com" => ENV.fetch("PUBLIC_AUTH_CORPORATE_URL"),
          "org" => ENV.fetch("PUBLIC_AUTH_STAFF_URL"),
        }.fetch(admission_surface)
        admission_browser.host!(admission_host)
        admission_issuance = OidcTestEntry.issue!(
          surface: admission_surface, intent: admission_intent,
          base_browser_nonce: SecureRandom.hex(32), base_token: nil,
        )
        admission_path = "/sign/#{(admission_intent == "sign_up") ? "up" : "in"}"
        # An entry reference is accepted only on a top-level document navigation, and a live
        # reference never renders: it answers 303 to the ceremony binding action and redeems only
        # after Base confirmed the binding.
        admission_navigation = { "Sec-Fetch-Mode" => "navigate", "Sec-Fetch-Dest" => "document" }
        admission_browser.get(
          admission_path,
          params: { entry_ref: admission_issuance.reference, ri: "jp" },
          headers: admission_navigation,
        )

        assert_equal 303, admission_browser.response.status
        admission_browser.get(admission_browser.response.location, headers: admission_navigation)

        assert_equal 303, admission_browser.response.status
        admission_binding = BaseAuthAdmissionCoordinator.find_admission_binding!(
          surface: admission_surface, reference: admission_issuance.reference,
        )
        admission_binding.reload.confirm_base!(
          base_token: nil,
          browser_digest: admission_binding.base_browser_digest,
        )
        admission_browser.get(
          admission_path,
          params: { entry_ref: admission_issuance.reference, ri: "jp" },
          headers: admission_navigation,
        )

        assert_equal 303, admission_browser.response.status
        admission_browser.get(admission_browser.response.location, headers: admission_navigation)

        assert_equal 200, admission_browser.response.status
      end
      quota = RateLimitProfiles.email_address_submit.to
      params = { param_key => { address: "signup_addr_#{surface}@example.com", confirm_policy: "1" } }

      quota.times { post public_send(helper, ri: "jp", host: host), params: params }

      # Past the one-minute per-source window, so only the per-address rule is left holding a count.
      travel(61.seconds) do
        post public_send(helper, ri: "jp", host: host), params: params

        assert_response :too_many_requests
        assert_equal RateLimitProfiles.email_address_submit.retry_after.to_s, response.headers["Retry-After"]
      end
    end
  end
end
