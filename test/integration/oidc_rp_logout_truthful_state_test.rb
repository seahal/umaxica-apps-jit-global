# frozen_string_literal: true

require "test_helper"
require_relative "../support/browser_rp_logout_flow_helper"

# REQ-008 / REQ-009: every sign-out display is derived from the parent state. A failure after the
# parent COMMIT is never shown as a sign-out failure, an unknown COMMIT outcome is shown as
# indeterminate, and no output states an end time.
class OidcRpLogoutTruthfulStateTest < ActionDispatch::IntegrationTest
  include BrowserRpLogoutFlowHelper

  setup do
    @core_host = ENV.fetch("PUBLIC_CORE_SERVICE_URL")
    @base_host = visa_host_for_test_surface(:app)
    https!
    host! @core_host
    @user = clients(:one)
    @root_token = ClientToken.create!(
      authentication_epoch: 0,
      user: @user,
      user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      user_token_status_id: ClientTokenStatus::ACTIVE,
    )
    @core_session = create_rp_session("core-app-jp")
    @sibling_session = create_rp_session("warp-app-jp")
  end

  test "a failed progress write after the parent COMMIT shows the global result with cleanup incomplete" do
    challenge, origin_session_cookie = start_sign_out
    failed_advance = AcmeLogoutTransactionCoordinator::Result.new(
      transaction: nil, status: :rejected, error: "invalid_request", error_description: "progress write failed",
    )

    AcmeLogoutTransactionCoordinator.stub(:advance!, ->(**) { failed_advance }) do
      confirm_at_authority(challenge, origin_session_cookie)
    end

    assert_response :ok
    assert_nil response.location
    assert_includes response.headers.fetch("Cache-Control").downcase, "no-store"
    assert_includes response.body, I18n.t("sign.shared.sign_out.completed_title")
    assert_includes response.body, I18n.t("sign.shared.sign_out.cleanup_incomplete_description")
    assert_not_includes response.body, I18n.t("sign.shared.sign_out.unavailable_title")
    assert_not_predicate @root_token.reload, :currently_usable?
    assert_predicate @core_session.reload, :revoked?
    assert_predicate @sibling_session.reload, :revoked?
  end

  test "a database error on the progress write after the parent COMMIT still shows the global result" do
    challenge, origin_session_cookie = start_sign_out
    unreadable = ->(**) { raise ActiveRecord::ConnectionNotEstablished, "app ticket writer unavailable" }

    AcmeLogoutTransactionCoordinator.stub(:advance!, unreadable) do
      confirm_at_authority(challenge, origin_session_cookie)
    end

    assert_response :ok
    assert_includes response.body, I18n.t("sign.shared.sign_out.cleanup_incomplete_description")
    assert_not_predicate @root_token.reload, :currently_usable?
  end

  test "an authority that no longer holds under the parent lock stops with the IdP session error" do
    challenge, origin_session_cookie = start_sign_out
    changed = ->(**) { raise AuthenticationLogoutCurrentSession::PreconditionFailed }

    AuthenticationLogoutCurrentSession.stub(:call, changed) do
      confirm_at_authority(challenge, origin_session_cookie)
    end

    assert_response :bad_request
    assert_equal I18n.t("sign.shared.sign_out.idp_session_error"), response.body
    assert_nil response.location
    assert_predicate @root_token.reload, :currently_usable?
    assert_predicate @core_session.reload, :active?
    assert_equal AcmeLogoutTransaction::STEP_AUTHORITY_REVOKED,
                 AcmeLogoutTransactionCoordinator.find_by!(logout_challenge: challenge).expected_step
  end

  test "the authority confirmation re-checks the binding inside the revoking transaction" do
    challenge, origin_session_cookie = start_sign_out
    received = nil
    original_call = AuthenticationLogoutCurrentSession.method(:call)
    spy =
      lambda do |**options|
        received = options[:precondition]
        original_call.call(**options)
      end

    AuthenticationLogoutCurrentSession.stub(:call, spy) do
      confirm_at_authority(challenge, origin_session_cookie)
    end

    assert_response :see_other
    assert_respond_to received, :call
    assert_not_predicate @root_token.reload, :currently_usable?
  end

  test "an unknown COMMIT outcome is shown as indeterminate, never as success or failure" do
    challenge, origin_session_cookie = start_sign_out
    raise_unknown = ->(**) { raise AuthenticationLogoutCurrentSession::CommitOutcomeUnknown }

    AuthenticationLogoutCurrentSession.stub(:call, raise_unknown) do
      confirm_at_authority(challenge, origin_session_cookie)
    end

    assert_response :service_unavailable
    assert_includes response.headers.fetch("Cache-Control").downcase, "no-store"
    assert_includes response.body, I18n.t("sign.shared.sign_out.indeterminate_title")
    assert_not_includes response.body, I18n.t("sign.shared.sign_out.unavailable_title")
    assert_not_includes response.body, I18n.t("sign.shared.sign_out.completed_title")
  end

  test "a failed origin cleanup after the parent COMMIT shows the global result with cleanup incomplete" do
    challenge, origin_session_cookie = start_sign_out
    confirm_at_authority(challenge, origin_session_cookie)

    assert_response :see_other
    host! @core_host
    get core_app_sign_out_completion_path(logout_challenge: challenge, ri: "jp")
    form_params = response_form_params
    failed_revoke = RpSessionRevoker::Result.new(success: false, revoked_count: 0)

    RpSessionRevoker.stub(:call, ->(**) { failed_revoke }) do
      post core_app_sign_out_completion_path(logout_challenge: challenge, ri: "jp"),
           params: form_params,
           headers: with_session_cookie(origin_headers("same-origin"), session_cookie: origin_session_cookie)
    end

    assert_response :ok
    assert_includes response.body, I18n.t("sign.shared.sign_out.completed_title")
    assert_includes response.body, I18n.t("sign.shared.sign_out.cleanup_incomplete_description")
    assert_not_includes response.body, I18n.t("sign.shared.sign_out.unavailable_title")
    assert_not_predicate @root_token.reload, :currently_usable?
  end

  test "the completed origin page states the global result and no end time" do
    challenge, origin_session_cookie = start_sign_out
    confirm_at_authority(challenge, origin_session_cookie)
    host! @core_host
    get core_app_sign_out_completion_path(logout_challenge: challenge, ri: "jp")
    post core_app_sign_out_completion_path(logout_challenge: challenge, ri: "jp"),
         params: response_form_params,
         headers: with_session_cookie(origin_headers("same-origin"), session_cookie: origin_session_cookie)

    assert_response :see_other
    get URI.parse(response.location).request_uri

    assert_response :ok
    assert_includes response.body, I18n.t("sign.shared.sign_out.completed_title")
    assert_includes response.body, I18n.t("sign.shared.sign_out.completed_description")
    assert_not_includes response.body, I18n.t("sign.shared.sign_out.cleanup_incomplete_description")
    assert_no_match(/\d{1,2}:\d{2}/, response.parsed_body.at_css("main, body").text)
  end
end
