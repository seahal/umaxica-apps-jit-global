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
      base.get("/sign", params: { ri: "jp" })
      csrf = Nokogiri::HTML(base.response.body).at_css('input[name="authenticity_token"]')["value"]
      base.post(
        "/sign", params: { ri: "jp", authenticity_token: csrf }, headers: {
          "Origin" => "https://#{base_host}", "Sec-Fetch-Site" => "same-origin",
        },
      )
      rt = Rack::Utils.parse_query(URI.parse(base.response.location).query).fetch("rt")
      issuer = JitSecurityJwtRegistry.surface("BASE_APP")
      payload, = JWT.decode(
        rt, JitSecurityJwtRegistry.public_key_for(issuer.id, issuer.current_kid), true,
        algorithms: ["ES384"], verify_iss: true, iss: "https://#{base_host}",
        verify_aud: true, aud: Rails.configuration.x.boot_config.fetch(:jump).audience,
      )
      target = URI.parse(payload.fetch("url"))
      flow = ClientSignInFlow.find_by!(public_id: Rack::Utils.parse_query(target.query).fetch("entry_ref"))
      auth = open_session
      auth.host!(auth_host)
      auth.https!
      auth.get(target.request_uri)
      csrf = Nokogiri::HTML(auth.response.body).at_css('input[name="authenticity_token"]')["value"]
      auth.post(
        auth_app_sign_in_path(ri: "jp"), params: {
          entry_ref: flow.public_id, authenticity_token: csrf,
        }, headers: { "Origin" => "https://#{auth_host}", "Sec-Fetch-Site" => "same-origin" },
      )
      auth.get(new_auth_app_sign_in_secret_path(ri: "jp"))
      page = JSON.parse(Nokogiri::HTML(auth.response.body).at_css("script[data-page='app']").text)
      auth.post(
        auth_app_sign_in_secret_path(ri: "jp"), params: {
          :secret => raw,
          :authenticity_token => page.fetch("props").fetch("authenticity_token"),
          "cf-turnstile-response" => "synthetic",
        }, headers: { "Origin" => "https://#{auth_host}", "Sec-Fetch-Site" => "same-origin" },
      )
      auth.follow_redirect!
      auth.follow_redirect! if auth.response.redirect?
      csrf = Nokogiri::HTML(auth.response.body).at_css('input[name="authenticity_token"]')["value"]
      auth.post(
        auth_app_sign_handoff_path(ri: "jp"), params: { authenticity_token: csrf }, headers: {
          "Origin" => "https://#{auth_host}", "Sec-Fetch-Site" => "same-origin",
        },
      )
      result = Nokogiri::HTML(auth.response.body).at_css('input[name="result"]')["value"]
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
                  base_app_sign_completion_path(ri: "jp"), params: {
                    result: result, transaction_ref: flow.public_id,
                  }, headers: { "Origin" => "https://#{auth_host}", "Sec-Fetch-Site" => "same-site" },
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
                  base_app_sign_completion_path(ri: "jp"), params: {
                    result: result, transaction_ref: flow.public_id,
                  }, headers: { "Origin" => "https://#{auth_host}", "Sec-Fetch-Site" => "same-site" },
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
          base_app_sign_completion_path(ri: "jp"),
          params: { result: result, transaction_ref: flow.public_id },
          headers: { "Origin" => "https://#{auth_host}", "Sec-Fetch-Site" => "same-site" },
        )
        statuses << duplicate.response.status
      end
      expected = (outcome == :completion) ? [303, 409] : [302, 400]

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
        assert_equal 1, [base, duplicate].count { |browser| browser.cookies[AuthenticationBase::ACCESS_COOKIE_KEY] }
      else
        assert_equal "/", URI.parse(duplicate.response.location).path
        duplicate.follow_redirect!

        assert_equal 200, duplicate.response.status
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
end
