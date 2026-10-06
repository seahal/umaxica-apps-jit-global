# frozen_string_literal: true

require "test_helper"

class AppSecretReceiptCollectionJourneyTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    @previous_lifetimes = ENV.to_h.slice(
      "APP_SECRET_PROOF_RETENTION_SECONDS", "APP_SECRET_OUTBOX_RETENTION_SECONDS", "APP_SECRET_PURGE_DELAY_SECONDS",
    )
    ENV["APP_SECRET_PROOF_RETENTION_SECONDS"] = "1"
    ENV["APP_SECRET_OUTBOX_RETENTION_SECONDS"] = "3600"
    ENV["APP_SECRET_PURGE_DELAY_SECONDS"] = "86400"
    @host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    ClientIdentityState.ensure_defaults!
    TurnstileVerifierStub.challenge_enabled = true
    TurnstileVerifierStub.challenge_response = { "success" => true }
  end

  teardown do
    %w(APP_SECRET_PROOF_RETENTION_SECONDS APP_SECRET_OUTBOX_RETENTION_SECONDS
       APP_SECRET_PURGE_DELAY_SECONDS).each do |key|
      ENV[key] = @previous_lifetimes[key]
    end
    TurnstileVerifierStub.challenge_enabled = false
    TurnstileVerifierStub.challenge_response = nil
  end

  test "receipt scan continues past a held canonical login and collects a later committed receipt" do
    ENV["APP_SECRET_PURGE_DELAY_SECONDS"] = "1"
    receipts = []
    credentials = [client_secret_credentials(:one), client_secret_credentials(:two)]
    identifiers =
      credentials.to_h do |credential|
        email = credential.client.client_emails.create!(
          address: "receipt-#{credential.client.public_id}-#{SecureRandom.hex(4)}@example.com",
          user_email_status_id: ClientEmailStatus::VERIFIED,
        )
        email.finalize_binding!
        [credential.client_id, email.address]
      end
    transactions = []
    ["a" * 32, "b" * 32].each do |raw|
      reset!
      host! @host
      transaction = OidcAuthorizationTransactionCoordinator.issue!(
        surface: "app", intent: "sign_in", ttl: 10.seconds, login_challenge_ttl: 10.seconds,
        params: {
          response_type: "code",
          client_id: "core-app",
          redirect_uri: OidcClientRegistry.find!("core-app").redirect_uris_by_realm.fetch("client").first,
          code_challenge: "challenge",
          code_challenge_method: "S256",
          state: "state",
          nonce: "nonce",
          scope: "openid profile",
        },
      ).transaction
      reference = BaseAuthAdmissionCoordinator.issue_handoff!(
        transaction: transaction, base_browser_nonce: "test-browser-nonce", base_token: nil,
      ).reference
      redeem_auth_ceremony_session!(
        self, auth_app_sign_in_path, reference: reference,
                                     params: { ri: "jp" },
                                     headers: { "Host" => @host, "Origin" => "https://#{@host}", "Sec-Fetch-Site" => "same-origin" },
      )

      assert_response :see_other
      follow_redirect!
      get new_auth_app_sign_in_secret_path(ri: "jp")
      post auth_app_sign_in_secret_path(ri: "jp"), params: {
        identifier: identifiers.fetch(credentials[transactions.length].client_id),
        secret: raw,
        "cf-turnstile-response": "test_token",
      }

      assert_response :see_other
      follow_redirect!
      follow_redirect!
      handoff_csrf = css_select("input[name=authenticity_token]").first["value"]
      post auth_app_sign_oidc_handoff_path(ri: "jp"), params: { authenticity_token: handoff_csrf }, headers: {
        "Host" => @host, "Origin" => "https://#{@host}", "Sec-Fetch-Site" => "same-origin",
      }

      assert_response :see_other
      result_uri = URI.parse(response.location)
      host!(result_uri.host)
      https!
      get result_uri.request_uri, headers: { "Host" => result_uri.host }

      assert_response :success
      result_form = css_select("form#oidc-authorization-result-form").first
      result_ref = result_form.at_css('input[name="result_ref"]')["value"]
      transaction_ref = result_form.at_css('input[name="transaction_ref"]')["value"]
      action = result_form["action"]
      assert_difference("ClientToken.count", 1) do
        post action, params: { transaction_ref: transaction_ref, result_ref: result_ref },
                     headers: { "Origin" => OidcIssuer.absolute_url(result_uri.host) }

        assert_response :redirect
      end
      transactions << transaction
      receipts << ClientSecretSignInReceipt.find_by!(sign_in_flow_id: transaction.reload.secret_sign_in_flow_id)
    end
    ChronicleRetentionPolicy.find_by(code: "security") ||
      ChronicleRetentionPolicy.create!(code: "security", name: "Security", duration_days: 365, permanent: false)
    Timeout.timeout(3) do
      sleep 0.01 while credentials.any? { |credential| credential.reload.purge_eligible_at > Client.database_now }
    end
    ClientSecretLifecycleJob.perform_now(batch_size: 500)

    assert credentials.none? { |credential| ClientSecretCredential.exists?(credential.id) }
    ClientSecretAuditDeliveryJob.perform_now(batch_size: 500, retention_seconds: 3600)
    deadline = transactions.flat_map do |transaction|
      [transaction.expires_at, transaction.login_challenge_expires_at, transaction.secret_sign_in_flow.expires_at]
    end.max + 1.second
    Timeout.timeout(15) { sleep 0.01 while ClientSignInFlow.database_now < deadline }
    hold = ClientRetentionHold.create!(client: clients(:one), hold_kind: "legal_hold", reason_code: "legal_hold")
    assert_enqueued_with(
      job: ClientSecretLifecycleJob,
      args: [{ batch_size: 1, phase: "receipts", after_id: receipts.first.id, through_id: receipts.last.id }],
    ) do
      ClientSecretLifecycleJob.perform_now(batch_size: 1)
    end
    while enqueued_jobs.any? { |entry| entry.fetch(:job) == ClientSecretLifecycleJob }
      perform_enqueued_jobs(only: ClientSecretLifecycleJob)
    end

    assert ClientSecretSignInReceipt.exists?(receipts.first.id)
    assert_not ClientSecretSignInReceipt.exists?(receipts.last.id)
    assert hold.reload.active_at?(Client.database_now)
    receipts.each do |receipt|
      token = ClientToken.find_by!(public_id: receipt.root_token_ref)

      assert token.currently_usable?(ClientToken.database_now)
    end
  end
end
