# frozen_string_literal: true

require "test_helper"
require "concurrent/executor/simple_executor_service"
require "timeout"

class AppSecretParallelLoginTest < ActionDispatch::IntegrationTest
  include AuthorityStopCleanup

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
        ClientSessionLimitResolutionTransaction.where(sign_in_flow_id: flow.id).find_each(&:destroy!)
        ClientAuthAdmissionBinding.where(
          authorization_transaction_id: ClientOidcAuthorizationTransaction.where(
            secret_sign_in_flow_id: flow.id,
          ).select(:id),
        ).find_each(&:destroy!)
        ClientOidcAuthorizationTransaction.where(secret_sign_in_flow_id: flow.id).find_each(&:destroy!)
        flow.reload.destroy!
      end
      token_ids = ClientToken.where(user_id: @actor.id).pluck(:id)
      delete_authority_stops_for!(realm: "app", root_ids: token_ids)
      OpBaseAppRecord.connected_to(role: :writing) do
        grant_ids = OpAppGrant.where(client_token_id: token_ids).pluck(:id)
        OpAppGrantLogoutHint.where(grant_id: grant_ids).delete_all
        OpAppGrant.where(id: grant_ids).delete_all
      end
      ClientToken.where(user_id: @actor.id).find_each(&:destroy!)
      ClientSecretAuditOutbox.where(client_ref: @actor.public_id).find_each(&:destroy!)
      ClientSecretCredential.where(client_id: @actor.id).find_each(&:destroy!)
      ClientSecretIssuance.where(client_id: @actor.id).find_each(&:destroy!)
      # An Identity is physically erased only once it has lapsed and is purgeable.
      @actor.reload.update!(discard_at: @actor.created_at, purge_eligible_at: @actor.created_at)
      destroy_test_client_after_cross_database_cleanup!(@actor)
    end
  end

  setup do
    auth_host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    visa_host = visa_host_for_test_surface(:app)
    @actor = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
    @identifier = "parallel-secret-#{SecureRandom.hex(4)}@example.com"
    @actor.client_emails.create!(
      address: @identifier, user_email_status_id: ClientEmailStatus::VERIFIED,
    ).finalize_binding!
    token = ClientToken.create!(authentication_epoch: 0, user: @actor)
    now = ClientToken.database_now
    token.update!(authentication_event_at: now, established_authentication_method: "passkey")
    token.rotate_refresh_token!(now:)
    token.device_session_record!
    oidc_client = OidcClientRegistry.find!("base-app-ww")
    @step_up_grant = OpAppGrant.create!(
      authentication_epoch: token.authentication_epoch, client_token: token, oidc_client_id: oidc_client.client_id,
      oidc_scope: "openid profile", oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16),
      oidc_auth_time: Time.at(now.to_i).utc, oidc_acr: StepUpEvidenceResolver::STEP_UP_ACR,
      oidc_amr: JSON.generate(["passkey"]), refresh_token_expires_at: now + 1.hour,
    )
    @step_up_grant.issue_refresh_token!(now:)
    step_up_evidence = StepUpEvidenceValue.new(
      acr: @step_up_grant.oidc_acr, amr: ["passkey"], auth_time: now.to_i, sid: @step_up_grant.public_id,
      sub: OidcSubject.for(@actor, resource_type: "client"), client_id: oidc_client.client_id,
      aud: [oidc_client.aud], jti: @step_up_grant.oidc_jti,
    )
    initial_count = ClientToken.where(user_id: @actor.id).count
    context = ActorValuesContext.empty.with(subject: @actor, actor_type: :client, tld: :app, surface: :base)
    issuance = ClientSecretManualReservationIssuer.call!(
      actor_context: context, token: token, operation_id: SecureRandom.uuid, expires_after: 1.minute,
      step_up_evidence:,
    )
    ClientSecretPresentationIssuer.prepare!(actor_context: context, token: token, issuance:, step_up_evidence:)
    raw = ClientSecretPresentationIssuer.call!(actor_context: context, token: token, issuance:, step_up_evidence:).first
    ClientSecretStorageConfirmationCommitter.call!(actor_context: context, token: token, issuance:, step_up_evidence:)
    client = OidcClientRegistry.find!("core-app-jp")
    browsers = Array.new(2) { prepare_secret_login_attempt(client:, auth_host:, visa_host:) }
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
    flow = ClientSignInFlow.find_by(id: transaction.reload.secret_sign_in_flow_id)
    @flows =
      browsers.filter_map do |_, _, authorization, _|
        ClientSignInFlow.find_by(id: authorization.reload.secret_sign_in_flow_id)
      end
    action, continuation_fields = visa_result_continuation!(
      visa_browser: base, auth_browser: auth, auth_host:, visa_host:,
    )
    @base, @auth, @flow = base, auth, flow
    @oidc_action = action
    @continuation_fields = continuation_fields
    @base_host, @auth_host, @issuance, @raw = visa_host, auth_host, issuance, raw
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
        copy_browser_cookies!(source: @base, destination: browser, host: @base_host)
        session_cookie = Rails.application.config.session_options.fetch(:key)

        assert_includes(
          browser.cookies.to_hash.keys,
          session_cookie,
          "The Visa browser session cookie must be copied with the Visa host scope",
        )
        browser
      end
    ready = Queue.new
    release = Queue.new
    ActiveRecord::Base.connection_handler.clear_active_connections!
    futures =
      callbacks.map do |browser|
        Concurrent::Future.execute(executor: Concurrent::SimpleExecutorService.new) do
          OpBaseAppRecord.connection_pool.with_connection(prevent_permanent_checkout: true) do |connection|
            ready << connection.select_value("SELECT pg_backend_pid()")
            release.pop
            begin
              fv5005 = browser
              fv5005.post(
                @oidc_action, params: @continuation_fields,
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
    # WU-27/D-104: one concurrent result commits; the other sees the finalized
    # terminal and cannot issue a second Root Session.
    assert_equal [303, 400], statuses.sort
    assert_equal 2, ClientToken.where(user_id: @actor.id).count
    credential = ClientSecretCredential.find_by!(issuance_id: @issuance.id)
    receipt = ClientSecretSignInReceipt.find_by!(credential_ref: credential.public_id)

    assert_equal 1, ClientSecretSignInReceipt.where(credential_ref: credential.public_id).count
    root = ClientToken.find_by!(id: @flow.reload.token_id, user_id: @actor.id)

    assert_equal root.public_id, receipt.root_token_ref
    assert_predicate root, :currently_usable?
    assert_equal @actor.public_id, receipt.client_ref
    assert credential.reload.consumed_at
    assert_nil ClientSecretLookupQuery.call(client: @actor, secret: @raw)
    @auth.host!(@auth_host)
    @auth.https!

    assert_nil @auth.cookies[AuthenticationBase::ACCESS_COOKIE_KEY]
    assert callbacks.any? { |browser| browser.cookies[AuthenticationBase::ACCESS_COOKIE_KEY] }
    now = ClientSignInFlow.database_now
    @flow.update!(issued_at: now - 16.minutes, expires_at: now)

    assert_raises(FlowInvalidTransition) { @flow.expire_sign_in! }
    assert_predicate @flow.reload, :sign_in_completed?
    root = ClientToken.find_by!(id: @flow.token_id, user_id: @actor.id)

    assert_equal receipt.root_token_ref, root.public_id
  ensure
    2.times { release << true } if release
    futures&.each { |future| future.wait(10) }
  end

  test "session limit cancellation retires the claim and rejects a callback with the old valid browser locator" do
    (ClientToken::MAX_SESSIONS_PER_USER - 1).times { ClientToken.create!(authentication_epoch: 0, user: @actor) }
    begin
      fv5004 = @base
      fv5004.post(
        @oidc_action, params: @continuation_fields,
                      headers: { "Origin" => "https://#{@base_host}", "Sec-Fetch-Site" => "same-origin" },
      )
    end

    assert_equal 303, @base.response.status
    assert_predicate @flow.reload, :sign_in_session_issuance_pending?
    credential = ClientSecretCredential.find_by!(issuance_id: @issuance.id)

    assert_nil credential.consumed_at
    assert_nil ClientSecretLookupQuery.call(client: @actor, secret: @raw)
    @base.get(visa_app_sign_in_limitation_path(ri: "jp"))

    assert_equal 200, @base.response.status
    JSON.parse(Nokogiri::HTML(@base.response.body).at_css("script[data-page='app']").text)
    csrf = Nokogiri::HTML(@base.response.body).at_css('meta[name="csrf-token"]')["content"]
    stale_browser = open_session
    stale_browser.host!(@base_host)
    stale_browser.https!
    copy_browser_cookies!(source: @base, destination: stale_browser, host: @base_host)
    @base.delete(
      visa_app_sign_in_limitation_path(ri: "jp"), params: { authenticity_token: csrf }, headers: {
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
        @oidc_action, params: @continuation_fields,
                      headers: { "Origin" => "https://#{@base_host}", "Sec-Fetch-Site" => "same-origin" },
      )
    end

    assert_equal 400, stale_browser.response.status
    assert_nil stale_browser.cookies[AuthenticationBase::ACCESS_COOKIE_KEY]
    assert_equal 0, ClientSecretSignInReceipt.where(credential_ref: credential.public_id).count
    assert_equal ClientToken::MAX_SESSIONS_PER_USER, ClientToken.where(user_id: @actor.id).count
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
        @oidc_action, params: @continuation_fields,
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
        @oidc_action, params: @continuation_fields,
                      headers: { "Origin" => "https://#{@base_host}", "Sec-Fetch-Site" => "same-origin" },
      )
    end

    assert_equal 400, @base.response.status
    assert_equal 1, ClientToken.where(user_id: @actor.id).count
    assert_equal 0, ClientSecretSignInReceipt.where(credential_ref: credential.public_id).count
  end

  test "partial session revocation keeps the claim pending and sufficient capacity permits its one root login" do
    (ClientToken::MAX_SESSIONS_PER_USER - 1).times { ClientToken.create!(authentication_epoch: 0, user: @actor) }
    begin
      fv5000 = @base
      fv5000.post(
        @oidc_action, params: @continuation_fields,
                      headers: { "Origin" => "https://#{@base_host}", "Sec-Fetch-Site" => "same-origin" },
      )
    end

    assert_equal 303, @base.response.status
    assert_predicate @flow.reload, :sign_in_session_issuance_pending?
    credential = ClientSecretCredential.find_by!(issuance_id: @issuance.id)

    assert_nil credential.consumed_at
    assert_nil ClientSecretLookupQuery.call(client: @actor, secret: @raw)
    @base.get(visa_app_sign_in_limitation_path(ri: "jp"))

    assert_equal 200, @base.response.status
    page = JSON.parse(Nokogiri::HTML(@base.response.body).at_css("script[data-page='app']").text)
    csrf = Nokogiri::HTML(@base.response.body).at_css('meta[name="csrf-token"]')["content"]
    @base.patch(
      visa_app_sign_in_limitation_path(ri: "jp"), params: {
        authenticity_token: csrf, session_ref: page.fetch("props").fetch("sessions").first.fetch("session_ref"),
      }, headers: { "Origin" => "https://#{@base_host}", "Sec-Fetch-Site" => "same-origin" },
    )

    assert_equal 302, @base.response.status
    assert_predicate @flow.reload, :sign_in_completed?
    assert credential.reload.consumed_at
    receipt = ClientSecretSignInReceipt.find_by!(credential_ref: credential.public_id)

    root = ClientToken.find_by!(id: @flow.token_id, user_id: @actor.id)

    assert_equal root.public_id, receipt.root_token_ref
    assert_predicate root, :currently_usable?
    assert_equal 2, ClientToken.currently_usable_at.where(user_id: @actor.id).count
    assert_nil ClientSecretLookupQuery.call(client: @actor, secret: @raw)
  end

  private

  def copy_browser_cookies!(source:, destination:, host:)
    host_uri = URI.parse("https://#{host}/")
    source.cookies.for(host_uri).split(/;\s*/).each do |cookie|
      destination.cookies.merge(cookie, host_uri)
    end
  end

  def prepare_secret_login_attempt(client:, auth_host:, visa_host:)
    parameters = authorization_parameters(client)
    visa_browser = open_session
    visa_browser.host!(visa_host)
    visa_browser.https!
    visa_browser.get(
      "/oauth/authorize", params: parameters,
                          headers: navigation_headers(visa_host, "same-origin"),
    )
    auth_browser = visa_browser
    follow_authorization_bootstrap!(visa_browser:, auth_browser:, visa_host:, auth_host:)
    transaction = ClientOidcAuthorizationTransaction.find_by!(state: parameters.fetch(:state))
    auth_browser.get(
      new_auth_app_sign_in_secret_path(ri: "jp"),
      headers: navigation_headers(auth_host, "same-origin"),
    )
    page = JSON.parse(Nokogiri::HTML(auth_browser.response.body).at_css("script[data-page='app']").text)
    [visa_browser, auth_browser, transaction, page.fetch("props").fetch("authenticity_token")]
  end

  def authorization_parameters(client)
    {
      response_type: "code",
      client_id: client.client_id,
      redirect_uri: client.redirect_uris_by_realm.fetch("client").first,
      code_challenge: "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM",
      code_challenge_method: "S256",
      state: SecureRandom.urlsafe_base64(32),
      nonce: SecureRandom.urlsafe_base64(32),
      scope: "openid profile",
    }
  end

  def follow_authorization_bootstrap!(visa_browser:, auth_browser:, visa_host:, auth_host:)
    jump_host = URI.parse(Rails.configuration.x.boot_config.fetch(:jump).origin.to_s).host
    current_browser = visa_browser
    current_host = visa_host
    trace = []
    12.times do
      break unless current_browser.response.redirect?

      target = absolute_uri(current_browser.response.location, current_host)
      issuer_namespace = { visa_host => "VISA_APP", auth_host => "AUTH_APP" }.fetch(current_host)
      target = decode_signed_jump!(target, source_host: current_host, issuer_namespace:) if target.host == jump_host
      trace << [current_host, current_browser.response.status, target.host, target.path]
      current_browser, current_host = navigate_authorization_target(
        target:, visa_browser:, auth_browser:, visa_host:, auth_host:,
      )
    end

    bootstrap_failure_details = {
      host: current_host,
      status: current_browser.response.status,
      trace:,
      body: current_browser.response.body.first(200),
    }.inspect

    assert_same auth_browser, current_browser,
                "OIDC authorization bootstrap must reach Auth (#{bootstrap_failure_details})"

    assert_equal auth_host, current_host,
                 "OIDC authorization bootstrap must settle on Auth (trace=#{trace.inspect})"
    auth_entry_failure_details = { trace:, body: auth_browser.response.body.first(200) }.inspect

    assert_equal 200, auth_browser.response.status,
                 "OIDC authorization bootstrap must render Auth entry (#{auth_entry_failure_details})"
  end

  def navigate_authorization_target(target:, visa_browser:, auth_browser:, visa_host:, auth_host:)
    case target.host
    when visa_host
      navigate_browser!(visa_browser, visa_host, target, "cross-site")
      [visa_browser, visa_host]
    when auth_host
      navigate_browser!(auth_browser, auth_host, target, "cross-site")
      [auth_browser, auth_host]
    else
      raise RuntimeError, "unexpected OIDC bootstrap host: #{target.host.inspect}"
    end
  end

  def visa_result_continuation!(visa_browser:, auth_browser:, auth_host:, visa_host:)
    result_uri = auth_handoff_result_uri!(auth_browser, auth_host)
    result_uri = decode_signed_jump!(result_uri, source_host: auth_host, issuer_namespace: "AUTH_APP")

    assert_equal visa_host, result_uri.host, "OIDC handoff must return to the Visa APP authority"
    navigate_browser!(visa_browser, visa_host, result_uri, "cross-site")
    form = visa_result_continuation_form(visa_browser)
    [form["action"], form.css("input[name]").to_h { |input| [input["name"], input["value"]] }]
  end

  def auth_handoff_result_uri!(auth_browser, auth_host)
    auth_browser.follow_redirect!
    handoff_target = absolute_uri(auth_browser.response.location, auth_host)
    3.times do
      assert_equal auth_host, handoff_target.host, "OIDC handoff GET must stay on Auth"
      navigate_browser!(auth_browser, auth_host, handoff_target, "same-origin")
      break unless auth_browser.response.redirect?

      next_target = absolute_uri(auth_browser.response.location, auth_host)
      break unless next_target.host == auth_host

      handoff_target = next_target
    end

    assert_predicate auth_browser.response, :redirect?, "OIDC handoff must redirect to Visa"
    absolute_uri(auth_browser.response.location, auth_host)
  end

  def visa_result_continuation_form(visa_browser)
    assert_equal 200, visa_browser.response.status
    form = Nokogiri::HTML(visa_browser.response.body).at_css("form#visa-authorization-continuation-form")

    assert form, "Visa result must render its POST continuation form"
    fields = form.css("input[name]").to_h { |input| [input["name"], input["value"]] }

    assert fields.key?("continuation")

    assert fields.key?("authenticity_token")
    form
  end

  def decode_signed_jump!(uri, source_host:, issuer_namespace:)
    jump_host = URI.parse(Rails.configuration.x.boot_config.fetch(:jump).origin.to_s).host
    return uri unless uri.host == jump_host

    token = Rack::Utils.parse_query(uri.query.to_s).fetch("rt")
    issuer = JitSecurityJwtRegistry.surface(issuer_namespace)
    payload, = JWT.decode(
      token,
      JitSecurityJwtRegistry.public_key_for(issuer.id, issuer.current_kid),
      true,
      algorithms: ["ES384"],
      verify_iss: true,
      iss: "https://#{source_host}",
      verify_aud: true,
      aud: Rails.configuration.x.boot_config.fetch(:jump).audience,
    )
    URI.parse(payload.fetch("url"))
  end

  def navigate_browser!(browser, host, target, site)
    browser.host!(host)
    browser.https!
    browser.get(target.request_uri, headers: navigation_headers(host, site))
  end

  def absolute_uri(location, host)
    uri = URI.parse(location.to_s)
    uri.host.present? ? uri : URI.parse("https://#{host}#{uri}")
  end

  def navigation_headers(host, site)
    {
      "Host" => host,
      "Sec-Fetch-Mode" => "navigate",
      "Sec-Fetch-Dest" => "document",
      "Sec-Fetch-Site" => site,
    }
  end
end
