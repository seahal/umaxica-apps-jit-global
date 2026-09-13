# typed: false
# frozen_string_literal: true

require "test_helper"

class BaseIdentitySessionsPresentationTest < ActionDispatch::IntegrationTest
  fixtures :clients, :client_statuses, :client_token_kinds, :client_token_statuses,
           :client_token_binding_methods, :client_token_dbsc_statuses,
           :visitors, :visitor_statuses, :visitor_token_kinds, :visitor_token_statuses,
           :visitor_token_binding_methods, :visitor_token_dbsc_statuses,
           :operators, :operator_statuses, :operator_token_kinds, :operator_token_statuses,
           :operator_token_binding_methods, :operator_token_dbsc_statuses

  setup do
    @original_preference = Actor.preferences
    Actor.preferences = Actor::Preference.from_jwt(
      { "lx" => "en", "tz" => "Etc/UTC", "df" => "iso", "tf" => "24" },
    )
  end

  teardown do
    Actor.preferences = @original_preference
  end

  test "app session inventory contains only user-facing fields and refuses self-revocation" do
    assert_session_contract(:app)
  end

  test "com session inventory contains only user-facing fields and refuses self-revocation" do
    assert_session_contract(:com)
  end

  test "org session inventory contains only user-facing fields and refuses self-revocation" do
    assert_session_contract(:org)
  end

  test "app rejects an otherwise valid Access Token after its session absolute expiry" do
    assert_expired_session_cannot_authenticate(:app)
  end

  test "com rejects an otherwise valid Access Token after its session absolute expiry" do
    assert_expired_session_cannot_authenticate(:com)
  end

  test "org rejects an otherwise valid Access Token after its session absolute expiry" do
    assert_expired_session_cannot_authenticate(:org)
  end

  def assert_session_contract(surface)
    principal, token, host, resource_type = create_actor_session_token(surface)
    create_other_com_session(principal) if surface == :com
    create_other_org_session(principal, except: token) if surface == :org
    access_token = authenticate_session(surface, principal, token, host, resource_type)
    open_session do |test_session|
      test_session.get sessions_path(surface, host), headers: request_headers(host, token, access_token)
      assert_equal 200, test_session.response.status
      props = inertia_props_from(test_session.response.body)
      rows = props.fetch("sessions")
      row = rows.find { |session| session.fetch("status") == "現在のセッション" }
      assert_predicate row, :present?
      expected_keys = %w(created device expires_at last_activity revoke status)
      expected_keys << "mode" if surface == :org
      assert_equal expected_keys.sort, row.keys.sort
      assert_equal "不明なデバイス", row.fetch("device")
      assert_match(/\A\d{4}-\d{2}-\d{2} \d{2}:\d{2}\z/, row.fetch("created"))
      assert_match(/\A\d{4}-\d{2}-\d{2} \d{2}:\d{2}\z/, row.fetch("expires_at"))
      assert_equal "現在のセッション", row.fetch("status")
      assert_nil row.fetch("revoke")
      assert_equal "緊急アクセス", row.fetch("mode") if surface == :org
      refute row.key?("public_id")
      refute row.key?("kind")
      refute row.key?("binding")
      refute row.key?("refresh_expires")
      refute row.key?("refresh_token_generation")
      assert_equal "このセッションはこの時刻に終了します。この期限は延長されません。",
                   props.fetch("expires_at_description")

      other_row = rows.find { |session| session.fetch("revoke").present? }
      assert_predicate other_row, :present?
      other_href = URI.join("https://#{host}", other_row.fetch("revoke").fetch("href")).to_s
      other_public_id = URI.parse(other_href).path.split("/").last
      other_token = token.class.find_by!(public_id: other_public_id)
      if surface == :org
        assert_equal "通常", other_row.fetch("mode")
        assert_predicate other_token, :dbsc_enabled?
        refute token.dbsc_enabled?
      end
      test_session.delete other_href, headers: request_headers(host, token, access_token)
      assert_equal 303, test_session.response.status
      assert_predicate other_token.reload, :revoked?

      test_session.delete session_path(surface, token.public_id, host), headers: request_headers(host, token, access_token)
      assert_equal 303, test_session.response.status
      refute token.reload.revoked?
    end
  end

  def assert_expired_session_cannot_authenticate(surface)
    travel_to Time.utc(2026, 9, 13, 9, 0)
    principal, token, host, resource_type = create_actor_session_token(surface)
    token.update!(discarded_at: 1.hour.from_now)
    absolute_expiry = token.discarded_at
    BaseSelectorBootstrapAuthority.call(surface: surface, principal: principal)
    BaseSelectorAuthority.prepare(surface: surface, principal: principal, session: token)
    access_token = AuthenticationToken.encode(
      principal, host: host, session_public_id: token.public_id, resource_type: resource_type,
      jwt_issuer_id: "surface:BASE_#{surface.to_s.upcase}", expires_at: 2.hours.from_now,
      authentication_context: surface == :org ? token.authentication_context : nil,
    )
    payload = JWT.decode(access_token, nil, false).first
    assert_operator Time.at(payload.fetch("exp")), :>, absolute_expiry

    travel_to absolute_expiry + 1.second
    open_session do |test_session|
      test_session.get sessions_path(surface, host), headers: request_headers(host, token, access_token)
      refute_equal 200, test_session.response.status
    end
  ensure
    travel_back
  end

  def inertia_props_from(body)
    script = Nokogiri::HTML(body).at_css("script[data-page='app']")
    assert_predicate script, :present?
    JSON.parse(script.text).fetch("props")
  end

  private

  def create_actor_session_token(surface)
    case surface
    when :app
      host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
      principal = clients(:one)
      principal.update!(status_id: ClientStatus::ACTIVE)
      token = ClientToken.create!(
        user: principal, user_token_kind_id: ClientTokenKind::BROWSER_WEB,
        user_token_status_id: ClientTokenStatus::ACTIVE, discarded_at: 30.days.from_now,
      )
      [principal, token, host, "client"]
    when :com
      host = ENV.fetch("PUBLIC_BASE_CORPORATE_URL")
      principal = visitors(:reserved_visitor)
      token = VisitorToken.create!(
        visitor: principal, visitor_token_kind_id: VisitorTokenKind::BROWSER_WEB,
        visitor_token_status_id: VisitorTokenStatus::ACTIVE, discarded_at: 30.days.from_now,
      )
      [principal, token, host, "visitor"]
    when :org
      host = ENV.fetch("PUBLIC_BASE_STAFF_URL")
      principal = operators(:one)
      token = OperatorToken.create!(
        staff: principal, staff_token_kind_id: OperatorTokenKind::BROWSER_WEB,
        staff_token_status_id: OperatorTokenStatus::ACTIVE, discarded_at: 30.days.from_now,
        staff_token_binding_method_id: OperatorTokenBindingMethod::LEGACY,
        authentication_context: AuthenticationContextValue::EMERGENCY_KEY,
      )
      [principal, token, host, "operator"]
    end
  end

  def create_other_com_session(visitor)
    VisitorToken.create!(visitor: visitor, visitor_token_kind_id: VisitorTokenKind::BROWSER_WEB,
                          visitor_token_status_id: VisitorTokenStatus::ACTIVE, discarded_at: 1.day.from_now)
  end

  def create_other_org_session(operator, except:)
    OperatorToken.where(staff_id: operator.id).where.not(id: except.id).update_all(discarded_at: Time.current)
    OperatorToken.create!(
      staff: operator, staff_token_kind_id: OperatorTokenKind::BROWSER_WEB,
      staff_token_status_id: OperatorTokenStatus::ACTIVE,
      staff_token_binding_method_id: OperatorTokenBindingMethod::DBSC,
      authentication_context: AuthenticationContextValue::NORMAL_KEY,
      discarded_at: 1.day.from_now,
    )
  end

  def authenticate_session(surface, principal, token, host, resource_type)
    BaseSelectorBootstrapAuthority.call(surface: surface, principal: principal)
    BaseSelectorAuthority.prepare(surface: surface, principal: principal, session: token)
    AuthenticationToken.encode(
      principal, host: host, session_public_id: token.public_id, resource_type: resource_type,
      jwt_issuer_id: "surface:BASE_#{surface.to_s.upcase}",
      authentication_context: surface == :org ? token.authentication_context : nil,
    )
  end

  def request_headers(host, token, access_token)
    {
      "Authorization" => "Bearer #{access_token}",
      "Client-Agent" => "Mozilla/5.0",
      "Host" => host,
      "X-TEST-SESSION-PUBLIC-ID" => token.public_id,
    }
  end

  def sessions_path(_surface, host)
    "https://#{host}/identity/sessions?ri=jp"
  end

  def session_path(_surface, public_id, host)
    "https://#{host}/identity/sessions/#{public_id}?ri=jp"
  end
end
