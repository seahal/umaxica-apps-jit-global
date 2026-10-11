# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class Auth::App::Sign::In::SessionsControllerExtraTest < ActionDispatch::IntegrationTest
  fixtures :clients

  setup do
    @host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL", "auth.app.localhost")
    @user = clients(:one)
    ClientToken.where(user: @user).delete_all

    # Ensure necessary records exist
    Prosopite.pause do
      ClientTokenKind.find_or_create_by!(id: ClientTokenKind::BROWSER_WEB)
      ClientTokenStatus::DEFAULTS.each do |id|
        ClientTokenStatus.find_or_create_by!(id: id)
      end
      ClientTokenBindingMethod.find_or_create_by!(id: 0) # NOTHING
      ClientTokenDbscStatus.find_or_create_by!(id: 0) # NOTHING
    end
  end

  test "update with single ref param revokes and stays on page if not promoted" do
    active1 = create_active_session(@user)
    create_active_session(@user)

    restricted = create_restricted_session(@user)
    headers = as_user_headers_with_token(@user, restricted, host: @host)

    # Bypass validation to create 3rd active
    active3 = ClientToken.new(
      user: @user,
      user_token_status_id: ClientTokenStatus::ACTIVE,
      user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      discarded_at: 1.month.from_now,
    )
    active3.save!(validate: false)
    active3.rotate_refresh_token!

    patch auth_app_sign_in_session_url(ri: "jp"),
          params: { ref: active1.signed_ref },
          headers: headers

    assert_response :success
    assert_includes response.body, I18n.t("sign.app.in.session.session_revoked")

    restricted.reload

    assert_equal ClientTokenStatus::RESTRICTED, restricted.user_token_status_id
  end

  test "destroy with ref param revokes and stays on page" do
    active = create_active_session(@user)
    restricted = create_restricted_session(@user)
    headers = as_user_headers_with_token(@user, restricted, host: @host)

    delete auth_app_sign_in_session_url(ri: "jp"),
           params: { ref: active.signed_ref },
           headers: headers

    assert_response :success
    assert_includes response.body, I18n.t("sign.app.in.session.session_revoked")
    active.reload

    assert_not_nil active.discarded_at
  end

  test "pending cycle promotion consumes legacy gate but preserves pending actor id" do
    controller = Auth::App::Sign::In::SessionsController.new
    session_hash = {
      :pending_login_user_id => @user.id,
      SessionLimitGate::GATE_SESSION_KEY => {
        "nonce" => "legacy",
        "issued_at" => Time.current.to_i,
        "pt" => "/dashboard",
        "flow" => "in.email.session",
      },
    }
    redirects = []

    controller.define_singleton_method(:session) { session_hash }
    controller.define_singleton_method(:params) do
      ActionController::Parameters.new(revoke_refs: ["selected"], ri: "jp")
    end
    controller.define_singleton_method(:resolve_current_client) { @resolved_client }
    controller.define_singleton_method(:revoke_sessions_by_refs) { |_client, _refs| true }
    controller.define_singleton_method(:pending_session_limit_cycle?) { true }
    controller.define_singleton_method(:current_session_restricted?) { false }
    controller.define_singleton_method(:can_promote_session?) { |_client| true }
    controller.define_singleton_method(:promote_current_session_limit_cycle!) { |_client| true }
    controller.define_singleton_method(:consume_session_limit_gate!) { session.delete(SessionLimitGate::GATE_SESSION_KEY) }
    controller.define_singleton_method(:retrieve_pt) { nil }
    controller.define_singleton_method(:session_limit_pt) { "/dashboard" }
    controller.define_singleton_method(:redirect_to_sign_in_sequence!) { |**kwargs| redirects << kwargs }
    controller.instance_variable_set(:@resolved_client, @user)

    controller.update

    assert_equal [{ pt: "/dashboard" }], redirects
    assert_nil session_hash[SessionLimitGate::GATE_SESSION_KEY]
    assert_equal @user.id, session_hash[:pending_login_user_id]
  end

  private

  def create_restricted_session(user)
    token = ClientToken.new(
      user: user,
      user_token_status_id: ClientTokenStatus::RESTRICTED,
      user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      discarded_at: 1.month.from_now,
    )
    token.save!(validate: false)
    token.rotate_refresh_token!
    token
  end

  def create_active_session(user)
    token = ClientToken.new(
      user: user,
      user_token_status_id: ClientTokenStatus::ACTIVE,
      user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      discarded_at: 1.month.from_now,
    )
    token.save!(validate: false)
    token.rotate_refresh_token!
    token
  end

  def as_user_headers_with_token(user, token, host:)
    access_token = AuthenticationToken.encode(
      user, host: host, session_public_id: token.public_id,
            jwt_issuer_id: jwt_issuer_id_for_test_host(host, "client"),
    )
    {
      "Host" => host,
      "Authorization" => "Bearer #{access_token}",
      "Cookie" => "#{AuthenticationBase::ACCESS_COOKIE_KEY}=#{access_token}",
    }
  end
  private

  def host_headers(host = nil)
    host_value = host || (respond_to?(:request, true) ? request&.host : nil) || ENV["DEFAULT_URL_HOST"]
    headers = {
      "Client-Agent" => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 " \
                        "(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
    }
    headers["Host"] = host_value if host_value.present?
    headers
  end

  def browser_headers
    csrf_token = "test_csrf_token"
    headers = {
      "Client-Agent" => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 " \
                        "(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
      "X-CSRF-Token" => csrf_token,
    }

    if respond_to?(:cookies, true)
      cookies["csrf_token"] = csrf_token
    else
      headers["Cookie"] = "csrf_token=#{csrf_token}"
    end

    headers
  end

  def as_user_headers(user, host: nil, headers: {}, session_public_id: nil)
    base = host_headers(host).merge(headers).merge("X-TEST-CURRENT-USER" => user.id.to_s)

    if user.respond_to?(:persisted?) && user.persisted? && user.class.name == "Client"
      token =
        if session_public_id.present?
          ClientToken.find_by(public_id: session_public_id)
        else
          ClientToken.where(user_id: user.id).where("discarded_at > ?", Time.current).order(created_at: :desc).first
        end
      token ||= ClientToken.create!(user_id: user.id, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
      base["X-TEST-SESSION-PUBLIC-ID"] = session_public_id.presence || token.public_id
    end

    if token
      base.merge(
        "Authorization" => "Bearer #{
        jwt_access_token_for(user, host: host, session_public_id: token.public_id, resource_type: "client")
      }",
      )
    else
      base
    end
  end

  def as_staff_headers(staff, host: nil, headers: {}, session_public_id: nil)
    base = host_headers(host).merge(headers).merge("X-TEST-CURRENT-STAFF" => staff.id.to_s)

    if staff.respond_to?(:persisted?) && staff.persisted? && staff.class.name == "Operator"
      token =
        if session_public_id.present?
          OperatorToken.find_by(public_id: session_public_id)
        else
          OperatorToken.where(staff_id: staff.id).where(
            "discarded_at > ?",
            Time.current,
          ).order(created_at: :desc).first
        end
      token ||= OperatorToken.create!(staff: staff, staff_token_kind_id: OperatorTokenKind::BROWSER_WEB)
      base["X-TEST-SESSION-PUBLIC-ID"] = session_public_id.presence || token.public_id
    end

    if token
      base.merge(
        "Authorization" => "Bearer #{
        jwt_access_token_for(staff, host: host, session_public_id: token.public_id, resource_type: "operator")
      }",
      )
    else
      base
    end
  end

  def as_visitor_headers(visitor, host: nil, headers: {}, session_public_id: nil)
    VisitorTokenBindingMethod.ensure_defaults! if defined?(VisitorTokenBindingMethod)
    VisitorTokenKind.find_or_create_by!(id: VisitorTokenKind::BROWSER_WEB) if defined?(VisitorTokenKind)
    base = host_headers(host).merge(headers).merge("X-TEST-CURRENT-RESOURCE" => visitor.id.to_s)

    if visitor.respond_to?(:persisted?) && visitor.persisted? && visitor.class.name == "Visitor"
      token =
        if session_public_id.present?
          VisitorToken.find_by(public_id: session_public_id)
        else
          VisitorToken.where(visitor_id: visitor.id).where(
            "discarded_at > ?",
            Time.current,
          ).order(created_at: :desc).first
        end
      token ||= VisitorToken.create!(visitor_id: visitor.id, visitor_token_kind_id: VisitorTokenKind::BROWSER_WEB)
      base["X-TEST-SESSION-PUBLIC-ID"] = session_public_id.presence || token.public_id
    end

    if token
      base.merge(
        "Authorization" => "Bearer #{
        jwt_access_token_for(visitor, host: host, session_public_id: token.public_id, resource_type: "visitor")
      }",
      )
    else
      base
    end
  end

  def bearer_headers(token, host: nil, headers: {})
    host_headers(host).merge(headers).merge("Authorization" => "Bearer #{token}")
  end
