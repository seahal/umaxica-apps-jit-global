# typed: false
# frozen_string_literal: true

require "test_helper"

# Withdrawal entry and scheduling pages for a visitor on the corporate surface:
# the acknowledgement gate that reveals the deactivation form, the validation
# failure that keeps the visitor active, and the deactivation that starts the
# withdrawal and moves the visitor to the recovery page.
class Base::Com::Identity::WithdrawalsControllerTest < ActionDispatch::IntegrationTest
  fixtures :visitors, :visitor_statuses, :visitor_email_statuses,
           :visitor_token_kinds, :visitor_token_statuses, :visitor_token_binding_methods,
           :visitor_token_dbsc_statuses

  setup do
    @host = ENV.fetch("PUBLIC_BASE_CORPORATE_URL")
    host! @host
    @visitor = visitors(:reserved_visitor)
    @token = VisitorToken.create!(
      visitor: @visitor,
      visitor_token_kind_id: VisitorTokenKind::BROWSER_WEB,
      visitor_token_status_id: VisitorTokenStatus::ACTIVE,
      discard_at: 1.day.from_now,
    )
    BaseSelectorBootstrapAuthority.call(surface: :com, principal: @visitor)
    BaseSelectorAuthority.prepare(surface: :com, principal: @visitor, session: @token)
    _verification, raw_verification = VisitorVerification.issue_for_token!(token: @token)
    cookies[VisitorVerification.cookie_name] = raw_verification
    @token.update!(
      last_step_up_at: Time.current,
      last_step_up_scope: "withdrawal",
      last_step_up_aal: "aal2",
      last_step_up_method: "passkey",
      last_step_up_session_public_id: @token.public_id,
      last_step_up_purpose: "step_up",
      last_step_up_audience: "step_up:com",
    )
    access_token = AuthenticationToken.encode(
      @visitor, host: @host, session_public_id: @token.public_id,
                resource_type: "visitor", jwt_issuer_id: "surface:BASE_COM",
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
    get new_base_com_identity_withdrawal_url(ri: "jp", host: @host), headers: @headers

    assert_response :success
    props = inertia_props

    assert_equal I18n.t("sign.app.settings.withdrawal.new.page_title"), props.fetch("title")
    assert_not props.fetch("already_deactivated")
    assert_nil props.fetch("deactivate")
  end

  test "new reveals the deactivation form once the purge schedule is acknowledged" do
    get new_base_com_identity_withdrawal_url(ri: "jp", host: @host, ack_schedule_purge: "1"), headers: @headers

    assert_response :success
    assert_equal base_com_identity_withdrawal_path(ri: "jp"), inertia_props.fetch("deactivate").fetch("url")
  end

  test "new re-renders the entry when the purge acknowledgement is rejected" do
    get new_base_com_identity_withdrawal_url(ri: "jp", host: @host, ack_schedule_purge: "0"), headers: @headers

    assert_response :unprocessable_content
    assert_predicate inertia_props.fetch("schedule").fetch("errors"), :present?
  end

  test "update without acknowledging the purge schedule leaves the visitor active" do
    patch base_com_identity_withdrawal_url(ri: "jp", host: @host),
          params: { ack_schedule_purge: "0" }, headers: @headers

    assert_response :unprocessable_content
    assert_not VisitorWithdrawalFlow.exists?(visitor_id: @visitor.id)
  end

  test "update with the purge acknowledgement starts the withdrawal request" do
    patch base_com_identity_withdrawal_url(ri: "jp", host: @host),
          params: { ack_schedule_purge: "1" }, headers: @headers

    assert_response :see_other
    assert_predicate VisitorWithdrawalFlow.where(visitor_id: @visitor.id), :exists?
  end

  test "update rejects deactivation when today's acknowledgement is missing" do
    patch base_com_identity_withdrawal_url(ri: "jp", host: @host),
          params: { ack_schedule_purge: "1" }, headers: @headers

    patch base_com_identity_withdrawal_url(ri: "jp", host: @host),
          params: { ack_deactivate_today: "0" }, headers: @headers

    assert_response :unprocessable_content
    assert_nil @visitor.reload.deactivated_at
  end

  test "update deactivates the visitor once both acknowledgements are given" do
    patch base_com_identity_withdrawal_url(ri: "jp", host: @host),
          params: { ack_schedule_purge: "1" }, headers: @headers

    patch base_com_identity_withdrawal_url(ri: "jp", host: @host),
          params: { ack_deactivate_today: "1" }, headers: @headers

    assert_response :see_other
    assert_redirected_to edit_base_com_identity_withdrawal_path(ri: "jp")
    assert_not_nil @visitor.reload.deactivated_at
    assert_nil cookies[AuthenticationBase::ACCESS_COOKIE_KEY].presence
  end
  test "recovery page and privacy erasure pages are reachable once the ceremony is issued" do
    patch base_com_identity_withdrawal_url(ri: "jp", host: @host),
          params: { ack_schedule_purge: "1" }, headers: @headers
    patch base_com_identity_withdrawal_url(ri: "jp", host: @host),
          params: { ack_deactivate_today: "1" }, headers: @headers

    assert_response :see_other

    get edit_base_com_identity_withdrawal_url(ri: "jp", host: @host), headers: { "Host" => @host }

    assert_response :success
    assert_equal I18n.t("sign.app.settings.withdrawal.recovery.page_title"), inertia_props.fetch("title")

    get new_base_com_identity_privacy_erasure_url(ri: "jp", host: @host), headers: { "Host" => @host }

    assert_response :success
    assert_equal "Early personal data erasure", inertia_props.fetch("title")

    assert_difference("VisitorPrivacyRequest.count", 1) do
      post base_com_identity_privacy_erasure_url(ri: "jp", host: @host), headers: { "Host" => @host }
    end

    get base_com_identity_privacy_erasure_status_url(ri: "jp", host: @host), headers: { "Host" => @host }

    assert_response :success
    assert_predicate inertia_props.fetch("privacy_request"), :present?
  end

  test "the withdrawal ceremony session can be ended from the recovery page" do
    patch base_com_identity_withdrawal_url(ri: "jp", host: @host),
          params: { ack_schedule_purge: "1" }, headers: @headers
    patch base_com_identity_withdrawal_url(ri: "jp", host: @host),
          params: { ack_deactivate_today: "1" }, headers: @headers

    delete base_com_identity_withdrawal_session_url(ri: "jp", host: @host), headers: { "Host" => @host }

    assert_response :redirect

    get edit_base_com_identity_withdrawal_url(ri: "jp", host: @host), headers: { "Host" => @host }

    assert_response :redirect
  end
end
