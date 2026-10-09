# frozen_string_literal: true

require "test_helper"
require "concurrent/executor/simple_executor_service"
require "timeout"

class AppSecretParallelLoginTest < ActionDispatch::IntegrationTest
  self.use_transactional_tests = false

  setup do
    @previous_forgery_protection = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    ENV["APP_SECRET_PURGE_DELAY_SECONDS"] = "86400"
    TurnstileVerifierStub.challenge_enabled = true
    TurnstileVerifierStub.challenge_response = { "success" => true }
  end

  teardown do
    ActionController::Base.allow_forgery_protection = @previous_forgery_protection
    TurnstileVerifierStub.challenge_enabled = false
    TurnstileVerifierStub.challenge_response = nil
    if @actor
      @flows&.each do |flow|
        ClientSecretSignInReceipt.where(sign_in_flow_id: flow.id).find_each(&:destroy!)
        ClientAuthCeremonySession.where(local_sign_in_flow_ref: flow.public_id).find_each(&:destroy!)
        ClientSessionLimitResolutionTransaction.where(sign_in_flow_id: flow.id).find_each(&:destroy!)
        ClientAuthAdmissionBinding.where(sign_in_flow_id: flow.id).find_each(&:destroy!)
        ClientAuthAdmissionBinding.where(
          authorization_transaction_id: ClientOidcAuthorizationTransaction.where(
            secret_sign_in_flow_id: flow.id,
          ).select(:id),
        ).find_each(&:destroy!)
        ClientOidcAuthorizationTransaction.where(secret_sign_in_flow_id: flow.id).find_each(&:destroy!)
        flow.reload.destroy!
      end
      ClientToken.where(user_id: @actor.id).find_each(&:destroy!)
      ClientSecretAuditOutbox.where(client_ref: @actor.public_id).find_each(&:destroy!)
      ClientSecretCredential.where(client_id: @actor.id).find_each(&:destroy!)
      ClientSecretIssuance.where(client_id: @actor.id).find_each(&:destroy!)
      # An Identity is physically erased only once it has lapsed and is purgeable.
      @actor.reload.update!(discard_at: @actor.created_at, purge_eligible_at: @actor.created_at)
      @actor.reload.destroy!
    end
  end

  setup do
    auth_host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    base_host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    @actor = Client.create!(status_id: ClientStatus::ACTIVE)
    @identifier = "parallel-secret-#{SecureRandom.hex(4)}@example.com"
    @actor.client_emails.create!(
      address: @identifier, user_email_status_id: ClientEmailStatus::VERIFIED,
    ).finalize_binding!
    token = ClientToken.create!(user: @actor)
    token.update!(
      last_step_up_at: ClientToken.database_now, last_step_up_scope: "settings_secret_credential",
      last_step_up_method: "passkey", last_step_up_session_public_id: token.public_id,
      last_step_up_purpose: "step_up", last_step_up_audience: "step_up:app",
      last_step_up_phishing_resistant: true, last_step_up_user_verified: true,
      last_step_up_credential_ref: "test-step-up", last_step_up_full_reauthentication: false,
    )
    initial_count = ClientToken.where(user_id: @actor.id).count
    context = ActorValuesContext.empty.with(subject: @actor, actor_type: :client, tld: :app, surface: :base)
    issuance = ClientSecretManualReservationIssuer.call!(
      actor_context: context, token: token, operation_id: SecureRandom.uuid, expires_after: 1.minute,
    )
    ClientSecretPresentationIssuer.prepare!(actor_context: context, token: token, issuance: issuance)
    raw = ClientSecretPresentationIssuer.call!(actor_context: context, token: token, issuance: issuance).first
    ClientSecretStorageConfirmationCommitter.call!(actor_context: context, token: token, issuance: issuance)
    browsers =
      Array.new(2) do
        base = open_session
        base.host!(base_host)
        base.https!
        target =
          begin
            fv5073 = base
            fv5069 = base_host
            fv5073.get("/sign", params: { ri: "jp" })
            fv5079 = Nokogiri::HTML(fv5073.response.body).at_css('input[name="authenticity_token"]')["value"]
            fv5073.post(
              "/sign", params: { ri: "jp", authenticity_token: fv5079 }, headers: {
                "Origin" => "https://#{fv5069}", "Sec-Fetch-Site" => "same-origin",
              },
            )
            fv5078 = URI.parse(fv5073.response.location)
            fv5077 = Rack::Utils.parse_query(fv5078.query).fetch("rt")
            fv5070 = JitSecurityJwtRegistry.surface("BASE_APP")
            fv5076, = JWT.decode(
              fv5077, JitSecurityJwtRegistry.public_key_for(
                fv5070.id,
                fv5070.current_kid,
              ), true,
              algorithms: ["ES384"], verify_iss: true, iss: "https://#{fv5069}",
              verify_aud: true, aud: Rails.configuration.x.boot_config.fetch(:jump).audience,
            )
            fv5075 = URI.parse(fv5076.fetch("url"))
            fv5073.host!(fv5075.host)
            fv5073.https!
            fv5073.get(fv5075.request_uri)
            fv5012 = Nokogiri::HTML(fv5073.response.body).at_css("form#base-authorization-ceremony-start-form")
            fv5073.post(
              fv5012["action"],
              params: fv5012.css("input[name]").to_h { |fv5074|
                [fv5074["name"], fv5074["value"]]
              },
              headers: {
                "Origin" => "https://#{fv5069}",
                "Sec-Fetch-Site" => "same-origin",
              },
            )
            fv5072 = URI.parse(fv5073.response.location)
            fv5071 = Rack::Utils.parse_query(fv5072.query).fetch("rt")
            fv5068, = JWT.decode(
              fv5071, JitSecurityJwtRegistry.public_key_for(
                fv5070.id,
                fv5070.current_kid,
              ), true,
              algorithms: ["ES384"], verify_iss: true, iss: "https://#{fv5069}",
              verify_aud: true, aud: Rails.configuration.x.boot_config.fetch(:jump).audience,
            )
            URI.parse(fv5068.fetch("url"))
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
          fv5067 = auth
          fv5066 = target.path
          fv5065 = entry_ref
          fv5064 = :entry_ref
          fv5063 = { ri: "jp" }
          fv5062 = auth_headers
          fv5061 = true
          fv5060 = base
          begin
            fv5004 = fv5067
            fv5016 = fv5066
            fv5058 = fv5065
            fv5059 = fv5064
            fv5025 = fv5063
            fv5018 = fv5062
            fv5046 = fv5061
            fv5045 = fv5060
            fv5021 = nil
            fv5015 = fv5025.merge(fv5059 => fv5058)
            fv5004.get(fv5016, params: fv5015, headers: fv5018)
            fv5052 =
              begin
                fv5057 = fv5004.response.body
                fv5056 = true
                fv5055 = Nokogiri::HTML(fv5057).at_css("form")
                if fv5055.nil? && fv5056
                  nil
                else
                  raise RuntimeError, "Auth continuation form is missing" unless fv5055

                  fv5054 = fv5055.at_css("input[name='authenticity_token']")&.[]("value")
                  raise RuntimeError,
                        "Auth continuation is missing its CSRF token" if fv5054.blank?

                  fv5053 = fv5055.css("input[type='hidden']").to_h do |input|
                    [input["name"], input["value"]]
                  end.except("authenticity_token")
                  [fv5055["action"], fv5054, fv5053]
                end
              end
            if fv5052

              fv5051, fv5049, fv5050 = fv5052

              fv5004.session[BaseAdmissionBrowserBinding::BROWSER_NONCE_SESSION_KEY] ||=
                "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn"
              fv5004.post(
                fv5051, params: fv5050.merge(authenticity_token: fv5049),
                        headers: fv5018,
              )
              fv5048 = fv5004.response.location
              if fv5048.present?

                fv5044 = URI.parse(fv5048)
                fv5043 = fv5044.host
                fv5020 =
                  begin
                    fv5047 = fv5043
                    {
                      ENV.fetch("PUBLIC_BASE_SERVICE_URL") => "app",
                      ENV.fetch("PUBLIC_BASE_CORPORATE_URL") => "com",
                      ENV.fetch("PUBLIC_BASE_STAFF_URL") => "org",
                    }.fetch(fv5047)
                  end
                fv5019 = BaseAuthAdmissionCoordinator.find_admission_binding_by_confirmation!(
                  surface: fv5020, reference: fv5044.path.split("/").fetch(-2),
                )

                if fv5046
                  fv5027 = fv5045 || fv5004
                  fv5027.host!(fv5043)
                  fv5027.https!
                  fv5027.session[BaseAdmissionBrowserBinding::BROWSER_NONCE_SESSION_KEY] ||=
                    "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn"
                  fv5042 = fv5044.request_uri
                  fv5033 = fv5018.merge(
                    "Host" => fv5043,
                    "Origin" => "https://#{fv5043}",
                    "Sec-Fetch-Site" => "same-origin",
                  )
                  fv5027.get(fv5042, headers: fv5033)
                  fv5036, fv5034, fv5035 =
                    begin
                      fv5041 = fv5027.response.body
                      fv5040 = false
                      fv5039 = Nokogiri::HTML(fv5041).at_css("form")
                      if fv5039.nil? && fv5040
                        nil
                      else
                        raise RuntimeError, "Auth continuation form is missing" unless fv5039

                        fv5038 = fv5039.at_css("input[name='authenticity_token']")&.[]("value")
                        raise RuntimeError,
                              "Auth continuation is missing its CSRF token" if fv5038.blank?

                        fv5037 = fv5039.css("input[type='hidden']").to_h do |input|
                          [input["name"], input["value"]]
                        end.except("authenticity_token")
                        [fv5039["action"], fv5038, fv5037]
                      end
                    end
                  fv5027.post(
                    fv5036,
                    params: fv5035.merge(authenticity_token: fv5034),
                    headers: fv5033,
                  )
                  begin
                    fv5000 = fv5027
                    fv5029 = "session"
                    fv5028 = fv5000.response.cookies[fv5029]
                    if fv5028.nil?
                      fv5032 = fv5000.response.headers["Set-Cookie"] || fv5000.response.headers["set-cookie"]
                      fv5031 =
                        if fv5032.is_a?(String) && fv5032.start_with?("[")
                          JSON.parse(fv5032)
                        else
                          Array(fv5032)
                        end
                      fv5030 =
                        fv5031.flat_map { |entry| entry.to_s.split("\n") }.find do |entry|
                          entry.split(";", 2).first.to_s.start_with?("#{fv5029}=")
                        end
                      if fv5030

                        _, fv5028 = fv5030.split(";", 2).first.to_s.split("=", 2)
                        fv5028 = Rack::Utils.unescape(fv5028.to_s)
                      end
                    end

                    unless fv5028.nil?
                      fv5000.cookies.delete(fv5029)
                      # Rack::Test's []= uses its default host. The current request may target a
                      # different surface, so install the cookie against the browser's active host.
                      fv5000.cookies.merge(
                        "#{fv5029}=#{Rack::Utils.escape(fv5028)}",
                        URI.parse("https://#{fv5000.host}/"),
                      )
                    end
                  end
                  fv5026 = fv5027.response.location
                  raise RuntimeError, "Base confirmation did not return to Auth" if fv5026.blank?

                  fv5023 = URI.parse(fv5026)
                  if fv5025[:ri].present?
                    fv5024 = Rack::Utils.parse_nested_query(fv5023.query.to_s)
                    fv5024["ri"] ||= fv5025[:ri].to_s
                    fv5023.query = URI.encode_www_form(fv5024)
                  end
                  fv5004.host!(fv5023.host)
                  fv5004.https!
                  fv5022 = fv5023.request_uri
                  fv5006 = fv5018.merge("Host" => fv5023.host)
                  fv5004.get(fv5022, headers: fv5006)
                else
                  fv5019.confirm_base!(
                    base_token: fv5021,
                    browser_digest: AuthAdmissionBinding.browser_digest(
                      surface: fv5020,
                      entry_ref: fv5019.entry_ref,
                      nonce: "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn",
                    ),
                  )
                  fv5017 = fv5004.host
                  fv5004.host!(fv5017)
                  fv5004.https!
                  fv5006 = fv5018.merge("Host" => fv5017)
                  fv5004.get(fv5016, params: fv5015, headers: fv5006)
                end
                fv5009, fv5007, fv5008 =
                  begin
                    fv5014 = fv5004.response.body
                    fv5013 = false
                    fv5012 = Nokogiri::HTML(fv5014).at_css("form")
                    if fv5012.nil? && fv5013
                      nil
                    else
                      raise RuntimeError, "Auth continuation form is missing" unless fv5012

                      fv5011 = fv5012.at_css("input[name='authenticity_token']")&.[]("value")
                      raise RuntimeError,
                            "Auth continuation is missing its CSRF token" if fv5011.blank?

                      fv5010 = fv5012.css("input[type='hidden']").to_h do |input|
                        [input["name"], input["value"]]
                      end.except("authenticity_token")
                      [fv5012["action"], fv5011, fv5010]
                    end
                  end
                fv5004.post(
                  fv5009,
                  params: fv5008.merge(authenticity_token: fv5007),
                  headers: fv5006,
                )
              end
            end
          end
        end
        auth.get(new_auth_app_sign_in_secret_path(ri: "jp"), headers: auth_headers)
        page = JSON.parse(Nokogiri::HTML(auth.response.body).at_css("script[data-page='app']").text)
        [base, auth, transaction, page.fetch("props").fetch("authenticity_token")]
      end
    ready = Queue.new
    release = Queue.new
    ActiveRecord::Base.connection_handler.clear_active_connections!
    futures =
      browsers.map do |_, auth, _, csrf|
        Concurrent::Future.execute(executor: Concurrent::SimpleExecutorService.new) do
          AppZenithRecord.connection_pool.with_connection(prevent_permanent_checkout: true) do |connection|
            ready << connection.select_value("SELECT pg_backend_pid()")
            release.pop
            auth.post(
              auth_app_sign_in_secret_path(ri: "jp"), params: {
                :secret => raw,
                :authenticity_token => csrf,
                "cf-turnstile-response" => "synthetic",
                :identifier => @identifier,
              }, headers: { "Origin" => "https://#{auth_host}", "Sec-Fetch-Site" => "same-origin" },
            )
            auth.response.status
          end
        ensure
          # Release model-clock leases before the dedicated worker exits.
          ActiveRecord::Base.connection_handler.clear_active_connections!
        end
      end
    pids, statuses =
      Timeout.timeout(20) do
      identities = [ready.pop, ready.pop]
      2.times { release << true }
      [identities, futures.map(&:value!)]
    end
    # Worker writes must be observed through a fresh coordinator-thread read.
    ActiveRecord::Base.clear_query_caches_for_current_thread

    assert_equal 2, pids.uniq.length
    assert_equal [303, 422], statuses.sort
    assert_equal initial_count, ClientToken.where(user_id: @actor.id).count
    base, auth, transaction, = browsers.find { |_, browser, _, _| browser.response.status == 303 }
    flow = transaction.reload.secret_sign_in_flow
    @flows = browsers.filter_map { |_, _, authorization, _| authorization.reload.secret_sign_in_flow }
    auth.follow_redirect!
    auth.follow_redirect! if auth.response.redirect?
    auth.host!(auth_host)
    auth.https!

    assert_equal 200, auth.response.status, "Auth handoff page must be reached"
    csrf_input = Nokogiri::HTML(auth.response.body).at_css('input[name="authenticity_token"]')

    assert csrf_input, "Auth handoff page must contain its protected submission form"
    csrf = csrf_input["value"]
    auth.post(
      auth_app_sign_oidc_handoff_path(ri: "jp"), params: { authenticity_token: csrf }, headers: {
        "Host" => auth_host, "Origin" => "https://#{auth_host}", "Sec-Fetch-Site" => "same-origin",
      },
    )

    assert_equal 303, auth.response.status
    result_target = URI.parse(auth.response.location)
    base.host!(base_host)
    base.https!
    base.get(result_target.request_uri, headers: { "Host" => base_host })

    assert_equal 200, base.response.status
    result_form = Nokogiri::HTML(base.response.body).at_css("form#oidc-authorization-result-form")
    @base, @auth, @flow = base, auth, flow
    @oidc_action = result_form["action"]
    @result_ref = result_form.at_css('input[name="result_ref"]')["value"]
    @transaction_ref = result_form.at_css('input[name="transaction_ref"]')["value"]
    @base_host, @auth_host, @issuance, @raw = base_host, auth_host, issuance, raw
  ensure
    2.times { release << true } if release
    futures&.each { |future| future.wait(10) }
  end

  test "parallel submissions and duplicate callbacks commit one root login and receipt" do
    callbacks =
      Array.new(2) do
        browser = open_session
        browser.host!(@base_host)
        browser.https!
        @base.cookies.to_hash.each { |key, value| browser.cookies[key] = value }
        browser
      end
    ready = Queue.new
    release = Queue.new
    ActiveRecord::Base.connection_handler.clear_active_connections!
    futures =
      callbacks.map do |browser|
        Concurrent::Future.execute(executor: Concurrent::SimpleExecutorService.new) do
          AppTicketRecord.connection_pool.with_connection(prevent_permanent_checkout: true) do |connection|
            ready << connection.select_value("SELECT pg_backend_pid()")
            release.pop
            begin
              fv5005 = browser
              fv5005.post(
                @oidc_action, params: { result_ref: @result_ref, transaction_ref: @transaction_ref },
                              headers: { "Origin" => "https://#{@base_host}", "Sec-Fetch-Site" => "same-origin" },
              )
            end
            browser.response.status
          end
        ensure
          # Release model-clock leases before the dedicated worker exits.
          ActiveRecord::Base.connection_handler.clear_active_connections!
        end
      end
    pids, statuses =
      Timeout.timeout(20) do
      identities = [ready.pop, ready.pop]
      2.times { release << true }
      [identities, futures.map(&:value!)]
    end
    # Worker writes must be observed through a fresh coordinator-thread read.
    ActiveRecord::Base.clear_query_caches_for_current_thread

    assert_equal 2, pids.uniq.length
    assert_equal [303, 303], statuses.sort
    assert_equal 2, ClientToken.where(user_id: @actor.id).count
    credential = ClientSecretCredential.find_by!(issuance_id: @issuance.id)
    receipt = ClientSecretSignInReceipt.find_by!(credential_ref: credential.public_id)

    assert_equal 1, ClientSecretSignInReceipt.where(credential_ref: credential.public_id).count
    assert_equal @flow.reload.token.public_id, receipt.root_token_ref
    assert_predicate @flow.token, :currently_usable?
    assert_equal @actor.public_id, receipt.client_ref
    assert credential.reload.consumed_at
    assert_nil ClientSecretLookupQuery.call(client: @actor, secret: @raw)
    assert_nil @auth.cookies[AuthenticationBase::ACCESS_COOKIE_KEY]
    assert callbacks.any? { |browser| browser.cookies[AuthenticationBase::ACCESS_COOKIE_KEY] }
    now = ClientSignInFlow.database_now
    @flow.update!(issued_at: now - 16.minutes, expires_at: now)

    assert_raises(FlowInvalidTransition) { @flow.expire_sign_in! }
    assert_predicate @flow.reload, :sign_in_completed?
    assert_equal receipt.root_token_ref, @flow.token.public_id
  ensure
    2.times { release << true } if release
    futures&.each { |future| future.wait(10) }
  end

  test "session limit cancellation retires the claim and rejects a callback with the old valid browser locator" do
    (ClientToken::MAX_TOTAL_SESSIONS_PER_USER - 1).times { ClientToken.create!(user: @actor) }
    begin
      fv5004 = @base
      fv5004.post(
        @oidc_action, params: { result_ref: @result_ref, transaction_ref: @transaction_ref },
                      headers: { "Origin" => "https://#{@base_host}", "Sec-Fetch-Site" => "same-origin" },
      )
    end

    assert_equal 303, @base.response.status
    assert_predicate @flow.reload, :sign_in_session_issuance_pending?
    credential = ClientSecretCredential.find_by!(issuance_id: @issuance.id)

    assert_nil credential.consumed_at
    assert_nil ClientSecretLookupQuery.call(client: @actor, secret: @raw)
    @base.get(base_app_sign_in_limitation_path(ri: "jp"))

    assert_equal 200, @base.response.status
    JSON.parse(Nokogiri::HTML(@base.response.body).at_css("script[data-page='app']").text)
    csrf = Nokogiri::HTML(@base.response.body).at_css('meta[name="csrf-token"]')["content"]
    stale_browser = open_session
    stale_browser.host!(@base_host)
    stale_browser.https!
    @base.cookies.to_hash.each { |key, value| stale_browser.cookies[key] = value }
    @base.delete(
      base_app_sign_in_limitation_path(ri: "jp"), params: { authenticity_token: csrf }, headers: {
        "Origin" => "https://#{@base_host}", "Sec-Fetch-Site" => "same-origin",
      },
    )

    assert_equal 303, @base.response.status
    assert_predicate @flow.reload, :sign_in_cancelled?
    assert_operator credential.reload.discard_at, :<=, Client.database_now
    assert_equal 0, ClientSecretSignInReceipt.where(credential_ref: credential.public_id).count
    begin
      fv5003 = stale_browser
      fv5003.post(
        @oidc_action, params: { result_ref: @result_ref, transaction_ref: @transaction_ref },
                      headers: { "Origin" => "https://#{@base_host}", "Sec-Fetch-Site" => "same-origin" },
      )
    end

    assert_equal 400, stale_browser.response.status
    assert_nil stale_browser.cookies[AuthenticationBase::ACCESS_COOKIE_KEY]
    assert_equal 0, ClientSecretSignInReceipt.where(credential_ref: credential.public_id).count
    assert_equal ClientToken::MAX_TOTAL_SESSIONS_PER_USER, ClientToken.where(user_id: @actor.id).count
    assert_equal "flow_canceled", ClientSecretAuditOutbox.find_by!(
      credential_ref: credential.public_id, event_name: "secret.discarded",
    ).reason
  end

  test "an expired admitted flow rejects delayed HTTP completion and irreversibly retires its claim" do
    credential = ClientSecretCredential.find_by!(issuance_id: @issuance.id)
    now = ClientSignInFlow.database_now
    @flow.with_lock { @flow.update!(issued_at: now - 16.minutes, expires_at: now - 0.000001.seconds) }
    begin
      fv5002 = @base
      fv5002.post(
        @oidc_action, params: { result_ref: @result_ref, transaction_ref: @transaction_ref },
                      headers: { "Origin" => "https://#{@base_host}", "Sec-Fetch-Site" => "same-origin" },
      )
    end

    # The existing completion boundary rejects an expired result binding as invalid.
    assert_equal 400, @base.response.status
    assert_equal(
      { "error" => "invalid_request", "error_description" => "login_failed" },
      JSON.parse(@base.response.body),
    )
    assert_nil @base.cookies[AuthenticationBase::ACCESS_COOKIE_KEY]
    assert_equal 1, ClientToken.where(user_id: @actor.id).count
    assert_equal 0, ClientSecretSignInReceipt.where(credential_ref: credential.public_id).count
    assert_nil ClientSecretLookupQuery.call(client: @actor, secret: @raw)
    assert_equal :abandoned, ClientSecretClaimFinalizer.call!(credential: credential, purge_after: 1.day)
    assert_predicate @flow.reload, :sign_in_expired?
    assert_nil credential.reload.consumed_at
    assert_operator credential.discard_at, :<=, Client.database_now
    assert_equal "flow_expired", ClientSecretAuditOutbox.find_by!(
      credential_ref: credential.public_id, event_name: "secret.discarded",
    ).reason
    begin
      fv5001 = @base
      fv5001.post(
        @oidc_action, params: { result_ref: @result_ref, transaction_ref: @transaction_ref },
                      headers: { "Origin" => "https://#{@base_host}", "Sec-Fetch-Site" => "same-origin" },
      )
    end

    assert_equal 400, @base.response.status
    assert_equal 1, ClientToken.where(user_id: @actor.id).count
    assert_equal 0, ClientSecretSignInReceipt.where(credential_ref: credential.public_id).count
  end

  test "partial session revocation keeps the claim pending and sufficient capacity permits its one root login" do
    (ClientToken::MAX_TOTAL_SESSIONS_PER_USER - 1).times { ClientToken.create!(user: @actor) }
    begin
      fv5000 = @base
      fv5000.post(
        @oidc_action, params: { result_ref: @result_ref, transaction_ref: @transaction_ref },
                      headers: { "Origin" => "https://#{@base_host}", "Sec-Fetch-Site" => "same-origin" },
      )
    end

    assert_equal 303, @base.response.status
    assert_predicate @flow.reload, :sign_in_session_issuance_pending?
    credential = ClientSecretCredential.find_by!(issuance_id: @issuance.id)

    assert_nil credential.consumed_at
    assert_nil ClientSecretLookupQuery.call(client: @actor, secret: @raw)
    @base.get(base_app_sign_in_limitation_path(ri: "jp"))

    assert_equal 200, @base.response.status
    page = JSON.parse(Nokogiri::HTML(@base.response.body).at_css("script[data-page='app']").text)
    csrf = Nokogiri::HTML(@base.response.body).at_css('meta[name="csrf-token"]')["content"]
    @base.patch(
      base_app_sign_in_limitation_path(ri: "jp"), params: {
        authenticity_token: csrf, session_ref: page.fetch("props").fetch("sessions").first.fetch("session_ref"),
      }, headers: { "Origin" => "https://#{@base_host}", "Sec-Fetch-Site" => "same-origin" },
    )

    assert_equal 422, @base.response.status
    assert_predicate @flow.reload, :sign_in_session_issuance_pending?
    assert_nil credential.reload.consumed_at
    assert_equal Float::INFINITY, credential.discard_at
    assert_nil ClientSecretLookupQuery.call(client: @actor, secret: @raw)
    page = JSON.parse(Nokogiri::HTML(@base.response.body).at_css("script[data-page='app']").text)

    assert_equal I18n.t("base.app.sign.in.limitations.capacity_still_full"), page.fetch("props").fetch("notice")
    csrf = Nokogiri::HTML(@base.response.body).at_css('meta[name="csrf-token"]')["content"]
    @base.patch(
      base_app_sign_in_limitation_path(ri: "jp"), params: {
        authenticity_token: csrf, session_ref: page.fetch("props").fetch("sessions").first.fetch("session_ref"),
      }, headers: { "Origin" => "https://#{@base_host}", "Sec-Fetch-Site" => "same-origin" },
    )

    assert_equal 302, @base.response.status
    assert_predicate @flow.reload, :sign_in_completed?
    assert credential.reload.consumed_at
    receipt = ClientSecretSignInReceipt.find_by!(credential_ref: credential.public_id)

    assert_equal @flow.token.public_id, receipt.root_token_ref
    assert_predicate @flow.token, :currently_usable?
    assert_equal 2, ClientToken.currently_usable_at.where(user_id: @actor.id).count
    assert_nil ClientSecretLookupQuery.call(client: @actor, secret: @raw)
  end

  private

  # This fixture walks the complete Base-to-Auth browser handoff.
end
