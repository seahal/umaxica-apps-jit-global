# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"
require "base64"

class Auth::Org::Sign::In::CheckpointsControllerTest < ActionDispatch::IntegrationTest
  fixtures :operators

  setup do
    @host = ENV.fetch("PUBLIC_AUTH_STAFF_URL", "auth.org.localhost")
    @staff = operators(:one)
    OperatorSignInFlowStatus.ensure_defaults!
  end

  test "show without login starts OIDC handoff" do
    get auth_org_sign_in_check_url(ri: "jp"), headers: host_headers(@host)

    assert_response :redirect
    # Auth and Base are same-site, so the authorize hop goes straight to Base. The jump
    # gateway (an `rt=` token) is for cross-site hops and is not used here.
    assert_equal Rails.configuration.x.boot_config.fetch(:hosts).base_staff.host,
                 URI.parse(response.location).host
    assert_equal "/oauth/authorize", URI.parse(response.location).path
    assert_not_includes response.location, "rt="
  end

  test "show without sign in sequence is rejected" do
    get auth_org_sign_in_check_url(ri: "jp"),
        headers: as_staff_headers(@staff, host: @host)

    assert_response :bad_request
  end

  test "legacy bulletin state does not bypass checkpoint authorization" do
    start_checkpoint_sequence

    get auth_org_sign_in_check_url(ri: "jp"),
        headers: checkpoint_headers.merge(
          "X-TEST-BULLETIN" => bulletin_json(issued_at: Time.current.to_i, state: "new"),
        )

    assert_response :bad_request
  end

  test "update is not routed" do
    start_checkpoint_sequence
    previous_issued_at = 10.minutes.ago.to_i

    patch auth_org_sign_in_check_url(ri: "jp"),
          headers: checkpoint_headers.merge(
            "X-TEST-BULLETIN" => bulletin_json(issued_at: previous_issued_at, state: "new"),
          )

    assert_response :not_found
  end

  test "destroy is not routed" do
    start_checkpoint_sequence
    pt = Base64.urlsafe_encode64("/settings")

    delete auth_org_sign_in_check_url(ri: "jp", pt: pt),
           headers: checkpoint_headers.merge(
             "X-TEST-BULLETIN" => bulletin_json(issued_at: Time.current.to_i, state: "updated"),
           )

    assert_response :not_found
  end

  test "destroy without return target is not routed" do
    start_checkpoint_sequence

    delete auth_org_sign_in_check_url(ri: "jp"),
           headers: checkpoint_headers.merge(
             "X-TEST-BULLETIN" => bulletin_json(issued_at: Time.current.to_i, state: "updated"),
           )

    assert_response :not_found
  end

  test "legacy expired bulletin state does not bypass checkpoint authorization" do
    start_checkpoint_sequence
    expired_at = 2.hours.ago.to_i - 1

    get auth_org_sign_in_check_url(ri: "jp"),
        headers: checkpoint_headers.merge(
          "X-TEST-BULLETIN" => bulletin_json(issued_at: expired_at, state: "new"),
        )

    assert_response :bad_request
  end

  test "destroy is not routed when legacy bulletin state is expired" do
    start_checkpoint_sequence
    pt = Base64.urlsafe_encode64("/settings")

    delete auth_org_sign_in_check_url(ri: "jp", pt: pt),
           headers: checkpoint_headers.merge(
             "X-TEST-BULLETIN" => bulletin_json(issued_at: 2.hours.ago.to_i - 1, state: "updated"),
           )

    assert_response :not_found
  end

  private

  def start_checkpoint_sequence
    @checkpoint_headers = as_staff_headers(@staff, host: @host)
    get(auth_org_root_url(ri: "jp"), headers: checkpoint_headers)

    SignInSequenceCarrier.new(session, surface: :org).start!(
      surface: :org,
      actor: @staff,
      method: :passkey,
      state: "CHECKPOINT_PENDING",
      participant: :checkpoint,
      pt: nil,
    )
    cycle = OperatorSignInFlow.new(
      principal_id: @staff.id,
      status_id: OperatorSignInFlow.status_id_for("CHECKPOINT_PENDING"),
      state: "CHECKPOINT_PENDING",
      step: "checkpoint",
      nonce_digest: OperatorSignInFlow.digest_nonce("pending-test-nonce"),
      issued_at: Time.current,
      expires_at: 15.minutes.from_now,
    )
    cycle.save!(validate: false)
    SignInCycleLocator.new(session, surface: :org, actor: @staff).issue!(cycle)
  end

  def checkpoint_headers
    @checkpoint_headers ||= as_staff_headers(@staff, host: @host)
  end

  def bulletin_json(issued_at:, state:)
    { "issued_at" => issued_at, "kind" => "mock", "state" => state }.to_json
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

    base.merge(
      "Authorization" => "Bearer #{
        jwt_access_token_for(user, host: host, session_public_id: token.public_id, resource_type: "client")
      }",
    )
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

    base.merge(
      "Authorization" => "Bearer #{
        jwt_access_token_for(staff, host: host, session_public_id: token.public_id, resource_type: "operator")
      }",
    )
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

    base.merge(
      "Authorization" => "Bearer #{
        jwt_access_token_for(visitor, host: host, session_public_id: token.public_id, resource_type: "visitor")
      }",
    )
  end

  def bearer_headers(token, host: nil, headers: {})
    host_headers(host).merge(headers).merge("Authorization" => "Bearer #{token}")
  end

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

# DAMP auth header helpers for this test class.
class Auth::Org::Sign::In::CheckpointsControllerTest
  private
end
