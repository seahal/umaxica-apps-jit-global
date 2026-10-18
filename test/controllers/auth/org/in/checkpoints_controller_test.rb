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
  end

  test "show without admission refuses to establish an Auth ceremony" do
    get auth_org_sign_in_check_url(ri: "jp"), headers: host_headers(@host)

    assert_response :bad_request
    assert_nil response.headers["Location"]
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
      state_id: OperatorSignInFlow.state_id_for("CHECKPOINT_PENDING"),
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

  def bearer_headers(token, host: nil, headers: {})
    host_headers(host).merge(headers).merge("Authorization" => "Bearer #{token}")
  end

  def jwt_issuer_id_for_test_host(host, resource_type)
    normalized = host.to_s
    service = normalized.include?("acme") ? "ACME" : (normalized.include?("core") ? "CORE" : "AUTH")
    surface =
      if service == "AUTH"
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
