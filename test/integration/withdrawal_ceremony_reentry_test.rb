# frozen_string_literal: true

require "test_helper"

class WithdrawalCeremonyReentryTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  self.fixture_table_names = []

  test "withdrawal reentry refuses a ceremony when authority changes after OTP verification" do
    %i(email_release actor_recovery).each do |change|
      host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
      host! host
      client = Client.create!(
        status_id: ClientStatus::NOTHING, visibility_id: ClientVisibility::USER,
        security_mode_id: SecurityModeConfigurable::NORMAL, mfa_status_id: ClientMfaStatus::UNCONFIGURED,
        withdrawal_started_at: 2.hours.ago, deactivated_at: 90.minutes.ago,
        discard_at: 31.days.from_now, purge_eligible_at: 31.days.from_now,
      )
      email = ClientEmail.create!(
        user: client, address: "withdrawal-race-#{SecureRandom.hex(8)}@example.test", confirm_policy: "1",
        user_email_status_id: ClientEmailStatus::VERIFIED,
      )
      email.finalize_binding!
      cookies["csrf_token"] = "test_csrf_token"
      headers = { "Client-Agent" => "Mozilla/5.0", "X-CSRF-Token" => "test_csrf_token" }
      post base_app_identity_withdrawal_session_url(ri: "jp", host: host),
           params: { withdrawal_reentry: { address: email.address } }, headers: headers

      assert_response :success
      payload = ActiveJob::Arguments.deserialize(enqueued_jobs.last.fetch(:args)).last.fetch(:params)
      pass_code = OutboundSensitivePayload.decrypt_email_otp(payload.fetch(:encrypted_hotp_token))
      verify = EmailReentryOtpVerificationCommitter.method(:call)
      change_after_verification =
        lambda do |**arguments|
          result = verify.call(**arguments)
          if result && change == :email_release
            arguments.fetch(:email).release_binding!
          elsif result
            WithdrawalLifecycle.recover!(actor: client)
          end
          result
        end

      EmailReentryOtpVerificationCommitter.stub(:call, change_after_verification) do
        assert_no_difference "ClientWithdrawalCeremony.count" do
          post base_app_identity_withdrawal_session_url(ri: "jp", host: host),
               params: { pass_code: pass_code }, headers: headers
        end
      end
      assert_response :unprocessable_content
      assert_nil cookies[AuthenticationBase::ACCESS_COOKIE_KEY]
      assert_nil cookies[AuthenticationBase::REFRESH_COOKIE_KEY]
    end
  end

  test "deactivated client obtains ceremony after valid email otp without normal auth cookies" do
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    host! host
    client = create_client
    client.update!(
      withdrawal_started_at: 2.hours.ago,
      deactivated_at: 90.minutes.ago,
      discard_at: 31.days.from_now,
      purge_eligible_at: 31.days.from_now,
    )
    ClientEmailStatus.find_or_create_by!(id: ClientEmailStatus::VERIFIED)
    email = ClientEmail.create!(
      user: client,
      address: "reentry-client@example.test",
      confirm_policy: "1",
      user_email_status_id: ClientEmailStatus::VERIFIED,
    )
    email.finalize_binding!
    original_proof = email.attributes.slice(
      "public_id", "address_digest", "number_digest", "user_id",
      "staff_id",
    )

    assert_enqueued_jobs 1, only: OtpNotifierEmailDeliveryJob do
      post base_app_identity_withdrawal_session_url(ri: "jp", host: host),
           params: { withdrawal_reentry: { address: "reentry-client@example.test" } },
           headers: browser_headers
    end

    assert_response :success
    # The one-time-code field appears only when the server offers the pass-code form, which is the
    # prop that drives it; its absence would mean the code step was never reached.
    assert_predicate inertia_props.fetch("pass_code_form").fetch("action"), :present?
    proof_unchanged = original_proof == email.reload.attributes.slice(*original_proof.keys)

    assert proof_unchanged
    payload = ActiveJob::Arguments.deserialize(enqueued_jobs.last.fetch(:args)).last.fetch(:params)
    pass_code = OutboundSensitivePayload.decrypt_email_otp(payload.fetch(:encrypted_hotp_token))
    transaction = ClientEmailCeremonyTransaction.find_by!(
      transaction_id: payload.fetch(:email_ceremony_transaction_ref),
    )

    assert_equal "withdrawal", transaction.operation

    assert_difference -> { ClientWithdrawalCeremony.count }, 1 do
      post base_app_identity_withdrawal_session_url(ri: "jp", host: host),
           params: { pass_code: pass_code },
           headers: browser_headers
    end

    assert_response :see_other
    assert_redirected_to edit_base_app_identity_withdrawal_path(ri: "jp")
    assert_nil cookies[AuthenticationBase::ACCESS_COOKIE_KEY]
    assert_nil cookies[AuthenticationBase::REFRESH_COOKIE_KEY]
    assert_predicate ClientOccurrence.where(event_type: "withdrawal.ceremony_issued"), :exists?
    assert transaction.reload.otp_consumed_at
  end

  # A wrong code must not disclose whether the address, the state or the code was the
  # problem: the same generic page comes back with a 422 and no ceremony is issued.
  test "a wrong re-entry code answers the same generic page without issuing a ceremony" do
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL", "base.app.localhost")
    host! host
    client = create_client
    client.update!(
      withdrawal_started_at: 2.hours.ago,
      deactivated_at: 90.minutes.ago,
      discard_at: 31.days.from_now,
      purge_eligible_at: 31.days.from_now,
    )
    ClientEmailStatus.find_or_create_by!(id: ClientEmailStatus::VERIFIED)
    email = ClientEmail.create!(
      user: client,
      address: "reentry-wrong-code@example.test",
      confirm_policy: "1",
      user_email_status_id: ClientEmailStatus::VERIFIED,
    )
    email.finalize_binding!
    assert_enqueued_jobs 1, only: OtpNotifierEmailDeliveryJob do
      post base_app_identity_withdrawal_session_url(ri: "jp", host: host),
           params: { withdrawal_reentry: { address: "reentry-wrong-code@example.test" } },
           headers: browser_headers
    end

    assert_response :success
    payload = ActiveJob::Arguments.deserialize(enqueued_jobs.last.fetch(:args)).last.fetch(:params)
    code = OutboundSensitivePayload.decrypt_email_otp(payload.fetch(:encrypted_hotp_token))
    wrong = (code == "000000") ? "000001" : "000000"
    transaction = ClientEmailCeremonyTransaction.find_by!(
      transaction_id: payload.fetch(:email_ceremony_transaction_ref),
    )

    assert_no_difference -> { ClientWithdrawalCeremony.count } do
      post base_app_identity_withdrawal_session_url(ri: "jp", host: host),
           params: { pass_code: wrong },
           headers: browser_headers
    end

    assert_response :unprocessable_content
    assert_nil transaction.reload.otp_consumed_at
    assert transaction.otp_verifier
    assert_equal 1, email.reload.otp_attempts_count
  end

  test "active client does not obtain withdrawal ceremony through reentry" do
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL", "base.app.localhost")
    host! host
    client = create_client
    ClientEmailStatus.find_or_create_by!(id: ClientEmailStatus::VERIFIED)
    ClientEmail.create!(
      user: client,
      address: "active-client@example.test",
      confirm_policy: "1",
      user_email_status_id: ClientEmailStatus::VERIFIED,
    ).finalize_binding!

    assert_no_difference -> { ClientWithdrawalCeremony.count } do
      post base_app_identity_withdrawal_session_url(ri: "jp", host: host),
           params: { withdrawal_reentry: { address: "active-client@example.test" } },
           headers: browser_headers
    end

    assert_response :success
  end

  test "app withdrawal reentry keeps eligible and unknown email responses equivalent across sessions" do
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL", "base.app.localhost")
    client = create_client
    client.update!(
      withdrawal_started_at: 2.hours.ago,
      deactivated_at: 90.minutes.ago,
      discard_at: 31.days.from_now,
      purge_eligible_at: 31.days.from_now,
    )
    ClientEmailStatus.find_or_create_by!(id: ClientEmailStatus::VERIFIED)
    email = ClientEmail.create!(
      user: client,
      address: "reentry-equivalence-client@example.test",
      confirm_policy: "1",
      user_email_status_id: ClientEmailStatus::VERIFIED,
    )
    email.finalize_binding!
    eligible_session = open_session
    unknown_session = open_session

    assert_enqueued_jobs 1, only: OtpNotifierEmailDeliveryJob do
      eligible_session.post(
        base_app_identity_withdrawal_session_url(ri: "jp", host: host),
        params: { withdrawal_reentry: { address: email.address } },
      )
      unknown_session.post(
        base_app_identity_withdrawal_session_url(ri: "jp", host: host),
        params: { withdrawal_reentry: { address: "reentry-equivalence-unknown@example.test" } },
      )
    end

    assert_equal eligible_session.response.status, unknown_session.response.status
    assert_equal 200, eligible_session.response.status
    assert_nil eligible_session.response.headers["Location"]
    assert_nil unknown_session.response.headers["Location"]
    real_state = eligible_session.request.session.fetch(:withdrawal_ceremony_reentry)
    dummy_state = unknown_session.request.session.fetch(:withdrawal_ceremony_reentry)

    assert_equal [false, true], [real_state.fetch("dummy"), dummy_state.fetch("dummy")]
    assert_equal JSON.generate(real_state).bytesize, JSON.generate(dummy_state).bytesize
    session_key = Rails.application.config.session_options.fetch(:key)

    assert_equal Rack::Utils.unescape(eligible_session.cookies[session_key]).bytesize,
                 Rack::Utils.unescape(unknown_session.cookies[session_key]).bytesize
    assert_operator Rack::Utils.unescape(eligible_session.cookies[session_key]).bytesize, :<, 4096
    assert_equal eligible_session.response.headers["Content-Type"],
                 unknown_session.response.headers["Content-Type"]
    assert_equal eligible_session.response.headers["Cache-Control"],
                 unknown_session.response.headers["Cache-Control"]
    assert_match "pass_code_form", eligible_session.response.body
    assert_match "pass_code_form", unknown_session.response.body
  end

  private

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
