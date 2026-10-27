# frozen_string_literal: true

require "test_helper"

class OidcResultBrowserBindingTest < ActionDispatch::IntegrationTest
  test "a Visa result binds attachment confirmation redemption and root issuance to their owning browsers" do
    protection = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    [
      ["app", "core-app-jp", "client", ENV.fetch("PUBLIC_VISA_SERVICE_URL"), ENV.fetch("PUBLIC_AUTH_SERVICE_URL"),
       Client, ClientToken, :user_id, ClientStatus::ACTIVE,],
      ["com", "core-com-jp", "visitor", ENV.fetch("PUBLIC_VISA_CORPORATE_URL"), ENV.fetch("PUBLIC_AUTH_CORPORATE_URL"),
       Visitor, VisitorToken, :visitor_id, VisitorStatus::ACTIVE,],
      ["org", "core-org-jp", "operator", ENV.fetch("PUBLIC_VISA_STAFF_URL"), ENV.fetch("PUBLIC_AUTH_STAFF_URL"),
       Operator, OperatorToken, :staff_id, OperatorStatus::ACTIVE,],
    ].each do |surface, client_id, realm, visa_host, auth_host, actor_model, token_model, owner_key, active_status|
      navigation = { "Sec-Fetch-Mode" => "navigate", "Sec-Fetch-Dest" => "document", "Sec-Fetch-Site" => "cross-site" }
      parameters = {
        response_type: "code",
        client_id:,
        redirect_uri: OidcClientRegistry.find!(client_id).redirect_uris_by_realm.fetch(realm).first,
        code_challenge: "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM",
        code_challenge_method: "S256",
        scope: "openid",
        state: SecureRandom.urlsafe_base64(32),
        nonce: SecureRandom.urlsafe_base64(32),
        ri: "jp",
      }
      owner = open_session
      owner.host!(visa_host)
      owner.https!
      owner.get("/oauth/authorize", params: parameters, headers: navigation)

      assert_equal 303, owner.response.status
      parent = OidcAuthorizationTransactionCoordinator.model_for(surface).find_by!(state: parameters.fetch(:state))
      binding = BaseAuthAdmissionCoordinator.admission_binding_model(surface).find_by!(
        authorization_transaction_id: parent.id,
      )
      auth = open_session
      auth.host!(auth_host)
      auth.https!
      current_browser = owner
      current_host = visa_host
      confirmation = nil
      jump_host = URI.parse(Rails.configuration.x.boot_config.fetch(:jump).origin.to_s).host
      12.times do
        target = URI.parse(current_browser.response.location.to_s)
        target = URI.parse("https://#{current_host}#{target}") unless target.host
        if target.host == jump_host
          namespace = (current_host == visa_host) ? "VISA_#{surface.upcase}" : "AUTH_#{surface.upcase}"
          issuer = JitSecurityJwtRegistry.surface(namespace)
          payload, = JWT.decode(
            Rack::Utils.parse_query(target.query).fetch("rt"),
            JitSecurityJwtRegistry.public_key_for(issuer.id, issuer.current_kid), true,
            algorithms: ["ES384"], verify_iss: true, iss: "https://#{current_host}",
            verify_aud: true, aud: Rails.configuration.x.boot_config.fetch(:jump).audience,
          )
          target = URI.parse(payload.fetch("url"))
        end

        assert_includes [visa_host, auth_host], target.host
        if target.host == visa_host
          confirmation = target
          break
        end
        auth.get(target.request_uri, headers: navigation)

        assert_equal 303, auth.response.status
        current_browser = auth
        current_host = auth_host
      end

      assert confirmation
      assert_predicate binding.reload, :attached?

      attached_session = binding.auth_ceremony_session_id
      other_auth = open_session
      other_auth.host!(auth_host)
      other_auth.https!
      other_auth.get("/ceremony_bindings", params: { entry_ref: binding.entry_ref, ri: "jp" }, headers: navigation)

      assert_equal 400, other_auth.response.status
      assert_equal attached_session, binding.reload.auth_ceremony_session_id

      foreign = open_session
      foreign.host!(visa_host)
      foreign.https!
      foreign.get(confirmation.request_uri, headers: navigation)

      assert_equal 400, foreign.response.status
      assert_nil binding.reload.base_confirmed_at

      owner.get(confirmation.request_uri, headers: navigation)

      assert_equal 303, owner.response.status
      entry_uri = URI.parse(owner.response.location)
      other_auth.get(entry_uri.request_uri, headers: navigation)

      assert_equal 400, other_auth.response.status
      assert_nil binding.reload.redeemed_at
      assert_predicate binding.reload, :confirmed?
      auth.get(URI.parse(owner.response.location).request_uri, headers: navigation)

      assert_equal 303, auth.response.status
      assert_predicate binding.reload, :redeemed?
      auth.get(URI.parse(auth.response.location).request_uri, headers: navigation)

      assert_equal 200, auth.response.status

      # Public Auth proof issuance isolates the OP receiver from credential verification.
      actor = actor_model.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: active_status)
      result = BaseAuthAdmissionCoordinator.register_result_and_issue!(
        surface:, login_challenge: parent.login_challenge, actor:, session_ref: "ceremony-result",
        auth_method: "passkey", authentication_event_at: parent.class.database_now,
        ceremony_session_ref: binding.admitted_auth_ceremony_session_id.to_s,
      )
      submission = { result_ref: result.reference, transaction_ref: parent.transaction_id, ri: "jp" }
      before_parent = parent.reload.attributes
      before_binding = binding.reload.attributes
      tokens_before = token_model.where(owner_key => actor.id).count

      foreign.get("/oidc/result", params: submission, headers: navigation)

      assert_equal 400, foreign.response.status
      assert_nil foreign.response.location
      parent_unchanged = before_parent == parent.reload.attributes

      assert parent_unchanged, "foreign result changed the parent"
      binding_unchanged = before_binding == binding.reload.attributes

      assert binding_unchanged, "foreign result changed the binding"
      assert_equal tokens_before, token_model.where(owner_key => actor.id).count

      owner.get("/oidc/result", params: submission, headers: navigation)

      assert_equal 303, owner.response.status
      assert_predicate parent.reload.base_finalized_at, :present?
      assert_equal tokens_before + 1, token_model.where(owner_key => actor.id).count
      finalized_root = parent.browser_session_ref
      owner.get("/oidc/result", params: submission, headers: navigation)

      assert_equal 400, owner.response.status
      assert_nil owner.response.location
      assert_equal finalized_root, parent.reload.browser_session_ref
      assert_equal tokens_before + 1, token_model.where(owner_key => actor.id).count
    end
  ensure
    ActionController::Base.allow_forgery_protection = protection
  end

  test "A27-1b: a lost root cookie is not reused and can be removed through session-limit remediation" do
    host = ENV.fetch("PUBLIC_VISA_SERVICE_URL")
    host!(host)
    https!
    feature = FeatureFlags::REGISTRY.fetch(:sign_in_available_app).name
    previous_availability = Flipper.enabled?(feature)
    Flipper.enable(feature)
    actor = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
    client_id = "core-app-jp"
    parameters = {
      response_type: "code",
      client_id: client_id,
      redirect_uri: OidcClientRegistry.find!(client_id).redirect_uris_by_realm.fetch("client").first,
      code_challenge: "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM",
      code_challenge_method: "S256",
      scope: "openid profile",
      state: SecureRandom.urlsafe_base64(32),
      nonce: SecureRandom.urlsafe_base64(32),
    }
    # The browser nonce lives in the Visa session, which an integration test can only obtain from a
    # real request; the authorization start writes it together with the parent transaction.
    get(
      "/oauth/authorize", params: parameters.merge(ri: "jp"), headers: {
        "Sec-Fetch-Mode" => "navigate", "Sec-Fetch-Dest" => "document",
      },
    )

    assert_equal 303, response.status
    first_parent = ClientOidcAuthorizationTransaction.find_by!(state: parameters.fetch(:state))
    first_binding = ClientAuthAdmissionBinding.find_by!(authorization_transaction_id: first_parent.id)
    first_ceremony, first_sid = ClientAuthCeremonySession.issue!
    first_binding.attach_auth_session!(auth_session: first_ceremony, confirmation_ref: SecureRandom.uuid)
    first_binding.confirm_base!(base_token: nil, browser_digest: first_binding.base_browser_digest)
    admitted_ceremony, = ClientAuthCeremonySession.rotate_and_admit!(
      admission_purpose: "authentication_handoff", previous_raw_sid: first_sid,
      authorization_transaction_ref: first_parent.transaction_id,
    )
    first_binding.redeem!(auth_session: first_ceremony, admitted_auth_session: admitted_ceremony)
    first_result = BaseAuthAdmissionCoordinator.register_result_and_issue!(
      surface: "app", login_challenge: first_parent.login_challenge, actor: actor,
      session_ref: "first-authentication-evidence", auth_method: "passkey",
      authentication_event_at: first_parent.class.database_now,
      ceremony_session_ref: admitted_ceremony.id.to_s,
    )
    navigation = {
      "Sec-Fetch-Mode" => "navigate",
      "Sec-Fetch-Dest" => "document",
      "Sec-Fetch-Site" => "cross-site",
    }
    get(
      "/oidc/result", params: {
        result_ref: first_result.reference, transaction_ref: first_parent.transaction_id, ri: "jp",
      }, headers: navigation,
    )

    assert_equal 303, response.status
    orphan_root = ClientToken.find_by!(public_id: first_parent.reload.browser_session_ref)

    assert_equal ClientTokenStatus::ACTIVE, orphan_root.user_token_status_id
    assert_predicate cookies[AuthenticationBase::ACCESS_COOKIE_KEY], :present?
    assert_predicate cookies[AuthenticationBase::REFRESH_COOKIE_KEY], :present?

    cookies.delete(AuthenticationBase::ACCESS_COOKIE_KEY)
    cookies.delete(AuthenticationBase::REFRESH_COOKIE_KEY)

    assert_nil cookies[AuthenticationBase::ACCESS_COOKIE_KEY]
    assert_nil cookies[AuthenticationBase::REFRESH_COOKIE_KEY]
    assert_equal ClientTokenStatus::ACTIVE, orphan_root.reload.user_token_status_id

    active_slots = ClientToken.where(user_id: actor.id, user_token_status_id: ClientTokenStatus::ACTIVE).count
    Array.new(ClientToken::MAX_SESSIONS_PER_USER - active_slots) do
      ClientToken.create!(authentication_epoch: 0, user: actor)
    end
    orphan_root.update!(root_login_established_at: ClientToken.database_now - 1.hour)
    second_parameters = parameters.merge(
      state: SecureRandom.urlsafe_base64(32), nonce: SecureRandom.urlsafe_base64(32), ri: "jp",
    )
    assert_no_difference "ClientToken.where(user_id: actor.id).count" do
      post(
        "/oauth/authorize", params: second_parameters.merge(ceremony_action: "start"), headers: {
          "Origin" => "https://#{host}", "Sec-Fetch-Site" => "same-origin",
        },
      )
    end

    assert_equal 303, response.status
    second_parent = ClientOidcAuthorizationTransaction.find_by!(state: second_parameters.fetch(:state))

    assert_equal "pending", second_parent.status
    second_binding = ClientAuthAdmissionBinding.find_by!(authorization_transaction_id: second_parent.id)
    second_ceremony, second_sid = ClientAuthCeremonySession.issue!
    second_binding.attach_auth_session!(auth_session: second_ceremony, confirmation_ref: SecureRandom.uuid)
    second_binding.confirm_base!(base_token: nil, browser_digest: second_binding.base_browser_digest)
    second_admitted_ceremony, = ClientAuthCeremonySession.rotate_and_admit!(
      admission_purpose: "authentication_handoff", previous_raw_sid: second_sid,
      authorization_transaction_ref: second_parent.transaction_id,
    )
    second_binding.redeem!(auth_session: second_ceremony, admitted_auth_session: second_admitted_ceremony)
    second_result = BaseAuthAdmissionCoordinator.register_result_and_issue!(
      surface: "app", login_challenge: second_parent.login_challenge, actor: actor,
      session_ref: "second-authentication-evidence", auth_method: "passkey",
      authentication_event_at: second_parent.class.database_now,
      ceremony_session_ref: second_admitted_ceremony.id.to_s,
    )
    assert_no_difference "ClientToken.where(user_id: actor.id).count" do
      get(
        "/oidc/result", params: {
          result_ref: second_result.reference, transaction_ref: second_parent.transaction_id, ri: "jp",
        }, headers: navigation,
      )
    end

    assert_equal 303, response.status
    limitation = URI.parse(response.location)
    gate = session[:session_limit_gate] || session["session_limit_gate"]
    challenge = gate.fetch("resolution_challenge")
    resolution = ClientSessionLimitResolutionTransaction.find_active_by_challenge(challenge)

    assert resolution
    patch(
      limitation.request_uri, params: {
        resolution_challenge: challenge,
        session_ref: SessionLimitResolutionTokenRef.issue(orphan_root),
      },
    )

    assert_response :redirect
    second_root = ClientToken.find_by!(public_id: second_parent.reload.browser_session_ref)

    assert_not_equal orphan_root.public_id, second_root.public_id
    assert_equal ClientTokenStatus::REVOKED, orphan_root.reload.user_token_status_id
    assert_equal ClientTokenStatus::ACTIVE, second_root.user_token_status_id
    assert_equal ClientToken::MAX_SESSIONS_PER_USER,
                 ClientToken.where(user_id: actor.id, user_token_status_id: ClientTokenStatus::ACTIVE).count
    assert_predicate resolution.reload, :resolved?
  ensure
    previous_availability.nil? ? nil : (previous_availability ? Flipper.enable(feature) : Flipper.disable(feature))
  end

  test "A27-3: the OP accepts only the last-started tab binding and issues at most one Root" do
    host = ENV.fetch("PUBLIC_VISA_SERVICE_URL")
    host!(host)
    https!
    feature = FeatureFlags::REGISTRY.fetch(:sign_in_available_app).name
    previous_availability = Flipper.enabled?(feature)
    Flipper.enable(feature)
    client = OidcClientRegistry.find!("core-app-jp")
    authorization_parameters = {
      response_type: "code",
      client_id: client.client_id,
      redirect_uri: client.redirect_uris_by_realm.fetch("client").first,
      code_challenge: "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM",
      code_challenge_method: "S256",
      scope: "openid profile",
      ri: "jp",
    }
    first_parameters = authorization_parameters.merge(
      state: SecureRandom.urlsafe_base64(32), nonce: SecureRandom.urlsafe_base64(32),
    )
    navigation = { "Sec-Fetch-Mode" => "navigate", "Sec-Fetch-Dest" => "document" }
    get("/oauth/authorize", params: first_parameters, headers: navigation)

    assert_equal 303, response.status
    first_parent = ClientOidcAuthorizationTransaction.find_by!(state: first_parameters.fetch(:state))
    first_nonce = session.fetch(BaseAdmissionBrowserBinding::BROWSER_NONCE_SESSION_KEY)
    second_parameters = authorization_parameters.merge(
      state: SecureRandom.urlsafe_base64(32), nonce: SecureRandom.urlsafe_base64(32),
    )
    get("/oauth/authorize", params: second_parameters, headers: navigation)

    assert_equal 303, response.status
    second_parent = ClientOidcAuthorizationTransaction.find_by!(state: second_parameters.fetch(:state))
    second_nonce = session.fetch(BaseAdmissionBrowserBinding::BROWSER_NONCE_SESSION_KEY)

    assert_not_equal first_nonce, second_nonce
    first_binding = ClientAuthAdmissionBinding.find_by!(authorization_transaction_id: first_parent.id)
    second_binding = ClientAuthAdmissionBinding.find_by!(authorization_transaction_id: second_parent.id)
    [
      [first_parent, first_binding],
      [second_parent, second_binding],
    ].each do |parent, binding|
      attached, raw_sid = ClientAuthCeremonySession.issue!
      binding.attach_auth_session!(auth_session: attached, confirmation_ref: SecureRandom.uuid)
      nonce_for_binding = (parent.id == first_parent.id) ? first_nonce : second_nonce
      binding.confirm_base!(
        base_token: nil,
        browser_digest: AuthAdmissionBinding.browser_digest(
          surface: "app", entry_ref: binding.entry_ref, nonce: nonce_for_binding,
        ),
      )
      admitted, = ClientAuthCeremonySession.rotate_and_admit!(
        admission_purpose: "authentication_handoff", previous_raw_sid: raw_sid,
        authorization_transaction_ref: parent.transaction_id,
      )
      binding.redeem!(auth_session: attached, admitted_auth_session: admitted)
    end
    actor = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
    first_result = BaseAuthAdmissionCoordinator.register_result_and_issue!(
      surface: "app", login_challenge: first_parent.login_challenge, actor: actor,
      session_ref: "first-tab-evidence", auth_method: "passkey",
      authentication_event_at: first_parent.class.database_now,
      ceremony_session_ref: first_binding.reload.admitted_auth_ceremony_session_id.to_s,
    )
    second_result = BaseAuthAdmissionCoordinator.register_result_and_issue!(
      surface: "app", login_challenge: second_parent.login_challenge, actor: actor,
      session_ref: "second-tab-evidence", auth_method: "passkey",
      authentication_event_at: second_parent.class.database_now,
      ceremony_session_ref: second_binding.reload.admitted_auth_ceremony_session_id.to_s,
    )
    token_count = ClientToken.where(user_id: actor.id).count
    first_binding_before = first_binding.reload.attributes

    get(
      "/oidc/result", params: {
        result_ref: first_result.reference, transaction_ref: first_parent.transaction_id,
      }, headers: navigation,
    )

    assert_equal 400, response.status
    assert_nil first_parent.reload.base_finalized_at
    assert_equal first_binding_before, first_binding.reload.attributes
    assert_equal token_count, ClientToken.where(user_id: actor.id).count

    get(
      "/oidc/result", params: {
        result_ref: second_result.reference, transaction_ref: second_parent.transaction_id,
      }, headers: navigation,
    )

    assert_equal 303, response.status
    assert_predicate second_parent.reload.base_finalized_at, :present?
    assert_equal token_count + 1, ClientToken.where(user_id: actor.id).count
    assert_nil first_parent.reload.base_finalized_at
  ensure
    previous_availability.nil? ? nil : (previous_availability ? Flipper.enable(feature) : Flipper.disable(feature))
  end
end
