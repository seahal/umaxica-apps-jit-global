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
    host! ENV.fetch("PUBLIC_AUTH_SERVICE_URL", "auth.app.localhost")
    TurnstileVerifierStub.challenge_enabled = true
    TurnstileVerifierStub.challenge_response = { "success" => true }
    @user = clients(:one)
    ClientToken.where(user_id: @user.id).delete_all
    @email = @user.client_emails.create!(address: "root_#{SecureRandom.hex(4)}@example.com")
  end

  teardown do
    TurnstileVerifierStub.challenge_enabled = false
    TurnstileVerifierStub.challenge_response = nil
  end

  # Separate browser cookie jars exercise the actual Base issuance boundary.
  # rubocop:disable Minitest/MultipleAssertions
  test "a normal sign-in establishes exactly one root login with its anchor, cookie, and audit" do
    host! ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    destination = nil
    JumpRtIssuer.stub(:call, ->(**args) { destination = args.fetch(:url); "opaque-jump" }) do
      RedirectsJumpGatewayUrl.stub(
        :call, ->(_code) { RedirectsTargetResult.ok(kind: :external, source: :test, value: destination) },
      ) do
        post base_app_sign_show_path, params: { ri: "jp" }
      end
    end

    assert_response :see_other
    reference = Rack::Utils.parse_nested_query(URI.parse(destination).query).fetch("entry_ref")
    flow = ClientSignInFlow.find_by!(public_id: reference)
    auth_browser = open_session
    auth_browser.host!(ENV.fetch("PUBLIC_AUTH_SERVICE_URL"))
    auth_browser.get(auth_app_sign_in_path, params: { entry_ref: reference, ri: "jp" })
    csrf = Nokogiri::HTML(auth_browser.response.body).at_css('input[name="authenticity_token"]')["value"]
    auth_browser.post(
      auth_app_sign_in_path, params: { entry_ref: reference, authenticity_token: csrf, ri: "jp" },
    )
    auth_browser.post(
      auth_app_sign_in_email_path,
      params: { :user_email => { address: @email.address }, "cf-turnstile-response" => "t", :ri => "jp" },
    )
    secret = "JBSWY3DPEHPK3PXP"
    @email.reload.store_otp(secret, 7, 5.minutes.from_now.to_i)
    audit_count = ClientChronicle.where(subject_id: @user.id, event_id: ClientChronicleEvent::LOGGED_IN).count
    assert_no_difference(-> { ClientToken.where(user_id: @user.id).count }) do
      auth_browser.patch(
        auth_app_sign_in_email_path,
        params: { :user_email => { pass_code: ROTP::HOTP.new(secret).at(7).to_s },
                  "cf-turnstile-response" => "t",
                  :ri => "jp", },
      )
      auth_browser.follow_redirect!
      auth_browser.follow_redirect!
      auth_browser.post(auth_app_sign_handoff_path, params: { ri: "jp" })
    end

    assert_equal 200, auth_browser.response.status
    assert_nil auth_browser.cookies[AuthenticationBase::ACCESS_COOKIE_KEY]
    assert_nil auth_browser.cookies[AuthenticationBase::REFRESH_COOKIE_KEY]
    assert_equal audit_count,
                 ClientChronicle.where(subject_id: @user.id, event_id: ClientChronicleEvent::LOGGED_IN).count
    document = Nokogiri::HTML(auth_browser.response.body)
    result = document.at_css('input[name="result"]')["value"]
    assert_difference(-> { ClientToken.where(user_id: @user.id).count }, 1) do
      post base_app_sign_completion_path,
           params: { result: result, transaction_ref: flow.public_id, ri: "jp" },
           headers: { "Origin" => "https://#{ENV.fetch("PUBLIC_AUTH_SERVICE_URL")}", "Sec-Fetch-Site" => "same-site" }
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
    follow_redirect!

    assert_redirected_to base_app_selector_path(ri: "jp")
    follow_redirect!

    assert_redirected_to base_app_dashboard_path(ri: "jp")
    follow_redirect!

    assert_response :success
  end
  # rubocop:enable Minitest/MultipleAssertions

  test "credential change after Auth completion rejects the outstanding result at the Base root boundary" do
    host! ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    destination = nil
    JumpRtIssuer.stub(:call, ->(**args) { destination = args.fetch(:url); "opaque-jump" }) do
      RedirectsJumpGatewayUrl.stub(
        :call, ->(_code) { RedirectsTargetResult.ok(kind: :external, source: :test, value: destination) },
      ) do
        post base_app_sign_show_path, params: { ri: "jp" }
      end
    end
    reference = Rack::Utils.parse_nested_query(URI.parse(destination).query).fetch("entry_ref")
    flow = ClientSignInFlow.find_by!(public_id: reference)
    auth_browser = open_session
    auth_browser.host!(ENV.fetch("PUBLIC_AUTH_SERVICE_URL"))
    auth_browser.get(auth_app_sign_in_path, params: { entry_ref: reference, ri: "jp" })
    csrf = Nokogiri::HTML(auth_browser.response.body).at_css('input[name="authenticity_token"]')["value"]
    auth_browser.post(
      auth_app_sign_in_path, params: { entry_ref: reference, authenticity_token: csrf, ri: "jp" },
    )
    auth_browser.post(
      auth_app_sign_in_email_path,
      params: { :user_email => { address: @email.address }, "cf-turnstile-response" => "t", :ri => "jp" },
    )
    secret = "JBSWY3DPEHPK3PXP"
    @email.reload.store_otp(secret, 7, 5.minutes.from_now.to_i)
    auth_browser.patch(
      auth_app_sign_in_email_path,
      params: { :user_email => { pass_code: ROTP::HOTP.new(secret).at(7).to_s },
                "cf-turnstile-response" => "t",
                :ri => "jp", },
    )
    auth_browser.follow_redirect!
    auth_browser.follow_redirect!
    auth_browser.post(auth_app_sign_handoff_path, params: { ri: "jp" })

    assert_equal 200, auth_browser.response.status
    result = Nokogiri::HTML(auth_browser.response.body).at_css('input[name="result"]')["value"]
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
           params: { result: result, transaction_ref: flow.public_id, ri: "jp" },
           headers: { "Origin" => "https://#{ENV.fetch("PUBLIC_AUTH_SERVICE_URL")}", "Sec-Fetch-Site" => "same-site" }
    end

    # The existing policy rejects FAILED flows before the result committer runs.
    assert_redirected_to "/"
    assert_nil cookies[AuthenticationBase::ACCESS_COOKIE_KEY]
    assert_nil cookies[AuthenticationBase::REFRESH_COOKIE_KEY]
    assert_predicate flow.reload, :sign_in_failed?
    assert_nil flow.base_finalized_at
    assert_equal event, flow.authentication_event_at
    assert_equal generation, flow.result_generation
    assert_equal audit_count,
                 ClientChronicle.where(subject_id: @user.id, event_id: ClientChronicleEvent::LOGGED_IN).count
  end

  # rubocop:disable Minitest/MultipleAssertions
  test "at the session limit nothing is issued: no token, no cookie, no audit, and the flow waits" do
    existing = Array.new(ClientToken::MAX_SESSIONS_PER_USER) { ClientToken.create!(user: @user) }
    host! ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    destination = nil
    JumpRtIssuer.stub(:call, ->(**args) { destination = args.fetch(:url); "opaque-jump" }) do
      RedirectsJumpGatewayUrl.stub(
        :call, ->(_code) { RedirectsTargetResult.ok(kind: :external, source: :test, value: destination) },
      ) do
        post base_app_sign_show_path, params: { ri: "jp" }
      end
    end

    assert_response :see_other
    reference = Rack::Utils.parse_nested_query(URI.parse(destination).query).fetch("entry_ref")
    flow = ClientSignInFlow.find_by!(public_id: reference)
    auth_browser = open_session
    auth_browser.host!(ENV.fetch("PUBLIC_AUTH_SERVICE_URL"))
    auth_browser.get(auth_app_sign_in_path, params: { entry_ref: reference, ri: "jp" })
    csrf = Nokogiri::HTML(auth_browser.response.body).at_css('input[name="authenticity_token"]')["value"]
    auth_browser.post(
      auth_app_sign_in_path, params: { entry_ref: reference, authenticity_token: csrf, ri: "jp" },
    )
    auth_browser.post(
      auth_app_sign_in_email_path,
      params: { :user_email => { address: @email.address }, "cf-turnstile-response" => "t", :ri => "jp" },
    )
    secret = "JBSWY3DPEHPK3PXP"
    @email.reload.store_otp(secret, 7, 5.minutes.from_now.to_i)
    audit_count = ClientChronicle.where(subject_id: @user.id, event_id: ClientChronicleEvent::LOGGED_IN).count
    assert_no_difference(-> { ClientToken.where(user_id: @user.id).count }) do
      auth_browser.patch(
        auth_app_sign_in_email_path,
        params: { :user_email => { pass_code: ROTP::HOTP.new(secret).at(7).to_s },
                  "cf-turnstile-response" => "t",
                  :ri => "jp", },
      )
      auth_browser.follow_redirect!
      auth_browser.follow_redirect!
      auth_browser.post(auth_app_sign_handoff_path, params: { ri: "jp" })
    end

    assert_equal 200, auth_browser.response.status
    assert_nil auth_browser.cookies[AuthenticationBase::ACCESS_COOKIE_KEY]
    assert_nil auth_browser.cookies[AuthenticationBase::REFRESH_COOKIE_KEY]
    assert_equal audit_count,
                 ClientChronicle.where(subject_id: @user.id, event_id: ClientChronicleEvent::LOGGED_IN).count
    document = Nokogiri::HTML(auth_browser.response.body)
    result = document.at_css('input[name="result"]')["value"]
    assert_no_difference(-> { ClientToken.where(user_id: @user.id).count }) do
      post base_app_sign_completion_path,
           params: { result: result, transaction_ref: flow.public_id, ri: "jp" },
           headers: { "Origin" => "https://#{ENV.fetch("PUBLIC_AUTH_SERVICE_URL")}", "Sec-Fetch-Site" => "same-site" }
    end

    assert_redirected_to base_app_sign_in_limitation_path(ri: "jp")
    assert_nil cookies[AuthenticationBase::ACCESS_COOKIE_KEY]
    assert_nil cookies[AuthenticationBase::REFRESH_COOKIE_KEY]
    assert_predicate flow.reload, :sign_in_session_limit_pending?
    assert_nil flow.token_id
    assert_nil flow.base_finalized_at
    assert(existing.all? { |token| token.reload.active_status? })
    assert_equal audit_count,
                 ClientChronicle.where(subject_id: @user.id, event_id: ClientChronicleEvent::LOGGED_IN).count
    assert_equal 0, ClientToken.where(user_id: @user.id, user_token_status_id: ClientTokenStatus::RESTRICTED).count
    follow_redirect!

    assert_response :success
    props = JSON.parse(response.parsed_body.at_css('script[type="application/json"]').text).fetch("props")

    assert_equal ClientToken::MAX_SESSIONS_PER_USER, props.fetch("sessions").length
  end
  # rubocop:enable Minitest/MultipleAssertions

  # rubocop:disable Minitest/MultipleAssertions
  test "resolving the limit commits the waiting flow once; a repeated submit issues nothing more" do
    existing = Array.new(ClientToken::MAX_SESSIONS_PER_USER) { ClientToken.create!(user: @user) }
    host! ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    destination = nil
    JumpRtIssuer.stub(:call, ->(**args) { destination = args.fetch(:url); "opaque-jump" }) do
      RedirectsJumpGatewayUrl.stub(
        :call, ->(_code) { RedirectsTargetResult.ok(kind: :external, source: :test, value: destination) },
      ) do
        post base_app_sign_show_path, params: { ri: "jp" }
      end
    end

    assert_response :see_other
    reference = Rack::Utils.parse_nested_query(URI.parse(destination).query).fetch("entry_ref")
    flow = ClientSignInFlow.find_by!(public_id: reference)
    auth_browser = open_session
    auth_browser.host!(ENV.fetch("PUBLIC_AUTH_SERVICE_URL"))
    auth_browser.get(auth_app_sign_in_path, params: { entry_ref: reference, ri: "jp" })
    csrf = Nokogiri::HTML(auth_browser.response.body).at_css('input[name="authenticity_token"]')["value"]
    auth_browser.post(
      auth_app_sign_in_path, params: { entry_ref: reference, authenticity_token: csrf, ri: "jp" },
    )
    auth_browser.post(
      auth_app_sign_in_email_path,
      params: { :user_email => { address: @email.address }, "cf-turnstile-response" => "t", :ri => "jp" },
    )
    secret = "JBSWY3DPEHPK3PXP"
    @email.reload.store_otp(secret, 7, 5.minutes.from_now.to_i)
    audit_count = ClientChronicle.where(subject_id: @user.id, event_id: ClientChronicleEvent::LOGGED_IN).count
    assert_no_difference(-> { ClientToken.where(user_id: @user.id).count }) do
      auth_browser.patch(
        auth_app_sign_in_email_path,
        params: { :user_email => { pass_code: ROTP::HOTP.new(secret).at(7).to_s },
                  "cf-turnstile-response" => "t",
                  :ri => "jp", },
      )
      auth_browser.follow_redirect!
      auth_browser.follow_redirect!
      auth_browser.post(auth_app_sign_handoff_path, params: { ri: "jp" })
    end

    assert_equal 200, auth_browser.response.status
    assert_nil auth_browser.cookies[AuthenticationBase::ACCESS_COOKIE_KEY]
    assert_nil auth_browser.cookies[AuthenticationBase::REFRESH_COOKIE_KEY]
    assert_equal audit_count,
                 ClientChronicle.where(subject_id: @user.id, event_id: ClientChronicleEvent::LOGGED_IN).count
    document = Nokogiri::HTML(auth_browser.response.body)
    result = document.at_css('input[name="result"]')["value"]
    assert_no_difference(-> { ClientToken.where(user_id: @user.id).count }) do
      post base_app_sign_completion_path,
           params: { result: result, transaction_ref: flow.public_id, ri: "jp" },
           headers: { "Origin" => "https://#{ENV.fetch("PUBLIC_AUTH_SERVICE_URL")}", "Sec-Fetch-Site" => "same-site" }
    end

    assert_redirected_to base_app_sign_in_limitation_path(ri: "jp")
    event_at = flow.reload.authentication_event_at
    follow_redirect!
    props = JSON.parse(response.parsed_body.at_css('script[type="application/json"]').text).fetch("props")
    ref = props.fetch("sessions").first.fetch("session_ref")
    assert_difference(-> { ClientToken.where(user_id: @user.id).count }, 1) do
      patch base_app_sign_in_limitation_path, params: { ri: "jp", session_ref: ref }
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
    assert_no_difference(-> { ClientToken.where(user_id: @user.id).count }) do
      patch base_app_sign_in_limitation_path, params: { ri: "jp", session_ref: ref }
    end
    assert_equal audit_count + 1,
                 ClientChronicle.where(subject_id: @user.id, event_id: ClientChronicleEvent::LOGGED_IN).count
  end
  # rubocop:enable Minitest/MultipleAssertions

  # rubocop:disable Minitest/MultipleAssertions
  test "cancelling at the limit ends only the waiting flow and keeps every existing session" do
    existing = Array.new(ClientToken::MAX_SESSIONS_PER_USER) { ClientToken.create!(user: @user) }
    host! ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    destination = nil
    JumpRtIssuer.stub(:call, ->(**args) { destination = args.fetch(:url); "opaque-jump" }) do
      RedirectsJumpGatewayUrl.stub(
        :call, ->(_code) { RedirectsTargetResult.ok(kind: :external, source: :test, value: destination) },
      ) do
        post base_app_sign_show_path, params: { ri: "jp" }
      end
    end

    assert_response :see_other
    reference = Rack::Utils.parse_nested_query(URI.parse(destination).query).fetch("entry_ref")
    flow = ClientSignInFlow.find_by!(public_id: reference)
    auth_browser = open_session
    auth_browser.host!(ENV.fetch("PUBLIC_AUTH_SERVICE_URL"))
    auth_browser.get(auth_app_sign_in_path, params: { entry_ref: reference, ri: "jp" })
    csrf = Nokogiri::HTML(auth_browser.response.body).at_css('input[name="authenticity_token"]')["value"]
    auth_browser.post(
      auth_app_sign_in_path, params: { entry_ref: reference, authenticity_token: csrf, ri: "jp" },
    )
    auth_browser.post(
      auth_app_sign_in_email_path,
      params: { :user_email => { address: @email.address }, "cf-turnstile-response" => "t", :ri => "jp" },
    )
    secret = "JBSWY3DPEHPK3PXP"
    @email.reload.store_otp(secret, 7, 5.minutes.from_now.to_i)
    audit_count = ClientChronicle.where(subject_id: @user.id, event_id: ClientChronicleEvent::LOGGED_IN).count
    assert_no_difference(-> { ClientToken.where(user_id: @user.id).count }) do
      auth_browser.patch(
        auth_app_sign_in_email_path,
        params: { :user_email => { pass_code: ROTP::HOTP.new(secret).at(7).to_s },
                  "cf-turnstile-response" => "t",
                  :ri => "jp", },
      )
      auth_browser.follow_redirect!
      auth_browser.follow_redirect!
      auth_browser.post(auth_app_sign_handoff_path, params: { ri: "jp" })
    end

    assert_equal 200, auth_browser.response.status
    assert_nil auth_browser.cookies[AuthenticationBase::ACCESS_COOKIE_KEY]
    assert_nil auth_browser.cookies[AuthenticationBase::REFRESH_COOKIE_KEY]
    assert_equal audit_count,
                 ClientChronicle.where(subject_id: @user.id, event_id: ClientChronicleEvent::LOGGED_IN).count
    document = Nokogiri::HTML(auth_browser.response.body)
    result = document.at_css('input[name="result"]')["value"]
    assert_no_difference(-> { ClientToken.where(user_id: @user.id).count }) do
      post base_app_sign_completion_path,
           params: { result: result, transaction_ref: flow.public_id, ri: "jp" },
           headers: { "Origin" => "https://#{ENV.fetch("PUBLIC_AUTH_SERVICE_URL")}", "Sec-Fetch-Site" => "same-site" }
    end

    assert_redirected_to base_app_sign_in_limitation_path(ri: "jp")
    assert_no_difference(-> { ClientToken.where(user_id: @user.id).count }) do
      delete base_app_sign_in_limitation_path, params: { ri: "jp" }
    end

    assert_redirected_to base_app_sign_show_path(ri: "jp")
    assert_predicate flow.reload, :sign_in_failed?
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
           params: { result: result, transaction_ref: flow.public_id, ri: "jp" },
           headers: { "Origin" => "https://#{ENV.fetch("PUBLIC_AUTH_SERVICE_URL")}", "Sec-Fetch-Site" => "same-site" }
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
      ClientSignInFlow.stub(:database_now, -> { Time.current }) do
        ClientAuthCeremonySession.stub(:database_now, -> { Time.current }) do
          [0, 10, 29.999999, final_elapsed].each do |elapsed|
            travel_to(anchor + elapsed, with_usec: true)
            attempt_email =
              elapsed.zero? ? @email :
                           @user.client_emails.create!(address: "cooldown-#{SecureRandom.hex(4)}@example.com")
            host! ENV.fetch("PUBLIC_BASE_SERVICE_URL")
            destination = nil
            JumpRtIssuer.stub(:call, ->(**args) { destination = args.fetch(:url); "opaque-jump" }) do
              RedirectsJumpGatewayUrl.stub(
                :call, ->(_code) { RedirectsTargetResult.ok(kind: :external, source: :test, value: destination) },
              ) do
                post base_app_sign_show_path, params: { ri: "jp" }
              end
            end

            assert_response :see_other
            reference = Rack::Utils.parse_nested_query(URI.parse(destination).query).fetch("entry_ref")
            flow = ClientSignInFlow.find_by!(public_id: reference)
            auth_browser = open_session
            auth_browser.host!(ENV.fetch("PUBLIC_AUTH_SERVICE_URL"))
            auth_browser.get(auth_app_sign_in_path, params: { entry_ref: reference, ri: "jp" })
            csrf = Nokogiri::HTML(auth_browser.response.body).at_css('input[name="authenticity_token"]')["value"]
            auth_browser.post(
              auth_app_sign_in_path, params: { entry_ref: reference, authenticity_token: csrf, ri: "jp" },
            )
            auth_browser.post(
              auth_app_sign_in_email_path,
              params: { :user_email => { address: attempt_email.address },
                        "cf-turnstile-response" => "t",
                        :ri => "jp", },
            )
            secret = "JBSWY3DPEHPK3PXP"
            attempt_email.reload.store_otp(secret, 7, 5.minutes.from_now.to_i)
            audit_count = ClientChronicle.where(subject_id: @user.id, event_id: ClientChronicleEvent::LOGGED_IN).count
            assert_no_difference(-> { ClientToken.where(user_id: @user.id).count }) do
              auth_browser.patch(
                auth_app_sign_in_email_path,
                params: { :user_email => { pass_code: ROTP::HOTP.new(secret).at(7).to_s },
                          "cf-turnstile-response" => "t",
                          :ri => "jp", },
              )
              auth_browser.follow_redirect!
              auth_browser.follow_redirect!
              auth_browser.post(auth_app_sign_handoff_path, params: { ri: "jp" })
            end

            assert_equal 200, auth_browser.response.status
            assert_nil auth_browser.cookies[AuthenticationBase::ACCESS_COOKIE_KEY]
            assert_nil auth_browser.cookies[AuthenticationBase::REFRESH_COOKIE_KEY]
            assert_equal audit_count,
                         ClientChronicle.where(subject_id: @user.id, event_id: ClientChronicleEvent::LOGGED_IN).count
            document = Nokogiri::HTML(auth_browser.response.body)
            result = document.at_css('input[name="result"]')["value"]
            count_before = ClientToken.where(user_id: @user.id).count
            post base_app_sign_completion_path,
                 params: { result: result, transaction_ref: flow.public_id, ri: "jp" },
                 headers: { "Origin" => "https://#{ENV.fetch("PUBLIC_AUTH_SERVICE_URL")}",
                            "Sec-Fetch-Site" => "same-site", }
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

  test "a legacy RESTRICTED token does not authenticate even with a valid access token" do
    legacy = ClientToken.create!(user: @user, user_token_status_id: ClientTokenStatus::RESTRICTED)
    host! ENV.fetch("PUBLIC_BASE_SERVICE_URL")

    get base_app_root_url(ri: "jp"),
        headers: as_user_headers(@user, host: ENV.fetch("PUBLIC_BASE_SERVICE_URL"), session_public_id: legacy.public_id)

    assert_not_equal 200, response.status
  end
end
