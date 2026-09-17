# typed: false
# frozen_string_literal: true

require "test_helper"

# The OAuth authorization endpoint exists on all three base surfaces and each
# one owns its own realm, validator resource type, and error mapping. The app
# surface is covered by BaseOauthOidcAuthorityTest; these pin the spec-defined
# error responses of the corporate and staff surfaces.
class BaseOauthAuthorizationSurfacesTest < ActionDispatch::IntegrationTest
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

      assert_response :bad_request
      assert_equal "login_required", response.parsed_body.fetch("error")
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

  test "com authorize rejects an unknown result code as an invalid request" do
    host = ENV.fetch("PUBLIC_BASE_CORPORATE_URL")

    get base_com_oauth_authorization_url(host: host, result: "no-such-challenge"),
        headers: { "Host" => host }

    assert_response :bad_request
    assert_equal "invalid_request", response.parsed_body.fetch("error")
    assert_equal "invalid authorization request", response.parsed_body.fetch("error_description")
  end

  test "com authorize resumes an authenticated result exactly once" do
    host = ENV.fetch("PUBLIC_BASE_CORPORATE_URL")
    issuance = OidcAuthorizationTransactionCoordinator.issue!(
      surface: "com", intent: "sign_in", params: authorize_params(realm: "visitor"),
    )
    result = BaseAuthAdmissionCoordinator.register_result_and_issue_resume!(
      surface: "com", login_challenge: issuance.transaction.login_challenge,
      actor: visitors(:reserved_visitor), session_ref: "com-resume-session", auth_method: "passkey",
      authentication_event_at: Time.current,
    )

    get base_com_oauth_authorization_url(host: host, result: result.code),
        headers: { "Host" => host }

    assert_response :redirect
    assert_predicate issuance.transaction.reload, :consumed?

    get base_com_oauth_authorization_url(host: host, result: result.code),
        headers: { "Host" => host }

    assert_response :bad_request
    assert_equal "invalid authorization request", response.parsed_body.fetch("error_description")
  end

  test "org authorize resumes an authenticated result exactly once" do
    host = ENV.fetch("PUBLIC_BASE_STAFF_URL")
    issuance = OidcAuthorizationTransactionCoordinator.issue!(
      surface: "org", intent: "sign_in", params: authorize_params(realm: "operator"),
    )
    result = BaseAuthAdmissionCoordinator.register_result_and_issue_resume!(
      surface: "org", login_challenge: issuance.transaction.login_challenge,
      actor: operators(:one), session_ref: "org-resume-session", auth_method: "passkey",
      authentication_event_at: Time.current,
    )

    get base_org_oauth_authorization_url(host: host, result: result.code),
        headers: { "Host" => host }

    assert_response :redirect
    assert_predicate issuance.transaction.reload, :consumed?

    get base_org_oauth_authorization_url(host: host, result: result.code),
        headers: { "Host" => host }

    assert_response :bad_request
    assert_equal "invalid authorization request", response.parsed_body.fetch("error_description")
  end

  test "com authorize refuses a result whose ceremony is not ready" do
    host = ENV.fetch("PUBLIC_BASE_CORPORATE_URL")
    issuance = OidcAuthorizationTransactionCoordinator.issue!(
      surface: "com", intent: "sign_in", params: authorize_params(realm: "visitor"),
    )
    result = BaseAuthAdmissionCoordinator.issue_result!(transaction: issuance.transaction)

    get base_com_oauth_authorization_url(host: host, result: result.code),
        headers: { "Host" => host }

    assert_response :bad_request
    assert_equal "authorization transaction is not ready", response.parsed_body.fetch("error_description")
    assert_not issuance.transaction.reload.consumed?
  end

  test "org authorize refuses a result whose ceremony is not ready" do
    host = ENV.fetch("PUBLIC_BASE_STAFF_URL")
    issuance = OidcAuthorizationTransactionCoordinator.issue!(
      surface: "org", intent: "sign_in", params: authorize_params(realm: "operator"),
    )
    result = BaseAuthAdmissionCoordinator.issue_result!(transaction: issuance.transaction)

    get base_org_oauth_authorization_url(host: host, result: result.code),
        headers: { "Host" => host }

    assert_response :bad_request
    assert_equal "authorization transaction is not ready", response.parsed_body.fetch("error_description")
    assert_not issuance.transaction.reload.consumed?
  end

  test "com authorize refuses an expired result ceremony" do
    host = ENV.fetch("PUBLIC_BASE_CORPORATE_URL")
    now = Time.current
    issuance = result = nil
    travel_to(now) do
      issuance = OidcAuthorizationTransactionCoordinator.issue!(
        surface: "com", intent: "sign_in", params: authorize_params(realm: "visitor"),
        login_challenge_ttl: 1.second, now: now,
      )
      result = BaseAuthAdmissionCoordinator.register_result_and_issue_resume!(
        surface: "com", login_challenge: issuance.transaction.login_challenge,
        actor: visitors(:reserved_visitor), session_ref: "com-expired-session", auth_method: "passkey",
        authentication_event_at: now,
      )
    end

    travel_to(issuance.transaction.login_challenge_expires_at + 1.second) do
      get base_com_oauth_authorization_url(host: host, result: result.code),
          headers: { "Host" => host }
    end

    assert_response :bad_request
    assert_equal "authorization transaction expired", response.parsed_body.fetch("error_description")
  end

  test "org authorize refuses an expired result ceremony" do
    host = ENV.fetch("PUBLIC_BASE_STAFF_URL")
    now = Time.current
    issuance = result = nil
    travel_to(now) do
      issuance = OidcAuthorizationTransactionCoordinator.issue!(
        surface: "org", intent: "sign_in", params: authorize_params(realm: "operator"),
        login_challenge_ttl: 1.second, now: now,
      )
      result = BaseAuthAdmissionCoordinator.register_result_and_issue_resume!(
        surface: "org", login_challenge: issuance.transaction.login_challenge,
        actor: operators(:one), session_ref: "org-expired-session", auth_method: "passkey",
        authentication_event_at: now,
      )
    end

    travel_to(issuance.transaction.login_challenge_expires_at + 1.second) do
      get base_org_oauth_authorization_url(host: host, result: result.code),
          headers: { "Host" => host }
    end

    assert_response :bad_request
    assert_equal "authorization transaction expired", response.parsed_body.fetch("error_description")
  end

  private

  def authorize_params(realm:)
    {
      response_type: "code",
      client_id: "core-next-rp",
      redirect_uri: OidcClientRegistry.find!("core-next-rp").redirect_uris_by_realm.fetch(realm).first,
      code_challenge: "challenge",
      code_challenge_method: "S256",
      state: "state",
      nonce: "nonce",
      scope: "openid",
    }
  end
end
