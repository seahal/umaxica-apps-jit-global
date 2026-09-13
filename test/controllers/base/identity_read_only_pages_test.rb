# typed: false
# frozen_string_literal: true

require "test_helper"

# Read-only identity pages that every surface serves to its own authenticated
# principal: account standing, activity log, and birthdate. Each surface is
# asserted separately so a page that regresses on one surface cannot hide
# behind another.
class BaseIdentityReadOnlyPagesTest < ActionDispatch::IntegrationTest
  fixtures :clients, :client_statuses, :client_token_kinds, :client_token_statuses,
           :client_token_binding_methods, :client_token_dbsc_statuses,
           :client_chronicle_events, :client_chronicle_levels,
           :visitors, :visitor_statuses, :visitor_token_kinds, :visitor_token_statuses,
           :visitor_token_binding_methods, :visitor_token_dbsc_statuses,
           :operators, :operator_statuses, :operator_token_kinds, :operator_token_statuses,
           :operator_token_binding_methods, :operator_token_dbsc_statuses,
           :operator_chronicle_events, :operator_chronicle_levels

  test "app standing page reports the signed-in client's account standing" do
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    host! host
    client = clients(:one)
    token = ClientToken.create!(
      user: client, user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      user_token_status_id: ClientTokenStatus::ACTIVE, discarded_at: 1.day.from_now,
    )
    BaseSelectorBootstrapAuthority.call(surface: :app, principal: client)
    BaseSelectorAuthority.prepare(surface: :app, principal: client, session: token)
    access_token = AuthenticationToken.encode(
      client, host: host, session_public_id: token.public_id,
              resource_type: "client", jwt_issuer_id: "surface:BASE_APP",
    )
    cookies[AuthenticationBase::ACCESS_COOKIE_KEY] = access_token

    get base_app_identity_standing_url(ri: "jp", host: host),
        headers: {
          "Authorization" => "Bearer #{access_token}",
          "Client-Agent" => "Mozilla/5.0",
          "Host" => host,
          "X-TEST-SESSION-PUBLIC-ID" => token.public_id,
        }

    assert_response :success
    assert_equal "Account Standing", inertia_props.fetch("title")
    assert_empty inertia_props.fetch("decisions")
  end

  test "com standing page reports the signed-in visitor's account standing" do
    host = ENV.fetch("PUBLIC_BASE_CORPORATE_URL")
    host! host
    visitor = visitors(:reserved_visitor)
    token = VisitorToken.create!(
      visitor: visitor, visitor_token_kind_id: VisitorTokenKind::BROWSER_WEB,
      visitor_token_status_id: VisitorTokenStatus::ACTIVE, discarded_at: 1.day.from_now,
    )
    BaseSelectorBootstrapAuthority.call(surface: :com, principal: visitor)
    BaseSelectorAuthority.prepare(surface: :com, principal: visitor, session: token)
    access_token = AuthenticationToken.encode(
      visitor, host: host, session_public_id: token.public_id,
               resource_type: "visitor", jwt_issuer_id: "surface:BASE_COM",
    )
    cookies[AuthenticationBase::ACCESS_COOKIE_KEY] = access_token

    get base_com_identity_standing_url(ri: "jp", host: host),
        headers: {
          "Authorization" => "Bearer #{access_token}",
          "Client-Agent" => "Mozilla/5.0",
          "Host" => host,
          "X-TEST-SESSION-PUBLIC-ID" => token.public_id,
        }

    assert_response :success
    assert_equal "Account Standing", inertia_props.fetch("title")
  end

  test "org standing page reports the signed-in operator's account standing" do
    host = ENV.fetch("PUBLIC_BASE_STAFF_URL")
    host! host
    operator = operators(:one)
    token = OperatorToken.create!(
      staff: operator, staff_token_kind_id: OperatorTokenKind::BROWSER_WEB,
      staff_token_status_id: OperatorTokenStatus::ACTIVE, discarded_at: 1.day.from_now,
    )
    BaseSelectorBootstrapAuthority.call(surface: :org, principal: operator)
    BaseSelectorAuthority.prepare(surface: :org, principal: operator, session: token)
    access_token = AuthenticationToken.encode(
      operator, host: host, session_public_id: token.public_id,
                resource_type: "operator", jwt_issuer_id: "surface:BASE_ORG",
    )
    cookies[AuthenticationBase::ACCESS_COOKIE_KEY] = access_token

    get base_org_identity_standing_url(ri: "jp", host: host),
        headers: {
          "Authorization" => "Bearer #{access_token}",
          "Client-Agent" => "Mozilla/5.0",
          "Host" => host,
          "X-TEST-SESSION-PUBLIC-ID" => token.public_id,
        }

    assert_response :success
    assert_equal "Account Standing", inertia_props.fetch("title")
  end

  test "app activity log lists only normalized activity for the signed-in client" do
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    host! host
    client = clients(:one)
    token = ClientToken.create!(
      user: client, user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      user_token_status_id: ClientTokenStatus::ACTIVE, discarded_at: 1.day.from_now,
    )
    ChronicleRecord.connected_to(role: :writing) do
      ClientChronicle.create!(
        subject_id: client.id.to_s, subject_type: "Client", event_id: ClientChronicleEvent::LOGIN_SUCCESS,
        context: {
          provider: "google", auth_method: "social", oidc_client_id: "private-client-id",
          "sign-rp": "internal-rp", social_session_limitation: "private-policy",
          user_agent: "Mozilla/5.0 (X11; Linux x86_64) Gecko/20100101 Firefox/128.0",
        },
        ip_address: "10.2.3.4", occurred_at: 10.minutes.ago,
      )
      ClientChronicle.create!(
        subject_id: client.id.to_s, subject_type: "Client", event_id: ClientChronicleEvent::TOKEN_REFRESHED,
        context: { secret: "refresh-secret-sentinel" }, occurred_at: 1.minute.ago,
      )
    end
    BaseSelectorBootstrapAuthority.call(surface: :app, principal: client)
    BaseSelectorAuthority.prepare(surface: :app, principal: client, session: token)
    access_token = AuthenticationToken.encode(
      client, host: host, session_public_id: token.public_id,
      resource_type: "client", jwt_issuer_id: "surface:BASE_APP",
    )
    cookies[AuthenticationBase::ACCESS_COOKIE_KEY] = access_token

    get base_app_identity_activities_url(ri: "jp", host: host),
        headers: {
          "Authorization" => "Bearer #{access_token}",
          "Client-Agent" => "Mozilla/5.0",
          "Host" => host,
          "X-TEST-SESSION-PUBLIC-ID" => token.public_id,
        }

    assert_response :success
    assert_equal %w(occurred_at activity device source risk), inertia_props.fetch("columns").keys
    rows = inertia_props.fetch("activities")
    assert_equal 1, rows.length
    assert_equal "Googleでサインイン", rows.first.fetch("activity")
    assert_equal "低", rows.first.fetch("risk")
    %w(10.2.3.4 private-client-id internal-rp private-policy refresh-secret-sentinel).each do |value|
      assert_not_includes response.body, value
    end
  end

  test "com activity log lists the visitor's own recorded activity" do
    host = ENV.fetch("PUBLIC_BASE_CORPORATE_URL")
    host! host
    visitor = visitors(:reserved_visitor)
    token = VisitorToken.create!(
      visitor: visitor, visitor_token_kind_id: VisitorTokenKind::BROWSER_WEB,
      visitor_token_status_id: VisitorTokenStatus::ACTIVE, discarded_at: 1.day.from_now,
    )
    ChronicleRecord.connected_to(role: :writing) do
      ClientChronicle.create!(
        subject_id: visitor.id.to_s, subject_type: "Visitor", event_id: ClientChronicleEvent::LOGIN_SUCCESS,
        context: {
          provider: "google", auth_method: "social", oidc_client_id: "private-client-id",
          "sign-rp": "internal-rp", social_session_limitation: "private-policy",
          user_agent: "Mozilla/5.0 (X11; Linux x86_64) Gecko/20100101 Firefox/128.0",
        },
        ip_address: "10.2.3.4", occurred_at: 10.minutes.ago,
      )
      ClientChronicle.create!(
        subject_id: visitor.id.to_s, subject_type: "Visitor", event_id: ClientChronicleEvent::LOGIN_FAILED,
        context: { auth_method: "internal-auth-value" }, ip_address: "192.168.1.5", occurred_at: 5.minutes.ago,
      )
      ClientChronicle.create!(
        subject_id: visitor.id.to_s, subject_type: "Visitor", event_id: ClientChronicleEvent::TOKEN_REFRESHED,
        context: { secret: "refresh-secret-sentinel" }, occurred_at: 1.minute.ago,
      )
    end
    BaseSelectorBootstrapAuthority.call(surface: :com, principal: visitor)
    BaseSelectorAuthority.prepare(surface: :com, principal: visitor, session: token)
    access_token = AuthenticationToken.encode(
      visitor, host: host, session_public_id: token.public_id,
               resource_type: "visitor", jwt_issuer_id: "surface:BASE_COM",
    )
    cookies[AuthenticationBase::ACCESS_COOKIE_KEY] = access_token

    get base_com_identity_activities_url(ri: "jp", host: host),
        headers: {
          "Authorization" => "Bearer #{access_token}",
          "Client-Agent" => "Mozilla/5.0",
          "Host" => host,
          "X-TEST-SESSION-PUBLIC-ID" => token.public_id,
        }

    assert_response :success
    assert_equal I18n.t("base.shared.identity.activities.title"), inertia_props.fetch("title")
    assert_equal %w(occurred_at activity device source risk), inertia_props.fetch("columns").keys
    rows = inertia_props.fetch("activities")
    assert_equal ["サインインに失敗", "Googleでサインイン"], rows.map { |row| row.fetch("activity") }
    assert_equal ["中", "低"], rows.map { |row| row.fetch("risk") }
    assert_equal %w(occurred_at activity device source risk risk_rank), rows.last.keys
    %w(10.2.3.4 192.168.1.5 private-client-id internal-rp private-policy internal-auth-value refresh-secret-sentinel).each do |value|
      assert_not_includes response.body, value
    end
  end

  test "org activity log lists the operator's own recorded activity" do
    host = ENV.fetch("PUBLIC_BASE_STAFF_URL")
    host! host
    operator = operators(:one)
    token = OperatorToken.create!(
      staff: operator, staff_token_kind_id: OperatorTokenKind::BROWSER_WEB,
      staff_token_status_id: OperatorTokenStatus::ACTIVE, discarded_at: 1.day.from_now,
    )
    ChronicleRecord.connected_to(role: :writing) do
      OperatorChronicle.create!(
        subject_id: operator.id.to_s, subject_type: "Operator", event_id: OperatorChronicleEvent::LOGIN_SUCCESS,
        context: {
          provider: "google", auth_method: "social", oidc_client_id: "private-operator-client",
          "sign-rp": "internal-operator-rp", social_session_limitation: "private-policy",
          user_agent: "Mozilla/5.0 (X11; Linux x86_64) Gecko/20100101 Firefox/128.0",
        },
        ip_address: "172.16.0.2", occurred_at: 10.minutes.ago,
      )
      OperatorChronicle.create!(
        subject_id: operator.id.to_s, subject_type: "Operator", event_id: OperatorChronicleEvent::LOGIN_FAILED,
        context: { auth_method: "internal-auth-value" }, ip_address: "10.0.0.5", occurred_at: 5.minutes.ago,
      )
      OperatorChronicle.create!(
        subject_id: operator.id.to_s, subject_type: "Operator", event_id: OperatorChronicleEvent::TOKEN_REFRESHED,
        context: { secret: "refresh-secret-sentinel" }, occurred_at: 1.minute.ago,
      )
    end
    BaseSelectorBootstrapAuthority.call(surface: :org, principal: operator)
    BaseSelectorAuthority.prepare(surface: :org, principal: operator, session: token)
    access_token = AuthenticationToken.encode(
      operator, host: host, session_public_id: token.public_id,
                resource_type: "operator", jwt_issuer_id: "surface:BASE_ORG",
    )
    cookies[AuthenticationBase::ACCESS_COOKIE_KEY] = access_token

    get base_org_identity_activities_url(ri: "jp", host: host),
        headers: {
          "Authorization" => "Bearer #{access_token}",
          "Client-Agent" => "Mozilla/5.0",
          "Host" => host,
          "X-TEST-SESSION-PUBLIC-ID" => token.public_id,
        }

    assert_response :success
    assert_equal I18n.t("base.shared.identity.activities.title"), inertia_props.fetch("title")
    assert_equal %w(occurred_at activity device source risk), inertia_props.fetch("columns").keys
    rows = inertia_props.fetch("activities")
    assert_equal ["サインインに失敗", "Googleでサインイン"], rows.map { |row| row.fetch("activity") }
    assert_equal ["中", "低"], rows.map { |row| row.fetch("risk") }
    assert_equal %w(occurred_at activity device source risk risk_rank), rows.last.keys
    %w(172.16.0.2 10.0.0.5 private-operator-client internal-operator-rp private-policy internal-auth-value refresh-secret-sentinel).each do |value|
      assert_not_includes response.body, value
    end
  end

  test "app birthdate page sends a client without a step-up method to the auth setup host" do
    base_host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    auth_host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    host! base_host
    client = Client.create!
    token = ClientToken.create!(
      user: client, user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      user_token_status_id: ClientTokenStatus::ACTIVE, discarded_at: 1.day.from_now,
    )
    BaseSelectorBootstrapAuthority.call(surface: :app, principal: client)
    BaseSelectorAuthority.prepare(surface: :app, principal: client, session: token)
    access_token = AuthenticationToken.encode(
      client, host: base_host, session_public_id: token.public_id,
              resource_type: "client", jwt_issuer_id: "surface:BASE_APP",
    )
    cookies[AuthenticationBase::ACCESS_COOKIE_KEY] = access_token

    get base_app_identity_birthdate_url(ri: "jp", host: base_host),
        headers: {
          "Authorization" => "Bearer #{access_token}",
          "Client-Agent" => "Mozilla/5.0",
          "Host" => base_host,
          "X-TEST-SESSION-PUBLIC-ID" => token.public_id,
        }

    assert_response :redirect
    uri = URI.parse(response.location)

    assert_equal auth_host, uri.host
    assert_equal "/verification/setup/new", uri.path
  end

  test "com birthdate page sends a visitor without a fresh step-up through the verification setup" do
    host = ENV.fetch("PUBLIC_BASE_CORPORATE_URL")
    host! host
    visitor = visitors(:reserved_visitor)
    token = VisitorToken.create!(
      visitor: visitor, visitor_token_kind_id: VisitorTokenKind::BROWSER_WEB,
      visitor_token_status_id: VisitorTokenStatus::ACTIVE, discarded_at: 1.day.from_now,
    )
    BaseSelectorBootstrapAuthority.call(surface: :com, principal: visitor)
    BaseSelectorAuthority.prepare(surface: :com, principal: visitor, session: token)
    access_token = AuthenticationToken.encode(
      visitor, host: host, session_public_id: token.public_id,
               resource_type: "visitor", jwt_issuer_id: "surface:BASE_COM",
    )
    cookies[AuthenticationBase::ACCESS_COOKIE_KEY] = access_token

    get base_com_identity_birthdate_url(ri: "jp", host: host),
        headers: {
          "Authorization" => "Bearer #{access_token}",
          "Client-Agent" => "Mozilla/5.0",
          "Host" => host,
          "X-TEST-SESSION-PUBLIC-ID" => token.public_id,
        }

    assert_response :redirect
    uri = URI.parse(response.location)

    assert_equal ENV.fetch("PUBLIC_AUTH_CORPORATE_URL"), uri.host
    assert_equal "/verification/setup/new", uri.path
  end

  test "app standing page rejects an unauthenticated request" do
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    host! host

    get base_app_identity_standing_url(ri: "jp", host: host),
        headers: { "Client-Agent" => "Mozilla/5.0", "Host" => host }

    assert_not_equal 200, response.status
  end
  test "app standing page lists an in-force decision against the client" do
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    host! host
    client = clients(:one)
    enforcement_case = AppEnforcementCase.create!(
      kind: "cooldown", state: "draft", duration_mode: "timed", visibility: "visible",
      release_mode: "automatic", effective_at: Time.current, expires_at: 1.day.from_now,
      reason_code: "abuse", principal_public_id: client.public_id,
      applied_by_operator_public_id: "standing-test-operator",
    )
    EnforcementCaseApplyOperation.call(enforcement_case: enforcement_case)
    token = ClientToken.create!(
      user: client, user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      user_token_status_id: ClientTokenStatus::ACTIVE, discarded_at: 1.day.from_now,
    )
    BaseSelectorBootstrapAuthority.call(surface: :app, principal: client)
    BaseSelectorAuthority.prepare(surface: :app, principal: client, session: token)
    access_token = AuthenticationToken.encode(
      client, host: host, session_public_id: token.public_id,
              resource_type: "client", jwt_issuer_id: "surface:BASE_APP",
    )
    cookies[AuthenticationBase::ACCESS_COOKIE_KEY] = access_token

    get base_app_identity_standing_url(ri: "jp", host: host),
        headers: {
          "Authorization" => "Bearer #{access_token}",
          "Client-Agent" => "Mozilla/5.0",
          "Host" => host,
          "X-TEST-SESSION-PUBLIC-ID" => token.public_id,
        }

    assert_response :success
    decision = inertia_props.fetch("decisions").first

    assert_equal enforcement_case.public_id, decision.fetch("public_id")
    assert_equal "Cooldown", decision.fetch("kind")
    assert_equal "Abuse", decision.fetch("reason")
    assert_predicate decision.fetch("ends_at"), :present?
  end

  test "com standing page lists an in-force decision against the visitor" do
    host = ENV.fetch("PUBLIC_BASE_CORPORATE_URL")
    host! host
    visitor = visitors(:reserved_visitor)
    enforcement_case = ComEnforcementCase.create!(
      kind: "cooldown", state: "draft", duration_mode: "timed", visibility: "visible",
      release_mode: "automatic", effective_at: Time.current, expires_at: 1.day.from_now,
      reason_code: "abuse", principal_public_id: visitor.public_id,
      applied_by_operator_public_id: "standing-test-operator",
    )
    EnforcementCaseApplyOperation.call(enforcement_case: enforcement_case)
    token = VisitorToken.create!(
      visitor: visitor, visitor_token_kind_id: VisitorTokenKind::BROWSER_WEB,
      visitor_token_status_id: VisitorTokenStatus::ACTIVE, discarded_at: 1.day.from_now,
    )
    BaseSelectorBootstrapAuthority.call(surface: :com, principal: visitor)
    BaseSelectorAuthority.prepare(surface: :com, principal: visitor, session: token)
    access_token = AuthenticationToken.encode(
      visitor, host: host, session_public_id: token.public_id,
               resource_type: "visitor", jwt_issuer_id: "surface:BASE_COM",
    )
    cookies[AuthenticationBase::ACCESS_COOKIE_KEY] = access_token

    get base_com_identity_standing_url(ri: "jp", host: host),
        headers: {
          "Authorization" => "Bearer #{access_token}",
          "Client-Agent" => "Mozilla/5.0",
          "Host" => host,
          "X-TEST-SESSION-PUBLIC-ID" => token.public_id,
        }

    assert_response :success
    assert_equal enforcement_case.public_id, inertia_props.fetch("decisions").first.fetch("public_id")
  end

  test "org standing page lists an in-force decision against the operator" do
    host = ENV.fetch("PUBLIC_BASE_STAFF_URL")
    host! host
    operator = operators(:one)
    enforcement_case = OrgEnforcementCase.create!(
      kind: "cooldown", state: "draft", duration_mode: "timed", visibility: "visible",
      release_mode: "automatic", effective_at: Time.current, expires_at: 1.day.from_now,
      reason_code: "abuse", principal_public_id: operator.public_id,
      applied_by_operator_public_id: "standing-test-operator",
    )
    EnforcementCaseApplyOperation.call(enforcement_case: enforcement_case)
    token = OperatorToken.create!(
      staff: operator, staff_token_kind_id: OperatorTokenKind::BROWSER_WEB,
      staff_token_status_id: OperatorTokenStatus::ACTIVE, discarded_at: 1.day.from_now,
    )
    BaseSelectorBootstrapAuthority.call(surface: :org, principal: operator)
    BaseSelectorAuthority.prepare(surface: :org, principal: operator, session: token)
    access_token = AuthenticationToken.encode(
      operator, host: host, session_public_id: token.public_id,
                resource_type: "operator", jwt_issuer_id: "surface:BASE_ORG",
    )
    cookies[AuthenticationBase::ACCESS_COOKIE_KEY] = access_token

    get base_org_identity_standing_url(ri: "jp", host: host),
        headers: {
          "Authorization" => "Bearer #{access_token}",
          "Client-Agent" => "Mozilla/5.0",
          "Host" => host,
          "X-TEST-SESSION-PUBLIC-ID" => token.public_id,
        }

    assert_response :success
    assert_equal enforcement_case.public_id, inertia_props.fetch("decisions").first.fetch("public_id")
  end
end
