# frozen_string_literal: true

require "test_helper"

class PrivacyErasureRequestTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  test "deactivated client creates erasure request through withdrawal ceremony" do
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL", "base.app.localhost")
    host! host
    client = create_client
    client.update!(
      withdrawal_started_at: 2.hours.ago,
      deactivated_at: 90.minutes.ago,
      discard_at: 31.days.from_now,
      purge_eligible_at: 31.days.from_now,
    )
    ceremony = ClientWithdrawalCeremony.issue!(subject: client, request: ActionDispatch::TestRequest.create)
    cookies[withdrawal_ceremony_cookie_name] = "#{ceremony.public_id}:#{ceremony.plaintext_token}"

    assert_difference -> { ClientPrivacyRequest.count }, 1 do
      post base_app_identity_privacy_erasure_url(ri: "jp", host: host), headers: browser_headers
    end

    assert_response :see_other
    request_record = ClientPrivacyRequest.order(:created_at).last

    assert_equal "erasure", request_record.request_kind
    assert_equal "self_service", request_record.request_source
    assert_equal "unknown", request_record.jurisdiction
    assert_predicate request_record.response_due_at, :present?
    assert_equal client.id, request_record.client_id
    assert_predicate ClientOccurrence.where(event_type: "privacy_erasure.requested"), :exists?
  end

  test "deactivated visitor creates erasure request through withdrawal ceremony" do
    host = ENV.fetch("PUBLIC_BASE_CORPORATE_URL", "base.com.localhost")
    host! host
    visitor = create_visitor
    visitor.update!(
      withdrawal_started_at: 2.hours.ago,
      deactivated_at: 90.minutes.ago,
      discard_at: 31.days.from_now,
      purge_eligible_at: 31.days.from_now,
    )
    ceremony = VisitorWithdrawalCeremony.issue!(subject: visitor, request: ActionDispatch::TestRequest.create)
    cookies[withdrawal_ceremony_cookie_name] = "#{ceremony.public_id}:#{ceremony.plaintext_token}"

    assert_difference -> { VisitorPrivacyRequest.count }, 1 do
      post base_com_identity_privacy_erasure_url(ri: "jp", host: host), headers: browser_headers
    end

    assert_response :see_other
    request_record = VisitorPrivacyRequest.order(:created_at).last

    assert_equal "erasure", request_record.request_kind
    assert_equal "self_service", request_record.request_source
    assert_equal visitor.id, request_record.visitor_id
    assert_predicate VisitorOccurrence.where(event_type: "privacy_erasure.requested"), :exists?
  end

  test "received client erasure request is cancelled on recovery" do
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL", "base.app.localhost")
    host! host
    client = create_client
    client.update!(
      withdrawal_started_at: 2.hours.ago,
      deactivated_at: 90.minutes.ago,
      discard_at: 31.days.from_now,
      purge_eligible_at: 31.days.from_now,
    )
    privacy_request = ClientPrivacyRequest.create!(client: client)
    ceremony = ClientWithdrawalCeremony.issue!(subject: client, request: ActionDispatch::TestRequest.create)
    cookies[withdrawal_ceremony_cookie_name] = "#{ceremony.public_id}:#{ceremony.plaintext_token}"

    post base_app_identity_withdrawal_url(ri: "jp", host: host), headers: browser_headers

    assert_response :see_other
    assert_equal ClientPrivacyRequest.status_id_for("CANCELLED"), privacy_request.reload.status_id
    assert_nil client.reload.deactivated_at
  end

  test "processing client erasure request blocks recovery" do
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL", "base.app.localhost")
    host! host
    client = create_client
    client.update!(
      withdrawal_started_at: 2.hours.ago,
      deactivated_at: 90.minutes.ago,
      discard_at: 31.days.from_now,
      purge_eligible_at: 31.days.from_now,
    )
    ClientPrivacyRequest.create!(client: client, status_id: ClientPrivacyRequest.status_id_for("PROCESSING"))
    ceremony = ClientWithdrawalCeremony.issue!(subject: client, request: ActionDispatch::TestRequest.create)
    cookies[withdrawal_ceremony_cookie_name] = "#{ceremony.public_id}:#{ceremony.plaintext_token}"

    post base_app_identity_withdrawal_url(ri: "jp", host: host), headers: browser_headers

    assert_response :see_other
    assert_predicate client.reload, :deactivated?
  end

  private

  def withdrawal_ceremony_cookie_name
    AuthenticationCookieName.with_host_prefix("withdrawal_ceremony", production: JitSessionCookieConfig.force_secure?)
  end

  def browser_headers
    csrf_token = "test_csrf_token"
    cookies["csrf_token"] = csrf_token
    {
      "Client-Agent" => "Mozilla/5.0",
      "X-CSRF-Token" => csrf_token,
    }
  end

  def create_client
    ClientStatus.find_or_create_by!(id: ClientStatus::NOTHING)
    ClientVisibility.find_or_create_by!(id: ClientVisibility::USER)
    ClientMfaLevel.find_or_create_by!(id: ClientMfaLevel::NOTHING)
    ClientMfaStatus.find_or_create_by!(id: ClientMfaStatus::UNCONFIGURED)
    Client.create!(
      status_id: ClientStatus::NOTHING,
      visibility_id: ClientVisibility::USER,
      mfa_level_id: ClientMfaLevel::NOTHING,
      mfa_status_id: ClientMfaStatus::UNCONFIGURED,
    )
  end

  def create_visitor
    VisitorStatus.find_or_create_by!(id: VisitorStatus::NOTHING)
    VisitorVisibility.find_or_create_by!(id: VisitorVisibility::VISITOR)
    VisitorMfaLevel.find_or_create_by!(id: VisitorMfaLevel::NOTHING)
    VisitorMfaStatus.find_or_create_by!(id: VisitorMfaStatus::UNCONFIGURED)
    Visitor.create!(
      status_id: VisitorStatus::NOTHING,
      visibility_id: VisitorVisibility::VISITOR,
      mfa_level_id: VisitorMfaLevel::NOTHING,
      mfa_status_id: VisitorMfaStatus::UNCONFIGURED,
    )
  end
end
