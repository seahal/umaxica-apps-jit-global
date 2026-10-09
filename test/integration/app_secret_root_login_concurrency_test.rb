# frozen_string_literal: true

require "test_helper"
require "concurrent/executor/simple_executor_service"
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
      target =
        begin
          fv5069 = base
          fv5065 = base_host
          fv5069.get("/sign", params: { ri: "jp" })
          fv5075 = Nokogiri::HTML(fv5069.response.body).at_css('input[name="authenticity_token"]')["value"]
          fv5069.post(
            "/sign", params: { ri: "jp", authenticity_token: fv5075 }, headers: {
              "Origin" => "https://#{fv5065}", "Sec-Fetch-Site" => "same-origin",
            },
          )
          fv5074 = URI.parse(fv5069.response.location)
          fv5073 = Rack::Utils.parse_query(fv5074.query).fetch("rt")
          fv5066 = JitSecurityJwtRegistry.surface("BASE_APP")
          fv5072, = JWT.decode(
            fv5073, JitSecurityJwtRegistry.public_key_for(
              fv5066.id,
              fv5066.current_kid,
            ), true,
            algorithms: ["ES384"], verify_iss: true, iss: "https://#{fv5065}",
            verify_aud: true, aud: Rails.configuration.x.boot_config.fetch(:jump).audience,
          )
          fv5071 = URI.parse(fv5072.fetch("url"))
          fv5069.host!(fv5071.host)
          fv5069.https!
          fv5069.get(fv5071.request_uri)
          fv5007 = Nokogiri::HTML(fv5069.response.body).at_css("form#base-authorization-ceremony-start-form")
          fv5069.post(
            fv5007["action"],
            params: fv5007.css("input[name]").to_h { |fv5070|
              [fv5070["name"], fv5070["value"]]
            },
            headers: {
              "Origin" => "https://#{fv5065}",
              "Sec-Fetch-Site" => "same-origin",
            },
          )
          fv5068 = URI.parse(fv5069.response.location)
          fv5067 = Rack::Utils.parse_query(fv5068.query).fetch("rt")
          fv5064, = JWT.decode(
            fv5067, JitSecurityJwtRegistry.public_key_for(
              fv5066.id,
              fv5066.current_kid,
            ), true,
            algorithms: ["ES384"], verify_iss: true, iss: "https://#{fv5065}",
            verify_aud: true, aud: Rails.configuration.x.boot_config.fetch(:jump).audience,
          )
          URI.parse(fv5064.fetch("url"))
        end
      entry_ref = Rack::Utils.parse_query(target.query).fetch("entry_ref")
      admission = BaseAuthAdmissionCoordinator.find_admission_binding!(surface: "app", reference: entry_ref)
      transaction = admission.authorization_transaction
      auth = open_session
      auth.host!(auth_host)
      auth.https!
      auth_headers = {
        "Host" => auth_host, "Origin" => "https://#{auth_host}", "Sec-Fetch-Site" => "same-origin",
      }
      begin
        fv5063 = auth
        fv5062 = target.path
        fv5061 = entry_ref
        fv5060 = :entry_ref
        fv5059 = { ri: "jp" }
        fv5058 = auth_headers
        fv5057 = true
        fv5056 = base
        begin
          fv5004 = fv5063
          fv5011 = fv5062
          fv5054 = fv5061
          fv5055 = fv5060
          fv5020 = fv5059
          fv5013 = fv5058
          fv5042 = fv5057
          fv5041 = fv5056
          fv5016 = nil
          fv5010 = fv5020.merge(fv5055 => fv5054)
          fv5004.get(fv5011, params: fv5010, headers: fv5013)
          fv5048 =
            begin
              fv5053 = fv5004.response.body
              fv5052 = true
              fv5051 = Nokogiri::HTML(fv5053).at_css("form")
              if fv5051.nil? && fv5052
                nil
              else
                raise RuntimeError, "Auth continuation form is missing" unless fv5051

                fv5050 = fv5051.at_css("input[name='authenticity_token']")&.[]("value")
                raise RuntimeError,
                      "Auth continuation is missing its CSRF token" if fv5050.blank?

                fv5049 = fv5051.css("input[type='hidden']").to_h do |input|
                  [input["name"], input["value"]]
                end.except("authenticity_token")
                [fv5051["action"], fv5050, fv5049]
              end
            end
          if fv5048

            fv5047, fv5045, fv5046 = fv5048

            fv5004.session[BaseAdmissionBrowserBinding::BROWSER_NONCE_SESSION_KEY] ||=
              "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn"
            fv5004.post(fv5047, params: fv5046.merge(authenticity_token: fv5045), headers: fv5013)
            fv5044 = fv5004.response.location
            if fv5044.present?

              fv5040 = URI.parse(fv5044)
              fv5039 = fv5040.host
              fv5015 =
                begin
                  fv5043 = fv5039
                  {
                    ENV.fetch("PUBLIC_BASE_SERVICE_URL") => "app",
                    ENV.fetch("PUBLIC_BASE_CORPORATE_URL") => "com",
                    ENV.fetch("PUBLIC_BASE_STAFF_URL") => "org",
                  }.fetch(fv5043)
                end
              fv5014 = BaseAuthAdmissionCoordinator.find_admission_binding_by_confirmation!(
                surface: fv5015, reference: fv5040.path.split("/").fetch(-2),
              )

              if fv5042
                fv5022 = fv5041 || fv5004
                fv5022.host!(fv5039)
                fv5022.https!
                fv5022.session[BaseAdmissionBrowserBinding::BROWSER_NONCE_SESSION_KEY] ||=
                  "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn"
                fv5038 = fv5040.request_uri
                fv5029 = fv5013.merge(
                  "Host" => fv5039,
                  "Origin" => "https://#{fv5039}",
                  "Sec-Fetch-Site" => "same-origin",
                )
                fv5022.get(fv5038, headers: fv5029)
                fv5032, fv5030, fv5031 =
                  begin
                    fv5037 = fv5022.response.body
                    fv5036 = false
                    fv5035 = Nokogiri::HTML(fv5037).at_css("form")
                    if fv5035.nil? && fv5036
                      nil
                    else
                      raise RuntimeError, "Auth continuation form is missing" unless fv5035

                      fv5034 = fv5035.at_css("input[name='authenticity_token']")&.[]("value")
                      raise RuntimeError,
                            "Auth continuation is missing its CSRF token" if fv5034.blank?

                      fv5033 = fv5035.css("input[type='hidden']").to_h do |input|
                        [input["name"], input["value"]]
                      end.except("authenticity_token")
                      [fv5035["action"], fv5034, fv5033]
                    end
                  end
                fv5022.post(
                  fv5032,
                  params: fv5031.merge(authenticity_token: fv5030),
                  headers: fv5029,
                )
                begin
                  fv5023 = fv5022
                  fv5025 = "session"
                  fv5024 = fv5023.response.cookies[fv5025]
                  if fv5024.nil?
                    fv5028 = fv5023.response.headers["Set-Cookie"] || fv5023.response.headers["set-cookie"]
                    fv5027 =
                      if fv5028.is_a?(String) && fv5028.start_with?("[")
                        JSON.parse(fv5028)
                      else
                        Array(fv5028)
                      end
                    fv5026 =
                      fv5027.flat_map { |entry| entry.to_s.split("\n") }.find do |entry|
                        entry.split(";", 2).first.to_s.start_with?("#{fv5025}=")
                      end
                    if fv5026

                      _, fv5024 = fv5026.split(";", 2).first.to_s.split("=", 2)
                      fv5024 = Rack::Utils.unescape(fv5024.to_s)
                    end
                  end

                  unless fv5024.nil?
                    fv5023.cookies.delete(fv5025)
                    # Rack::Test's []= uses its default host. The current request may target a
                    # different surface, so install the cookie against the browser's active host.
                    fv5023.cookies.merge(
                      "#{fv5025}=#{Rack::Utils.escape(fv5024)}",
                      URI.parse("https://#{fv5023.host}/"),
                    )
                  end
                end
                fv5021 = fv5022.response.location
                raise RuntimeError, "Base confirmation did not return to Auth" if fv5021.blank?

                fv5018 = URI.parse(fv5021)
                if fv5020[:ri].present?
                  fv5019 = Rack::Utils.parse_nested_query(fv5018.query.to_s)
                  fv5019["ri"] ||= fv5020[:ri].to_s
                  fv5018.query = URI.encode_www_form(fv5019)
                end
                fv5004.host!(fv5018.host)
                fv5004.https!
                fv5017 = fv5018.request_uri
                fv5000 = fv5013.merge("Host" => fv5018.host)
                fv5004.get(fv5017, headers: fv5000)
              else
                fv5014.confirm_base!(
                  base_token: fv5016,
                  browser_digest: AuthAdmissionBinding.browser_digest(
                    surface: fv5015,
                    entry_ref: fv5014.entry_ref,
                    nonce: "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn",
                  ),
                )
                fv5012 = fv5004.host
                fv5004.host!(fv5012)
                fv5004.https!
                fv5000 = fv5013.merge("Host" => fv5012)
                fv5004.get(fv5011, params: fv5010, headers: fv5000)
              end
              fv5003, fv5001, fv5002 =
                begin
                  fv5009 = fv5004.response.body
                  fv5008 = false
                  fv5007 = Nokogiri::HTML(fv5009).at_css("form")
                  if fv5007.nil? && fv5008
                    nil
                  else
                    raise RuntimeError, "Auth continuation form is missing" unless fv5007

                    fv5006 = fv5007.at_css("input[name='authenticity_token']")&.[]("value")
                    raise RuntimeError,
                          "Auth continuation is missing its CSRF token" if fv5006.blank?

                    fv5005 = fv5007.css("input[type='hidden']").to_h do |input|
                      [input["name"], input["value"]]
                    end.except("authenticity_token")
                    [fv5007["action"], fv5006, fv5005]
                  end
                end
              fv5004.post(
                fv5003,
                params: fv5002.merge(authenticity_token: fv5001),
                headers: fv5000,
              )
            end
          end
        end
      end
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
            Concurrent::Future.execute(executor: Concurrent::SimpleExecutorService.new) do
              # Rack completion runs after the explicit connection scope returns its lease.
              response_finished = []
              begin
                AppZenithRecord.connection_pool.with_connection(prevent_permanent_checkout: true) do |connection|
                  connection.execute("SET lock_timeout = '10000'")
                  ready << connection.select_value("SELECT pg_backend_pid()")
                  release.pop
                  browser.post(
                    result_action, params: { result_ref: result_ref, transaction_ref: transaction_ref },
                                   headers: { "Origin" => "https://#{base_host}", "Sec-Fetch-Site" => "same-origin" },
                                   env: { "rack.response_finished" => response_finished },
                  )
                  browser.response.status
                ensure
                  connection.execute("RESET lock_timeout")
                end
              ensure
                response_finished.reverse_each do |callback|
                  callback.call(browser.request.env, browser.response.status, browser.response.headers, nil)
                end
              end
            rescue StandardError => e
              ready << e
              raise
            ensure
              # Release model-clock leases before the dedicated worker exits.
              ActiveRecord::Base.connection_handler.clear_active_connections!
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
            Concurrent::Future.execute(executor: Concurrent::SimpleExecutorService.new) do
              # Rack completion runs after the explicit connection scope returns its lease.
              response_finished = []
              begin
                AppZenithRecord.connection_pool.with_connection(prevent_permanent_checkout: true) do |connection|
                  connection.execute("SET lock_timeout = '10000'")
                  ready << connection.select_value("SELECT pg_backend_pid()")
                  release.pop
                  base.post(
                    result_action, params: { result_ref: result_ref, transaction_ref: transaction_ref },
                                   headers: { "Origin" => "https://#{base_host}", "Sec-Fetch-Site" => "same-origin" },
                                   env: { "rack.response_finished" => response_finished },
                  )
                  base.response.status
                ensure
                  connection.execute("RESET lock_timeout")
                end
              ensure
                response_finished.reverse_each do |callback|
                  callback.call(base.request.env, base.response.status, base.response.headers, nil)
                end
              end
            rescue StandardError => e
              ready << e
              raise
            ensure
              # Release model-clock leases before the dedicated worker exits.
              ActiveRecord::Base.connection_handler.clear_active_connections!
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
      expected = (outcome == :completion) ? [303, 303] : [400, 400]

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
        # An Identity is physically erased only once it has lapsed and is purgeable.
        actor.reload.update!(discard_at: actor.created_at, purge_eligible_at: actor.created_at)
        actor.reload.destroy!
      end
    end
  end

  private

  # This fixture walks the complete Base-to-Auth browser handoff.
end
