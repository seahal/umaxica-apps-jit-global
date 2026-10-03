# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class SignInResultTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "maps successful session hash to common result" do
    result = SignInResult.from_session_result(
      {
        status: :success,
        access_token: "access",
        token_type: "Bearer",
        expires_in: 3600,
      },
      actor: "actor",
      sequence_id: "sequence",
    )

    assert_predicate result, :success?
    assert_equal "actor", result.actor
    assert_equal "sequence", result.sequence_id
    assert_equal "access", result.token.fetch(:access_token)
    assert_equal :found, result.response_status
  end

  test "maps mfa required to redirect result" do
    result = SignInResult.from_session_result(
      { status: :mfa_required, redirect_path: "/mfa" },
    )

    assert_predicate result, :mfa_required?
    assert_equal "/mfa", result.redirect_to
    assert_equal :found, result.response_status
  end

  test "a success carrying the retired restricted flag is still only a success, never pending" do
    result = SignInResult.from_session_result(
      { status: :success, restricted: true, session_management_required: true },
      session_management_path: "/in/session",
    )

    assert_predicate result, :success?
    assert_not_predicate result, :session_limit_pending?
  end

  test "maps session limit pending to the session management path with no token" do
    result = SignInResult.from_session_result(
      { status: :session_limit_pending, access_token: "never-exposed" },
      session_management_path: "/in/session",
    )

    assert_predicate result, :session_limit_pending?
    assert_not_predicate result, :success?
    assert_not_predicate result, :proceed?
    assert_nil result.token
    assert_equal "/in/session", result.redirect_to
    assert_equal :found, result.response_status
  end

  test "recorded OIDC evidence proceeds without being a committed session" do
    result = SignInResult.from_session_result({ status: :authentication_evidence_recorded, redirect_path: "/check" })

    assert_predicate result, :proceed?
    assert_not_predicate result, :success?
    assert_nil result.token
    assert_equal "/check", result.redirect_to
  end

  test "an unknown or missing status is an invalid request" do
    [{ status: :session_limit_exceeded }, { status: nil }, {}, { status: "" }].each do |data|
      result = SignInResult.from_session_result(data)

      assert_equal :invalid_request, result.status, data.inspect
      assert_not_predicate result, :proceed?
    end
  end

  test "maps hard reject to terminal forbidden result" do
    result = SignInResult.from_session_result(
      { status: :session_limit_hard_reject, message: "full" },
    )

    assert_predicate result, :terminal?
    assert_equal :session_limit_hard_reject, result.status
    assert_equal :forbidden, result.response_status
    assert_equal "full", result.message
  end

  test "passes through terminal sign-in failure statuses" do
    expectations = {
      credential_rejected: :unauthorized,
      identity_unavailable: :unauthorized,
      transaction_expired: :gone,
      failure: :bad_request,
    }

    expectations.each do |status, http_status|
      result = SignInResult.from_session_result({ status: status, message: "boom" })

      assert_predicate result, :terminal?, "expected #{status} to be terminal"
      assert_equal status, result.status
      assert_equal http_status, result.response_status
      assert_equal "boom", result.message
    end
  end

  test "maps unknown session hash to invalid request" do
    result = SignInResult.from_session_result({})

    assert_predicate result, :terminal?
    assert_equal :invalid_request, result.status
    assert_equal :bad_request, result.response_status
  end
end
