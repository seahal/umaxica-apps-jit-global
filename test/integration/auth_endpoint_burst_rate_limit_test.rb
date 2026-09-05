# typed: false
# frozen_string_literal: true

require "test_helper"

# Per-IP burst limiters declared on the unauthenticated auth endpoints. Each
# endpoint declares its own `rate_limit(..., with: -> { render_rate_limited })`
# handler; these exercise that handler through the real routing and controller
# stack so a limiter that is declared but never wired is a failing test rather
# than silent absence of protection.
class AuthEndpointBurstRateLimitTest < ActionDispatch::IntegrationTest
  counts_rate_limits!
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

    (BURST_ALLOWANCE + 1).times do
      post auth_app_sign_in_passkey_options_url(ri: "jp", host: host),
           params: { identifier: "burst_app@example.com" }, as: :json
    end

    assert_response :too_many_requests
    assert_equal "60", response.headers["Retry-After"]
  end

  test "app passkey verification answers 429 once the per-IP burst allowance is spent" do
    host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    host! host

    (BURST_ALLOWANCE + 1).times do
      post auth_app_sign_in_passkey_verification_url(ri: "jp", host: host),
           params: { challenge_id: "missing", credential: { id: "x" } }, as: :json
    end

    assert_response :too_many_requests
  end

  test "com passkey options answers 429 once the per-IP burst allowance is spent" do
    host = ENV.fetch("PUBLIC_AUTH_CORPORATE_URL")
    host! host

    (BURST_ALLOWANCE + 1).times do
      post auth_com_sign_in_passkey_options_url(ri: "jp", host: host),
           params: { identifier: "burst_com@example.com" }, as: :json
    end

    assert_response :too_many_requests
  end

  test "com passkey verification answers 429 once the per-IP burst allowance is spent" do
    host = ENV.fetch("PUBLIC_AUTH_CORPORATE_URL")
    host! host

    (BURST_ALLOWANCE + 1).times do
      post auth_com_sign_in_passkey_verification_url(ri: "jp", host: host),
           params: { challenge_id: "missing", credential: { id: "x" } }, as: :json
    end

    assert_response :too_many_requests
  end

  test "org passkey options answers 429 once the per-IP burst allowance is spent" do
    host = ENV.fetch("PUBLIC_AUTH_STAFF_URL")
    host! host

    (BURST_ALLOWANCE + 1).times do
      post auth_org_sign_in_passkey_options_url(ri: "jp", host: host),
           params: { identifier: "0123456789ABCDEF" }, as: :json
    end

    assert_response :too_many_requests
  end

  test "org passkey verification answers 429 once the per-IP burst allowance is spent" do
    host = ENV.fetch("PUBLIC_AUTH_STAFF_URL")
    host! host

    (BURST_ALLOWANCE + 1).times do
      post auth_org_sign_in_passkey_verification_url(ri: "jp", host: host),
           params: { challenge_id: "missing", credential: { id: "x" } }, as: :json
    end

    assert_response :too_many_requests
  end

  test "app MFA passkey challenge answers 429 once the per-IP burst allowance is spent" do
    host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    host! host

    (BURST_ALLOWANCE + 1).times do
      post auth_app_sign_in_challenge_passkey_url(ri: "jp", host: host),
           params: { challenge_id: "missing" }, as: :json
    end

    assert_response :too_many_requests
  end

  test "com MFA passkey challenge answers 429 once the per-IP burst allowance is spent" do
    host = ENV.fetch("PUBLIC_AUTH_CORPORATE_URL")
    host! host

    (BURST_ALLOWANCE + 1).times do
      post auth_com_sign_in_challenge_passkey_url(ri: "jp", host: host),
           params: { challenge_id: "missing" }, as: :json
    end

    assert_response :too_many_requests
  end

  test "org MFA passkey challenge answers 429 once the per-IP burst allowance is spent" do
    host = ENV.fetch("PUBLIC_AUTH_STAFF_URL")
    host! host

    (BURST_ALLOWANCE + 1).times do
      post auth_org_sign_in_challenge_passkey_url(ri: "jp", host: host),
           params: { challenge_id: "missing" }, as: :json
    end

    assert_response :too_many_requests
  end

  test "app MFA TOTP challenge answers 429 once the per-IP burst allowance is spent" do
    host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    host! host

    (BURST_ALLOWANCE + 1).times do
      post auth_app_sign_in_challenge_totp_url(ri: "jp", host: host),
           params: { totp_challenge_form: { token: "000000" } }
    end

    assert_response :too_many_requests
  end

  test "app secret credential sign-in answers 429 once the per-IP burst allowance is spent" do
    host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    host! host

    (BURST_ALLOWANCE + 1).times do
      post auth_app_sign_in_secret_url(ri: "jp", host: host),
           params: { client_secret_credential: { identifier: "burst@example.com", secret_credential_value: "x" } }
    end

    assert_response :too_many_requests
  end

  test "com secret credential sign-in answers 429 once the per-IP burst allowance is spent" do
    host = ENV.fetch("PUBLIC_AUTH_CORPORATE_URL")
    host! host

    (BURST_ALLOWANCE + 1).times do
      post auth_com_sign_in_secret_url(ri: "jp", host: host),
           params: { visitor_secret_credential: { identifier: "burst@example.com", secret_credential_value: "x" } }
    end

    assert_response :too_many_requests
  end

  test "org secret credential sign-in answers 429 once the per-IP burst allowance is spent" do
    host = ENV.fetch("PUBLIC_AUTH_STAFF_URL")
    host! host

    (BURST_ALLOWANCE + 1).times do
      post auth_org_sign_in_secret_url(ri: "jp", host: host),
           params: { staff_secret_credential: { identifier: "0123456789ABCDEF", secret_credential_value: "x" } }
    end

    assert_response :too_many_requests
  end

  test "app email sign-in answers 429 once the per-IP burst allowance is spent" do
    host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    host! host

    (BURST_ALLOWANCE + 1).times do
      post auth_app_sign_in_email_url(ri: "jp", host: host),
           params: { user_email: { address: "burst_signin@example.com" } }
    end

    assert_response :too_many_requests
  end

  test "com email sign-in answers 429 once the per-IP burst allowance is spent" do
    host = ENV.fetch("PUBLIC_AUTH_CORPORATE_URL")
    host! host

    (BURST_ALLOWANCE + 1).times do
      post auth_com_sign_in_email_url(ri: "jp", host: host),
           params: { visitor_email: { address: "burst_signin_com@example.com" } }
    end

    assert_response :too_many_requests
  end

  # The secret-credential and email sign-in endpoints declare a sustained limiter
  # alongside the burst one, with a longer retry hint. Only the burst arm was
  # exercised, so a sustained limiter that stopped firing would have gone unnoticed.
  {
    "app secret credential sign-in" => [
      :auth_app_sign_in_secret_url, "PUBLIC_AUTH_SERVICE_URL",
      { client_secret_credential: { identifier: "sustained@example.com", secret_credential_value: "x" } },
    ],
    "com secret credential sign-in" => [
      :auth_com_sign_in_secret_url, "PUBLIC_AUTH_CORPORATE_URL",
      { visitor_secret_credential: { identifier: "sustained@example.com", secret_credential_value: "x" } },
    ],
    "app email sign-in" => [
      :auth_app_sign_in_email_url, "PUBLIC_AUTH_SERVICE_URL",
      { client_email: { address: "sustained@example.com" } },
    ],
    "com email sign-in" => [
      :auth_com_sign_in_email_url, "PUBLIC_AUTH_CORPORATE_URL",
      { visitor_email: { address: "sustained@example.com" } },
    ],
  }.each do |label, (helper, host_env, request_params)|
    test "#{label} answers 429 with the sustained retry hint once the 15-minute allowance is spent" do
      host = ENV.fetch(host_env)
      host! host

      (SUSTAINED_ALLOWANCE / BURST_ALLOWANCE).times do |burst|
        travel((burst * 61).seconds) do
          BURST_ALLOWANCE.times { post public_send(helper, ri: "jp", host: host), params: request_params }
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

  test "com passkey options answers 429 with the sustained retry hint once the 15-minute allowance is spent" do
    host = ENV.fetch("PUBLIC_AUTH_CORPORATE_URL")
    host! host

    (SUSTAINED_ALLOWANCE / BURST_ALLOWANCE).times do |burst|
      travel((burst * 61).seconds) do
        BURST_ALLOWANCE.times do
          post auth_com_sign_in_passkey_options_url(ri: "jp", host: host),
               params: { identifier: "sustained_com@example.com" }, as: :json
        end
      end
    end

    travel((SUSTAINED_ALLOWANCE / BURST_ALLOWANCE * 61).seconds) do
      post auth_com_sign_in_passkey_options_url(ri: "jp", host: host),
           params: { identifier: "sustained_com@example.com" }, as: :json
    end

    assert_response :too_many_requests
    assert_equal "900", response.headers["Retry-After"]
  end

  test "org passkey options answers 429 with the sustained retry hint once the 15-minute allowance is spent" do
    host = ENV.fetch("PUBLIC_AUTH_STAFF_URL")
    host! host

    (SUSTAINED_ALLOWANCE / BURST_ALLOWANCE).times do |burst|
      travel((burst * 61).seconds) do
        BURST_ALLOWANCE.times do
          post auth_org_sign_in_passkey_options_url(ri: "jp", host: host),
               params: { identifier: "0123456789ABCDEF" }, as: :json
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

    (SUSTAINED_ALLOWANCE / BURST_ALLOWANCE).times do |burst|
      travel((burst * 61).seconds) do
        BURST_ALLOWANCE.times do
          post auth_app_sign_in_passkey_verification_url(ri: "jp", host: host),
               params: { challenge_id: "missing", credential: { id: "x" } }, as: :json
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

  test "com passkey verification answers 429 with the sustained retry hint once the 15-minute allowance is spent" do
    host = ENV.fetch("PUBLIC_AUTH_CORPORATE_URL")
    host! host

    (SUSTAINED_ALLOWANCE / BURST_ALLOWANCE).times do |burst|
      travel((burst * 61).seconds) do
        BURST_ALLOWANCE.times do
          post auth_com_sign_in_passkey_verification_url(ri: "jp", host: host),
               params: { challenge_id: "missing", credential: { id: "x" } }, as: :json
        end
      end
    end

    travel((SUSTAINED_ALLOWANCE / BURST_ALLOWANCE * 61).seconds) do
      post auth_com_sign_in_passkey_verification_url(ri: "jp", host: host),
           params: { challenge_id: "missing", credential: { id: "x" } }, as: :json
    end

    assert_response :too_many_requests
    assert_equal "900", response.headers["Retry-After"]
  end

  test "org passkey verification answers 429 with the sustained retry hint once the 15-minute allowance is spent" do
    host = ENV.fetch("PUBLIC_AUTH_STAFF_URL")
    host! host

    (SUSTAINED_ALLOWANCE / BURST_ALLOWANCE).times do |burst|
      travel((burst * 61).seconds) do
        BURST_ALLOWANCE.times do
          post auth_org_sign_in_passkey_verification_url(ri: "jp", host: host),
               params: { challenge_id: "missing", credential: { id: "x" } }, as: :json
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
  {
    "app" => [:auth_app_sign_in_challenge_passkey_url, "PUBLIC_AUTH_SERVICE_URL"],
    "com" => [:auth_com_sign_in_challenge_passkey_url, "PUBLIC_AUTH_CORPORATE_URL"],
    "org" => [:auth_org_sign_in_challenge_passkey_url, "PUBLIC_AUTH_STAFF_URL"],
  }.each do |surface, (helper, host_env)|
    test "#{surface} MFA passkey challenge answers 429 with the sustained hint once the 15-minute allowance is spent" do
      host = ENV.fetch(host_env)
      host! host

      (SUSTAINED_ALLOWANCE / BURST_ALLOWANCE).times do |burst|
        travel((burst * 61).seconds) do
          BURST_ALLOWANCE.times do
            post public_send(helper, ri: "jp", host: host), params: { challenge_id: "missing" }, as: :json
          end
        end
      end

      travel((SUSTAINED_ALLOWANCE / BURST_ALLOWANCE * 61).seconds) do
        post public_send(helper, ri: "jp", host: host), params: { challenge_id: "missing" }, as: :json
      end

      assert_response :too_many_requests
      assert_equal "900", response.headers["Retry-After"]
    end
  end

  # The per-account rule is the only one that bounds a distributed attacker, who
  # spreads the guesses across enough source addresses that neither IP rule fires.
  # It is stricter than the sustained IP rule, so it is what answers first.
  ACCOUNT_ALLOWANCE = 10

  test "app MFA TOTP challenge answers 429 once the per-account allowance is spent" do
    host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    host! host

    (ACCOUNT_ALLOWANCE / BURST_ALLOWANCE).times do |burst|
      travel((burst * 61).seconds) do
        BURST_ALLOWANCE.times do
          post auth_app_sign_in_challenge_totp_url(ri: "jp", host: host),
               params: { totp_challenge_form: { token: "000000" } }
        end
      end
    end

    travel((ACCOUNT_ALLOWANCE / BURST_ALLOWANCE * 61).seconds) do
      post auth_app_sign_in_challenge_totp_url(ri: "jp", host: host),
           params: { totp_challenge_form: { token: "000000" } }
    end

    assert_response :too_many_requests
    assert_equal "900", response.headers["Retry-After"]
  end

  test "org secret credential sign-in answers 429 once one identifier has spent its allowance" do
    host = ENV.fetch("PUBLIC_AUTH_STAFF_URL")
    host! host
    params = { secret_credential_login_form: { identifier: "0123456789ABCDEF", secret_credential_value: "x" } }

    (ACCOUNT_ALLOWANCE / BURST_ALLOWANCE).times do |burst|
      travel((burst * 61).seconds) do
        BURST_ALLOWANCE.times { post auth_org_sign_in_secret_url(ri: "jp", host: host), params: params }
      end
    end

    travel((ACCOUNT_ALLOWANCE / BURST_ALLOWANCE * 61).seconds) do
      post auth_org_sign_in_secret_url(ri: "jp", host: host), params: params
    end

    assert_response :too_many_requests
    assert_equal "900", response.headers["Retry-After"]
  end

  test "org secret credential sign-in answers 429 once one source has spent its allowance across identifiers" do
    host = ENV.fetch("PUBLIC_AUTH_STAFF_URL")
    host! host
    attempt = 0
    spend =
      lambda do
        attempt += 1
        post(
          auth_org_sign_in_secret_url(ri: "jp", host: host),
          params: {
            secret_credential_login_form: {
              identifier: format("%016d", attempt),
              secret_credential_value: "x",
            },
          },
        )
      end

    # A different identifier each time, so only the per-source rules accumulate.
    (SUSTAINED_ALLOWANCE / BURST_ALLOWANCE).times do |burst|
      travel((burst * 61).seconds) { BURST_ALLOWANCE.times { spend.call } }
    end

    travel((SUSTAINED_ALLOWANCE / BURST_ALLOWANCE * 61).seconds) { spend.call }

    assert_response :too_many_requests
    assert_equal "900", response.headers["Retry-After"]
  end

  # Submitting the sign-in code is a separate action from requesting it, and
  # carries its own limiter pair; only the request side was exercised.
  test "app email sign-in code submission answers 429 once the per-IP burst allowance is spent" do
    host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    host! host

    (BURST_ALLOWANCE + 1).times do
      patch auth_app_sign_in_email_url(ri: "jp", host: host), params: { client_email: { pass_code: "000000" } }
    end

    assert_response :too_many_requests
    assert_equal "60", response.headers["Retry-After"]
  end

  test "app email sign-in code submission answers 429 with the sustained hint once the 15-minute allowance is spent" do
    host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    host! host
    params = { client_email: { pass_code: "000000" } }

    (SUSTAINED_ALLOWANCE / BURST_ALLOWANCE).times do |burst|
      travel((burst * 61).seconds) do
        BURST_ALLOWANCE.times { patch auth_app_sign_in_email_url(ri: "jp", host: host), params: params }
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
    "com" => [:auth_com_sign_up_email_url, "PUBLIC_AUTH_CORPORATE_URL", :visitor_email],
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
