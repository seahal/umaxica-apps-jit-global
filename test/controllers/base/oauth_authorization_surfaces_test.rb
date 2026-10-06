# typed: false
# frozen_string_literal: true

require "test_helper"

# The OAuth authorization endpoint exists on all three base surfaces and each
# one owns its own realm, validator resource type, and error mapping. The app
# surface is covered by BaseOauthOidcAuthorityTest; these pin the spec-defined
# error responses of the corporate and staff surfaces.
class BaseOauthAuthorizationSurfacesTest < ActionDispatch::IntegrationTest
  include OidcAuthorizationResponseHelper

  # Rate-limit counters are a NullStore by default in test so unrelated tests
  # cannot accumulate them; this file asserts real limiting behavior, so it
  # opts into a deterministic MemoryStore.
  rate_limit_counters!

  fixtures :operators, :operator_statuses, :operator_token_kinds, :operator_token_statuses,
           :operator_token_binding_methods, :operator_token_dbsc_statuses,
           :visitors, :visitor_statuses, :visitor_token_kinds, :visitor_token_statuses,
           :visitor_token_binding_methods, :visitor_token_dbsc_statuses

  setup { Rails.configuration.x.rate_limit.fetch(:store).clear }

  test "com authorize rejects a scope that omits openid" do
    host = ENV.fetch("PUBLIC_BASE_CORPORATE_URL")

    get base_com_oauth_authorization_url(
      host: host, **authorize_params(realm: "visitor").merge(scope: "profile"),
    ), headers: { "Host" => host }

    assert_response :bad_request
    assert_equal "invalid_request", response.parsed_body.fetch("error")
    assert_match(/openid/, response.parsed_body.fetch("error_description"))
  end

  test "org authorize rejects a scope that omits openid" do
    host = ENV.fetch("PUBLIC_BASE_STAFF_URL")

    get base_org_oauth_authorization_url(
      host: host, **authorize_params(realm: "operator").merge(scope: "profile"),
    ), headers: { "Host" => host }

    assert_response :bad_request
    assert_equal "invalid_request", response.parsed_body.fetch("error")
  end

  test "com authorize rejects a request with no state" do
    host = ENV.fetch("PUBLIC_BASE_CORPORATE_URL")

    get base_com_oauth_authorization_url(
      host: host, **authorize_params(realm: "visitor").except(:state),
    ), headers: { "Host" => host }

    assert_response :bad_request
    assert_equal "invalid_request", response.parsed_body.fetch("error")
  end

  test "org authorize rejects a request with no state" do
    host = ENV.fetch("PUBLIC_BASE_STAFF_URL")

    get base_org_oauth_authorization_url(
      host: host, **authorize_params(realm: "operator").except(:state),
    ), headers: { "Host" => host }

    assert_response :bad_request
    assert_equal "invalid_request", response.parsed_body.fetch("error")
  end

  test "com authorize rejects an unregistered client" do
    host = ENV.fetch("PUBLIC_BASE_CORPORATE_URL")

    get base_com_oauth_authorization_url(
      host: host, **authorize_params(realm: "visitor").merge(client_id: "not-registered"),
    ), headers: { "Host" => host }

    assert_response :bad_request
    assert_equal "invalid_request", response.parsed_body.fetch("error")
  end

  test "org authorize rejects an unregistered client" do
    host = ENV.fetch("PUBLIC_BASE_STAFF_URL")

    get base_org_oauth_authorization_url(
      host: host, **authorize_params(realm: "operator").merge(client_id: "not-registered"),
    ), headers: { "Host" => host }

    assert_response :bad_request
    assert_equal "invalid_request", response.parsed_body.fetch("error")
  end

  test "com and org authorize return login_required for prompt none without a session" do
    [
      {
        host: ENV.fetch("PUBLIC_BASE_CORPORATE_URL"),
        route: :base_com_oauth_authorization_url,
        realm: "visitor",
        transaction_class: VisitorOidcAuthorizationTransaction,
      },
      {
        host: ENV.fetch("PUBLIC_BASE_STAFF_URL"),
        route: :base_org_oauth_authorization_url,
        realm: "operator",
        transaction_class: OperatorOidcAuthorizationTransaction,
      },
    ].each do |surface|
      host!(surface.fetch(:host))

      assert_no_difference -> { surface.fetch(:transaction_class).count } do
        get public_send(
          surface.fetch(:route),
          host: surface.fetch(:host),
          **authorize_params(realm: surface.fetch(:realm)).merge(prompt: "none"),
        ),
            headers: { "Host" => surface.fetch(:host) }
      end

      assert_oidc_error_redirect(
        error: "login_required",
        redirect_uri: authorize_params(realm: surface.fetch(:realm)).fetch(:redirect_uri),
      )
    end
  end

  test "com authorize rejects a redirect_uri that is not registered for the corporate realm" do
    host = ENV.fetch("PUBLIC_BASE_CORPORATE_URL")

    get base_com_oauth_authorization_url(
      host: host,
      **authorize_params(realm: "visitor").merge(redirect_uri: "https://attacker.example/callback"),
    ), headers: { "Host" => host }

    assert_response :bad_request
    assert_equal "invalid_request", response.parsed_body.fetch("error")
  end

  # Capacity (plans/active/sign-fqdn-integrated-plan.md section 5): 2048 bytes per parameter and
  # 8192 bytes per query, refused with 400 before any transaction is allocated. Values use only
  # unreserved characters so the byte counts are exact on the wire.
  test "authorize accepts a 2048-byte parameter and refuses 2049 bytes before allocating state" do
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    base = authorize_params(realm: "client").except(:state).to_query

    { 2047 => true, 2048 => true, 2049 => false }.each do |bytes, accepted|
      count = ClientOidcAuthorizationTransaction.count
      get "/oauth/authorize?#{base}&state=#{"a" * bytes}", headers: { "Host" => host }

      if accepted
        assert_response :redirect, "#{bytes} bytes"
        assert_equal count + 1, ClientOidcAuthorizationTransaction.count, "#{bytes} bytes"
      else
        assert_response :bad_request, "#{bytes} bytes"
        assert_equal "invalid_request", response.parsed_body.fetch("error")
        assert_equal count, ClientOidcAuthorizationTransaction.count, "#{bytes} bytes"
      end
    end
  end

  test "authorize accepts an 8192-byte query and refuses 8193 bytes before allocating state" do
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    padding = (1..3).map { |index| "pad#{index}=#{"b" * 2000}" }.join("&")
    base = "#{authorize_params(realm: "client").to_query}&#{padding}&pad4="

    { 8191 => true, 8192 => true, 8193 => false }.each do |bytes, accepted|
      query = "#{base}#{"c" * (bytes - base.bytesize)}"
      count = ClientOidcAuthorizationTransaction.count

      assert_equal bytes, query.bytesize
      get "/oauth/authorize?#{query}", headers: { "Host" => host }

      if accepted
        assert_response :redirect, "#{bytes} bytes"
        assert_equal count + 1, ClientOidcAuthorizationTransaction.count, "#{bytes} bytes"
      else
        assert_response :bad_request, "#{bytes} bytes"
        assert_equal count, ClientOidcAuthorizationTransaction.count, "#{bytes} bytes"
      end
    end
  end

  test "authorize refuses array and hash parameter values before allocating state" do
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    base = authorize_params(realm: "client").except(:state).to_query

    ["state[]=a", "state[k]=a"].each do |shaped|
      count = ClientOidcAuthorizationTransaction.count
      get "/oauth/authorize?#{base}&#{shaped}", headers: { "Host" => host }

      assert_response :bad_request, shaped
      assert_equal count, ClientOidcAuthorizationTransaction.count, shaped
    end
  end

  # E02: a browser already authenticated at Base starting a new Sign is refused, even when the RP has
  # no session yet. This is the intended product constraint, not an SSO success path.
  test "E02 app authorize refuses an authenticated browser with a plain 403 and issues nothing" do
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    transaction_count = ClientOidcAuthorizationTransaction.count

    get base_app_oauth_authorization_url(host: host, **authorize_params(realm: "client")),
        headers: as_user_headers(clients(:one), host: host)

    assert_response :forbidden
    assert_equal I18n.t("errors.messages.operation_not_permitted"), response.body
    assert_equal "text/plain", response.media_type
    assert_includes response.headers["Cache-Control"], "no-store"
    assert_nil response.location
    assert_equal transaction_count, ClientOidcAuthorizationTransaction.count
  end

  # E02: a browser already authenticated at Base starting a new Sign is refused, even when the RP has
  # no session yet. This is the intended product constraint, not an SSO success path.
  test "E02 com authorize refuses an authenticated browser with a plain 403 and issues nothing" do
    host = ENV.fetch("PUBLIC_BASE_CORPORATE_URL")
    transaction_count = VisitorOidcAuthorizationTransaction.count

    get base_com_oauth_authorization_url(host: host, **authorize_params(realm: "visitor")),
        headers: as_visitor_headers(visitors(:reserved_visitor), host: host)

    assert_response :forbidden
    assert_equal I18n.t("errors.messages.operation_not_permitted"), response.body
    assert_equal "text/plain", response.media_type
    assert_includes response.headers["Cache-Control"], "no-store"
    assert_nil response.location
    assert_equal transaction_count, VisitorOidcAuthorizationTransaction.count
  end

  # E02: a browser already authenticated at Base starting a new Sign is refused, even when the RP has
  # no session yet. This is the intended product constraint, not an SSO success path.
  test "E02 org authorize refuses an authenticated browser with a plain 403 and issues nothing" do
    host = ENV.fetch("PUBLIC_BASE_STAFF_URL")
    transaction_count = OperatorOidcAuthorizationTransaction.count

    get base_org_oauth_authorization_url(host: host, **authorize_params(realm: "operator")),
        headers: as_staff_headers(operators(:one), host: host)

    assert_response :forbidden
    assert_equal I18n.t("errors.messages.operation_not_permitted"), response.body
    assert_equal "text/plain", response.media_type
    assert_includes response.headers["Cache-Control"], "no-store"
    assert_nil response.location
    assert_equal transaction_count, OperatorOidcAuthorizationTransaction.count
  end

  # E03: a Valkey outage while reading the result is a dependency failure, not a rejected request.
  # Only the Valkey store is replaced; transaction lookup, readiness checks, and the route are real.
  test "E03 com authorize answers 503 without consuming the transaction when Valkey is unavailable" do
    host = ENV.fetch("PUBLIC_BASE_CORPORATE_URL")
    visitor = visitors(:reserved_visitor)
    issuance = OidcAuthorizationTransactionCoordinator.issue!(
      surface: "com", intent: "sign_in", params: authorize_params(realm: "visitor"),
    )
    result = BaseAuthAdmissionCoordinator.register_result_and_issue!(
      surface: "com", login_challenge: issuance.transaction.login_challenge,
      actor: visitor, session_ref: "com-e03-session", auth_method: "passkey",
      authentication_event_at: Time.current,
    )
    unavailable_store = Object.new
    def unavailable_store.read(*, **) = raise(Umaxica::Valkey::Unavailable, "Valkey admission read unavailable")

    Valkey::AuthState::OpaqueAdmissionStore.stub(:new, unavailable_store) do
      post base_com_oauth_authorization_url(host: host),
           params: { result: result.code, transaction_ref: result.transaction.transaction_id },
           headers: cross_surface_result_headers(host, "PUBLIC_AUTH_CORPORATE_URL")
    end

    assert_response :service_unavailable
    assert_equal "temporarily_unavailable", response.parsed_body.fetch("error")
    assert_not_predicate issuance.transaction.reload, :consumed?
  end

  test "com authorize rejects an unknown result code as an invalid request" do
    host = ENV.fetch("PUBLIC_BASE_CORPORATE_URL")

    post base_com_oauth_authorization_url(host: host),
         params: { result: "no-such-challenge", transaction_ref: "unknown" },
         headers: cross_surface_result_headers(host, "PUBLIC_AUTH_CORPORATE_URL")

    assert_response :bad_request
    assert_equal "invalid_request", response.parsed_body.fetch("error")
    assert_equal "invalid authorization request", response.parsed_body.fetch("error_description")
  end

  test "com authorize reuses a finalized browser session without creating another root session" do
    host = ENV.fetch("PUBLIC_BASE_CORPORATE_URL")
    visitor = visitors(:reserved_visitor)
    token_count_before = VisitorToken.where(visitor_id: visitor.id).count
    issuance = OidcAuthorizationTransactionCoordinator.issue!(
      surface: "com", intent: "sign_in", params: authorize_params(realm: "visitor"),
    )
    result = BaseAuthAdmissionCoordinator.register_result_and_issue!(
      surface: "com", login_challenge: issuance.transaction.login_challenge,
      actor: visitor, session_ref: "com-resume-session", auth_method: "passkey",
      authentication_event_at: Time.current,
    )

    post base_com_oauth_authorization_url(host: host),
         params: { result: result.code, transaction_ref: result.transaction.transaction_id },
         headers: cross_surface_result_headers(host, "PUBLIC_AUTH_CORPORATE_URL")

    assert_response :redirect
    assert_predicate issuance.transaction.reload, :consumed?
    browser_session_ref = issuance.transaction.browser_session_ref

    assert_predicate browser_session_ref, :present?
    assert_equal token_count_before + 1, VisitorToken.where(visitor_id: visitor.id).count

    post base_com_oauth_authorization_url(host: host),
         params: { result: result.code, transaction_ref: result.transaction.transaction_id },
         headers: cross_surface_result_headers(host, "PUBLIC_AUTH_CORPORATE_URL")

    assert_response :redirect
    assert_equal browser_session_ref, issuance.transaction.reload.browser_session_ref
    assert_equal token_count_before + 1, VisitorToken.where(visitor_id: visitor.id).count
  end

  test "org authorize refuses a new root login at the one-session limit and issues nothing" do
    host = ENV.fetch("PUBLIC_BASE_STAFF_URL")
    operator = operators(:one)
    OperatorToken.where(staff_id: operator.id).delete_all
    OperatorToken.create!(staff_id: operator.id, staff_token_status_id: OperatorTokenStatus::ACTIVE)
    issuance = OidcAuthorizationTransactionCoordinator.issue!(
      surface: "org", intent: "sign_in", params: authorize_params(realm: "operator"),
    )
    result = BaseAuthAdmissionCoordinator.register_result_and_issue!(
      surface: "org", login_challenge: issuance.transaction.login_challenge,
      actor: operator, session_ref: "org-limit-session", auth_method: "passkey",
      authentication_event_at: Time.current,
    )

    assert_no_difference(-> { OperatorToken.where(staff_id: operator.id).count }) do
      post base_org_oauth_authorization_url(host: host),
           params: { result: result.code, transaction_ref: result.transaction.transaction_id },
           headers: cross_surface_result_headers(host, "PUBLIC_AUTH_STAFF_URL")
    end

    assert_response :forbidden
    assert_nil issuance.transaction.reload.browser_session_ref
  end

  test "org authorize reuses a finalized browser session without creating another root session" do
    host = ENV.fetch("PUBLIC_BASE_STAFF_URL")
    operator = operators(:one)
    # The org limit is one session; start from none so the first resume can establish one.
    OperatorToken.where(staff_id: operator.id).delete_all
    token_count_before = OperatorToken.where(staff_id: operator.id).count
    issuance = OidcAuthorizationTransactionCoordinator.issue!(
      surface: "org", intent: "sign_in", params: authorize_params(realm: "operator"),
    )
    result = BaseAuthAdmissionCoordinator.register_result_and_issue!(
      surface: "org", login_challenge: issuance.transaction.login_challenge,
      actor: operator, session_ref: "org-resume-session", auth_method: "passkey",
      authentication_event_at: Time.current,
    )

    post base_org_oauth_authorization_url(host: host),
         params: { result: result.code, transaction_ref: result.transaction.transaction_id },
         headers: cross_surface_result_headers(host, "PUBLIC_AUTH_STAFF_URL")

    assert_response :redirect
    assert_predicate issuance.transaction.reload, :consumed?
    browser_session_ref = issuance.transaction.browser_session_ref

    assert_predicate browser_session_ref, :present?
    assert_equal token_count_before + 1, OperatorToken.where(staff_id: operator.id).count

    post base_org_oauth_authorization_url(host: host),
         params: { result: result.code, transaction_ref: result.transaction.transaction_id },
         headers: cross_surface_result_headers(host, "PUBLIC_AUTH_STAFF_URL")

    assert_response :redirect
    assert_equal browser_session_ref, issuance.transaction.reload.browser_session_ref
    assert_equal token_count_before + 1, OperatorToken.where(staff_id: operator.id).count
  end

  test "com authorize refuses a result whose ceremony is not ready" do
    host = ENV.fetch("PUBLIC_BASE_CORPORATE_URL")
    issuance = OidcAuthorizationTransactionCoordinator.issue!(
      surface: "com", intent: "sign_in", params: authorize_params(realm: "visitor"),
    )
    result_code = Valkey::AuthState::OpaqueAdmissionStore.new.issue!(
      purpose: "authentication_result",
      actor_type: "visitor",
      surface: "com",
      subject_ref: issuance.transaction.transaction_id,
    )

    post base_com_oauth_authorization_url(host: host),
         params: { result: result_code, transaction_ref: issuance.transaction.transaction_id },
         headers: cross_surface_result_headers(host, "PUBLIC_AUTH_CORPORATE_URL")

    assert_response :bad_request
    assert_equal "invalid authorization request", response.parsed_body.fetch("error_description")
    assert_not issuance.transaction.reload.consumed?

    still_available = Valkey::AuthState::OpaqueAdmissionStore.new.consume!(
      purpose: "authentication_result",
      raw_code: result_code,
      expected: {
        actor_type: "visitor",
        surface: "com",
        subject_ref: issuance.transaction.transaction_id,
      },
    )

    assert_predicate still_available, :success?
  end

  test "org authorize refuses a result whose ceremony is not ready" do
    host = ENV.fetch("PUBLIC_BASE_STAFF_URL")
    issuance = OidcAuthorizationTransactionCoordinator.issue!(
      surface: "org", intent: "sign_in", params: authorize_params(realm: "operator"),
    )
    result_code = Valkey::AuthState::OpaqueAdmissionStore.new.issue!(
      purpose: "authentication_result",
      actor_type: "operator",
      surface: "org",
      subject_ref: issuance.transaction.transaction_id,
    )

    post base_org_oauth_authorization_url(host: host),
         params: { result: result_code, transaction_ref: issuance.transaction.transaction_id },
         headers: cross_surface_result_headers(host, "PUBLIC_AUTH_STAFF_URL")

    assert_response :bad_request
    assert_equal "invalid authorization request", response.parsed_body.fetch("error_description")
    assert_not issuance.transaction.reload.consumed?

    still_available = Valkey::AuthState::OpaqueAdmissionStore.new.consume!(
      purpose: "authentication_result",
      raw_code: result_code,
      expected: {
        actor_type: "operator",
        surface: "org",
        subject_ref: issuance.transaction.transaction_id,
      },
    )

    assert_predicate still_available, :success?
  end

  test "com authorize refuses an expired result ceremony" do
    host = ENV.fetch("PUBLIC_BASE_CORPORATE_URL")
    issuance = OidcAuthorizationTransactionCoordinator.issue!(
      surface: "com", intent: "sign_in", params: authorize_params(realm: "visitor"),
    )
    result = BaseAuthAdmissionCoordinator.register_result_and_issue!(
      surface: "com", login_challenge: issuance.transaction.login_challenge,
      actor: visitors(:reserved_visitor), session_ref: "com-expired-session", auth_method: "passkey",
      authentication_event_at: Time.current,
    )
    decision_time = issuance.transaction.class.database_now
    issuance.transaction.update!(login_challenge_expires_at: decision_time - 1.second)

    post base_com_oauth_authorization_url(host: host),
         params: { result: result.code, transaction_ref: result.transaction.transaction_id },
         headers: cross_surface_result_headers(host, "PUBLIC_AUTH_CORPORATE_URL")

    assert_response :bad_request
    assert_equal "invalid authorization request", response.parsed_body.fetch("error_description")

    still_available = Valkey::AuthState::OpaqueAdmissionStore.new.consume!(
      purpose: "authentication_result",
      raw_code: result.code,
      expected: {
        actor_type: "visitor",
        surface: "com",
        subject_ref: result.transaction.transaction_id,
      },
    )

    assert_predicate still_available, :success?
  end

  test "org authorize refuses an expired result ceremony" do
    host = ENV.fetch("PUBLIC_BASE_STAFF_URL")
    issuance = OidcAuthorizationTransactionCoordinator.issue!(
      surface: "org", intent: "sign_in", params: authorize_params(realm: "operator"),
    )
    result = BaseAuthAdmissionCoordinator.register_result_and_issue!(
      surface: "org", login_challenge: issuance.transaction.login_challenge,
      actor: operators(:one), session_ref: "org-expired-session", auth_method: "passkey",
      authentication_event_at: Time.current,
    )
    decision_time = issuance.transaction.class.database_now
    issuance.transaction.update!(login_challenge_expires_at: decision_time - 1.second)

    post base_org_oauth_authorization_url(host: host),
         params: { result: result.code, transaction_ref: result.transaction.transaction_id },
         headers: cross_surface_result_headers(host, "PUBLIC_AUTH_STAFF_URL")

    assert_response :bad_request
    assert_equal "invalid authorization request", response.parsed_body.fetch("error_description")

    still_available = Valkey::AuthState::OpaqueAdmissionStore.new.consume!(
      purpose: "authentication_result",
      raw_code: result.code,
      expected: {
        actor_type: "operator",
        surface: "org",
        subject_ref: result.transaction.transaction_id,
      },
    )

    assert_predicate still_available, :success?
  end

  test "com result binding mismatch does not consume the result" do
    host = ENV.fetch("PUBLIC_BASE_CORPORATE_URL")
    first = OidcAuthorizationTransactionCoordinator.issue!(
      surface: "com", intent: "sign_in", params: authorize_params(realm: "visitor"),
    )
    second = OidcAuthorizationTransactionCoordinator.issue!(
      surface: "com", intent: "sign_in", params: authorize_params(realm: "visitor").merge(state: "second"),
    )
    result = BaseAuthAdmissionCoordinator.register_result_and_issue!(
      surface: "com", login_challenge: first.transaction.login_challenge,
      actor: visitors(:reserved_visitor), session_ref: "com-binding-session", auth_method: "passkey",
      authentication_event_at: Time.current,
    )

    post base_com_oauth_authorization_url(host: host),
         params: { result: result.code, transaction_ref: second.transaction.transaction_id },
         headers: cross_surface_result_headers(host, "PUBLIC_AUTH_CORPORATE_URL")

    assert_response :bad_request
    assert_not_predicate first.transaction.reload, :consumed?

    post base_com_oauth_authorization_url(host: host),
         params: { result: result.code, transaction_ref: first.transaction.transaction_id },
         headers: cross_surface_result_headers(host, "PUBLIC_AUTH_CORPORATE_URL")

    assert_response :redirect
    assert_predicate first.transaction.reload, :consumed?
  end

  test "com invalid authorization parameters do not consume a valid result" do
    host = ENV.fetch("PUBLIC_BASE_CORPORATE_URL")
    issuance = OidcAuthorizationTransactionCoordinator.issue!(
      surface: "com",
      intent: "sign_in",
      params: authorize_params(realm: "visitor").merge(
        redirect_uri: "https://attacker.example/callback",
      ),
    )
    result = BaseAuthAdmissionCoordinator.register_result_and_issue!(
      surface: "com", login_challenge: issuance.transaction.login_challenge,
      actor: visitors(:reserved_visitor), session_ref: "com-invalid-params-session", auth_method: "passkey",
      authentication_event_at: Time.current,
    )

    post base_com_oauth_authorization_url(host: host),
         params: { result: result.code, transaction_ref: result.transaction.transaction_id },
         headers: cross_surface_result_headers(host, "PUBLIC_AUTH_CORPORATE_URL")

    assert_response :bad_request
    assert_equal "invalid authorization request", response.parsed_body.fetch("error_description")
    assert_predicate issuance.transaction.reload, :authenticated?

    replay = Valkey::AuthState::OpaqueAdmissionStore.new.consume!(
      purpose: "authentication_result",
      raw_code: result.code,
      expected: {
        actor_type: "visitor",
        surface: "com",
        subject_ref: result.transaction.transaction_id,
      },
    )

    assert_predicate replay, :success?
  end

  test "com authorize does not consume a result with a different purpose" do
    host = ENV.fetch("PUBLIC_BASE_CORPORATE_URL")
    issuance = OidcAuthorizationTransactionCoordinator.issue!(
      surface: "com", intent: "authentication", params: authorize_params(realm: "visitor"),
    )
    store = Valkey::AuthState::OpaqueAdmissionStore.new
    result_code = store.issue!(
      purpose: "invitation_result",
      actor_type: "visitor",
      surface: "com",
      subject_ref: issuance.transaction.transaction_id,
      reference: SecureRandom.uuid,
    )

    post base_com_oauth_authorization_url(host: host),
         params: { result: result_code, transaction_ref: issuance.transaction.transaction_id },
         headers: cross_surface_result_headers(host, "PUBLIC_AUTH_CORPORATE_URL")

    assert_response :bad_request
    assert_equal "invalid authorization request", response.parsed_body.fetch("error_description")

    still_available = store.consume!(
      purpose: "invitation_result",
      raw_code: result_code,
      expected: {
        actor_type: "visitor",
        surface: "com",
        subject_ref: issuance.transaction.transaction_id,
      },
    )

    assert_predicate still_available, :success?
  end

  private

  def cross_surface_result_headers(base_host, auth_host_env)
    {
      "Host" => base_host,
      "Origin" => "https://#{ENV.fetch(auth_host_env)}",
      "Sec-Fetch-Site" => "same-site",
    }
  end

  def authorize_params(realm:)
    client_id =
      {
        "client" => "core-app",
        "visitor" => "core-com",
        "operator" => "core-org",
      }.fetch(realm)

    {
      response_type: "code",
      client_id: client_id,
      redirect_uri: OidcClientRegistry.find!(client_id).redirect_uris_by_realm.fetch(realm).first,
      code_challenge: "challenge",
      code_challenge_method: "S256",
      state: "state",
      nonce: "nonce",
      scope: "openid",
    }
  end
end
