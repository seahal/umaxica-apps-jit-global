# typed: false
# frozen_string_literal: true

require "test_helper"

# Withdrawal scheduling and the pages the withdrawal ceremony unlocks on the app
# identity surface: the recovery page, the early personal-data erasure request,
# its status page, and ending the ceremony session.
class Base::App::Identity::WithdrawalsControllerTest < ActionDispatch::IntegrationTest
  fixtures :clients, :client_statuses, :client_email_statuses,
           :client_token_kinds, :client_token_statuses, :client_token_binding_methods,
           :client_token_dbsc_statuses

  setup do
    @host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    host! @host
    @client = clients(:one)
    @token = ClientToken.create!(
      user: @client, user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      user_token_status_id: ClientTokenStatus::ACTIVE, discard_at: 1.day.from_now,
    )
    BaseSelectorBootstrapAuthority.call(surface: :app, principal: @client)
    BaseSelectorAuthority.prepare(surface: :app, principal: @client, session: @token)
    _verification, raw_verification = ClientVerification.issue_for_token!(token: @token)
    cookies[ClientVerification.cookie_name] = raw_verification
    @token.update!(
      last_step_up_at: Time.current, last_step_up_scope: "withdrawal",
      last_step_up_aal: "aal2", last_step_up_method: "passkey",
      last_step_up_session_public_id: @token.public_id, last_step_up_purpose: "step_up",
      last_step_up_audience: "step_up:app",
    )
    access_token = AuthenticationToken.encode(
      @client, host: @host, session_public_id: @token.public_id,
               resource_type: "client", jwt_issuer_id: "surface:BASE_APP",
    )
    cookies[AuthenticationBase::ACCESS_COOKIE_KEY] = access_token
    @headers = {
      "Authorization" => "Bearer #{access_token}",
      "Client-Agent" => "Mozilla/5.0",
      "Host" => @host,
      "X-TEST-SESSION-PUBLIC-ID" => @token.public_id,
    }.freeze
  end

  test "new renders the withdrawal entry without the deactivation form before the schedule is acknowledged" do
    get new_base_app_identity_withdrawal_url(ri: "jp", host: @host), headers: @headers

    assert_response :success
    assert_nil inertia_props.fetch("deactivate")
  end

  test "new reveals the deactivation form once the purge schedule is acknowledged" do
    get new_base_app_identity_withdrawal_url(ri: "jp", host: @host, ack_schedule_purge: "1"), headers: @headers

    assert_response :success
    assert_equal base_app_identity_withdrawal_path(ri: "jp"), inertia_props.fetch("deactivate").fetch("action")
  end

  test "update without acknowledging the purge schedule leaves the client active" do
    patch base_app_identity_withdrawal_url(ri: "jp", host: @host),
          params: { ack_schedule_purge: "0" }, headers: @headers

    assert_response :unprocessable_content
    assert_not ClientWithdrawalFlow.exists?(client_id: @client.id)
  end

  test "update with the purge acknowledgement starts the withdrawal request" do
    patch base_app_identity_withdrawal_url(ri: "jp", host: @host),
          params: { ack_schedule_purge: "1" }, headers: @headers

    assert_response :see_other
    assert_predicate ClientWithdrawalFlow.where(client_id: @client.id), :exists?
  end

  test "recovery page and privacy erasure pages are reachable once the ceremony is issued" do
    patch base_app_identity_withdrawal_url(ri: "jp", host: @host),
          params: { ack_schedule_purge: "1" }, headers: @headers
    patch base_app_identity_withdrawal_url(ri: "jp", host: @host),
          params: { ack_deactivate_today: "1" }, headers: @headers

    assert_response :see_other

    get edit_base_app_identity_withdrawal_url(ri: "jp", host: @host), headers: { "Host" => @host }

    assert_response :success

    get new_base_app_identity_privacy_erasure_url(ri: "jp", host: @host), headers: { "Host" => @host }

    assert_response :success
    assert_equal "Early personal data erasure", inertia_props.fetch("title")

    assert_difference("ClientPrivacyRequest.count", 1) do
      post base_app_identity_privacy_erasure_url(ri: "jp", host: @host), headers: { "Host" => @host }
    end

    get base_app_identity_privacy_erasure_status_url(ri: "jp", host: @host), headers: { "Host" => @host }

    assert_response :success
    assert_predicate inertia_props.fetch("privacy_request"), :present?
  end

  test "the withdrawal ceremony session can be ended from the recovery page" do
    patch base_app_identity_withdrawal_url(ri: "jp", host: @host),
          params: { ack_schedule_purge: "1" }, headers: @headers
    patch base_app_identity_withdrawal_url(ri: "jp", host: @host),
          params: { ack_deactivate_today: "1" }, headers: @headers

    delete base_app_identity_withdrawal_session_url(ri: "jp", host: @host), headers: { "Host" => @host }

    assert_response :redirect

    get edit_base_app_identity_withdrawal_url(ri: "jp", host: @host), headers: { "Host" => @host }

    assert_response :redirect
  end
end
