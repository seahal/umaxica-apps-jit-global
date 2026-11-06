# frozen_string_literal: true

require "test_helper"

class AppSecretReceiptCollectionJourneyTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper
  include AuthorityStopCleanup

  self.use_transactional_tests = false
  self.fixture_table_names = []

  setup do
    @previous_lifetimes = ENV.to_h.slice(
      "APP_SECRET_PROOF_RETENTION_SECONDS", "APP_SECRET_OUTBOX_RETENTION_SECONDS", "APP_SECRET_PURGE_DELAY_SECONDS",
    )
    @sign_in_feature = FeatureFlags::REGISTRY.fetch(:sign_in_available_app).name
    @previous_sign_in_available = Flipper.enabled?(@sign_in_feature)
    Flipper.enable(@sign_in_feature)
    ENV["APP_SECRET_PROOF_RETENTION_SECONDS"] = "1"
    ENV["APP_SECRET_OUTBOX_RETENTION_SECONDS"] = "3600"
    ENV["APP_SECRET_PURGE_DELAY_SECONDS"] = "86400"
    @host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    ClientIdentityState.ensure_defaults!
    TurnstileVerifierStub.challenge_enabled = true
    TurnstileVerifierStub.challenge_response = { "success" => true }
  end

  teardown do
    if @previous_lifetimes
      %w(APP_SECRET_PROOF_RETENTION_SECONDS APP_SECRET_OUTBOX_RETENTION_SECONDS
         APP_SECRET_PURGE_DELAY_SECONDS).each do |key|
        ENV[key] = @previous_lifetimes[key]
      end
    end
    if @sign_in_feature
      @previous_sign_in_available ? Flipper.enable(@sign_in_feature) : Flipper.disable(@sign_in_feature)
    end
    TurnstileVerifierStub.challenge_enabled = false
    TurnstileVerifierStub.challenge_response = nil
    cleanup_test_owned_clients!
  end

  test "receipt scan continues past a held canonical login and collects a later committed receipt" do
    ENV["APP_SECRET_PURGE_DELAY_SECONDS"] = "1"
    receipts = []
    @actors =
      Array.new(2) do
        Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
      end
    raw_secrets = ["a" * 32, "b" * 32]
    credentials =
      @actors.zip(raw_secrets).map.with_index do |(actor, raw), index|
        now = Client.database_now
        issuance = ClientSecretIssuance.create!(
          client: actor, origin_operation_id: SecureRandom.uuid, origin: "manual", attempt_number: 1,
          browser_session_ref: PublicId.generate, planned_count: 1, expires_at: now + 1.hour,
          presented_at: now - 1.second, confirmed_at: now, created_at: now - 1.second, updated_at: now,
        )
        ClientSecretCredential.create!(
          client: actor, issuance:, name: "Receipt collection #{index}",
          password_digest: Argon2::Password.create(raw), confirmed_at: now, created_at: now, updated_at: now,
        )
      end
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
    @parent_ids = []
    raw_secrets.each do |raw|
      reset!
      client = OidcClientRegistry.find!("core-app-jp")
      parameters = {
        response_type: "code",
        client_id: client.client_id,
        redirect_uri: client.redirect_uris_by_realm.fetch("client").first,
        code_challenge: "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM",
        code_challenge_method: "S256",
        state: SecureRandom.urlsafe_base64(32),
        nonce: SecureRandom.urlsafe_base64(32),
        scope: "openid profile",
      }
      visa_host = ENV.fetch("PUBLIC_VISA_SERVICE_URL")
      base_browser = open_session
      base_browser.host!(visa_host)
      base_browser.https!
      base_browser.get(
        "/oauth/authorize", params: parameters,
                            headers: {
                              "Host" => visa_host,
                              "Sec-Fetch-Mode" => "navigate",
                              "Sec-Fetch-Dest" => "document",
                              "Sec-Fetch-Site" => "same-origin",
                            },
      )

      jump_host = URI.parse(Rails.configuration.x.boot_config.fetch(:jump).origin.to_s).host
      current_browser = base_browser
      current_host = visa_host
      12.times do
        break unless current_browser.response.redirect?

        target = URI.parse(current_browser.response.location.to_s)
        target = URI.parse("https://#{current_host}#{target}") if target.host.blank?
        if target.host == jump_host
          token = Rack::Utils.parse_query(target.query.to_s).fetch("rt")
          issuer_namespace = (current_host == visa_host) ? "VISA_APP" : "AUTH_APP"
          issuer = JitSecurityJwtRegistry.surface(issuer_namespace)
          payload, = JWT.decode(
            token,
            JitSecurityJwtRegistry.public_key_for(issuer.id, issuer.current_kid),
            true,
            algorithms: ["ES384"],
            verify_iss: true,
            iss: "https://#{current_host}",
            verify_aud: true,
            aud: Rails.configuration.x.boot_config.fetch(:jump).audience,
          )
          target = URI.parse(payload.fetch("url"))
        end

        case target.host
        when visa_host
          base_browser.host!(visa_host)
          base_browser.https!
          base_browser.get(
            target.request_uri, headers: {
              "Host" => visa_host,
              "Sec-Fetch-Mode" => "navigate",
              "Sec-Fetch-Dest" => "document",
              "Sec-Fetch-Site" => "cross-site",
            },
          )
          current_browser = base_browser
          current_host = visa_host
        when @host
          host!(@host)
          https!
          get(
            target.request_uri, headers: {
              "Host" => @host,
              "Sec-Fetch-Mode" => "navigate",
              "Sec-Fetch-Dest" => "document",
              "Sec-Fetch-Site" => "cross-site",
            },
          )
          current_browser = self
          current_host = @host
        else
          raise RuntimeError, "unexpected OIDC bootstrap host: #{target.host.inspect}"
        end
      end
      raise RuntimeError, "OIDC authorization bootstrap did not reach Auth" unless current_browser.equal?(self)
      raise RuntimeError, "OIDC authorization bootstrap did not render Auth entry" unless response.successful?

      transaction = ClientOidcAuthorizationTransaction.find_by!(state: parameters.fetch(:state))
      @parent_ids << transaction.id
      get new_auth_app_sign_in_secret_path(ri: "jp")
      post auth_app_sign_in_secret_path(ri: "jp"), params: {
        identifier: identifiers.fetch(credentials[transactions.length].client_id),
        secret: raw,
        "cf-turnstile-response": "test_token",
      }

      assert_response :see_other
      follow_redirect!
      handoff_target = URI.parse(response.location)
      3.times do
        raise RuntimeError, "OIDC handoff redirect is not on Auth" unless handoff_target.host == @host

        host!(@host)
        https!
        get handoff_target.request_uri, headers: {
          "Host" => @host,
          "Sec-Fetch-Site" => "same-origin",
          "Sec-Fetch-Mode" => "navigate",
          "Sec-Fetch-Dest" => "document",
        }
        break unless response.redirect?

        next_target = URI.parse(response.location)
        break unless next_target.host == @host

        handoff_target = next_target
      end
      raise RuntimeError, "OIDC handoff did not redirect away from Auth" unless response.redirect?

      result_uri = URI.parse(response.location)
      base_browser.host!(result_uri.host)
      base_browser.https!
      base_browser.get(
        result_uri.request_uri, headers: {
          "Host" => result_uri.host,
          "Sec-Fetch-Site" => "cross-site",
          "Sec-Fetch-Mode" => "navigate",
          "Sec-Fetch-Dest" => "document",
        },
      )

      assert_equal 200, base_browser.response.status
      result_form = Nokogiri::HTML(base_browser.response.body).at_css("form#visa-authorization-continuation-form")
      continuation_fields = result_form.css("input[name]").to_h { |input| [input["name"], input["value"]] }
      action = result_form["action"]
      assert_difference("ClientToken.count", 1) do
        base_browser.post(
          action, params: continuation_fields,
                  headers: {
                    "Host" => result_uri.host,
                    "Origin" => OidcIssuer.absolute_url(result_uri.host),
                    "Sec-Fetch-Site" => "same-origin",
                    "Sec-Fetch-Mode" => "navigate",
                    "Sec-Fetch-Dest" => "document",
                  },
        )

        assert_equal 303, base_browser.response.status
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
    # The parents now live until the curfew (WU-06); end them and their Flows directly.
    past = ClientSignInFlow.database_now - 1.second
    transactions.each do |transaction|
      transaction.update_columns(expires_at: past, login_challenge_expires_at: past)
      ClientSignInFlow.where(id: transaction.secret_sign_in_flow_id).update_all(expires_at: past)
    end
    # Commit facts and the audit delivery just made are the last proof times the purger waits on.
    proof_times =
      receipts.map { |receipt|
        [receipt.reload.committed_at, ClientSignInFlow.find(receipt.sign_in_flow_id).completed_at].max
      }
    retention = ClientSecretLifetimesValue.proof_retention
    deadline = (proof_times + [ClientSignInFlow.database_now]).max + retention + 1.second
    Timeout.timeout(15) { sleep 0.01 while ClientSignInFlow.database_now < deadline }
    hold = ClientRetentionHold.create!(client: @actors.first, hold_kind: "legal_hold", reason_code: "legal_hold")
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

  private

  def cleanup_test_owned_clients!
    return if @actors.blank?

    actor_ids = @actors.map(&:id)
    flow_ids = ClientSignInFlow.where(principal_id: actor_ids).pluck(:id)
    parent_ids = ClientOidcAuthorizationTransaction.where(secret_sign_in_flow_id: flow_ids).pluck(:id)
    parent_ids.concat(Array(@parent_ids))
    parent_ids.uniq!

    cleanup_test_owned_admissions!(flow_ids:, parent_ids:)
    cleanup_test_owned_tokens!(actor_ids:)
    cleanup_test_owned_records!(actor_ids:)
    @actors.each { |actor| cleanup_test_owned_actor!(actor) }
  end

  def cleanup_test_owned_admissions!(flow_ids:, parent_ids:)
    ClientSecretSignInReceipt.where(sign_in_flow_id: flow_ids).find_each(&:destroy!)
    ClientSessionLimitResolutionTransaction.where(sign_in_flow_id: flow_ids).delete_all
    ClientSessionLimitResolutionTransaction.where(oidc_authorization_transaction_id: parent_ids).delete_all

    bindings = ClientAuthAdmissionBinding.where(authorization_transaction_id: parent_ids)
    ceremony_ids = bindings.pluck(:auth_ceremony_session_id, :admitted_auth_ceremony_session_id).flatten.compact.uniq
    bindings.delete_all
    ClientOidcAuthorizationTransaction.where(id: parent_ids).update_all(secret_sign_in_flow_id: nil)
    ClientOidcAuthorizationTransaction.where(id: parent_ids).delete_all
    ClientSignInFlow.where(id: flow_ids).find_each(&:destroy!)
    ClientAuthCeremonySession.where(id: ceremony_ids).delete_all
  end

  def cleanup_test_owned_tokens!(actor_ids:)
    token_ids = ClientToken.where(user_id: actor_ids).pluck(:id)
    grant_ids = OpAppGrant.where(client_token_id: token_ids).pluck(:id)
    delete_authority_stops_for!(realm: "app", root_ids: token_ids, grant_ids: grant_ids)
    ClientDeviceSession.where(user_id: actor_ids).update_all(current_refresh_token_id: nil)
    OpAppGrant.where(id: grant_ids).delete_all
    ClientStepUpSession.where(user_token_id: token_ids).delete_all
    ClientToken.where(id: token_ids).delete_all
    ClientDeviceSession.where(user_id: actor_ids).delete_all
  end

  def cleanup_test_owned_records!(actor_ids:)
    actor_public_ids = @actors.map(&:public_id)
    ClientChronicle.where(subject_type: "Client", subject_id: actor_ids.map(&:to_s)).delete_all
    Chronicle.where(subject_type: "Client", subject_id: actor_ids).find_each(&:destroy!)
    ClientSecretAuditOutbox.where(client_ref: actor_public_ids).find_each(&:destroy!)
    ClientSecretCredential.where(client_id: actor_ids).delete_all
    ClientSecretIssuance.where(client_id: actor_ids).delete_all
    ClientRetentionHold.where(client_id: actor_ids).delete_all
    ClientAccount.where(user_id: actor_ids).delete_all
    ClientAuthorityLock.where(client_id: actor_ids).delete_all
    ClientOidcConnection.where(user_id: actor_ids).delete_all
  end

  def cleanup_test_owned_actor!(actor)
    actor.reload.update!(discard_at: actor.created_at, purge_eligible_at: actor.created_at)
    dependent_associations =
      Client.reflect_on_all_associations.filter_map do |association|
        association.name if association.options[:dependent]
      end
    Client.preload(*(dependent_associations + [:client_external_identities])).find(actor.id).destroy!
  end
end
