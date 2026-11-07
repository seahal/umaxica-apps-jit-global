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

  # Secret claims commit in App Zenith independently from the Ticket evidence transaction.
  # These HTTP journeys must run without Rails' enclosing fixture transaction so they exercise
  # the same commit boundary as a request served by the application.
  uses_transaction(
    "test_A12-6:_a_repeated_final_result_after_Root_issuance_is_an_error_without_a_second_Root",
    "test_a_Secret_flow_whose_transaction_method_is_not_passcode_is_refused_without_a_Root",
    "test_expired_OIDC_Secret_flow_rejects_a_delayed_result_without_releasing_its_claim",
    "test_terminally_failed_OIDC_Secret_flow_rejects_delayed_result_before_its_deadline",
    "test_expired_OIDC_Secret_limitation_refuses_session_revocation",
    "test_canceling_OIDC_Secret_session_limit_ends_its_flow_and_rejects_old_results",
    "test_OIDC_Secret_session_limit_continuation_preserves_claim_and_commits_its_receipt",
  )

  self.fixture_table_names = []
  fixtures :clients, :client_statuses, :client_email_statuses,
           :client_telephone_statuses, :client_token_kinds, :client_token_statuses,
           :client_token_binding_methods, :client_token_dbsc_statuses,
           :client_visibilities, :client_security_modes, :client_mfa_statuses

  setup do
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
    @test_owned_actor = self.class.uses_transaction?(name)
    @user =
      if @test_owned_actor
        Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
      else
        clients(:one)
      end
    if @test_owned_actor
      now = Client.database_now
      issuance = ClientSecretIssuance.create!(
        client: @user, origin_operation_id: SecureRandom.uuid, origin: "manual", attempt_number: 1,
        browser_session_ref: PublicId.generate, planned_count: 1,
        expires_at: now + 1.hour, presented_at: now - 1.second, confirmed_at: now,
        created_at: now - 1.second, updated_at: now,
      )
      @secret_credential = ClientSecretCredential.create!(
        client: @user, issuance:, name: "OIDC integration Secret",
        password_digest: Argon2::Password.create("a" * 32), confirmed_at: now,
        created_at: now, updated_at: now,
      )
    end
    @address = "oidc_signin_#{SecureRandom.hex(4)}@example.com"
    @email_record = @user.client_emails.create!(address: @address, user_email_status_id: ClientEmailStatus::VERIFIED)
    @email_record.finalize_binding!
    @telephone_record = @user.client_telephones.create!(number: "+819012345901")
    ClientToken.where(user_id: @user.id).delete_all unless @test_owned_actor
    TurnstileVerifierStub.challenge_enabled = true
    TurnstileVerifierStub.challenge_response = { "success" => true }
  end

  teardown do
    # The Secret-claim cases run without fixture transactions, so remove only the contacts
    # created by this test before the owning actor is cleaned up.
    @email_record&.delete
    @telephone_record&.delete
    if @test_owned_actor && @user&.persisted?
      flow_ids = ClientSignInFlow.where(principal_id: @user.id).pluck(:id)
      parent_ids = ClientOidcAuthorizationTransaction.where(secret_sign_in_flow_id: flow_ids).pluck(:id)
      parent_ids << @transaction.id if @transaction
      parent_ids.uniq!
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

      token_ids = ClientToken.where(user_id: @user.id).pluck(:id)
      stop_ids = OpAppAuthorityStopRootTarget.where(root_id: token_ids).pluck(:stop_id).uniq
      OpAppAuthorityStopParticipant.where(stop_id: stop_ids).delete_all
      OpAppAuthorityStopEpochCutoff.where(stop_id: stop_ids).delete_all
      OpAppAuthorityStopGrantTarget.where(stop_id: stop_ids).delete_all
      OpAppAuthorityStopRootTarget.where(stop_id: stop_ids).delete_all
      OpAppAuthorityStop.where(id: stop_ids).delete_all
      ClientStepUpSession.where(user_token_id: token_ids).delete_all
      OpAppGrant.where(client_token_id: token_ids).delete_all
      ClientDeviceSession.where(user_id: @user.id).update_all(current_refresh_token_id: nil)
      ClientToken.where(id: token_ids).delete_all
      ClientDeviceSession.where(user_id: @user.id).delete_all

      ClientChronicle.where(subject_type: "Client", subject_id: @user.id.to_s).delete_all
      Chronicle.where(subject_type: "Client", subject_id: @user.id).find_each(&:destroy!)
      ClientSecretAuditOutbox.where(client_ref: @user.public_id).find_each(&:destroy!)
      ClientSecretCredential.where(client_id: @user.id).delete_all
      ClientSecretIssuance.where(client_id: @user.id).delete_all
      ClientAccount.where(user_id: @user.id).delete_all
      ClientAuthorityLock.where(client_id: @user.id).delete_all
      ClientRetentionHold.where(client_id: @user.id).delete_all
      ClientOidcConnection.where(user_id: @user.id).delete_all
      Client.where(id: @user.id).delete_all
    end
    ENV["APP_SECRET_PROOF_RETENTION_SECONDS"] = @previous_secret_proof_retention
    ENV["APP_SECRET_OUTBOX_RETENTION_SECONDS"] = @previous_secret_outbox_retention
    ENV["APP_SECRET_PURGE_DELAY_SECONDS"] = @previous_secret_purge_delay
    TurnstileVerifierStub.challenge_enabled = false
    TurnstileVerifierStub.challenge_response = nil
  end

  test "the sign-in entry stores the authorization transaction in Auth continuity" do
    parameters = oidc_authorize_params(realm: "client").merge(ri: "jp")
    start_oidc_authorization!(parameters)

    assert_response :success
    record = ClientAuthCeremonySession.order(created_at: :desc).first

    assert_predicate record, :admitted?
    assert_equal @transaction.transaction_id, record.authorization_transaction_ref
    assert_nil session[:oidc_authorization_login_challenge]
    assert_nil session[:oidc_authorization_intent]
  end

  test "APP parent Cancel commits only through its browser-bound Visa POST continuation" do
    visa_host = ENV.fetch("PUBLIC_VISA_SERVICE_URL")
    auth_host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    jump_host = URI.parse(Rails.configuration.x.boot_config.fetch(:jump).origin.to_s).host
    client = OidcClientRegistry.find!("core-app-jp")
    redirect_uri = client.redirect_uris_by_realm.fetch("client").first
    state = SecureRandom.urlsafe_base64(32)
    parameters = {
      response_type: "code",
      client_id: client.client_id,
      redirect_uri: redirect_uri,
      code_challenge: "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM",
      code_challenge_method: "S256",
      state: state,
      nonce: SecureRandom.urlsafe_base64(32),
      scope: "openid profile",
    }

    @base_browser = open_session
    @base_browser.host!(visa_host)
    @base_browser.https!
    @base_browser.get(
      "/oauth/authorize", params: parameters, headers: {
        "Host" => visa_host,
        "Sec-Fetch-Mode" => "navigate",
        "Sec-Fetch-Dest" => "document",
        "Sec-Fetch-Site" => "same-origin",
      },
    )

    current_browser = @base_browser
    current_host = visa_host
    12.times do
      break unless current_browser.response.redirect?

      target = URI.parse(current_browser.response.location.to_s)
      target = URI.parse("https://#{current_host}#{target}") if target.host.blank?
      if target.host == jump_host
        jump_token = Rack::Utils.parse_query(target.query.to_s).fetch("rt")
        issuer = JitSecurityJwtRegistry.surface("VISA_APP")
        jump_claims, = JWT.decode(
          jump_token,
          JitSecurityJwtRegistry.public_key_for(issuer.id, issuer.current_kid),
          true,
          algorithms: ["ES384"],
          verify_iss: true,
          iss: "https://#{current_host}",
          verify_aud: true,
          aud: Rails.configuration.x.boot_config.fetch(:jump).audience,
        )
        target = URI.parse(jump_claims.fetch("url"))
      end

      navigation_headers = {
        "Sec-Fetch-Mode" => "navigate",
        "Sec-Fetch-Dest" => "document",
        "Sec-Fetch-Site" => "cross-site",
      }
      case target.host
      when visa_host
        @base_browser.host!(visa_host)
        @base_browser.https!
        @base_browser.get(target.request_uri, headers: navigation_headers.merge("Host" => visa_host))
        current_browser = @base_browser
        current_host = visa_host
      when auth_host
        host!(auth_host)
        https!
        get(target.request_uri, headers: navigation_headers.merge("Host" => auth_host))
        current_browser = self
        current_host = auth_host
      else
        raise RuntimeError, "unexpected OIDC cancellation bootstrap host: #{target.host.inspect}"
      end
    end

    assert_same self, current_browser
    assert_response :success
    page = css_select("script[data-page='app']").first

    assert page, "expected the APP Auth sign-in page object"

    cancel_form = JSON.parse(page.text).fetch("props").fetch("cancel_form")

    assert_equal "/sign/cancellation?ri=jp", cancel_form.fetch("action")

    post cancel_form.fetch("action"), params: {
      authenticity_token: cancel_form.fetch("authenticity_token"),
    }, headers: {
      "Host" => auth_host,
      "Origin" => "https://#{auth_host}",
      "Sec-Fetch-Site" => "same-origin",
      "Sec-Fetch-Mode" => "navigate",
      "Sec-Fetch-Dest" => "document",
    }

    assert_response :see_other
    transaction = ClientOidcAuthorizationTransaction.find_by!(state: state)
    binding = ClientAuthAdmissionBinding.find_by!(authorization_transaction_id: transaction.id)
    ceremony = ClientAuthCeremonySession.find(binding.admitted_auth_ceremony_session_id)

    assert_predicate ceremony, :cancelled_before_authentication_progress?
    assert_predicate transaction.reload, :canceled?
    assert_predicate transaction.cancellation_handoff_ciphertext, :present?

    auth_jump = URI.parse(response.location)
    auth_jump_token = Rack::Utils.parse_query(auth_jump.query.to_s).fetch("rt")
    auth_issuer = JitSecurityJwtRegistry.surface("AUTH_APP")
    auth_jump_claims, = JWT.decode(
      auth_jump_token,
      JitSecurityJwtRegistry.public_key_for(auth_issuer.id, auth_issuer.current_kid),
      true,
      algorithms: ["ES384"],
      verify_iss: true,
      iss: "https://#{auth_host}",
      verify_aud: true,
      aud: Rails.configuration.x.boot_config.fetch(:jump).audience,
    )
    visa_target = URI.parse(auth_jump_claims.fetch("url"))

    assert_equal visa_host, visa_target.host

    @base_browser.host!(visa_host)
    @base_browser.https!
    @base_browser.get(
      visa_target.request_uri, headers: {
        "Host" => visa_host,
        "Sec-Fetch-Site" => "cross-site",
        "Sec-Fetch-Mode" => "navigate",
        "Sec-Fetch-Dest" => "document",
      },
    )

    assert_equal 200, @base_browser.response.status
    continuation_form = Nokogiri::HTML(@base_browser.response.body)
      .at_css("form#visa-authorization-continuation-form")

    assert continuation_form, "expected the Visa cancellation POST continuation"
    continuation_fields =
      continuation_form.css("input[type='hidden']").to_h { |input| [input["name"], input["value"]] }
    @base_browser.post(
      continuation_form["action"], params: continuation_fields, headers: {
        "Host" => visa_host,
        "Origin" => "https://#{visa_host}",
        "Sec-Fetch-Site" => "same-origin",
        "Sec-Fetch-Mode" => "navigate",
        "Sec-Fetch-Dest" => "document",
      },
    )

    assert_equal 303, @base_browser.response.status
    denial_jump = URI.parse(@base_browser.response.location)
    denial_token = Rack::Utils.parse_query(denial_jump.query.to_s).fetch("rt")
    denial_issuer = JitSecurityJwtRegistry.surface("VISA_APP")
    denial_claims, = JWT.decode(
      denial_token,
      JitSecurityJwtRegistry.public_key_for(denial_issuer.id, denial_issuer.current_kid),
      true,
      algorithms: ["ES384"],
      verify_iss: true,
      iss: "https://#{visa_host}",
      verify_aud: true,
      aud: Rails.configuration.x.boot_config.fetch(:jump).audience,
    )
    denial_target = URI.parse(denial_claims.fetch("url"))
    denial = Rack::Utils.parse_query(denial_target.query.to_s)

    assert_equal URI.parse(redirect_uri).host, denial_target.host
    assert_equal "access_denied", denial.fetch("error")
    assert_equal state, denial.fetch("state")
    assert_predicate transaction.reload, :canceled?
    assert_predicate transaction.cancellation_handoff_digest, :present?

    canceled_transaction_facts = transaction.attributes
    base_session_facts = @base_browser.session.to_hash.slice(
      "session_id", "auth_admission_browser_nonce", "timezone",
    )
    base_cookie_names = @base_browser.cookies.to_hash.keys.sort
    auth_sid_cookie_name =
      if JitSessionCookieConfig.force_secure?
        "#{AuthIoKeys::HOST_COOKIE_PREFIX}#{AuthCeremonySidCookie::COOKIE_BASENAME}"
      else
        AuthCeremonySidCookie::COOKIE_BASENAME
      end
    authentication_cookie_names = [
      auth_sid_cookie_name,
      AuthenticationBase::ACCESS_COOKIE_KEY,
      AuthenticationBase::REFRESH_COOKIE_KEY,
      AuthenticationBase::DBSC_COOKIE_KEY,
    ]
    token_count = ClientToken.count
    replay_headers = oidc_navigation_headers(visa_host, site: "same-origin").merge(base_result_headers).merge(
      "Origin" => "https://#{visa_host}",
    )
    @base_browser.post(
      continuation_form["action"], params: continuation_fields, headers: replay_headers,
    )

    assert_equal 303, @base_browser.response.status
    replay_denial_target = decode_oidc_jump_target!(
      URI.parse(@base_browser.response.location), issuer_namespace: "VISA_APP", issuer_host: visa_host,
    )
    replay_denial = Rack::Utils.parse_query(replay_denial_target.query.to_s)

    assert_equal denial_target.host, replay_denial_target.host
    assert_equal denial_target.path, replay_denial_target.path
    assert_equal "access_denied", replay_denial.fetch("error")
    assert_equal state, replay_denial.fetch("state")
    assert_equal canceled_transaction_facts, transaction.reload.attributes
    assert_equal base_session_facts,
                 @base_browser.session.to_hash.slice("session_id", "auth_admission_browser_nonce", "timezone")
    assert_equal base_cookie_names, @base_browser.cookies.to_hash.keys.sort
    assert_empty authentication_cookie_names & @base_browser.cookies.to_hash.keys
    assert_equal token_count, ClientToken.count
  end

  test "the primary factor sends the ceremony to the sign-in checkpoint" do
    parameters = oidc_authorize_params(realm: "client").merge(ri: "jp")
    start_oidc_authorization!(parameters)

    assert_response :success

    token_count = ClientToken.where(user_id: @user.id).count
    submit_email_otp!

    assert_response :redirect
    assert_equal URI.parse(auth_app_sign_in_check_path(ri: "jp")).path, URI.parse(response.location).path
    assert_equal token_count, ClientToken.where(user_id: @user.id).count

    ceremony = ClientAuthCeremonySession.order(created_at: :desc).first

    assert_equal "email", ceremony.authentication_method
    assert_predicate ceremony.authentication_event_at, :present?
  end

  test "an Inertia pass-code submission leaves the application for the sign-in checkpoint" do
    parameters = oidc_authorize_params(realm: "client").merge(ri: "jp")
    start_oidc_authorization!(parameters)

    assert_response :success

    submit_email_otp!(extra_headers: { "X-Inertia" => "true" })

    assert_response :conflict
    assert_equal URI.parse(auth_app_sign_in_check_path(ri: "jp")).path,
                 URI.parse(response.headers.fetch("X-Inertia-Location")).path
    assert_nil response.headers["Location"]
  end

  test "Visa APP sign-in reflects explicit display choices only and excludes region" do
    ClientPreferenceStatus.ensure_defaults!
    ClientPreference.where(client_id: @user.id).find_each(&:retire!)
    ClientPreferenceThemeOption.ensure_defaults!
    ClientPreferenceLanguageOption.ensure_defaults!
    ClientPreferenceRegionOption.ensure_defaults!
    actor_preference = ClientPreference.create!(
      client_id: @user.id,
      status_id: ClientPreferenceStatus::ACTIVE,
      explicit_fields: ["theme"],
    )
    ClientPreferenceTheme.create!(preference_id: actor_preference.id, option_id: ClientPreferenceThemeOption::DARK)
    ClientPreferenceLanguage.create!(preference_id: actor_preference.id, option_id: ClientPreferenceLanguageOption::EN)
    ClientPreferenceRegion.create!(preference_id: actor_preference.id, option_id: ClientPreferenceRegionOption::US)

    start_oidc_authorization!(oidc_authorize_params(realm: "client").merge(ri: "jp"))
    submit_email_otp!
    follow_redirect_to_oidc_handoff!
    post_oidc_handoff!
    get_oidc_result!

    assert_response :redirect
    claims = PreferenceToken.decode(
      cookies[PreferenceCookieName.anonymous_jwt],
      host: request.host,
      jwt_issuer_id: "preference_app",
    )
    anonymous = AppPreference.find_by!(public_id: claims.fetch("sub"))

    assert_equal "dark", claims.fetch("preferences").fetch("theme")
    assert_equal "ja", claims.fetch("preferences").fetch("language")
    assert_not_equal ClientPreferenceRegionOption::US,
                     AppPreferenceRegion.find_by!(preference_id: anonymous.id).option_id,
                     "account region is deliberately not reflected into the anonymous row"
    assert_equal ["theme"], actor_preference.reload.explicit_field_names
  end

  test "successful APP sign-in remains issued when the Preference writer fails" do
    start_oidc_authorization!(oidc_authorize_params(realm: "client").merge(ri: "jp"))
    submit_email_otp!
    follow_redirect_to_oidc_handoff!
    post_oidc_handoff!
    assert_difference -> { ClientToken.where(user_id: @user.id).count }, 1 do
      assert_no_difference -> { AppPreference.count } do
        PreferenceToken.stub(:encode, nil) { get_oidc_result! }
      end
    end

    assert_response :service_unavailable
    assert_equal "temporarily_unavailable", response.parsed_body.fetch("error")
    assert_nil cookies[PreferenceCookieName.anonymous_jwt]
  end

  test "A12-6: a repeated final result after Root issuance is an error without a second Root" do
    ENV["APP_SECRET_PURGE_DELAY_SECONDS"] = "1"
    credential = @secret_credential

    assert_equal credential.id, ClientSecretLookupQuery.call(client: @user, secret: "a" * 32).id
    parameters = oidc_authorize_params(realm: "client").merge(ri: "jp")
    start_oidc_authorization!(parameters)

    assert_response :success
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
    # This origin's service worker re-fetches navigations, which arrive with destination `empty`.
    follow_redirect_to_oidc_handoff!(destination: "empty")
    post_oidc_handoff!

    assert_response :see_other
    flow = ClientSignInFlow.find(@transaction.reload.secret_sign_in_flow_id)

    assert_equal ["passcode", "secret", @user.public_id, nil, nil, "SELECTOR_PENDING"],
                 [@transaction.auth_method, flow.authentication_method, @transaction.actor_ref,
                  flow.session_issued_at, flow.token_id, flow.state_name_for(flow.state_id),]
    assert_equal [true, nil, nil, "authentication_handoff"],
                 [ceremony.reload.completed?, ceremony.revoked_at, ceremony.cancelled_at, ceremony.admission_purpose]
    assert_equal ["normal", @user.id, @transaction.transaction_id],
                 [flow.authentication_context, flow.principal_id, ceremony.authorization_transaction_ref]
    assert_difference("ClientToken.count", 1) do
      get_oidc_result!

      assert_response :redirect, response.body
    end
    assert credential.reload.consumed_at
    assert_equal ClientToken.find(
      ClientSignInFlow.find(@transaction.secret_sign_in_flow_id).token_id,
    ).public_id,
                 ClientSecretSignInReceipt.find_by!(operation_id: credential.claim_operation_id).root_token_ref
    root_token_ref = @transaction.reload.browser_session_ref
    consumed_at = credential.consumed_at
    assert_no_difference ["ClientToken.count", "ClientSecretSignInReceipt.count"] do
      get_oidc_result!
    end
    # WU-27/D-104: a finalized result is terminal; a lost-response replay must not
    # issue another root or reissue the retained credentials.
    assert_response :bad_request
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
                  ClientToken.find(
                    ClientSignInFlow.find(@transaction.secret_sign_in_flow_id).token_id,
                  ).user_token_status_id,],
                 "a surviving successful receipt retains its authorization proof and active root"
    assert_equal :pending, ClientSecretSignInReceiptPurger.call!(
      receipt: ClientSecretSignInReceipt.find_by!(operation_id: credential.claim_operation_id),
      retention_after: 1.second,
    )
    flow = ClientSignInFlow.find(@transaction.secret_sign_in_flow_id)
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
                 [ClientSecretSignInReceipt.exists?(receipt.id), ClientToken.find(flow.token_id).user_token_status_id]
  end

  test "a Secret flow whose transaction method is not passcode is refused without a Root" do
    credential = @secret_credential
    start_oidc_authorization!(oidc_authorize_params(realm: "client").merge(ri: "jp"))
    get new_auth_app_sign_in_secret_path(ri: "jp")
    post auth_app_sign_in_secret_path(ri: "jp"), params: {
      identifier: @email_record.address, secret: "a" * 32, "cf-turnstile-response": "test_token",
    }

    assert_response :see_other
    follow_redirect_to_oidc_handoff!
    post_oidc_handoff!

    assert_response :see_other
    # A transaction that names another method must not be completed by the Secret flow.
    @transaction.reload.update_columns(auth_method: "email")
    assert_no_difference(%w(ClientToken.count ClientSecretSignInReceipt.count)) do
      get_oidc_result!
    end
    assert_operator response.status, :<, 500
    assert_nil credential.reload.consumed_at
  end

  test "expired OIDC Secret flow rejects a delayed result without releasing its claim" do
    credential = @secret_credential
    parameters = oidc_authorize_params(realm: "client").merge(ri: "jp")
    start_oidc_authorization!(parameters)

    assert_response :success
    post auth_app_sign_in_secret_path(ri: "jp"), params: {
      identifier: @email_record.address, secret: "a" * 32, "cf-turnstile-response": "test_token",
    }

    assert_response :see_other
    follow_redirect_to_oidc_handoff!
    post_oidc_handoff!

    assert_response :see_other
    flow = ClientSignInFlow.find(@transaction.reload.secret_sign_in_flow_id)
    flow.update!(expires_at: ClientSignInFlow.database_now)
    operation_id = credential.reload.claim_operation_id

    assert_no_difference ["ClientToken.count", "ClientSecretSignInReceipt.count"] do
      get_oidc_result!
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
      get_oidc_result!
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
    credential = @secret_credential
    parameters = oidc_authorize_params(realm: "client").merge(ri: "jp")
    start_oidc_authorization!(parameters)

    assert_response :success
    post auth_app_sign_in_secret_path(ri: "jp"), params: {
      identifier: @email_record.address, secret: "a" * 32, "cf-turnstile-response": "test_token",
    }

    assert_response :see_other
    follow_redirect_to_oidc_handoff!
    post_oidc_handoff!

    assert_response :see_other
    flow = ClientSignInFlow.find(@transaction.reload.secret_sign_in_flow_id)
    flow.halt_sign_in!

    assert_no_difference ["ClientToken.count", "ClientSecretSignInReceipt.count"] do
      get_oidc_result!
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
    parameters = oidc_authorize_params(realm: "client").merge(ri: "jp")
    start_oidc_authorization!(parameters)

    assert_response :success
    post auth_app_sign_in_secret_path(ri: "jp"), params: {
      identifier: @email_record.address, secret: "a" * 32, "cf-turnstile-response": "test_token",
    }

    assert_response :see_other
    follow_redirect_to_oidc_handoff!
    post_oidc_handoff!

    assert_response :see_other
    Array.new(ClientToken::MAX_SESSIONS_PER_USER) { ClientToken.create!(authentication_epoch: 0, user: @user) }
    get_oidc_result!

    assert_response :see_other
    limitation = response.location
    flow = ClientSignInFlow.find(@transaction.reload.secret_sign_in_flow_id)
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
    credential = @secret_credential
    parameters = oidc_authorize_params(realm: "client").merge(ri: "jp")
    start_oidc_authorization!(parameters)

    assert_response :success
    post auth_app_sign_in_secret_path(ri: "jp"), params: {
      identifier: @email_record.address, secret: "a" * 32, "cf-turnstile-response": "test_token",
    }

    assert_response :see_other
    follow_redirect_to_oidc_handoff!
    post_oidc_handoff!

    assert_response :see_other
    Array.new(ClientToken::MAX_SESSIONS_PER_USER) { ClientToken.create!(authentication_epoch: 0, user: @user) }
    get_oidc_result!

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
    assert_predicate ClientSignInFlow.find(@transaction.reload.secret_sign_in_flow_id), :sign_in_cancelled?
    assert_operator credential.reload.discard_at, :<=, Client.database_now
    assert_nil credential.consumed_at
    assert_nil ClientSecretLookupQuery.call(client: @user, secret: "a" * 32)
    assert_predicate admitted_resolution.reload, :cancelled?
    assert_predicate @transaction.reload, :canceled?

    visa_host = ENV.fetch("PUBLIC_VISA_SERVICE_URL")
    cancellation_location = URI.parse(response.location)

    assert_equal "/oidc/cancellation", cancellation_location.path
    assert_predicate @transaction.cancellation_handoff_ref, :present?
    @base_browser.host!(visa_host)
    @base_browser.https!
    @base_browser.get(
      cancellation_location.request_uri,
      headers: oidc_navigation_headers(visa_host, site: "same-origin"),
    )

    assert_equal 200, @base_browser.response.status
    cancellation_form = Nokogiri::HTML(@base_browser.response.body)
      .at_css("form#visa-authorization-continuation-form")

    assert cancellation_form, "session-limit Cancel must render the browser-bound Visa continuation"
    cancellation_fields =
      cancellation_form.css("input[type='hidden']").to_h { |input| [input["name"], input["value"]] }
    @base_browser.post(
      cancellation_form["action"],
      params: cancellation_fields,
      headers: oidc_navigation_headers(visa_host, site: "same-origin").merge(
        "Origin" => "https://#{visa_host}",
      ),
    )

    assert_equal 303, @base_browser.response.status
    denial_target = decode_oidc_jump_target!(
      URI.parse(@base_browser.response.location), issuer_namespace: "VISA_APP", issuer_host: visa_host,
    )
    denial = Rack::Utils.parse_query(denial_target.query.to_s)

    assert_equal "access_denied", denial.fetch("error")
    assert_equal @transaction.state, denial.fetch("state")
    assert_no_difference ["ClientToken.count", "ClientSecretSignInReceipt.count"] do
      get_oidc_result!
    end
    assert_response :bad_request
    assert_equal "flow_canceled", ClientSecretAuditOutbox.find_by!(
      credential_ref: credential.public_id, event_name: "secret.discarded",
    ).reason
  end

  test "OIDC Secret session limit continuation preserves claim and commits its receipt" do
    credential = @secret_credential
    parameters = oidc_authorize_params(realm: "client").merge(ri: "jp")
    start_oidc_authorization!(parameters)

    assert_response :success
    post auth_app_sign_in_secret_path(ri: "jp"), params: {
      identifier: @email_record.address, secret: "a" * 32, "cf-turnstile-response": "test_token",
    }

    assert_response :see_other
    follow_redirect_to_oidc_handoff!
    post_oidc_handoff!

    assert_response :see_other
    existing_tokens = Array.new(ClientToken::MAX_SESSIONS_PER_USER) { ClientToken.create!(authentication_epoch: 0, user: @user) }
    assert_no_difference "ClientToken.count" do
      get_oidc_result!
    end
    assert_response :see_other
    limitation = response.location

    assert_predicate ClientSignInFlow.find(@transaction.reload.secret_sign_in_flow_id),
                     :sign_in_session_issuance_pending?
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

    assert_response :redirect
    receipt = ClientSecretSignInReceipt.find_by!(operation_id: credential.claim_operation_id)

    assert_equal @transaction.reload.browser_session_ref, receipt.root_token_ref
    assert credential.reload.consumed_at
  end

  test "the local handoff POST binds the signed-in actor to the authorization transaction" do
    parameters = oidc_authorize_params(realm: "client").merge(ri: "jp")
    start_oidc_authorization!(parameters)

    assert_response :success
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
    parameters = oidc_authorize_params(realm: "client").merge(ri: "jp")
    start_oidc_authorization!(parameters)

    assert_response :success
    submit_email_otp!

    follow_redirect_to_oidc_handoff!
    post_oidc_handoff!

    assert_response :see_other
    result_uri = URI.parse(@oidc_result_action)

    assert_equal "/oidc/result", result_uri.path
    assert_equal ENV.fetch("PUBLIC_VISA_SERVICE_URL"), result_uri.host
    assert_predicate @oidc_result_ref, :present?
    assert_equal @transaction.transaction_id, @oidc_result_transaction_ref
    binding = ClientAuthAdmissionBinding.find_by!(authorization_transaction_id: @transaction.id)
    before = [@transaction.reload.attributes, binding.attributes, ClientToken.count]
    host!(result_uri.host)
    https!
    navigation = oidc_navigation_headers(result_uri.host, site: "cross-site").merge(base_result_headers)
    head(result_uri.request_uri, headers: navigation)

    assert_response :bad_request
    assert_equal before, [@transaction.reload.attributes, binding.reload.attributes, ClientToken.count]
    get(result_uri.request_uri, headers: navigation.merge("Sec-Fetch-Dest" => "iframe"))

    assert_response :bad_request
    assert_equal before, [@transaction.reload.attributes, binding.reload.attributes, ClientToken.count]
  end

  test "the checkpoint clears the login challenge from the session" do
    parameters = oidc_authorize_params(realm: "client").merge(ri: "jp")
    start_oidc_authorization!(parameters)

    assert_response :success
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

  def submit_email_otp!(extra_headers: {})
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
    pass_code = OutboundSensitivePayload.decrypt_email_otp(delivery.fetch(:encrypted_hotp_token))
    plaintext_queued = delivery_job.fetch(:args).to_s.include?(pass_code)

    assert_equal [@transaction.transaction_id, @email_record.public_id, @user.public_id,
                  delivery.fetch(:auth_email_otp_generation), "oidc",],
                 [ceremony.email_otp_context.fetch("parent_ref"),
                  ceremony.email_otp_context.fetch("contact_ref"), ceremony.email_otp_context.fetch("owner_ref"),
                  ceremony.email_otp_context.fetch("generation"), ceremony.email_otp_context.fetch("parent_kind"),],
                 "Delivery must bind the original Parent, Contact, owner, and generation"
    assert_not plaintext_queued, "Delivery must not queue plaintext code"
    assert_equal "sign_in", delivery.fetch(:purpose)

    patch(
      auth_app_sign_in_email_url(ri: "jp"),
      params: { :user_email => { pass_code: pass_code }, "cf-turnstile-response" => "test_token" },
      headers: { "Host" => @host }.merge(extra_headers),
    )
  end

  def post_oidc_handoff!
    target = URI.parse(@oidc_result_action)
    @oidc_result_ref = Rack::Utils.parse_nested_query(target.query.to_s).fetch("result_ref")
    @oidc_result_transaction_ref = Rack::Utils.parse_nested_query(target.query.to_s).fetch("transaction_ref")
  end

  def start_oidc_authorization!(parameters)
    base_host = ENV.fetch("PUBLIC_VISA_SERVICE_URL")
    @base_browser = open_session
    @base_browser.host!(base_host)
    @base_browser.https!
    @base_browser.get(
      "/oauth/authorize",
      params: parameters,
      headers: oidc_navigation_headers(base_host, site: "same-origin"),
    )

    follow_oidc_authorization_bootstrap!(base_host:)
    @transaction = ClientOidcAuthorizationTransaction.find_by!(state: parameters.fetch(:state))
  end

  def follow_oidc_authorization_bootstrap!(base_host:)
    jump_host = URI.parse(Rails.configuration.x.boot_config.fetch(:jump).origin.to_s).host
    current_browser = @base_browser
    current_host = base_host

    12.times do
      break unless current_browser.response.redirect?

      target = oidc_bootstrap_target_from_redirect(
        browser: current_browser, current_host:, base_host:, jump_host:,
      )
      current_browser, current_host = navigate_oidc_bootstrap_target(target:, base_host:)
    end

    raise RuntimeError, "OIDC authorization bootstrap did not reach Auth" unless current_browser.equal?(self)
    raise RuntimeError, "OIDC authorization bootstrap did not render Auth entry" unless response.successful?
  end

  def oidc_bootstrap_target_from_redirect(browser:, current_host:, base_host:, jump_host:)
    target = URI.parse(browser.response.location.to_s)
    target = URI.parse("https://#{current_host}#{target}") if target.host.blank?
    return target unless target.host == jump_host

    namespace = (current_host == base_host) ? "VISA_APP" : "AUTH_APP"
    decode_oidc_jump_target!(target, issuer_namespace: namespace, issuer_host: current_host)
  end

  def navigate_oidc_bootstrap_target(target:, base_host:)
    case target.host
    when base_host
      @base_browser.host!(base_host)
      @base_browser.https!
      @base_browser.get(target.request_uri, headers: oidc_navigation_headers(base_host, site: "cross-site"))
      [@base_browser, base_host]
    when @host
      host!(@host)
      https!
      get(target.request_uri, headers: oidc_navigation_headers(@host, site: "cross-site"))
      [self, @host]
    else
      raise RuntimeError, "unexpected OIDC bootstrap host: #{target.host.inspect}"
    end
  end

  def decode_oidc_jump_target!(uri, issuer_namespace:, issuer_host:)
    token = Rack::Utils.parse_query(uri.query.to_s).fetch("rt")
    issuer = JitSecurityJwtRegistry.surface(issuer_namespace)
    payload, = JWT.decode(
      token,
      JitSecurityJwtRegistry.public_key_for(issuer.id, issuer.current_kid),
      true,
      algorithms: ["ES384"],
      verify_iss: true,
      iss: "https://#{issuer_host}",
      verify_aud: true,
      aud: Rails.configuration.x.boot_config.fetch(:jump).audience,
    )
    URI.parse(payload.fetch("url"))
  end

  def oidc_navigation_headers(host, site:)
    {
      "Host" => host,
      "Sec-Fetch-Mode" => "navigate",
      "Sec-Fetch-Dest" => "document",
      "Sec-Fetch-Site" => site,
    }
  end

  def base_result_headers
    cookie_header = @base_browser.cookies.to_hash.map { |name, value|
      "#{name}=#{Rack::Utils.escape(value)}"
    }.join("; ")
    {
      "Origin" => OidcIssuer.absolute_url(ENV.fetch("PUBLIC_VISA_SERVICE_URL")),
      "Sec-Fetch-Site" => "same-origin",
      "Cookie" => cookie_header,
      "HTTP_COOKIE" => cookie_header,
    }
  end

  def follow_redirect_to_oidc_handoff!(destination: "document")
    target = URI.parse(response.location)
    3.times do
      raise RuntimeError, "OIDC handoff redirect is not on Auth" unless target.host == @host

      host!(@host)
      https!
      get(
        target.request_uri,
        headers: oidc_navigation_headers(@host, site: "same-origin").merge("Sec-Fetch-Dest" => destination),
      )
      break unless response.redirect?

      next_target = URI.parse(response.location)
      break if next_target.host != @host

      target = next_target
    end
    raise RuntimeError, "OIDC handoff did not redirect away from Auth" unless response.redirect?

    @oidc_result_action = response.location
  end

  def get_oidc_result!
    target = URI.parse(@oidc_result_action)
    visa_host = ENV.fetch("PUBLIC_VISA_SERVICE_URL")
    host!(target.host)
    https!
    get(
      target.request_uri,
      headers: oidc_navigation_headers(visa_host, site: "cross-site").merge(base_result_headers),
    )
    return unless response.status == 200

    form = response.parsed_body.at_css("form#visa-authorization-continuation-form")
    raise RuntimeError, "Visa result did not render its POST continuation" unless form

    fields = form.css("input[type='hidden']").to_h { |input| [input["name"], input["value"]] }
    post(
      form["action"], params: fields, headers: base_result_headers.merge(
        "Origin" => OidcIssuer.absolute_url(visa_host),
        "Sec-Fetch-Mode" => "navigate",
        "Sec-Fetch-Dest" => "document",
        "Sec-Fetch-Site" => "same-origin",
      ),
    )
  end

  def oidc_authorize_params(realm:)
    {
      response_type: "code",
      client_id: "core-app-jp",
      redirect_uri: OidcClientRegistry.find!("core-app-jp").redirect_uris_by_realm.fetch(realm).first,
      code_challenge: "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM",
      code_challenge_method: "S256",
      state: SecureRandom.urlsafe_base64(32),
      nonce: SecureRandom.urlsafe_base64(32),
      scope: "openid profile",
    }
  end
end
