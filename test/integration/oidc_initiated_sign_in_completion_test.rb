# typed: false
# frozen_string_literal: true

require "test_helper"

# A sign-in that began at the OIDC authorization endpoint carries a login
# challenge through the auth surface. The sign-in checkpoint is where the
# issued session is bound to the authorization transaction and the browser is
# handed back to the relying party, instead of landing on the ordinary
# post-sign-in destination.
class OidcInitiatedSignInCompletionTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  fixtures :clients, :client_statuses, :client_email_statuses,
           :client_telephone_statuses, :client_token_kinds, :client_token_statuses,
           :client_token_binding_methods, :client_token_dbsc_statuses

  setup do
    ClientSignOutFlowKind.ensure_defaults!
    ClientSignOutFlowStatus.ensure_defaults!
    ClientSessionLimitResolutionState::DEFAULTS.each do |id|
      ClientSessionLimitResolutionState.find_or_create_by!(id: id) do |state|
        state.created_at = Time.current
        state.updated_at = Time.current
      end
    end
    @previous_secret_proof_retention = ENV["APP_SECRET_PROOF_RETENTION_SECONDS"]
    ENV["APP_SECRET_PROOF_RETENTION_SECONDS"] = "1"
    @previous_secret_outbox_retention = ENV["APP_SECRET_OUTBOX_RETENTION_SECONDS"]
    ENV["APP_SECRET_OUTBOX_RETENTION_SECONDS"] = "3600"
    @previous_secret_purge_delay = ENV["APP_SECRET_PURGE_DELAY_SECONDS"]
    ENV["APP_SECRET_PURGE_DELAY_SECONDS"] = "86400"
    @host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    host! @host
    ClientIdentityState.ensure_defaults!
    @user = clients(:one)
    @address = "oidc_signin_#{SecureRandom.hex(4)}@example.com"
    @email_record = @user.client_emails.create!(address: @address, user_email_status_id: ClientEmailStatus::VERIFIED)
    @email_record.finalize_binding!
    @user.client_telephones.create!(number: "+819012345901")
    ClientToken.where(user_id: @user.id).delete_all
    TurnstileVerifierStub.challenge_enabled = true
    TurnstileVerifierStub.challenge_response = { "success" => true }
  end

  teardown do
    ENV["APP_SECRET_PROOF_RETENTION_SECONDS"] = @previous_secret_proof_retention
    ENV["APP_SECRET_OUTBOX_RETENTION_SECONDS"] = @previous_secret_outbox_retention
    ENV["APP_SECRET_PURGE_DELAY_SECONDS"] = @previous_secret_purge_delay
    TurnstileVerifierStub.challenge_enabled = false
    TurnstileVerifierStub.challenge_response = nil
  end

  test "the sign-in entry stores the authorization transaction in Auth continuity" do
    base_host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    parameters = oidc_authorize_params(realm: "client").merge(ri: "jp")
    @base_browser = open_session
    @base_browser.host!(base_host)
    @base_browser.https!
    @base_browser.get("/oauth/authorize", params: parameters)
    csrf = @base_browser.response.parsed_body.at_css('input[name="authenticity_token"]')["value"]
    base_headers = { "Origin" => "https://#{base_host}", "Sec-Fetch-Site" => "same-origin" }
    @base_browser.post(
      "/oauth/authorize", params: parameters.merge(ceremony_action: "start", authenticity_token: csrf),
                          headers: base_headers,
    )
    begin
      fv5147 = @base_browser
      fv5149 = JitSessionCookieConfig.cookie_key(force_secure: JitSessionCookieConfig.force_secure?)
      fv5148 = fv5147.response.cookies[fv5149]
      if fv5148.nil?
        fv5152 = fv5147.response.headers["Set-Cookie"] || fv5147.response.headers["set-cookie"]
        fv5151 =
          if fv5152.is_a?(String) && fv5152.start_with?("[")
            JSON.parse(fv5152)
          else
            Array(fv5152)
          end
        fv5150 =
          fv5151.flat_map { |entry| entry.to_s.split("\n") }.find do |entry|
            entry.split(";", 2).first.to_s.start_with?("#{fv5149}=")
          end
        if fv5150

          _, fv5148 = fv5150.split(";", 2).first.to_s.split("=", 2)
          fv5148 = Rack::Utils.unescape(fv5148.to_s)
        end
      end

      unless fv5148.nil?
        fv5147.cookies.delete(fv5149)
        # Rack::Test's []= uses its default host. The current request may target a
        # different surface, so install the cookie against the browser's active host.
        fv5147.cookies.merge(
          "#{fv5149}=#{Rack::Utils.escape(fv5148)}",
          URI.parse("https://#{fv5147.host}/"),
        )
      end
    end
    @transaction = ClientOidcAuthorizationTransaction.find_by!(state: parameters.fetch(:state))
    binding = ClientAuthAdmissionBinding.find_by!(authorization_transaction_id: @transaction.id)
    host!(@host)
    auth_headers = { "Origin" => "https://#{@host}", "Sec-Fetch-Site" => "same-origin" }
    get("/sign/in", params: { entry_ref: binding.entry_ref, ri: "jp" })
    csrf = response.parsed_body.at_css('input[name="authenticity_token"]')["value"]
    post(
      "/ceremony_bindings", params: { entry_ref: binding.entry_ref, ri: "jp", authenticity_token: csrf },
                            headers: auth_headers,
    )
    confirmation = URI.parse(response.location)
    @base_browser.get(confirmation.request_uri)
    csrf = @base_browser.response.parsed_body.at_css('input[name="authenticity_token"]')["value"]
    @base_browser.post(confirmation.request_uri, params: { authenticity_token: csrf }, headers: base_headers)
    begin
      fv5141 = @base_browser
      fv5143 = JitSessionCookieConfig.cookie_key(force_secure: JitSessionCookieConfig.force_secure?)
      fv5142 = fv5141.response.cookies[fv5143]
      if fv5142.nil?
        fv5146 = fv5141.response.headers["Set-Cookie"] || fv5141.response.headers["set-cookie"]
        fv5145 =
          if fv5146.is_a?(String) && fv5146.start_with?("[")
            JSON.parse(fv5146)
          else
            Array(fv5146)
          end
        fv5144 =
          fv5145.flat_map { |entry| entry.to_s.split("\n") }.find do |entry|
            entry.split(";", 2).first.to_s.start_with?("#{fv5143}=")
          end
        if fv5144

          _, fv5142 = fv5144.split(";", 2).first.to_s.split("=", 2)
          fv5142 = Rack::Utils.unescape(fv5142.to_s)
        end
      end

      unless fv5142.nil?
        fv5141.cookies.delete(fv5143)
        # Rack::Test's []= uses its default host. The current request may target a
        # different surface, so install the cookie against the browser's active host.
        fv5141.cookies.merge(
          "#{fv5143}=#{Rack::Utils.escape(fv5142)}",
          URI.parse("https://#{fv5141.host}/"),
        )
      end
    end
    entry = URI.parse(@base_browser.response.location)
    host!(@host)
    get(entry.request_uri)
    csrf = response.parsed_body.at_css('input[name="authenticity_token"]')["value"]
    post(
      "/sign/in", params: { entry_ref: binding.entry_ref, ri: "jp", authenticity_token: csrf }, headers: auth_headers,
    )

    assert_response :see_other
    follow_redirect!

    assert_response :success
    record = ClientAuthCeremonySession.order(created_at: :desc).first

    assert_predicate record, :admitted?
    assert_equal @transaction.transaction_id, record.authorization_transaction_ref
    assert_nil session[:oidc_authorization_login_challenge]
    assert_nil session[:oidc_authorization_intent]
  end

  test "the primary factor sends the ceremony to the sign-in checkpoint" do
    base_host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    parameters = oidc_authorize_params(realm: "client").merge(ri: "jp")
    @base_browser = open_session
    @base_browser.host!(base_host)
    @base_browser.https!
    @base_browser.get("/oauth/authorize", params: parameters)
    csrf = @base_browser.response.parsed_body.at_css('input[name="authenticity_token"]')["value"]
    base_headers = { "Origin" => "https://#{base_host}", "Sec-Fetch-Site" => "same-origin" }
    @base_browser.post(
      "/oauth/authorize", params: parameters.merge(ceremony_action: "start", authenticity_token: csrf),
                          headers: base_headers,
    )
    begin
      fv5135 = @base_browser
      fv5137 = JitSessionCookieConfig.cookie_key(force_secure: JitSessionCookieConfig.force_secure?)
      fv5136 = fv5135.response.cookies[fv5137]
      if fv5136.nil?
        fv5140 = fv5135.response.headers["Set-Cookie"] || fv5135.response.headers["set-cookie"]
        fv5139 =
          if fv5140.is_a?(String) && fv5140.start_with?("[")
            JSON.parse(fv5140)
          else
            Array(fv5140)
          end
        fv5138 =
          fv5139.flat_map { |entry| entry.to_s.split("\n") }.find do |entry|
            entry.split(";", 2).first.to_s.start_with?("#{fv5137}=")
          end
        if fv5138

          _, fv5136 = fv5138.split(";", 2).first.to_s.split("=", 2)
          fv5136 = Rack::Utils.unescape(fv5136.to_s)
        end
      end

      unless fv5136.nil?
        fv5135.cookies.delete(fv5137)
        # Rack::Test's []= uses its default host. The current request may target a
        # different surface, so install the cookie against the browser's active host.
        fv5135.cookies.merge(
          "#{fv5137}=#{Rack::Utils.escape(fv5136)}",
          URI.parse("https://#{fv5135.host}/"),
        )
      end
    end
    @transaction = ClientOidcAuthorizationTransaction.find_by!(state: parameters.fetch(:state))
    binding = ClientAuthAdmissionBinding.find_by!(authorization_transaction_id: @transaction.id)
    host!(@host)
    auth_headers = { "Origin" => "https://#{@host}", "Sec-Fetch-Site" => "same-origin" }
    get("/sign/in", params: { entry_ref: binding.entry_ref, ri: "jp" })
    csrf = response.parsed_body.at_css('input[name="authenticity_token"]')["value"]
    post(
      "/ceremony_bindings", params: { entry_ref: binding.entry_ref, ri: "jp", authenticity_token: csrf },
                            headers: auth_headers,
    )
    confirmation = URI.parse(response.location)
    @base_browser.get(confirmation.request_uri)
    csrf = @base_browser.response.parsed_body.at_css('input[name="authenticity_token"]')["value"]
    @base_browser.post(confirmation.request_uri, params: { authenticity_token: csrf }, headers: base_headers)
    begin
      fv5129 = @base_browser
      fv5131 = JitSessionCookieConfig.cookie_key(force_secure: JitSessionCookieConfig.force_secure?)
      fv5130 = fv5129.response.cookies[fv5131]
      if fv5130.nil?
        fv5134 = fv5129.response.headers["Set-Cookie"] || fv5129.response.headers["set-cookie"]
        fv5133 =
          if fv5134.is_a?(String) && fv5134.start_with?("[")
            JSON.parse(fv5134)
          else
            Array(fv5134)
          end
        fv5132 =
          fv5133.flat_map { |entry| entry.to_s.split("\n") }.find do |entry|
            entry.split(";", 2).first.to_s.start_with?("#{fv5131}=")
          end
        if fv5132

          _, fv5130 = fv5132.split(";", 2).first.to_s.split("=", 2)
          fv5130 = Rack::Utils.unescape(fv5130.to_s)
        end
      end

      unless fv5130.nil?
        fv5129.cookies.delete(fv5131)
        # Rack::Test's []= uses its default host. The current request may target a
        # different surface, so install the cookie against the browser's active host.
        fv5129.cookies.merge(
          "#{fv5131}=#{Rack::Utils.escape(fv5130)}",
          URI.parse("https://#{fv5129.host}/"),
        )
      end
    end
    entry = URI.parse(@base_browser.response.location)
    host!(@host)
    get(entry.request_uri)
    csrf = response.parsed_body.at_css('input[name="authenticity_token"]')["value"]
    post(
      "/sign/in", params: { entry_ref: binding.entry_ref, ri: "jp", authenticity_token: csrf }, headers: auth_headers,
    )

    assert_response :see_other
    follow_redirect!

    token_count = ClientToken.where(user_id: @user.id).count
    submit_email_otp!

    assert_response :redirect
    assert_equal URI.parse(auth_app_sign_in_check_path(ri: "jp")).path, URI.parse(response.location).path
    assert_equal token_count, ClientToken.where(user_id: @user.id).count

    ceremony = ClientAuthCeremonySession.order(created_at: :desc).first

    assert_equal "email", ceremony.authentication_method
    assert_predicate ceremony.authentication_event_at, :present?
  end

  test "saved Secret records OIDC authentication evidence without issuing an Auth session" do
    ENV["APP_SECRET_PURGE_DELAY_SECONDS"] = "1"
    credential = client_secret_credentials(:one)

    assert_equal credential.id, ClientSecretLookupQuery.call(client: @user, secret: "a" * 32).id
    base_host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    parameters = oidc_authorize_params(realm: "client").merge(ri: "jp")
    @base_browser = open_session
    @base_browser.host!(base_host)
    @base_browser.https!
    @base_browser.get("/oauth/authorize", params: parameters)
    csrf = @base_browser.response.parsed_body.at_css('input[name="authenticity_token"]')["value"]
    base_headers = { "Origin" => "https://#{base_host}", "Sec-Fetch-Site" => "same-origin" }
    @base_browser.post(
      "/oauth/authorize", params: parameters.merge(ceremony_action: "start", authenticity_token: csrf),
                          headers: base_headers,
    )
    begin
      fv5123 = @base_browser
      fv5125 = JitSessionCookieConfig.cookie_key(force_secure: JitSessionCookieConfig.force_secure?)
      fv5124 = fv5123.response.cookies[fv5125]
      if fv5124.nil?
        fv5128 = fv5123.response.headers["Set-Cookie"] || fv5123.response.headers["set-cookie"]
        fv5127 =
          if fv5128.is_a?(String) && fv5128.start_with?("[")
            JSON.parse(fv5128)
          else
            Array(fv5128)
          end
        fv5126 =
          fv5127.flat_map { |entry| entry.to_s.split("\n") }.find do |entry|
            entry.split(";", 2).first.to_s.start_with?("#{fv5125}=")
          end
        if fv5126

          _, fv5124 = fv5126.split(";", 2).first.to_s.split("=", 2)
          fv5124 = Rack::Utils.unescape(fv5124.to_s)
        end
      end

      unless fv5124.nil?
        fv5123.cookies.delete(fv5125)
        # Rack::Test's []= uses its default host. The current request may target a
        # different surface, so install the cookie against the browser's active host.
        fv5123.cookies.merge(
          "#{fv5125}=#{Rack::Utils.escape(fv5124)}",
          URI.parse("https://#{fv5123.host}/"),
        )
      end
    end
    @transaction = ClientOidcAuthorizationTransaction.find_by!(state: parameters.fetch(:state))
    binding = ClientAuthAdmissionBinding.find_by!(authorization_transaction_id: @transaction.id)
    host!(@host)
    auth_headers = { "Origin" => "https://#{@host}", "Sec-Fetch-Site" => "same-origin" }
    get("/sign/in", params: { entry_ref: binding.entry_ref, ri: "jp" })
    csrf = response.parsed_body.at_css('input[name="authenticity_token"]')["value"]
    post(
      "/ceremony_bindings", params: { entry_ref: binding.entry_ref, ri: "jp", authenticity_token: csrf },
                            headers: auth_headers,
    )
    confirmation = URI.parse(response.location)
    @base_browser.get(confirmation.request_uri)
    csrf = @base_browser.response.parsed_body.at_css('input[name="authenticity_token"]')["value"]
    @base_browser.post(confirmation.request_uri, params: { authenticity_token: csrf }, headers: base_headers)
    begin
      fv5117 = @base_browser
      fv5119 = JitSessionCookieConfig.cookie_key(force_secure: JitSessionCookieConfig.force_secure?)
      fv5118 = fv5117.response.cookies[fv5119]
      if fv5118.nil?
        fv5122 = fv5117.response.headers["Set-Cookie"] || fv5117.response.headers["set-cookie"]
        fv5121 =
          if fv5122.is_a?(String) && fv5122.start_with?("[")
            JSON.parse(fv5122)
          else
            Array(fv5122)
          end
        fv5120 =
          fv5121.flat_map { |entry| entry.to_s.split("\n") }.find do |entry|
            entry.split(";", 2).first.to_s.start_with?("#{fv5119}=")
          end
        if fv5120

          _, fv5118 = fv5120.split(";", 2).first.to_s.split("=", 2)
          fv5118 = Rack::Utils.unescape(fv5118.to_s)
        end
      end

      unless fv5118.nil?
        fv5117.cookies.delete(fv5119)
        # Rack::Test's []= uses its default host. The current request may target a
        # different surface, so install the cookie against the browser's active host.
        fv5117.cookies.merge(
          "#{fv5119}=#{Rack::Utils.escape(fv5118)}",
          URI.parse("https://#{fv5117.host}/"),
        )
      end
    end
    entry = URI.parse(@base_browser.response.location)
    host!(@host)
    get(entry.request_uri)
    csrf = response.parsed_body.at_css('input[name="authenticity_token"]')["value"]
    post(
      "/sign/in", params: { entry_ref: binding.entry_ref, ri: "jp", authenticity_token: csrf }, headers: auth_headers,
    )

    assert_response :see_other
    follow_redirect!
    deadline = ClientOidcAuthorizationTransaction.database_now + 10.seconds
    @transaction.update!(expires_at: deadline, login_challenge_expires_at: deadline)

    assert_response :success
    get new_auth_app_sign_in_secret_path(ri: "jp")

    assert_response :success
    assert_no_difference("ClientToken.count") do
      post auth_app_sign_in_secret_path(ri: "jp"), params: {
        identifier: @email_record.address, secret: "a" * 32, "cf-turnstile-response": "test_token",
      }
    end
    assert_response :see_other
    assert credential.reload.claimed_at
    ceremony = ClientAuthCeremonySession.find(credential.claim_ceremony_session_id)

    assert_equal ["secret", nil, nil],
                 [ceremony.authentication_method, credential.consumed_at,
                  ClientSecretLookupQuery.call(client: @user, secret: "a" * 32),]
    follow_redirect_to_oidc_handoff!
    post_oidc_handoff!

    assert_response :success
    flow = @transaction.reload.secret_sign_in_flow

    assert_equal ["passcode", "secret", @user.public_id, nil, nil, "SELECTOR_PENDING"],
                 [@transaction.auth_method, flow.authentication_method, @transaction.actor_ref,
                  flow.session_issued_at, flow.token_id, flow.state_name_for(flow.state_id),]
    assert_equal [true, nil, nil, "authentication_handoff"],
                 [ceremony.reload.completed?, ceremony.revoked_at, ceremony.cancelled_at, ceremony.admission_purpose]
    assert_equal ["normal", @user.id, @transaction.transaction_id],
                 [flow.authentication_context, flow.principal_id, ceremony.authorization_transaction_ref]
    action = @oidc_result_action
    assert_difference("ClientToken.count", 1) do
      begin
        fv5116 = action
        post(
          fv5116, params: {
            result_ref: @oidc_result_ref,
            transaction_ref: @oidc_result_transaction_ref,
          }, headers: {
            "Origin" => OidcIssuer.absolute_url(ENV.fetch("PUBLIC_BASE_SERVICE_URL")),
            "Sec-Fetch-Site" => "same-origin",
          },
        )
      end

      assert_response :redirect, response.body
    end
    assert credential.reload.consumed_at
    assert_equal @transaction.secret_sign_in_flow.reload.token.public_id,
                 ClientSecretSignInReceipt.find_by!(operation_id: credential.claim_operation_id).root_token_ref
    root_token_ref = @transaction.reload.browser_session_ref
    consumed_at = credential.consumed_at
    assert_no_difference ["ClientToken.count", "ClientSecretSignInReceipt.count"] do
      begin
        fv5115 = action
        post(
          fv5115, params: {
            result_ref: @oidc_result_ref,
            transaction_ref: @oidc_result_transaction_ref,
          }, headers: {
            "Origin" => OidcIssuer.absolute_url(ENV.fetch("PUBLIC_BASE_SERVICE_URL")),
            "Sec-Fetch-Site" => "same-origin",
          },
        )
      end
    end
    assert_response :redirect
    assert_equal [root_token_ref, consumed_at], [@transaction.reload.browser_session_ref, credential.reload.consumed_at]
    ChronicleRetentionPolicy.find_by(code: "security") ||
      ChronicleRetentionPolicy.create!(code: "security", name: "Security", duration_days: 365, permanent: false)
    # Wait for the explicit one-second retention deadline, not a concurrency ordering.
    Timeout.timeout(3) do
      sleep 0.01 while Client.database_now < credential.purge_eligible_at
    end
    ClientSecretLifecycleJob.perform_now(batch_size: 500)

    assert_equal [false, true],
                 [ClientSecretCredential.exists?(credential.id),
                  ClientSecretSignInReceipt.exists?(operation_id: credential.claim_operation_id),]
    OidcAuthorizationTransactionPurger.call(
      now: begin
        fv5114 = @transaction
        fv5113 = ClientAuthAdmissionBinding.where(authorization_transaction_id: fv5114.id)
        fv5112 = fv5113.pluck(
          :auth_ceremony_session_id,
          :admitted_auth_ceremony_session_id,
        ).flatten.compact
        fv5111 = [fv5114.expires_at,
                  fv5114.login_challenge_expires_at,] + fv5113.pluck(:expires_at)
        fv5111.concat(
          ClientAuthCeremonySession.where(id: fv5112).pluck(
            :expires_at, :completed_at, :cancelled_at, :revoked_at,
          ).flatten.compact,
        )
        fv5111.max + OidcAuthorizationTransactionable::RETENTION_PERIOD + 1.second
      end,
    )

    assert_equal [true, ClientTokenStatus::ACTIVE],
                 [ClientOidcAuthorizationTransaction.exists?(@transaction.id),
                  @transaction.secret_sign_in_flow.token.reload.user_token_status_id,],
                 "a surviving successful receipt retains its authorization proof and active root"
    assert_equal :pending, ClientSecretSignInReceiptPurger.call!(
      receipt: ClientSecretSignInReceipt.find_by!(operation_id: credential.claim_operation_id),
      retention_after: 1.second,
    )
    flow = @transaction.secret_sign_in_flow
    # Shortening the persisted parent deadline bounds the real continuation without extending its binding.
    deadline = [flow.expires_at, @transaction.expires_at, @transaction.login_challenge_expires_at].max + 1.second
    Timeout.timeout(15) do
      sleep 0.01 while ClientSignInFlow.database_now < deadline
    end
    receipt = ClientSecretSignInReceipt.find_by!(operation_id: credential.claim_operation_id)
    hold = ClientRetentionHold.create!(client: credential.client, hold_kind: "legal_hold", reason_code: "legal_hold")

    assert_equal :held, ClientSecretSignInReceiptPurger.call!(receipt: receipt, retention_after: 1.second)
    assert ClientSecretSignInReceipt.exists?(receipt.id)
    hold.update!(status_id: ClientRetentionHoldStatus::RELEASED)

    assert_equal :undelivered, ClientSecretSignInReceiptPurger.call!(receipt: receipt, retention_after: 1.second)
    assert ClientSecretSignInReceipt.exists?(receipt.id)
    ClientSecretAuditDeliveryJob.perform_now(batch_size: 500, retention_seconds: 3600)
    ClientSecretSignInReceipt.transaction do
      assert_equal :purged, ClientSecretSignInReceiptPurger.call!(receipt: receipt, retention_after: 1.second)
      assert_not ClientSecretSignInReceipt.exists?(receipt.id)
      raise ActiveRecord::Rollback
    end

    assert ClientSecretSignInReceipt.exists?(receipt.id)

    ClientSecretLifecycleJob.perform_now(batch_size: 500)

    assert_equal [false, ClientTokenStatus::ACTIVE],
                 [ClientSecretSignInReceipt.exists?(receipt.id), flow.token.reload.user_token_status_id]
  end

  test "expired OIDC Secret flow rejects a delayed result without releasing its claim" do
    credential = client_secret_credentials(:one)
    base_host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    parameters = oidc_authorize_params(realm: "client").merge(ri: "jp")
    @base_browser = open_session
    @base_browser.host!(base_host)
    @base_browser.https!
    @base_browser.get("/oauth/authorize", params: parameters)
    csrf = @base_browser.response.parsed_body.at_css('input[name="authenticity_token"]')["value"]
    base_headers = { "Origin" => "https://#{base_host}", "Sec-Fetch-Site" => "same-origin" }
    @base_browser.post(
      "/oauth/authorize", params: parameters.merge(ceremony_action: "start", authenticity_token: csrf),
                          headers: base_headers,
    )
    begin
      fv5105 = @base_browser
      fv5107 = JitSessionCookieConfig.cookie_key(force_secure: JitSessionCookieConfig.force_secure?)
      fv5106 = fv5105.response.cookies[fv5107]
      if fv5106.nil?
        fv5110 = fv5105.response.headers["Set-Cookie"] || fv5105.response.headers["set-cookie"]
        fv5109 =
          if fv5110.is_a?(String) && fv5110.start_with?("[")
            JSON.parse(fv5110)
          else
            Array(fv5110)
          end
        fv5108 =
          fv5109.flat_map { |entry| entry.to_s.split("\n") }.find do |entry|
            entry.split(";", 2).first.to_s.start_with?("#{fv5107}=")
          end
        if fv5108

          _, fv5106 = fv5108.split(";", 2).first.to_s.split("=", 2)
          fv5106 = Rack::Utils.unescape(fv5106.to_s)
        end
      end

      unless fv5106.nil?
        fv5105.cookies.delete(fv5107)
        # Rack::Test's []= uses its default host. The current request may target a
        # different surface, so install the cookie against the browser's active host.
        fv5105.cookies.merge(
          "#{fv5107}=#{Rack::Utils.escape(fv5106)}",
          URI.parse("https://#{fv5105.host}/"),
        )
      end
    end
    @transaction = ClientOidcAuthorizationTransaction.find_by!(state: parameters.fetch(:state))
    binding = ClientAuthAdmissionBinding.find_by!(authorization_transaction_id: @transaction.id)
    host!(@host)
    auth_headers = { "Origin" => "https://#{@host}", "Sec-Fetch-Site" => "same-origin" }
    get("/sign/in", params: { entry_ref: binding.entry_ref, ri: "jp" })
    csrf = response.parsed_body.at_css('input[name="authenticity_token"]')["value"]
    post(
      "/ceremony_bindings", params: { entry_ref: binding.entry_ref, ri: "jp", authenticity_token: csrf },
                            headers: auth_headers,
    )
    confirmation = URI.parse(response.location)
    @base_browser.get(confirmation.request_uri)
    csrf = @base_browser.response.parsed_body.at_css('input[name="authenticity_token"]')["value"]
    @base_browser.post(confirmation.request_uri, params: { authenticity_token: csrf }, headers: base_headers)
    begin
      fv5099 = @base_browser
      fv5101 = JitSessionCookieConfig.cookie_key(force_secure: JitSessionCookieConfig.force_secure?)
      fv5100 = fv5099.response.cookies[fv5101]
      if fv5100.nil?
        fv5104 = fv5099.response.headers["Set-Cookie"] || fv5099.response.headers["set-cookie"]
        fv5103 =
          if fv5104.is_a?(String) && fv5104.start_with?("[")
            JSON.parse(fv5104)
          else
            Array(fv5104)
          end
        fv5102 =
          fv5103.flat_map { |entry| entry.to_s.split("\n") }.find do |entry|
            entry.split(";", 2).first.to_s.start_with?("#{fv5101}=")
          end
        if fv5102

          _, fv5100 = fv5102.split(";", 2).first.to_s.split("=", 2)
          fv5100 = Rack::Utils.unescape(fv5100.to_s)
        end
      end

      unless fv5100.nil?
        fv5099.cookies.delete(fv5101)
        # Rack::Test's []= uses its default host. The current request may target a
        # different surface, so install the cookie against the browser's active host.
        fv5099.cookies.merge(
          "#{fv5101}=#{Rack::Utils.escape(fv5100)}",
          URI.parse("https://#{fv5099.host}/"),
        )
      end
    end
    entry = URI.parse(@base_browser.response.location)
    host!(@host)
    get(entry.request_uri)
    csrf = response.parsed_body.at_css('input[name="authenticity_token"]')["value"]
    post(
      "/sign/in", params: { entry_ref: binding.entry_ref, ri: "jp", authenticity_token: csrf }, headers: auth_headers,
    )

    assert_response :see_other
    follow_redirect!
    post auth_app_sign_in_secret_path(ri: "jp"), params: {
      identifier: @email_record.address, secret: "a" * 32, "cf-turnstile-response": "test_token",
    }

    assert_response :see_other
    follow_redirect_to_oidc_handoff!
    post_oidc_handoff!

    assert_response :success
    action = @oidc_result_action
    flow = @transaction.reload.secret_sign_in_flow
    flow.update!(expires_at: ClientSignInFlow.database_now)
    operation_id = credential.reload.claim_operation_id

    assert_no_difference ["ClientToken.count", "ClientSecretSignInReceipt.count"] do
      begin
        fv5098 = action
        post(
          fv5098, params: {
            result_ref: @oidc_result_ref,
            transaction_ref: @oidc_result_transaction_ref,
          }, headers: {
            "Origin" => OidcIssuer.absolute_url(ENV.fetch("PUBLIC_BASE_SERVICE_URL")),
            "Sec-Fetch-Site" => "same-origin",
          },
        )
      end
    end
    assert_response :bad_request
    assert_equal operation_id, credential.reload.claim_operation_id
    assert credential.claimed_at
    assert_nil credential.consumed_at
    assert_nil ClientSecretLookupQuery.call(client: @user, secret: "a" * 32)
    assert_nil flow.reload.token_id
    OidcAuthorizationTransactionPurger.call(
      now: @transaction.expires_at + OidcAuthorizationTransactionable::RETENTION_PERIOD + 1.second,
    )

    assert ClientOidcAuthorizationTransaction.exists?(@transaction.id),
           "a claimed Secret still needs its durable OIDC terminal proof"
    assert_equal :abandoned, ClientSecretClaimFinalizer.call!(credential: credential, purge_after: 0.000001.seconds)
    assert_predicate flow.reload, :sign_in_expired?
    assert_operator credential.reload.discard_at, :<=, Client.database_now
    assert_nil credential.consumed_at
    assert_equal operation_id, credential.claim_operation_id
    assert_no_difference ["ClientToken.count", "ClientSecretSignInReceipt.count"] do
      begin
        fv5097 = action
        post(
          fv5097, params: {
            result_ref: @oidc_result_ref,
            transaction_ref: @oidc_result_transaction_ref,
          }, headers: {
            "Origin" => OidcIssuer.absolute_url(ENV.fetch("PUBLIC_BASE_SERVICE_URL")),
            "Sec-Fetch-Site" => "same-origin",
          },
        )
      end
    end
    assert_response :bad_request
    ChronicleRetentionPolicy.find_by(code: "security") ||
      ChronicleRetentionPolicy.create!(code: "security", name: "Security", duration_days: 365, permanent: false)
    reference = credential.public_id

    assert_equal :undelivered,
                 ClientSecretCredentialPurger.call!(credential: credential, executor_job_id: "oidc-before-delivery")
    ClientSecretLifecycleJob.perform_now(batch_size: 500)

    assert_not ClientSecretCredential.exists?(credential.id)
    terminal = ClientSecretAuditOutbox.find_by!(credential_ref: reference, event_name: "secret.discarded")

    assert_equal "flow_expired", terminal.reason
    assert Chronicle.exists?(event_uuid: terminal.event_id)
    purged = ClientSecretAuditOutbox.find_by!(credential_ref: reference, event_name: "secret.purged")

    assert_nil purged.delivered_at
    ClientSecretAuditDeliveryJob.perform_now(batch_size: 500, retention_seconds: 3600)

    assert Chronicle.exists?(event_uuid: purged.event_id)
    assert_no_difference "Chronicle.count" do
      ClientSecretAuditDeliveryJob.perform_now(batch_size: 500, retention_seconds: 3600)
    end
    OidcAuthorizationTransactionPurger.call(
      now: begin
        fv5096 = @transaction
        fv5095 = ClientAuthAdmissionBinding.where(authorization_transaction_id: fv5096.id)
        fv5094 = fv5095.pluck(
          :auth_ceremony_session_id,
          :admitted_auth_ceremony_session_id,
        ).flatten.compact
        fv5093 = [fv5096.expires_at,
                  fv5096.login_challenge_expires_at,] + fv5095.pluck(:expires_at)
        fv5093.concat(
          ClientAuthCeremonySession.where(id: fv5094).pluck(
            :expires_at, :completed_at, :cancelled_at, :revoked_at,
          ).flatten.compact,
        )
        fv5093.max + OidcAuthorizationTransactionable::RETENTION_PERIOD + 1.second
      end,
    )

    assert_not ClientOidcAuthorizationTransaction.exists?(@transaction.id),
               "reconciled expired authorization no longer has a claim or receipt dependency"
    assert Chronicle.exists?(event_uuid: terminal.event_id)
    assert Chronicle.exists?(event_uuid: purged.event_id)
  end

  test "terminally failed OIDC Secret flow rejects delayed result before its deadline" do
    credential = client_secret_credentials(:one)
    base_host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    parameters = oidc_authorize_params(realm: "client").merge(ri: "jp")
    @base_browser = open_session
    @base_browser.host!(base_host)
    @base_browser.https!
    @base_browser.get("/oauth/authorize", params: parameters)
    csrf = @base_browser.response.parsed_body.at_css('input[name="authenticity_token"]')["value"]
    base_headers = { "Origin" => "https://#{base_host}", "Sec-Fetch-Site" => "same-origin" }
    @base_browser.post(
      "/oauth/authorize", params: parameters.merge(ceremony_action: "start", authenticity_token: csrf),
                          headers: base_headers,
    )
    begin
      fv5087 = @base_browser
      fv5089 = JitSessionCookieConfig.cookie_key(force_secure: JitSessionCookieConfig.force_secure?)
      fv5088 = fv5087.response.cookies[fv5089]
      if fv5088.nil?
        fv5092 = fv5087.response.headers["Set-Cookie"] || fv5087.response.headers["set-cookie"]
        fv5091 =
          if fv5092.is_a?(String) && fv5092.start_with?("[")
            JSON.parse(fv5092)
          else
            Array(fv5092)
          end
        fv5090 =
          fv5091.flat_map { |entry| entry.to_s.split("\n") }.find do |entry|
            entry.split(";", 2).first.to_s.start_with?("#{fv5089}=")
          end
        if fv5090

          _, fv5088 = fv5090.split(";", 2).first.to_s.split("=", 2)
          fv5088 = Rack::Utils.unescape(fv5088.to_s)
        end
      end

      unless fv5088.nil?
        fv5087.cookies.delete(fv5089)
        # Rack::Test's []= uses its default host. The current request may target a
        # different surface, so install the cookie against the browser's active host.
        fv5087.cookies.merge(
          "#{fv5089}=#{Rack::Utils.escape(fv5088)}",
          URI.parse("https://#{fv5087.host}/"),
        )
      end
    end
    @transaction = ClientOidcAuthorizationTransaction.find_by!(state: parameters.fetch(:state))
    binding = ClientAuthAdmissionBinding.find_by!(authorization_transaction_id: @transaction.id)
    host!(@host)
    auth_headers = { "Origin" => "https://#{@host}", "Sec-Fetch-Site" => "same-origin" }
    get("/sign/in", params: { entry_ref: binding.entry_ref, ri: "jp" })
    csrf = response.parsed_body.at_css('input[name="authenticity_token"]')["value"]
    post(
      "/ceremony_bindings", params: { entry_ref: binding.entry_ref, ri: "jp", authenticity_token: csrf },
                            headers: auth_headers,
    )
    confirmation = URI.parse(response.location)
    @base_browser.get(confirmation.request_uri)
    csrf = @base_browser.response.parsed_body.at_css('input[name="authenticity_token"]')["value"]
    @base_browser.post(confirmation.request_uri, params: { authenticity_token: csrf }, headers: base_headers)
    begin
      fv5081 = @base_browser
      fv5083 = JitSessionCookieConfig.cookie_key(force_secure: JitSessionCookieConfig.force_secure?)
      fv5082 = fv5081.response.cookies[fv5083]
      if fv5082.nil?
        fv5086 = fv5081.response.headers["Set-Cookie"] || fv5081.response.headers["set-cookie"]
        fv5085 =
          if fv5086.is_a?(String) && fv5086.start_with?("[")
            JSON.parse(fv5086)
          else
            Array(fv5086)
          end
        fv5084 =
          fv5085.flat_map { |entry| entry.to_s.split("\n") }.find do |entry|
            entry.split(";", 2).first.to_s.start_with?("#{fv5083}=")
          end
        if fv5084

          _, fv5082 = fv5084.split(";", 2).first.to_s.split("=", 2)
          fv5082 = Rack::Utils.unescape(fv5082.to_s)
        end
      end

      unless fv5082.nil?
        fv5081.cookies.delete(fv5083)
        # Rack::Test's []= uses its default host. The current request may target a
        # different surface, so install the cookie against the browser's active host.
        fv5081.cookies.merge(
          "#{fv5083}=#{Rack::Utils.escape(fv5082)}",
          URI.parse("https://#{fv5081.host}/"),
        )
      end
    end
    entry = URI.parse(@base_browser.response.location)
    host!(@host)
    get(entry.request_uri)
    csrf = response.parsed_body.at_css('input[name="authenticity_token"]')["value"]
    post(
      "/sign/in", params: { entry_ref: binding.entry_ref, ri: "jp", authenticity_token: csrf }, headers: auth_headers,
    )

    assert_response :see_other
    follow_redirect!
    post auth_app_sign_in_secret_path(ri: "jp"), params: {
      identifier: @email_record.address, secret: "a" * 32, "cf-turnstile-response": "test_token",
    }

    assert_response :see_other
    follow_redirect_to_oidc_handoff!
    post_oidc_handoff!

    assert_response :success
    action = @oidc_result_action
    flow = @transaction.reload.secret_sign_in_flow
    flow.halt_sign_in!

    assert_no_difference ["ClientToken.count", "ClientSecretSignInReceipt.count"] do
      begin
        fv5080 = action
        post(
          fv5080, params: {
            result_ref: @oidc_result_ref,
            transaction_ref: @oidc_result_transaction_ref,
          }, headers: {
            "Origin" => OidcIssuer.absolute_url(ENV.fetch("PUBLIC_BASE_SERVICE_URL")),
            "Sec-Fetch-Site" => "same-origin",
          },
        )
      end
    end
    assert_response :bad_request
    assert_nil flow.reload.token_id
    assert_nil ClientSecretLookupQuery.call(client: @user, secret: "a" * 32)
    assert_equal :abandoned, ClientSecretClaimFinalizer.call!(credential: credential.reload, purge_after: 1.day)
    assert_nil credential.reload.consumed_at
    assert_equal "flow_halted", ClientSecretAuditOutbox.find_by!(
      credential_ref: credential.public_id, event_name: "secret.discarded",
    ).reason
  end

  test "expired OIDC Secret limitation refuses session revocation" do
    client_secret_credentials(:one)
    base_host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    parameters = oidc_authorize_params(realm: "client").merge(ri: "jp")
    @base_browser = open_session
    @base_browser.host!(base_host)
    @base_browser.https!
    @base_browser.get("/oauth/authorize", params: parameters)
    csrf = @base_browser.response.parsed_body.at_css('input[name="authenticity_token"]')["value"]
    base_headers = { "Origin" => "https://#{base_host}", "Sec-Fetch-Site" => "same-origin" }
    @base_browser.post(
      "/oauth/authorize", params: parameters.merge(ceremony_action: "start", authenticity_token: csrf),
                          headers: base_headers,
    )
    begin
      fv5074 = @base_browser
      fv5076 = JitSessionCookieConfig.cookie_key(force_secure: JitSessionCookieConfig.force_secure?)
      fv5075 = fv5074.response.cookies[fv5076]
      if fv5075.nil?
        fv5079 = fv5074.response.headers["Set-Cookie"] || fv5074.response.headers["set-cookie"]
        fv5078 =
          if fv5079.is_a?(String) && fv5079.start_with?("[")
            JSON.parse(fv5079)
          else
            Array(fv5079)
          end
        fv5077 =
          fv5078.flat_map { |entry| entry.to_s.split("\n") }.find do |entry|
            entry.split(";", 2).first.to_s.start_with?("#{fv5076}=")
          end
        if fv5077

          _, fv5075 = fv5077.split(";", 2).first.to_s.split("=", 2)
          fv5075 = Rack::Utils.unescape(fv5075.to_s)
        end
      end

      unless fv5075.nil?
        fv5074.cookies.delete(fv5076)
        # Rack::Test's []= uses its default host. The current request may target a
        # different surface, so install the cookie against the browser's active host.
        fv5074.cookies.merge(
          "#{fv5076}=#{Rack::Utils.escape(fv5075)}",
          URI.parse("https://#{fv5074.host}/"),
        )
      end
    end
    @transaction = ClientOidcAuthorizationTransaction.find_by!(state: parameters.fetch(:state))
    binding = ClientAuthAdmissionBinding.find_by!(authorization_transaction_id: @transaction.id)
    host!(@host)
    auth_headers = { "Origin" => "https://#{@host}", "Sec-Fetch-Site" => "same-origin" }
    get("/sign/in", params: { entry_ref: binding.entry_ref, ri: "jp" })
    csrf = response.parsed_body.at_css('input[name="authenticity_token"]')["value"]
    post(
      "/ceremony_bindings", params: { entry_ref: binding.entry_ref, ri: "jp", authenticity_token: csrf },
                            headers: auth_headers,
    )
    confirmation = URI.parse(response.location)
    @base_browser.get(confirmation.request_uri)
    csrf = @base_browser.response.parsed_body.at_css('input[name="authenticity_token"]')["value"]
    @base_browser.post(confirmation.request_uri, params: { authenticity_token: csrf }, headers: base_headers)
    begin
      fv5068 = @base_browser
      fv5070 = JitSessionCookieConfig.cookie_key(force_secure: JitSessionCookieConfig.force_secure?)
      fv5069 = fv5068.response.cookies[fv5070]
      if fv5069.nil?
        fv5073 = fv5068.response.headers["Set-Cookie"] || fv5068.response.headers["set-cookie"]
        fv5072 =
          if fv5073.is_a?(String) && fv5073.start_with?("[")
            JSON.parse(fv5073)
          else
            Array(fv5073)
          end
        fv5071 =
          fv5072.flat_map { |entry| entry.to_s.split("\n") }.find do |entry|
            entry.split(";", 2).first.to_s.start_with?("#{fv5070}=")
          end
        if fv5071

          _, fv5069 = fv5071.split(";", 2).first.to_s.split("=", 2)
          fv5069 = Rack::Utils.unescape(fv5069.to_s)
        end
      end

      unless fv5069.nil?
        fv5068.cookies.delete(fv5070)
        # Rack::Test's []= uses its default host. The current request may target a
        # different surface, so install the cookie against the browser's active host.
        fv5068.cookies.merge(
          "#{fv5070}=#{Rack::Utils.escape(fv5069)}",
          URI.parse("https://#{fv5068.host}/"),
        )
      end
    end
    entry = URI.parse(@base_browser.response.location)
    host!(@host)
    get(entry.request_uri)
    csrf = response.parsed_body.at_css('input[name="authenticity_token"]')["value"]
    post(
      "/sign/in", params: { entry_ref: binding.entry_ref, ri: "jp", authenticity_token: csrf }, headers: auth_headers,
    )

    assert_response :see_other
    follow_redirect!
    post auth_app_sign_in_secret_path(ri: "jp"), params: {
      identifier: @email_record.address, secret: "a" * 32, "cf-turnstile-response": "test_token",
    }

    assert_response :see_other
    follow_redirect_to_oidc_handoff!
    post_oidc_handoff!

    assert_response :success
    action = @oidc_result_action
    Array.new(ClientToken::MAX_TOTAL_SESSIONS_PER_USER) { ClientToken.create!(user: @user) }
    begin
      fv5067 = action
      post(
        fv5067, params: {
          result_ref: @oidc_result_ref,
          transaction_ref: @oidc_result_transaction_ref,
        }, headers: {
          "Origin" => OidcIssuer.absolute_url(ENV.fetch("PUBLIC_BASE_SERVICE_URL")),
          "Sec-Fetch-Site" => "same-origin",
        },
      )
    end

    assert_response :see_other
    limitation = response.location
    flow = @transaction.reload.secret_sign_in_flow
    challenge =
      begin
        fv5066 = session[:session_limit_gate] || session["session_limit_gate"]
        fv5066.fetch("resolution_challenge")
      end
    resolution = ClientSessionLimitResolutionTransaction.find_active_by_challenge(challenge)
    flow.update!(expires_at: ClientSignInFlow.database_now)
    token = ClientToken.where(user_id: @user.id).first
    statuses = ClientToken.where(user_id: @user.id).order(:id).pluck(:id, :user_token_status_id)
    resolution.expire!
    patch limitation, params: { session_ref: SessionLimitResolutionTokenRef.issue(token) }

    assert_response :gone
    assert_equal statuses, ClientToken.where(user_id: @user.id).order(:id).pluck(:id, :user_token_status_id)
    assert_predicate resolution.reload, :expired?
    assert_nil flow.reload.token_id
  end

  test "canceling OIDC Secret session limit ends its flow and rejects old results" do
    credential = client_secret_credentials(:one)
    base_host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    parameters = oidc_authorize_params(realm: "client").merge(ri: "jp")
    @base_browser = open_session
    @base_browser.host!(base_host)
    @base_browser.https!
    @base_browser.get("/oauth/authorize", params: parameters)
    csrf = @base_browser.response.parsed_body.at_css('input[name="authenticity_token"]')["value"]
    base_headers = { "Origin" => "https://#{base_host}", "Sec-Fetch-Site" => "same-origin" }
    @base_browser.post(
      "/oauth/authorize", params: parameters.merge(ceremony_action: "start", authenticity_token: csrf),
                          headers: base_headers,
    )
    begin
      fv5060 = @base_browser
      fv5062 = JitSessionCookieConfig.cookie_key(force_secure: JitSessionCookieConfig.force_secure?)
      fv5061 = fv5060.response.cookies[fv5062]
      if fv5061.nil?
        fv5065 = fv5060.response.headers["Set-Cookie"] || fv5060.response.headers["set-cookie"]
        fv5064 =
          if fv5065.is_a?(String) && fv5065.start_with?("[")
            JSON.parse(fv5065)
          else
            Array(fv5065)
          end
        fv5063 =
          fv5064.flat_map { |entry| entry.to_s.split("\n") }.find do |entry|
            entry.split(";", 2).first.to_s.start_with?("#{fv5062}=")
          end
        if fv5063

          _, fv5061 = fv5063.split(";", 2).first.to_s.split("=", 2)
          fv5061 = Rack::Utils.unescape(fv5061.to_s)
        end
      end

      unless fv5061.nil?
        fv5060.cookies.delete(fv5062)
        # Rack::Test's []= uses its default host. The current request may target a
        # different surface, so install the cookie against the browser's active host.
        fv5060.cookies.merge(
          "#{fv5062}=#{Rack::Utils.escape(fv5061)}",
          URI.parse("https://#{fv5060.host}/"),
        )
      end
    end
    @transaction = ClientOidcAuthorizationTransaction.find_by!(state: parameters.fetch(:state))
    binding = ClientAuthAdmissionBinding.find_by!(authorization_transaction_id: @transaction.id)
    host!(@host)
    auth_headers = { "Origin" => "https://#{@host}", "Sec-Fetch-Site" => "same-origin" }
    get("/sign/in", params: { entry_ref: binding.entry_ref, ri: "jp" })
    csrf = response.parsed_body.at_css('input[name="authenticity_token"]')["value"]
    post(
      "/ceremony_bindings", params: { entry_ref: binding.entry_ref, ri: "jp", authenticity_token: csrf },
                            headers: auth_headers,
    )
    confirmation = URI.parse(response.location)
    @base_browser.get(confirmation.request_uri)
    csrf = @base_browser.response.parsed_body.at_css('input[name="authenticity_token"]')["value"]
    @base_browser.post(confirmation.request_uri, params: { authenticity_token: csrf }, headers: base_headers)
    begin
      fv5054 = @base_browser
      fv5056 = JitSessionCookieConfig.cookie_key(force_secure: JitSessionCookieConfig.force_secure?)
      fv5055 = fv5054.response.cookies[fv5056]
      if fv5055.nil?
        fv5059 = fv5054.response.headers["Set-Cookie"] || fv5054.response.headers["set-cookie"]
        fv5058 =
          if fv5059.is_a?(String) && fv5059.start_with?("[")
            JSON.parse(fv5059)
          else
            Array(fv5059)
          end
        fv5057 =
          fv5058.flat_map { |entry| entry.to_s.split("\n") }.find do |entry|
            entry.split(";", 2).first.to_s.start_with?("#{fv5056}=")
          end
        if fv5057

          _, fv5055 = fv5057.split(";", 2).first.to_s.split("=", 2)
          fv5055 = Rack::Utils.unescape(fv5055.to_s)
        end
      end

      unless fv5055.nil?
        fv5054.cookies.delete(fv5056)
        # Rack::Test's []= uses its default host. The current request may target a
        # different surface, so install the cookie against the browser's active host.
        fv5054.cookies.merge(
          "#{fv5056}=#{Rack::Utils.escape(fv5055)}",
          URI.parse("https://#{fv5054.host}/"),
        )
      end
    end
    entry = URI.parse(@base_browser.response.location)
    host!(@host)
    get(entry.request_uri)
    csrf = response.parsed_body.at_css('input[name="authenticity_token"]')["value"]
    post(
      "/sign/in", params: { entry_ref: binding.entry_ref, ri: "jp", authenticity_token: csrf }, headers: auth_headers,
    )

    assert_response :see_other
    follow_redirect!
    post auth_app_sign_in_secret_path(ri: "jp"), params: {
      identifier: @email_record.address, secret: "a" * 32, "cf-turnstile-response": "test_token",
    }

    assert_response :see_other
    follow_redirect_to_oidc_handoff!
    post_oidc_handoff!

    assert_response :success
    action = @oidc_result_action
    Array.new(ClientToken::MAX_TOTAL_SESSIONS_PER_USER) { ClientToken.create!(user: @user) }
    begin
      fv5053 = action
      post(
        fv5053, params: {
          result_ref: @oidc_result_ref,
          transaction_ref: @oidc_result_transaction_ref,
        }, headers: {
          "Origin" => OidcIssuer.absolute_url(ENV.fetch("PUBLIC_BASE_SERVICE_URL")),
          "Sec-Fetch-Site" => "same-origin",
        },
      )
    end

    assert_response :see_other
    limitation = response.location
    challenge =
      begin
        fv5052 = session[:session_limit_gate] || session["session_limit_gate"]
        fv5052.fetch("resolution_challenge")
      end
    admitted_resolution = ClientSessionLimitResolutionTransaction.find_active_by_challenge(challenge)
    assert_no_difference ["ClientToken.count", "ClientSecretSignInReceipt.count"] do
      delete limitation
    end
    assert_response :see_other
    assert_predicate @transaction.reload.secret_sign_in_flow, :sign_in_cancelled?
    assert_operator credential.reload.discard_at, :<=, Client.database_now
    assert_nil credential.consumed_at
    assert_nil ClientSecretLookupQuery.call(client: @user, secret: "a" * 32)
    assert_predicate admitted_resolution.reload, :cancelled?
    assert_no_difference ["ClientToken.count", "ClientSecretSignInReceipt.count"] do
      begin
        fv5051 = action
        post(
          fv5051, params: {
            result_ref: @oidc_result_ref,
            transaction_ref: @oidc_result_transaction_ref,
          }, headers: {
            "Origin" => OidcIssuer.absolute_url(ENV.fetch("PUBLIC_BASE_SERVICE_URL")),
            "Sec-Fetch-Site" => "same-origin",
          },
        )
      end
    end
    assert_response :bad_request
    assert_equal "flow_canceled", ClientSecretAuditOutbox.find_by!(
      credential_ref: credential.public_id, event_name: "secret.discarded",
    ).reason
  end

  test "OIDC Secret session limit continuation preserves claim and commits its receipt" do
    credential = client_secret_credentials(:one)
    base_host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    parameters = oidc_authorize_params(realm: "client").merge(ri: "jp")
    @base_browser = open_session
    @base_browser.host!(base_host)
    @base_browser.https!
    @base_browser.get("/oauth/authorize", params: parameters)
    csrf = @base_browser.response.parsed_body.at_css('input[name="authenticity_token"]')["value"]
    base_headers = { "Origin" => "https://#{base_host}", "Sec-Fetch-Site" => "same-origin" }
    @base_browser.post(
      "/oauth/authorize", params: parameters.merge(ceremony_action: "start", authenticity_token: csrf),
                          headers: base_headers,
    )
    begin
      fv5045 = @base_browser
      fv5047 = JitSessionCookieConfig.cookie_key(force_secure: JitSessionCookieConfig.force_secure?)
      fv5046 = fv5045.response.cookies[fv5047]
      if fv5046.nil?
        fv5050 = fv5045.response.headers["Set-Cookie"] || fv5045.response.headers["set-cookie"]
        fv5049 =
          if fv5050.is_a?(String) && fv5050.start_with?("[")
            JSON.parse(fv5050)
          else
            Array(fv5050)
          end
        fv5048 =
          fv5049.flat_map { |entry| entry.to_s.split("\n") }.find do |entry|
            entry.split(";", 2).first.to_s.start_with?("#{fv5047}=")
          end
        if fv5048

          _, fv5046 = fv5048.split(";", 2).first.to_s.split("=", 2)
          fv5046 = Rack::Utils.unescape(fv5046.to_s)
        end
      end

      unless fv5046.nil?
        fv5045.cookies.delete(fv5047)
        # Rack::Test's []= uses its default host. The current request may target a
        # different surface, so install the cookie against the browser's active host.
        fv5045.cookies.merge(
          "#{fv5047}=#{Rack::Utils.escape(fv5046)}",
          URI.parse("https://#{fv5045.host}/"),
        )
      end
    end
    @transaction = ClientOidcAuthorizationTransaction.find_by!(state: parameters.fetch(:state))
    binding = ClientAuthAdmissionBinding.find_by!(authorization_transaction_id: @transaction.id)
    host!(@host)
    auth_headers = { "Origin" => "https://#{@host}", "Sec-Fetch-Site" => "same-origin" }
    get("/sign/in", params: { entry_ref: binding.entry_ref, ri: "jp" })
    csrf = response.parsed_body.at_css('input[name="authenticity_token"]')["value"]
    post(
      "/ceremony_bindings", params: { entry_ref: binding.entry_ref, ri: "jp", authenticity_token: csrf },
                            headers: auth_headers,
    )
    confirmation = URI.parse(response.location)
    @base_browser.get(confirmation.request_uri)
    csrf = @base_browser.response.parsed_body.at_css('input[name="authenticity_token"]')["value"]
    @base_browser.post(confirmation.request_uri, params: { authenticity_token: csrf }, headers: base_headers)
    begin
      fv5039 = @base_browser
      fv5041 = JitSessionCookieConfig.cookie_key(force_secure: JitSessionCookieConfig.force_secure?)
      fv5040 = fv5039.response.cookies[fv5041]
      if fv5040.nil?
        fv5044 = fv5039.response.headers["Set-Cookie"] || fv5039.response.headers["set-cookie"]
        fv5043 =
          if fv5044.is_a?(String) && fv5044.start_with?("[")
            JSON.parse(fv5044)
          else
            Array(fv5044)
          end
        fv5042 =
          fv5043.flat_map { |entry| entry.to_s.split("\n") }.find do |entry|
            entry.split(";", 2).first.to_s.start_with?("#{fv5041}=")
          end
        if fv5042

          _, fv5040 = fv5042.split(";", 2).first.to_s.split("=", 2)
          fv5040 = Rack::Utils.unescape(fv5040.to_s)
        end
      end

      unless fv5040.nil?
        fv5039.cookies.delete(fv5041)
        # Rack::Test's []= uses its default host. The current request may target a
        # different surface, so install the cookie against the browser's active host.
        fv5039.cookies.merge(
          "#{fv5041}=#{Rack::Utils.escape(fv5040)}",
          URI.parse("https://#{fv5039.host}/"),
        )
      end
    end
    entry = URI.parse(@base_browser.response.location)
    host!(@host)
    get(entry.request_uri)
    csrf = response.parsed_body.at_css('input[name="authenticity_token"]')["value"]
    post(
      "/sign/in", params: { entry_ref: binding.entry_ref, ri: "jp", authenticity_token: csrf }, headers: auth_headers,
    )

    assert_response :see_other
    follow_redirect!
    post auth_app_sign_in_secret_path(ri: "jp"), params: {
      identifier: @email_record.address, secret: "a" * 32, "cf-turnstile-response": "test_token",
    }

    assert_response :see_other
    follow_redirect_to_oidc_handoff!
    post_oidc_handoff!

    assert_response :success
    action = @oidc_result_action
    existing_tokens = Array.new(ClientToken::MAX_TOTAL_SESSIONS_PER_USER) { ClientToken.create!(user: @user) }
    assert_no_difference "ClientToken.count" do
      begin
        fv5038 = action
        post(
          fv5038, params: {
            result_ref: @oidc_result_ref,
            transaction_ref: @oidc_result_transaction_ref,
          }, headers: {
            "Origin" => OidcIssuer.absolute_url(ENV.fetch("PUBLIC_BASE_SERVICE_URL")),
            "Sec-Fetch-Site" => "same-origin",
          },
        )
      end
    end
    assert_response :see_other
    limitation = response.location

    assert_predicate @transaction.reload.secret_sign_in_flow, :sign_in_session_issuance_pending?
    assert_nil credential.reload.consumed_at
    assert_nil ClientSecretLookupQuery.call(client: @user, secret: "a" * 32)
    challenge =
      begin
        fv5037 = session[:session_limit_gate] || session["session_limit_gate"]
        fv5037.fetch("resolution_challenge")
      end
    resolution = ClientSessionLimitResolutionTransaction.find_active_by_challenge(challenge)

    assert resolution
    patch limitation, params: {
      resolution_challenge: challenge,
      session_ref: SessionLimitResolutionTokenRef.issue(existing_tokens.first),
    }

    assert_response :unprocessable_content
    assert_predicate @transaction.secret_sign_in_flow.reload, :sign_in_session_issuance_pending?
    assert_nil credential.reload.consumed_at
    assert_equal I18n.t("base.app.sign.in.limitations.capacity_still_full"),
                 JSON.parse(css_select("script[data-page=app]").first.text).fetch("props").fetch("notice")
    challenge =
      begin
        fv5036 = session[:session_limit_gate] || session["session_limit_gate"]
        fv5036.fetch("resolution_challenge")
      end
    patch limitation, params: {
      resolution_challenge: challenge,
      session_ref: SessionLimitResolutionTokenRef.issue(existing_tokens.second),
    }

    assert_response :redirect
    receipt = ClientSecretSignInReceipt.find_by!(operation_id: credential.claim_operation_id)

    assert_equal @transaction.reload.browser_session_ref, receipt.root_token_ref
    assert credential.reload.consumed_at
  end

  test "the local handoff POST binds the signed-in actor to the authorization transaction" do
    base_host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    parameters = oidc_authorize_params(realm: "client").merge(ri: "jp")
    @base_browser = open_session
    @base_browser.host!(base_host)
    @base_browser.https!
    @base_browser.get("/oauth/authorize", params: parameters)
    csrf = @base_browser.response.parsed_body.at_css('input[name="authenticity_token"]')["value"]
    base_headers = { "Origin" => "https://#{base_host}", "Sec-Fetch-Site" => "same-origin" }
    @base_browser.post(
      "/oauth/authorize", params: parameters.merge(ceremony_action: "start", authenticity_token: csrf),
                          headers: base_headers,
    )
    begin
      fv5030 = @base_browser
      fv5032 = JitSessionCookieConfig.cookie_key(force_secure: JitSessionCookieConfig.force_secure?)
      fv5031 = fv5030.response.cookies[fv5032]
      if fv5031.nil?
        fv5035 = fv5030.response.headers["Set-Cookie"] || fv5030.response.headers["set-cookie"]
        fv5034 =
          if fv5035.is_a?(String) && fv5035.start_with?("[")
            JSON.parse(fv5035)
          else
            Array(fv5035)
          end
        fv5033 =
          fv5034.flat_map { |entry| entry.to_s.split("\n") }.find do |entry|
            entry.split(";", 2).first.to_s.start_with?("#{fv5032}=")
          end
        if fv5033

          _, fv5031 = fv5033.split(";", 2).first.to_s.split("=", 2)
          fv5031 = Rack::Utils.unescape(fv5031.to_s)
        end
      end

      unless fv5031.nil?
        fv5030.cookies.delete(fv5032)
        # Rack::Test's []= uses its default host. The current request may target a
        # different surface, so install the cookie against the browser's active host.
        fv5030.cookies.merge(
          "#{fv5032}=#{Rack::Utils.escape(fv5031)}",
          URI.parse("https://#{fv5030.host}/"),
        )
      end
    end
    @transaction = ClientOidcAuthorizationTransaction.find_by!(state: parameters.fetch(:state))
    binding = ClientAuthAdmissionBinding.find_by!(authorization_transaction_id: @transaction.id)
    host!(@host)
    auth_headers = { "Origin" => "https://#{@host}", "Sec-Fetch-Site" => "same-origin" }
    get("/sign/in", params: { entry_ref: binding.entry_ref, ri: "jp" })
    csrf = response.parsed_body.at_css('input[name="authenticity_token"]')["value"]
    post(
      "/ceremony_bindings", params: { entry_ref: binding.entry_ref, ri: "jp", authenticity_token: csrf },
                            headers: auth_headers,
    )
    confirmation = URI.parse(response.location)
    @base_browser.get(confirmation.request_uri)
    csrf = @base_browser.response.parsed_body.at_css('input[name="authenticity_token"]')["value"]
    @base_browser.post(confirmation.request_uri, params: { authenticity_token: csrf }, headers: base_headers)
    begin
      fv5024 = @base_browser
      fv5026 = JitSessionCookieConfig.cookie_key(force_secure: JitSessionCookieConfig.force_secure?)
      fv5025 = fv5024.response.cookies[fv5026]
      if fv5025.nil?
        fv5029 = fv5024.response.headers["Set-Cookie"] || fv5024.response.headers["set-cookie"]
        fv5028 =
          if fv5029.is_a?(String) && fv5029.start_with?("[")
            JSON.parse(fv5029)
          else
            Array(fv5029)
          end
        fv5027 =
          fv5028.flat_map { |entry| entry.to_s.split("\n") }.find do |entry|
            entry.split(";", 2).first.to_s.start_with?("#{fv5026}=")
          end
        if fv5027

          _, fv5025 = fv5027.split(";", 2).first.to_s.split("=", 2)
          fv5025 = Rack::Utils.unescape(fv5025.to_s)
        end
      end

      unless fv5025.nil?
        fv5024.cookies.delete(fv5026)
        # Rack::Test's []= uses its default host. The current request may target a
        # different surface, so install the cookie against the browser's active host.
        fv5024.cookies.merge(
          "#{fv5026}=#{Rack::Utils.escape(fv5025)}",
          URI.parse("https://#{fv5024.host}/"),
        )
      end
    end
    entry = URI.parse(@base_browser.response.location)
    host!(@host)
    get(entry.request_uri)
    csrf = response.parsed_body.at_css('input[name="authenticity_token"]')["value"]
    post(
      "/sign/in", params: { entry_ref: binding.entry_ref, ri: "jp", authenticity_token: csrf }, headers: auth_headers,
    )

    assert_response :see_other
    follow_redirect!
    submit_email_otp!
    follow_redirect_to_oidc_handoff!
    post_oidc_handoff!

    transaction = ClientOidcAuthorizationTransaction.find_by!(login_challenge: @transaction.login_challenge)

    assert_equal @user.public_id, transaction.actor_ref
    assert_nil transaction.session_ref
    assert_predicate transaction.authenticated_at, :present?
    assert_nil transaction.consumed_at, "the authorization endpoint consumes it, not the checkpoint"
  end

  test "the local handoff POST hands the browser to the Base authorization endpoint" do
    base_host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    parameters = oidc_authorize_params(realm: "client").merge(ri: "jp")
    @base_browser = open_session
    @base_browser.host!(base_host)
    @base_browser.https!
    @base_browser.get("/oauth/authorize", params: parameters)
    csrf = @base_browser.response.parsed_body.at_css('input[name="authenticity_token"]')["value"]
    base_headers = { "Origin" => "https://#{base_host}", "Sec-Fetch-Site" => "same-origin" }
    @base_browser.post(
      "/oauth/authorize", params: parameters.merge(ceremony_action: "start", authenticity_token: csrf),
                          headers: base_headers,
    )
    begin
      fv5018 = @base_browser
      fv5020 = JitSessionCookieConfig.cookie_key(force_secure: JitSessionCookieConfig.force_secure?)
      fv5019 = fv5018.response.cookies[fv5020]
      if fv5019.nil?
        fv5023 = fv5018.response.headers["Set-Cookie"] || fv5018.response.headers["set-cookie"]
        fv5022 =
          if fv5023.is_a?(String) && fv5023.start_with?("[")
            JSON.parse(fv5023)
          else
            Array(fv5023)
          end
        fv5021 =
          fv5022.flat_map { |entry| entry.to_s.split("\n") }.find do |entry|
            entry.split(";", 2).first.to_s.start_with?("#{fv5020}=")
          end
        if fv5021

          _, fv5019 = fv5021.split(";", 2).first.to_s.split("=", 2)
          fv5019 = Rack::Utils.unescape(fv5019.to_s)
        end
      end

      unless fv5019.nil?
        fv5018.cookies.delete(fv5020)
        # Rack::Test's []= uses its default host. The current request may target a
        # different surface, so install the cookie against the browser's active host.
        fv5018.cookies.merge(
          "#{fv5020}=#{Rack::Utils.escape(fv5019)}",
          URI.parse("https://#{fv5018.host}/"),
        )
      end
    end
    @transaction = ClientOidcAuthorizationTransaction.find_by!(state: parameters.fetch(:state))
    binding = ClientAuthAdmissionBinding.find_by!(authorization_transaction_id: @transaction.id)
    host!(@host)
    auth_headers = { "Origin" => "https://#{@host}", "Sec-Fetch-Site" => "same-origin" }
    get("/sign/in", params: { entry_ref: binding.entry_ref, ri: "jp" })
    csrf = response.parsed_body.at_css('input[name="authenticity_token"]')["value"]
    post(
      "/ceremony_bindings", params: { entry_ref: binding.entry_ref, ri: "jp", authenticity_token: csrf },
                            headers: auth_headers,
    )
    confirmation = URI.parse(response.location)
    @base_browser.get(confirmation.request_uri)
    csrf = @base_browser.response.parsed_body.at_css('input[name="authenticity_token"]')["value"]
    @base_browser.post(confirmation.request_uri, params: { authenticity_token: csrf }, headers: base_headers)
    begin
      fv5012 = @base_browser
      fv5014 = JitSessionCookieConfig.cookie_key(force_secure: JitSessionCookieConfig.force_secure?)
      fv5013 = fv5012.response.cookies[fv5014]
      if fv5013.nil?
        fv5017 = fv5012.response.headers["Set-Cookie"] || fv5012.response.headers["set-cookie"]
        fv5016 =
          if fv5017.is_a?(String) && fv5017.start_with?("[")
            JSON.parse(fv5017)
          else
            Array(fv5017)
          end
        fv5015 =
          fv5016.flat_map { |entry| entry.to_s.split("\n") }.find do |entry|
            entry.split(";", 2).first.to_s.start_with?("#{fv5014}=")
          end
        if fv5015

          _, fv5013 = fv5015.split(";", 2).first.to_s.split("=", 2)
          fv5013 = Rack::Utils.unescape(fv5013.to_s)
        end
      end

      unless fv5013.nil?
        fv5012.cookies.delete(fv5014)
        # Rack::Test's []= uses its default host. The current request may target a
        # different surface, so install the cookie against the browser's active host.
        fv5012.cookies.merge(
          "#{fv5014}=#{Rack::Utils.escape(fv5013)}",
          URI.parse("https://#{fv5012.host}/"),
        )
      end
    end
    entry = URI.parse(@base_browser.response.location)
    host!(@host)
    get(entry.request_uri)
    csrf = response.parsed_body.at_css('input[name="authenticity_token"]')["value"]
    post(
      "/sign/in", params: { entry_ref: binding.entry_ref, ri: "jp", authenticity_token: csrf }, headers: auth_headers,
    )

    assert_response :see_other
    follow_redirect!
    submit_email_otp!

    follow_redirect_to_oidc_handoff!
    post_oidc_handoff!

    assert_response :success
    assert_select "form#oidc-authorization-result-form[method=post]", 1
    assert_select "input[name=result_ref][value]", 1
    assert_select "form#oidc-authorization-result-form" do |forms|
      result_uri = URI.parse(forms.first.attributes.fetch("action").value)
      base_uri = URI.parse(OidcIssuer.absolute_url(ENV.fetch("PUBLIC_BASE_SERVICE_URL")))

      assert_equal "/oauth/authorize", result_uri.path
      resolved_result_uri = URI.join(base_uri.to_s, result_uri.to_s)

      assert_equal base_uri.host, resolved_result_uri.host
    end
  end

  test "the checkpoint clears the login challenge from the session" do
    base_host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    parameters = oidc_authorize_params(realm: "client").merge(ri: "jp")
    @base_browser = open_session
    @base_browser.host!(base_host)
    @base_browser.https!
    @base_browser.get("/oauth/authorize", params: parameters)
    csrf = @base_browser.response.parsed_body.at_css('input[name="authenticity_token"]')["value"]
    base_headers = { "Origin" => "https://#{base_host}", "Sec-Fetch-Site" => "same-origin" }
    @base_browser.post(
      "/oauth/authorize", params: parameters.merge(ceremony_action: "start", authenticity_token: csrf),
                          headers: base_headers,
    )
    begin
      fv5006 = @base_browser
      fv5008 = JitSessionCookieConfig.cookie_key(force_secure: JitSessionCookieConfig.force_secure?)
      fv5007 = fv5006.response.cookies[fv5008]
      if fv5007.nil?
        fv5011 = fv5006.response.headers["Set-Cookie"] || fv5006.response.headers["set-cookie"]
        fv5010 =
          if fv5011.is_a?(String) && fv5011.start_with?("[")
            JSON.parse(fv5011)
          else
            Array(fv5011)
          end
        fv5009 =
          fv5010.flat_map { |entry| entry.to_s.split("\n") }.find do |entry|
            entry.split(";", 2).first.to_s.start_with?("#{fv5008}=")
          end
        if fv5009

          _, fv5007 = fv5009.split(";", 2).first.to_s.split("=", 2)
          fv5007 = Rack::Utils.unescape(fv5007.to_s)
        end
      end

      unless fv5007.nil?
        fv5006.cookies.delete(fv5008)
        # Rack::Test's []= uses its default host. The current request may target a
        # different surface, so install the cookie against the browser's active host.
        fv5006.cookies.merge(
          "#{fv5008}=#{Rack::Utils.escape(fv5007)}",
          URI.parse("https://#{fv5006.host}/"),
        )
      end
    end
    @transaction = ClientOidcAuthorizationTransaction.find_by!(state: parameters.fetch(:state))
    binding = ClientAuthAdmissionBinding.find_by!(authorization_transaction_id: @transaction.id)
    host!(@host)
    auth_headers = { "Origin" => "https://#{@host}", "Sec-Fetch-Site" => "same-origin" }
    get("/sign/in", params: { entry_ref: binding.entry_ref, ri: "jp" })
    csrf = response.parsed_body.at_css('input[name="authenticity_token"]')["value"]
    post(
      "/ceremony_bindings", params: { entry_ref: binding.entry_ref, ri: "jp", authenticity_token: csrf },
                            headers: auth_headers,
    )
    confirmation = URI.parse(response.location)
    @base_browser.get(confirmation.request_uri)
    csrf = @base_browser.response.parsed_body.at_css('input[name="authenticity_token"]')["value"]
    @base_browser.post(confirmation.request_uri, params: { authenticity_token: csrf }, headers: base_headers)
    begin
      fv5000 = @base_browser
      fv5002 = JitSessionCookieConfig.cookie_key(force_secure: JitSessionCookieConfig.force_secure?)
      fv5001 = fv5000.response.cookies[fv5002]
      if fv5001.nil?
        fv5005 = fv5000.response.headers["Set-Cookie"] || fv5000.response.headers["set-cookie"]
        fv5004 =
          if fv5005.is_a?(String) && fv5005.start_with?("[")
            JSON.parse(fv5005)
          else
            Array(fv5005)
          end
        fv5003 =
          fv5004.flat_map { |entry| entry.to_s.split("\n") }.find do |entry|
            entry.split(";", 2).first.to_s.start_with?("#{fv5002}=")
          end
        if fv5003

          _, fv5001 = fv5003.split(";", 2).first.to_s.split("=", 2)
          fv5001 = Rack::Utils.unescape(fv5001.to_s)
        end
      end

      unless fv5001.nil?
        fv5000.cookies.delete(fv5002)
        # Rack::Test's []= uses its default host. The current request may target a
        # different surface, so install the cookie against the browser's active host.
        fv5000.cookies.merge(
          "#{fv5002}=#{Rack::Utils.escape(fv5001)}",
          URI.parse("https://#{fv5000.host}/"),
        )
      end
    end
    entry = URI.parse(@base_browser.response.location)
    host!(@host)
    get(entry.request_uri)
    csrf = response.parsed_body.at_css('input[name="authenticity_token"]')["value"]
    post(
      "/sign/in", params: { entry_ref: binding.entry_ref, ri: "jp", authenticity_token: csrf }, headers: auth_headers,
    )

    assert_response :see_other
    follow_redirect!
    submit_email_otp!

    follow_redirect!

    assert_nil session[:oidc_authorization_login_challenge]
  end

  test "Secret POST without admitted browser continuity leaves OIDC evidence and credentials unchanged" do
    @transaction = OidcAuthorizationTransactionCoordinator.issue!(
      surface: "app", intent: "sign_in", params: oidc_authorize_params(realm: "client"),
    ).transaction

    assert_no_difference("ClientToken.count") do
      assert_no_difference -> { ClientSecretCredential.where.not(claimed_at: nil).count } do
        post auth_app_sign_in_secret_path(ri: "jp"), params: {
          identifier: @email_record.address, secret: "a" * 32, "cf-turnstile-response": "test_token",
        }
      end
    end

    assert_response :bad_request
    assert_equal I18n.t("errors.messages.invalid_request"), response.body
    transaction = ClientOidcAuthorizationTransaction.find_by!(login_challenge: @transaction.login_challenge)

    assert_nil transaction.actor_ref
    assert_nil transaction.authenticated_at
  end

  private

  def submit_email_otp!
    post(
      auth_app_sign_in_email_url(ri: "jp"),
      params: { user_email: { address: @address }, "cf-turnstile-response": "test_token" },
      headers: { "Host" => @host },
    )

    assert_response :found

    binding = ClientAuthAdmissionBinding.find_by!(authorization_transaction_id: @transaction.id)
    ceremony = ClientAuthCeremonySession.find(binding.admitted_auth_ceremony_session_id)
    delivery_job =
      enqueued_jobs.reverse.find do |job|
        next false unless job.fetch(:job) == OtpNotifierEmailDeliveryJob

        delivery = ActiveJob::Arguments.deserialize(job.fetch(:args)).last.fetch(:params)
        delivery.fetch(:auth_ceremony_session_ref) == "#{ceremony.id}"
      end

    assert_not_nil delivery_job
    delivery = ActiveJob::Arguments.deserialize(delivery_job.fetch(:args)).last.fetch(:params)
    context = ceremony.email_otp_context
    pass_code = OutboundSensitivePayload.decrypt_email_otp(delivery.fetch(:encrypted_hotp_token))
    correct_parent = context.fetch("parent_ref") == @transaction.transaction_id
    correct_contact = context.fetch("contact_ref") == @email_record.public_id
    correct_owner = context.fetch("owner_ref") == @user.public_id
    correct_generation = context.fetch("generation") == delivery.fetch(:auth_email_otp_generation)
    plaintext_queued = delivery_job.fetch(:args).to_s.include?(pass_code)

    assert correct_parent, "Delivery must bind the original OIDC Parent"
    assert correct_contact, "Delivery must bind the actual Contact"
    assert correct_owner, "Delivery must bind the actual owner"
    assert correct_generation, "Delivery must bind the current ceremony generation"
    assert_not plaintext_queued, "Delivery must not queue plaintext code"
    assert_equal "sign_in", delivery.fetch(:purpose)
    assert_equal "oidc", context.fetch("parent_kind")

    patch(
      auth_app_sign_in_email_url(ri: "jp"),
      params: { :user_email => { pass_code: pass_code }, "cf-turnstile-response" => "test_token" },
      headers: { "Host" => @host },
    )
  end

  def post_oidc_handoff!
    csrf = css_select("input[name=authenticity_token]").first&.[]("value")
    post(
      auth_app_sign_oidc_handoff_path(ri: "jp"),
      params: { authenticity_token: csrf }.compact,
      headers: { "Host" => @host },
    )
    return unless response.redirect?

    target = URI.parse(response.location)
    base_host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    cookie_name = JitSessionCookieConfig.cookie_key(force_secure: JitSessionCookieConfig.force_secure?)
    cookies.delete(cookie_name)
    installed = cookies.merge(
      "#{cookie_name}=#{Rack::Utils.escape(@base_browser.cookies[cookie_name])}", URI.parse("https://#{base_host}/"),
    )

    assert_equal ["#{cookie_name}=#{Rack::Utils.escape(@base_browser.cookies[cookie_name])}"], installed
    host!(target.host)
    https!
    get(target.request_uri, headers: { "Host" => base_host })
    form = css_select("form#oidc-authorization-result-form").first
    @oidc_result_action = form["action"]
    @oidc_result_ref = form.at_css('input[name="result_ref"]')["value"]
    @oidc_result_transaction_ref = form.at_css('input[name="transaction_ref"]')["value"]
  end

  def follow_redirect_to_oidc_handoff!
    follow_redirect!
    follow_redirect!
  end

  def oidc_authorize_params(realm:)
    {
      response_type: "code",
      client_id: "core-app",
      redirect_uri: OidcClientRegistry.find!("core-app").redirect_uris_by_realm.fetch(realm).first,
      code_challenge: "a" * 43,
      code_challenge_method: "S256",
      state: SecureRandom.urlsafe_base64(32),
      nonce: SecureRandom.urlsafe_base64(32),
      scope: "openid profile",
    }
  end
end