end

# DAMP auth header helpers for this test class.
class Auth::App::Sign::In::SessionsControllerExtraTest
  private

  def jwt_access_token_for(resource, host: nil, session_id: nil, session_public_id: nil, resource_type: nil,
                           dpop_jkt: nil)
    host_value = host || (respond_to?(:request, true) ? request&.host : nil) || "unknown"
    resource_type ||=
      case resource
      when Client then "client"
      when Operator then "operator"
      when Visitor then "visitor"
      end
    AuthenticationToken.encode(
      resource,
      host: host_value,
      session_id: session_id,
      session_public_id: session_public_id,
      resource_type: resource_type,
      dpop_jkt: dpop_jkt,
      jwt_issuer_id: jwt_issuer_id_for_test_host(host_value, resource_type),
    )
  end

  def jwt_issuer_id_for_test_host(host, resource_type)
    normalized = host.to_s
    service = normalized.include?("acme") ? "ACME" : (normalized.include?("core") ? "CORE" : "SIGN")
    surface =
      if service == "SIGN"
        case resource_type
        when "operator" then "ORG"
        when "visitor" then "COM"
        else "APP"
        end
      elsif normalized.include?(".org") || normalized.include?("org.")
        "ORG"
      elsif normalized.include?(".com") || normalized.include?("com.")
        "COM"
      else
        "APP"
      end
    "surface:#{service}_#{surface}"
  end
end
