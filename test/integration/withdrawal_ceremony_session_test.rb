# frozen_string_literal: true

require "test_helper"

class WithdrawalCeremonySessionTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  test "deactivated client status requires app withdrawal ceremony" do
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL", "base.app.localhost")
    host! host
    client = create_client
    client.update!(
      withdrawal_started_at: 2.hours.ago,
      deactivated_at: 90.minutes.ago,
      discard_at: 31.days.from_now,
      purge_eligible_at: 31.days.from_now,
    )

    get edit_base_app_identity_withdrawal_url(ri: "jp", host: host)

    assert_response :see_other
    assert_redirected_to new_base_app_identity_withdrawal_session_path(ri: "jp")

    ceremony = ClientWithdrawalCeremony.issue!(subject: client, request: ActionDispatch::TestRequest.create)
    cookies[withdrawal_ceremony_cookie_name] = "#{ceremony.public_id}:#{ceremony.plaintext_token}"

    get edit_base_app_identity_withdrawal_url(ri: "jp", host: host)

    assert_response :success
  end

  test "client recovery consumes ceremony and does not create normal auth cookie" do
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

    post base_app_identity_withdrawal_url(ri: "jp", host: host), headers: browser_headers

    assert_response :see_other
    assert_predicate ceremony.reload, :consumed?
    assert_nil client.reload.deactivated_at
    assert_nil cookies[AuthenticationBase::ACCESS_COOKIE_KEY]
    assert_nil cookies[AuthenticationBase::REFRESH_COOKIE_KEY]
  end

  test "expired revoked and consumed ceremonies are rejected" do
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL", "base.app.localhost")
    host! host
    client = create_client
    client.update!(
      withdrawal_started_at: 2.hours.ago,
      deactivated_at: 90.minutes.ago,
      discard_at: 31.days.from_now,
      purge_eligible_at: 31.days.from_now,
    )

    expired = ClientWithdrawalCeremony.issue!(subject: client, request: ActionDispatch::TestRequest.create)
    expired.update!(expires_at: 1.minute.ago)
    cookies[withdrawal_ceremony_cookie_name] = "#{expired.public_id}:#{expired.plaintext_token}"
    get edit_base_app_identity_withdrawal_url(ri: "jp", host: host)

    assert_response :see_other

    revoked = ClientWithdrawalCeremony.issue!(subject: client, request: ActionDispatch::TestRequest.create)
    revoked.revoke!
    cookies[withdrawal_ceremony_cookie_name] = "#{revoked.public_id}:#{revoked.plaintext_token}"
    get edit_base_app_identity_withdrawal_url(ri: "jp", host: host)

    assert_response :see_other

    consumed = ClientWithdrawalCeremony.issue!(subject: client, request: ActionDispatch::TestRequest.create)
    consumed.consume!
    cookies[withdrawal_ceremony_cookie_name] = "#{consumed.public_id}:#{consumed.plaintext_token}"
    get edit_base_app_identity_withdrawal_url(ri: "jp", host: host)

    assert_response :see_other
  end

  test "status ceremony cannot authorize irreversible termination" do
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL", "base.app.localhost")
    host! host
    client = create_client
    client.update_columns(
      created_at: 9.days.ago,
      withdrawal_started_at: 8.days.ago,
      deactivated_at: 8.days.ago,
      discard_at: 8.days.ago,
      purge_eligible_at: 23.days.from_now,
    )
    ceremony = ClientWithdrawalCeremony.issue!(
      subject: client,
      purpose: "status",
      request: ActionDispatch::TestRequest.create,
    )
    cookies[withdrawal_ceremony_cookie_name] = "#{ceremony.public_id}:#{ceremony.plaintext_token}"

    delete base_app_identity_withdrawal_url(ri: "jp", host: host), headers: browser_headers

    assert_response :redirect
    assert_not_predicate client.reload, :terminated?
    assert_predicate ceremony.reload, :active?
  end

  test "termination clears Inertia history on the next app page" do
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    host! host
    client = create_client
    client.update_columns(
      created_at: 9.days.ago,
      withdrawal_started_at: 8.days.ago,
      deactivated_at: 8.days.ago,
      discard_at: 8.days.ago,
      purge_eligible_at: 23.days.from_now,
      withdrawn_at: 8.days.ago,
    )
    client.client_withdrawal_flows.create!(
      status_id: ClientWithdrawalFlowStatus::DISCARDED, began_at: 8.days.ago, discard_at: Float::INFINITY,
    )
    ceremony = ClientWithdrawalCeremony.issue!(
      subject: client,
      purpose: "termination",
      request: ActionDispatch::TestRequest.create,
    )
    cookies[withdrawal_ceremony_cookie_name] = "#{ceremony.public_id}:#{ceremony.plaintext_token}"

    delete base_app_identity_withdrawal_url(ri: "jp", host: host), headers: browser_headers

    assert_response :see_other
    assert_predicate client.reload, :terminated?
    get base_app_root_url(ri: "jp", host: host)

    assert_response :success
    assert inertia_page.fetch("clearHistory")
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
    ClientMfaStatus.find_or_create_by!(id: ClientMfaStatus::UNCONFIGURED)
    Client.create!(
      status_id: ClientStatus::NOTHING,
      visibility_id: ClientVisibility::USER,
      security_mode_id: SecurityModeConfigurable::NORMAL,
      mfa_status_id: ClientMfaStatus::UNCONFIGURED,
    )
  end
end
