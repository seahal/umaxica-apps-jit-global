# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class SessionLimitGateTest < ActionDispatch::IntegrationTest
  # Test class that includes the concern for testing
  class TestController < ApplicationController
    include SessionLimitGate

    def issue_gate
      issue_session_limit_gate!(
        pt: params[:pt] || "/test/return",
        flow: params[:flow] || "test.flow",
      )
      head :ok
    end

    def check_gate
      return unless require_session_limit_gate!(login_path: "/test/login")

      head :ok

    end

    def consume_gate
      consume_session_limit_gate!
      head :ok
    end

    def gate_info
      render json: {
        valid: session_limit_gate_valid?,
        pt: session_limit_pt,
        flow: session_limit_flow,
      }
    end
  end

  setup do
    Rails.application.routes.draw do
      get "/test/issue_gate" => "session_limit_gate_test/test#issue_gate"
      get "/test/check_gate" => "session_limit_gate_test/test#check_gate"
      get "/test/consume_gate" => "session_limit_gate_test/test#consume_gate"
      get "/test/gate_info" => "session_limit_gate_test/test#gate_info"
      get "/test/login" => "session_limit_gate_test/test#issue_gate"
    end
  end

  teardown do
    Rails.application.reload_routes!
  end

  test "issue_session_limit_gate! creates a valid gate in session" do
    get "/test/issue_gate", params: { pt: "/my/return/path", flow: "in.email.session" }

    assert_response :ok

    get "/test/gate_info"
    json = response.parsed_body

    assert json["valid"]
    assert_equal "/my/return/path", json["pt"]
    assert_equal "in.email.session", json["flow"]
  end

  test "issue_session_limit_gate! rejects external URLs in pt" do
    get "/test/issue_gate", params: { pt: "https://evil.com/attack", flow: "test" }

    assert_response :ok

    get "/test/gate_info"
    json = response.parsed_body

    assert json["valid"]
    assert_nil json["pt"]
  end

  test "require_session_limit_gate! redirects to login when no gate exists" do
    get "/test/check_gate"

    assert_redirected_to "/test/login"
    assert_nil flash[:alert]
  end

  test "require_session_limit_gate! allows access with valid gate" do
    # First issue a gate
    get "/test/issue_gate"

    assert_response :ok

    # Then check it
    get "/test/check_gate"

    assert_response :ok
  end

  test "require_session_limit_gate! redirects when gate is expired" do
    # Issue a gate
    get "/test/issue_gate"

    assert_response :ok

    # Simulate time passing beyond TTL (15 minutes = 900 seconds)
    travel 16.minutes do
      get "/test/check_gate"

      assert_redirected_to "/test/login"
      assert_nil flash[:alert]
    end
  end

  test "consume_session_limit_gate! removes the gate from session" do
    # Issue a gate
    get "/test/issue_gate"

    assert_response :ok

    # Verify it exists
    get "/test/gate_info"
    json = response.parsed_body

    assert json["valid"]

    # Consume it
    get "/test/consume_gate"

    assert_response :ok

    # Verify it's gone
    get "/test/gate_info"
    json = response.parsed_body

    assert_not json["valid"]
  end

  test "gate is single-use after consumption" do
    # Issue and consume
    get "/test/issue_gate"
    get "/test/consume_gate"

    # Now check should redirect
    get "/test/check_gate"

    assert_redirected_to "/test/login"
  end
end
