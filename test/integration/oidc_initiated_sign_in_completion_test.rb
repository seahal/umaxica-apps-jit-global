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
    sync_response_cookie!(
      @base_browser, JitSessionCookieConfig.cookie_key(force_secure: JitSessionCookieConfig.force_secure?),
    )
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
    sync_response_cookie!(
      @base_browser, JitSessionCookieConfig.cookie_key(force_secure: JitSessionCookieConfig.force_secure?),
    )
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
    sync_response_cookie!(
      @base_browser, JitSessionCookieConfig.cookie_key(force_secure: JitSessionCookieConfig.force_secure?),
    )
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
    sync_response_cookie!(
      @base_browser, JitSessionCookieConfig.cookie_key(force_secure: JitSessionCookieConfig.force_secure?),
    )
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
    assert_equal auth_app_sign_in_check_path(ri: "jp"), URI.parse(response.location).request_uri
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
    sync_response_cookie!(
      @base_browser, JitSessionCookieConfig.cookie_key(force_secure: JitSessionCookieConfig.force_secure?),
    )
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
    sync_response_cookie!(
      @base_browser, JitSessionCookieConfig.cookie_key(force_secure: JitSessionCookieConfig.force_secure?),
    )
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
      post_oidc_result!(action: action)

      assert_response :redirect, response.body
    end
    assert credential.reload.consumed_at
    assert_equal @transaction.secret_sign_in_flow.reload.token.public_id,
                 ClientSecretSignInReceipt.find_by!(operation_id: credential.claim_operation_id).root_token_ref
    root_token_ref = @transaction.reload.browser_session_ref
    consumed_at = credential.consumed_at
    assert_no_difference ["ClientToken.count", "ClientSecretSignInReceipt.count"] do
      post_oidc_result!(action: action)
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
      now: oidc_purge_now(@transaction),
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
    sync_response_cookie!(
      @base_browser, JitSessionCookieConfig.cookie_key(force_secure: JitSessionCookieConfig.force_secure?),
    )
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
    sync_response_cookie!(
      @base_browser, JitSessionCookieConfig.cookie_key(force_secure: JitSessionCookieConfig.force_secure?),
    )
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
      post_oidc_result!(action: action)
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
      post_oidc_result!(action: action)
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
      now: oidc_purge_now(@transaction),
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
    sync_response_cookie!(
      @base_browser, JitSessionCookieConfig.cookie_key(force_secure: JitSessionCookieConfig.force_secure?),
    )
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
    sync_response_cookie!(
      @base_browser, JitSessionCookieConfig.cookie_key(force_secure: JitSessionCookieConfig.force_secure?),
    )
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
      post_oidc_result!(action: action)
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
    sync_response_cookie!(
      @base_browser, JitSessionCookieConfig.cookie_key(force_secure: JitSessionCookieConfig.force_secure?),
    )
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
    sync_response_cookie!(
      @base_browser, JitSessionCookieConfig.cookie_key(force_secure: JitSessionCookieConfig.force_secure?),
    )
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
    post_oidc_result!(action: action)

    assert_response :see_other
    limitation = response.location
    flow = @transaction.reload.secret_sign_in_flow
    challenge = oidc_resolution_challenge
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
    sync_response_cookie!(
      @base_browser, JitSessionCookieConfig.cookie_key(force_secure: JitSessionCookieConfig.force_secure?),
    )
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
    sync_response_cookie!(
      @base_browser, JitSessionCookieConfig.cookie_key(force_secure: JitSessionCookieConfig.force_secure?),
    )
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
    post_oidc_result!(action: action)

    assert_response :see_other
    limitation = response.location
    challenge = oidc_resolution_challenge
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
      post_oidc_result!(action: action)
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
    sync_response_cookie!(
      @base_browser, JitSessionCookieConfig.cookie_key(force_secure: JitSessionCookieConfig.force_secure?),
    )
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
    sync_response_cookie!(
      @base_browser, JitSessionCookieConfig.cookie_key(force_secure: JitSessionCookieConfig.force_secure?),
    )
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
      post_oidc_result!(action: action)
    end
    assert_response :see_other
    limitation = response.location

    assert_predicate @transaction.reload.secret_sign_in_flow, :sign_in_session_issuance_pending?
    assert_nil credential.reload.consumed_at
    assert_nil ClientSecretLookupQuery.call(client: @user, secret: "a" * 32)
    challenge = oidc_resolution_challenge
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
    challenge = oidc_resolution_challenge
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
    sync_response_cookie!(
      @base_browser, JitSessionCookieConfig.cookie_key(force_secure: JitSessionCookieConfig.force_secure?),
    )
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
    sync_response_cookie!(
      @base_browser, JitSessionCookieConfig.cookie_key(force_secure: JitSessionCookieConfig.force_secure?),
    )
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
    sync_response_cookie!(
      @base_browser, JitSessionCookieConfig.cookie_key(force_secure: JitSessionCookieConfig.force_secure?),
    )
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
    sync_response_cookie!(
      @base_browser, JitSessionCookieConfig.cookie_key(force_secure: JitSessionCookieConfig.force_secure?),
    )
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
    sync_response_cookie!(
      @base_browser, JitSessionCookieConfig.cookie_key(force_secure: JitSessionCookieConfig.force_secure?),
    )
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
    sync_response_cookie!(
      @base_browser, JitSessionCookieConfig.cookie_key(force_secure: JitSessionCookieConfig.force_secure?),
    )
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
        next false unless job.fetch(:job) == OtpMailDeliveryJob

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

  def post_oidc_result!(action: @oidc_result_action)
    post(
      action, params: {
        result_ref: @oidc_result_ref,
        transaction_ref: @oidc_result_transaction_ref,
      }, headers: {
        "Origin" => OidcIssuer.absolute_url(ENV.fetch("PUBLIC_BASE_SERVICE_URL")),
        "Sec-Fetch-Site" => "same-origin",
      },
    )
  end

  def oidc_resolution_challenge
    gate = session[:session_limit_gate] || session["session_limit_gate"]
    gate.fetch("resolution_challenge")
  end

  def oidc_purge_now(transaction)
    binding_rows = ClientAuthAdmissionBinding.where(authorization_transaction_id: transaction.id)
    session_ids = binding_rows.pluck(:auth_ceremony_session_id, :admitted_auth_ceremony_session_id).flatten.compact
    deadlines = [transaction.expires_at, transaction.login_challenge_expires_at] + binding_rows.pluck(:expires_at)
    deadlines.concat(
      ClientAuthCeremonySession.where(id: session_ids).pluck(
        :expires_at, :completed_at, :cancelled_at, :revoked_at,
      ).flatten.compact,
    )
    deadlines.max + OidcAuthorizationTransactionable::RETENTION_PERIOD + 1.second
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
