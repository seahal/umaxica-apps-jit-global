# frozen_string_literal: true

require "test_helper"
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
        flow.reload.destroy!
      end
      ClientToken.where(user_id: @actor.id).find_each(&:destroy!)
      ClientSecretAuditOutbox.where(client_ref: @actor.public_id).find_each(&:destroy!)
      ClientSecretCredential.where(client_id: @actor.id).find_each(&:destroy!)
      ClientSecretIssuance.where(client_id: @actor.id).find_each(&:destroy!)
      @actor.reload.destroy!
    end
  end

  setup do
    auth_host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    base_host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    @actor = Client.create!(status_id: ClientStatus::ACTIVE)
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
    @flows = []
    browsers =
      Array.new(2) do
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
        entry_ref = Rack::Utils.parse_query(target.query).fetch("entry_ref")
        flow = ClientSignInFlow.find_by!(public_id: entry_ref)
        @flows << flow
        auth = open_session
        auth.host!(auth_host)
        auth.https!
        auth.get(target.request_uri)
        csrf = Nokogiri::HTML(auth.response.body).at_css('input[name="authenticity_token"]')["value"]
        auth.post(
          auth_app_sign_in_path(ri: "jp"), params: { entry_ref: entry_ref, authenticity_token: csrf }, headers: {
            "Origin" => "https://#{auth_host}", "Sec-Fetch-Site" => "same-origin",
          },
        )
        auth.get(new_auth_app_sign_in_secret_path(ri: "jp"))
        page = JSON.parse(Nokogiri::HTML(auth.response.body).at_css("script[data-page='app']").text)
        [base, auth, flow, page.fetch("props").fetch("authenticity_token")]
      end
    ready = Queue.new
    release = Queue.new
    ActiveRecord::Base.connection_handler.clear_active_connections!
    futures =
      browsers.map do |_, auth, _, csrf|
        Concurrent::Future.execute do
          AppZenithRecord.connection_pool.with_connection(prevent_permanent_checkout: true) do |connection|
            ready << connection.select_value("SELECT pg_backend_pid()")
            release.pop
            auth.post(
              auth_app_sign_in_secret_path(ri: "jp"), params: {
                :secret => raw, :authenticity_token => csrf, "cf-turnstile-response" => "synthetic",
              }, headers: { "Origin" => "https://#{auth_host}", "Sec-Fetch-Site" => "same-origin" },
            )
            auth.response.status
          end
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
    base, auth, flow, = browsers.find { |_, browser, _, _| browser.response.status == 303 }
    auth.follow_redirect!
    auth.follow_redirect! if auth.response.redirect?

    assert_equal 200, auth.response.status, "Auth handoff page must be reached"
    csrf_input = Nokogiri::HTML(auth.response.body).at_css('input[name="authenticity_token"]')

    assert csrf_input, "Auth handoff page must contain its protected submission form"
    csrf = csrf_input["value"]
    auth.post(
      auth_app_sign_handoff_path(ri: "jp"), params: { authenticity_token: csrf }, headers: {
        "Origin" => "https://#{auth_host}", "Sec-Fetch-Site" => "same-origin",
      },
    )

    assert_equal 200, auth.response.status
    result = Nokogiri::HTML(auth.response.body).at_css('input[name="result"]')["value"]
    @base, @auth, @flow, @result = base, auth, flow, result
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
        Concurrent::Future.execute do
          AppTicketRecord.connection_pool.with_connection(prevent_permanent_checkout: true) do |connection|
            ready << connection.select_value("SELECT pg_backend_pid()")
            release.pop
            browser.post(
              base_app_sign_completion_path(ri: "jp"), params: {
                result: @result, transaction_ref: @flow.public_id,
              }, headers: { "Origin" => "https://#{@auth_host}", "Sec-Fetch-Site" => "same-site" },
            )
            browser.response.status
          end
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
    assert_includes statuses, 303
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
    @base.post(
      base_app_sign_completion_path(ri: "jp"), params: {
        result: @result, transaction_ref: @flow.public_id,
      }, headers: { "Origin" => "https://#{@auth_host}", "Sec-Fetch-Site" => "same-site" },
    )

    assert_equal 303, @base.response.status
    assert_predicate @flow.reload, :sign_in_session_limit_pending?
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
    stale_browser.post(
      base_app_sign_completion_path(ri: "jp"), params: {
        result: @result, transaction_ref: @flow.public_id,
      }, headers: { "Origin" => "https://#{@auth_host}", "Sec-Fetch-Site" => "same-site" },
    )

    assert_equal 302, stale_browser.response.status
    assert_equal base_app_root_path, URI.parse(stale_browser.response.location).path
    stale_browser.follow_redirect!

    assert_equal 200, stale_browser.response.status
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
    @base.post(
      base_app_sign_completion_path(ri: "jp"), params: {
        result: @result, transaction_ref: @flow.public_id,
      }, headers: { "Origin" => "https://#{@auth_host}", "Sec-Fetch-Site" => "same-site" },
    )

    # The existing completion boundary rejects an expired result binding as invalid.
    assert_equal 400, @base.response.status
    assert_equal I18n.t("errors.messages.invalid_request"), @base.response.body
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
    @base.post(
      base_app_sign_completion_path(ri: "jp"), params: {
        result: @result, transaction_ref: @flow.public_id,
      }, headers: { "Origin" => "https://#{@auth_host}", "Sec-Fetch-Site" => "same-site" },
    )

    assert_equal 302, @base.response.status
    assert_equal 1, ClientToken.where(user_id: @actor.id).count
    assert_equal 0, ClientSecretSignInReceipt.where(credential_ref: credential.public_id).count
  end

  test "partial session revocation keeps the claim pending and sufficient capacity permits its one root login" do
    (ClientToken::MAX_TOTAL_SESSIONS_PER_USER - 1).times { ClientToken.create!(user: @actor) }
    @base.post(
      base_app_sign_completion_path(ri: "jp"), params: {
        result: @result, transaction_ref: @flow.public_id,
      }, headers: { "Origin" => "https://#{@auth_host}", "Sec-Fetch-Site" => "same-site" },
    )

    assert_equal 303, @base.response.status
    assert_predicate @flow.reload, :sign_in_session_limit_pending?
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
    assert_predicate @flow.reload, :sign_in_session_limit_pending?
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

    assert_equal 303, @base.response.status
    assert_predicate @flow.reload, :sign_in_completed?
    assert credential.reload.consumed_at
    receipt = ClientSecretSignInReceipt.find_by!(credential_ref: credential.public_id)

    assert_equal @flow.token.public_id, receipt.root_token_ref
    assert_predicate @flow.token, :currently_usable?
    assert_equal 2, ClientToken.currently_usable_at.where(user_id: @actor.id).count
    assert_nil ClientSecretLookupQuery.call(client: @actor, secret: @raw)
  end
end
