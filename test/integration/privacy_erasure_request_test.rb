# frozen_string_literal: true

require "test_helper"

class PrivacyErasureRequestTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  self.fixture_table_names = []

  test "withdrawal ceremony cannot submit a privacy erasure request or create side effects" do
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
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
    valid_preference = PreferenceToken.encode(
      SecurityJwtPreferenceTokenCodec::ANONYMOUS_PREFERENCE_VALUES.transform_values(&:first),
      host: host, preference_type: "AppPreference", public_id: PublicId.generate,
      jti: JitSecurityJwtJtiGenerator.generate,
      issued_at: Time.current,
    )

    assert_predicate PreferenceToken.decode(valid_preference, host: host), :present?

    writes = []
    record_write =
      lambda do |*_args, payload|
        operation = payload.fetch(:sql).lstrip[/\A(?:INSERT|UPDATE|DELETE|MERGE|TRUNCATE)\b/i]
        writes << "#{operation.upcase} #{payload[:name]}" if operation
      end

    ActiveSupport::Notifications.subscribed(record_write, "sql.active_record") do
      assert_no_enqueued_jobs do
        assert_no_difference [-> { ClientPrivacyRequest.count }, -> { ClientProcessorErasureNotification.count },
                              -> { ClientOccurrence.count },] do
          post base_app_identity_privacy_erasure_url(ri: "jp", host: host), headers: browser_headers

          assert_response :forbidden

          cookies[PreferenceCookieName.anonymous_jwt] = "invalid"
          post base_app_identity_privacy_erasure_url(ri: "jp", host: host), headers: browser_headers

          assert_response :forbidden

          cookies[PreferenceCookieName.anonymous_jwt] = valid_preference
          post base_app_identity_privacy_erasure_url(ri: "jp", host: host), headers: browser_headers

          assert_response :forbidden
        end
      end
    end

    assert_empty writes
  end

  test "received client erasure request is cancelled on recovery" do
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
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
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
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
    ClientMfaStatus.find_or_create_by!(id: ClientMfaStatus::UNCONFIGURED)
    Client.create!(
      status_id: ClientStatus::NOTHING,
      visibility_id: ClientVisibility::USER,
      security_mode_id: SecurityModeConfigurable::NORMAL,
      mfa_status_id: ClientMfaStatus::UNCONFIGURED,
    )
  end
end
