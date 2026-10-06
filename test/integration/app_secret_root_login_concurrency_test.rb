# frozen_string_literal: true

require "test_helper"
require "timeout"

class AppSecretRootLoginConcurrencyTest < ActionDispatch::IntegrationTest
  self.use_transactional_tests = false
  self.fixture_table_names = %w(
    client_statuses client_visibilities client_mfa_levels client_mfa_statuses
    client_token_statuses client_token_kinds client_token_binding_methods client_token_dbsc_statuses
  )

  setup do
    @previous_forgery_protection = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    @previous_purge_delay = ENV["APP_SECRET_PURGE_DELAY_SECONDS"]
    ENV["APP_SECRET_PURGE_DELAY_SECONDS"] = "86400"
    TurnstileVerifierStub.challenge_enabled = true
    TurnstileVerifierStub.challenge_response = { "success" => true }
    ClientIdentityState.ensure_defaults!
  end

  teardown do
    ActionController::Base.allow_forgery_protection = @previous_forgery_protection
    ENV["APP_SECRET_PURGE_DELAY_SECONDS"] = @previous_purge_delay
    TurnstileVerifierStub.challenge_enabled = false
    TurnstileVerifierStub.challenge_response = nil
  end

  %i(completion cancellation expiration).each do |outcome|
    test "Base Secret results racing #{outcome} cannot establish a second or terminal root login" do
      actor = Client.create!(status_id: ClientStatus::ACTIVE)
      identifier = "root-secret-#{SecureRandom.hex(4)}@example.com"
      actor.client_emails.create!(
        address: identifier, user_email_status_id: ClientEmailStatus::VERIFIED,
      ).finalize_binding!
      token = ClientToken.create!(user: actor)
      token.update!(
        last_step_up_at: ClientToken.database_now, last_step_up_scope: "settings_secret_credential",
        last_step_up_method: "passkey", last_step_up_session_public_id: token.public_id,
        last_step_up_purpose: "step_up", last_step_up_audience: "step_up:app",
        last_step_up_phishing_resistant: true, last_step_up_user_verified: true,
        last_step_up_credential_ref: "test-step-up", last_step_up_full_reauthentication: false,
      )
      context = ActorValuesContext.empty.with(subject: actor, actor_type: :client, tld: :app, surface: :base)
      issuance = ClientSecretManualReservationIssuer.call!(
        actor_context: context, token: token, operation_id: SecureRandom.uuid, expires_after: 1.minute,
      )
      ClientSecretPresentationIssuer.prepare!(actor_context: context, token: token, issuance: issuance)
      raw = ClientSecretPresentationIssuer.call!(actor_context: context, token: token, issuance: issuance).first
      ClientSecretStorageConfirmationCommitter.call!(actor_context: context, token: token, issuance: issuance)
      base_host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
      auth_host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
      base = open_session
      base.host!(base_host)
      base.https!
      target = app_oidc_auth_target!(base, base_host: base_host)
      entry_ref = Rack::Utils.parse_query(target.query).fetch("entry_ref")
      admission = BaseAuthAdmissionCoordinator.find_admission_binding!(surface: "app", reference: entry_ref)
      transaction = admission.authorization_transaction
      auth = open_session
      auth.host!(auth_host)
      auth.https!
      auth_headers = {
        "Host" => auth_host, "Origin" => "https://#{auth_host}", "Sec-Fetch-Site" => "same-origin",
      }
      redeem_auth_ceremony_session!(
        auth, target.path, reference: entry_ref, params: { ri: "jp" }, headers: auth_headers,
                           confirm_via_http: true, base_browser: base,
      )
      auth.get(new_auth_app_sign_in_secret_path(ri: "jp"))
      page = JSON.parse(Nokogiri::HTML(auth.response.body).at_css("script[data-page='app']").text)
      auth.post(
        auth_app_sign_in_secret_path(ri: "jp"), params: {
          :secret => raw,
          :identifier => identifier,
          :authenticity_token => page.fetch("props").fetch("authenticity_token"),
          "cf-turnstile-response" => "synthetic",
        }, headers: auth_headers,
      )
      auth.follow_redirect!
      auth.follow_redirect! if auth.response.redirect?
      csrf = Nokogiri::HTML(auth.response.body).at_css('input[name="authenticity_token"]')["value"]
      auth.post(
        auth_app_sign_oidc_handoff_path(ri: "jp"), params: { authenticity_token: csrf }, headers: auth_headers,
      )

      assert_equal 303, auth.response.status
      result_uri = URI.parse(auth.response.location)
      base.host!(result_uri.host)
      base.https!
      base.get(result_uri.request_uri, headers: { "Host" => result_uri.host })
      result_form = Nokogiri::HTML(base.response.body).at_css("form#oidc-authorization-result-form")
      result_action = result_form["action"]
      result_ref = result_form.at_css('input[name="result_ref"]')["value"]
      transaction_ref = result_form.at_css('input[name="transaction_ref"]')["value"]
      flow = transaction.reload.secret_sign_in_flow
      credential = ClientSecretCredential.find_by!(issuance_id: issuance.id)
      ceremony = ClientAuthCeremonySession.find(credential.claim_ceremony_session_id)
      duplicate = open_session
      duplicate.host!(base_host)
      duplicate.https!
      # Two in-flight requests from the same legitimate pre-completion browser.
      base.cookies.to_hash.each { |name, value| duplicate.cookies[name] = value }
      ready = Queue.new
      release = Queue.new
      ActiveRecord::Base.connection_handler.clear_active_connections!
      futures = nil
      if outcome == :completion
        futures =
          [base, duplicate].map do |browser|
            Concurrent::Future.execute do
              AppZenithRecord.connection_pool.with_connection(prevent_permanent_checkout: true) do |connection|
                connection.execute("SET lock_timeout = '10000'")
                ready << connection.select_value("SELECT pg_backend_pid()")
                release.pop
                browser.post(
                  result_action, params: { result_ref: result_ref, transaction_ref: transaction_ref },
                                 headers: { "Origin" => "https://#{base_host}", "Sec-Fetch-Site" => "same-origin" },
                )
                browser.response.status
              ensure
                connection.execute("RESET lock_timeout")
              end
            rescue StandardError => e
              ready << e
              raise
            end
          end
        pids = Timeout.timeout(10) { [ready.pop, ready.pop] }
        pids.each { |entry| raise entry if entry.is_a?(Exception) }
        2.times { release << true }

        assert_equal 2, pids.uniq.length
      else
        # The configured two-connection pool supports one observer and one
        # blocked HTTP request. The second stale callback is sent afterward.
        actor.with_lock do
          futures = [
            Concurrent::Future.execute do
              AppZenithRecord.connection_pool.with_connection(prevent_permanent_checkout: true) do |connection|
                connection.execute("SET lock_timeout = '10000'")
                ready << connection.select_value("SELECT pg_backend_pid()")
                release.pop
                base.post(
                  result_action, params: { result_ref: result_ref, transaction_ref: transaction_ref },
                                 headers: { "Origin" => "https://#{base_host}", "Sec-Fetch-Site" => "same-origin" },
                )
                base.response.status
              ensure
                connection.execute("RESET lock_timeout")
              end
            rescue StandardError => e
              ready << e
              raise
            end,
          ]
          pid = Timeout.timeout(10) { ready.pop }
          raise pid if pid.is_a?(Exception)

          release << true
          Timeout.timeout(10) do
            loop do
              if futures.first.complete?
                raise RuntimeError, "completion escaped the Client lock barrier"
              end

              blocked =
                Client.uncached do
                  Client.lease_connection.select_value("SELECT cardinality(pg_blocking_pids(#{Integer(pid)})) > 0")
                end
              break if blocked

              Thread.pass
            end
          end

          assert_not_equal Client.lease_connection.select_value("SELECT pg_backend_pid()"), pid
          AppTicketRecord.transaction do
            flow.lock!
            if outcome == :cancellation
              flow.halt_sign_in!
            else
              flow.update!(expires_at: ClientSignInFlow.database_now)
              flow.expire_sign_in!
            end
          end
        end
      end
      statuses = Timeout.timeout(15) { futures.map(&:value!) }
      unless outcome == :completion
        duplicate.post(
          result_action, params: { result_ref: result_ref, transaction_ref: transaction_ref },
                         headers: { "Origin" => "https://#{base_host}", "Sec-Fetch-Site" => "same-origin" },
        )
        statuses << duplicate.response.status
      end
      expected = (outcome == :completion) ? [302, 302] : [400, 400]

      assert_equal expected, statuses.sort
      assert_nil ClientSecretLookupQuery.call(client: actor, secret: raw)
      assert_equal (outcome == :completion) ? 2 : 1, ClientToken.where(user_id: actor.id).count
      receipts = ClientSecretSignInReceipt.where(credential_ref: credential.public_id)

      assert_equal (outcome == :completion) ? 1 : 0, receipts.count
      if outcome == :completion
        root = flow.reload.token

        assert_equal root.public_id, receipts.first.root_token_ref
        assert_equal actor.public_id, receipts.first.client_ref
        assert credential.reload.consumed_at
        assert_predicate root, :currently_usable?
        assert_equal 2, [base, duplicate].count { |browser| browser.cookies[AuthenticationBase::ACCESS_COOKIE_KEY] }
      else
        assert_equal 400, duplicate.response.status
        assert_nil flow.reload.token_id
        assert_nil credential.reload.consumed_at
        assert_equal :abandoned, ClientSecretClaimFinalizer.call!(credential: credential, purge_after: 1.day)
        assert_nil ClientSecretLookupQuery.call(client: actor, secret: raw)
        assert [base, duplicate].all? { |browser| browser.cookies[AuthenticationBase::ACCESS_COOKIE_KEY].nil? }
      end
    ensure
      2.times { release << true } if release
      futures&.each { |future| future.wait(15) }
      if actor
        ClientSecretSignInReceipt.where(client_ref: actor.public_id).find_each(&:destroy!)
        if flow
          ClientSessionLimitResolutionTransaction.where(sign_in_flow_id: flow.id).find_each(&:destroy!)
          transaction_rows = ClientOidcAuthorizationTransaction.where(secret_sign_in_flow_id: flow.id)
          ClientAuthAdmissionBinding.where(
            authorization_transaction_id: transaction_rows.select(:id),
          ).find_each(&:destroy!)
          transaction_rows.find_each(&:destroy!)
          ClientAuthAdmissionBinding.where(sign_in_flow_id: flow.id).find_each(&:destroy!)
        end
        ceremony&.destroy!
        flow&.destroy!
        Chronicle.where(subject_type: "Client", subject_id: actor.id).find_each(&:destroy!)
        ClientSecretAuditOutbox.where(client_ref: actor.public_id).find_each(&:destroy!)
        ClientSecretCredential.where(client_id: actor.id).find_each(&:destroy!)
        ClientSecretIssuance.where(client_id: actor.id).find_each(&:destroy!)
        ClientToken.where(user_id: actor.id).find_each(&:destroy!)
        actor.reload.destroy!
      end
    end
  end

  private

  def app_oidc_auth_target!(base, base_host:)
    base.get("/sign", params: { ri: "jp" })
    csrf = Nokogiri::HTML(base.response.body).at_css('input[name="authenticity_token"]')["value"]
    base.post(
      "/sign", params: { ri: "jp", authenticity_token: csrf }, headers: {
        "Origin" => "https://#{base_host}", "Sec-Fetch-Site" => "same-origin",
      },
    )
    gateway = URI.parse(base.response.location)
    rt = Rack::Utils.parse_query(gateway.query).fetch("rt")
    issuer = JitSecurityJwtRegistry.surface("BASE_APP")
    payload, = JWT.decode(
      rt, JitSecurityJwtRegistry.public_key_for(issuer.id, issuer.current_kid), true,
      algorithms: ["ES384"], verify_iss: true, iss: "https://#{base_host}",
      verify_aud: true, aud: Rails.configuration.x.boot_config.fetch(:jump).audience,
    )
    authorization = URI.parse(payload.fetch("url"))
    base.host!(authorization.host)
    base.https!
    base.get(authorization.request_uri)
    form = Nokogiri::HTML(base.response.body).at_css("form#base-authorization-ceremony-start-form")
    base.post(
      form["action"], params: form.css("input[name]").to_h { |input| [input["name"], input["value"]] },
                      headers: { "Origin" => "https://#{base_host}", "Sec-Fetch-Site" => "same-origin" },
    )
    result_gateway = URI.parse(base.response.location)
    result_rt = Rack::Utils.parse_query(result_gateway.query).fetch("rt")
    result_payload, = JWT.decode(
      result_rt, JitSecurityJwtRegistry.public_key_for(issuer.id, issuer.current_kid), true,
      algorithms: ["ES384"], verify_iss: true, iss: "https://#{base_host}",
      verify_aud: true, aud: Rails.configuration.x.boot_config.fetch(:jump).audience,
    )
    URI.parse(result_payload.fetch("url"))
  end
end
