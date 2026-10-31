# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class Auth::App::Web::V0::In::Email::OtpsControllerTest < ActionDispatch::IntegrationTest
  # Rate-limit counters are a NullStore by default in test so unrelated tests
  # cannot accumulate them; this file asserts real limiting behavior, so it
  # opts into a deterministic MemoryStore.
  rate_limit_counters!

  include ActiveJob::TestHelper

  skip_transactional_tests_for_database :op_base_app
  skip_transactional_tests_for_database :occurrence

  setup do
    host! ENV.fetch("PUBLIC_AUTH_SERVICE_URL", "auth.app.localhost")
    @host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL", "auth.app.localhost")
    admission = OidcTestEntry.issue!(
      surface: "app", intent: "sign_in", base_browser_nonce: SecureRandom.hex(32), base_token: nil,
    )
    @admissions = [admission]
    @occurrence_bodies = []
    admit_auth_ceremony_entry!("/sign/in", reference: admission.reference, params: { ri: "jp" })
    @primary_sign_in_binding = nil
    ActionMailer::Base.deliveries.clear
  end

  teardown do
    EmailOccurrence.where(body: @occurrence_bodies).delete_all if @occurrence_bodies.present?
    @admissions&.each do |admission|
      bindings = ClientAuthAdmissionBinding.where(authorization_transaction_id: admission.transaction.id)
      session_ids = bindings.pluck(:auth_ceremony_session_id, :admitted_auth_ceremony_session_id).flatten.compact.uniq
      bindings.delete_all
      ClientAuthCeremonySession.where(id: session_ids).delete_all
      admission.transaction.delete
    end
  end

  test "queue refusal reports unavailable and retains the newly issued generation" do
    owner = Client.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL,
      id: SecureRandom.random_number(1 << 60) + 1_000_000_000, status_id: ClientStatus::ACTIVE,
    )
    email = create_verified_contact(owner: owner, address: "resend-failure-#{SecureRandom.hex(8)}@example.test")
    state = state_for(email.address)
    ceremony = current_ceremony
    old_generation = ceremony.reload.email_otp_context.fetch("generation")
    clear_delivery_occurrences_for(email.address)
    refused_job = Object.new
    refused_job.define_singleton_method(:perform_later) { |*_, **_| false }

    OtpNotifierEmailDeliveryJob.stub(:set, refused_job) do
      post auth_app_web_v0_in_email_otp_path, params: { state: state }, headers: { "Host" => @host }, as: :json
    end

    assert_response :service_unavailable
    assert_equal({ "resendable" => false, "retry_after" => 0 }, response.parsed_body)
    assert_not_equal old_generation, ceremony.reload.email_otp_context.fetch("generation")
    assert_empty ActionMailer::Base.deliveries
    assert_includes response.headers.fetch("Cache-Control"), "no-store"
  end

  test "occurrence database connection failure returns unavailable without changing the challenge" do
    address = "resend-database-#{SecureRandom.hex(8)}@example.test"
    state = state_for(address)
    ceremony = current_ceremony
    original = ceremony.reload.email_otp_context.deep_dup

    EmailOccurrence.stub(:find_by, ->(**) { raise ActiveRecord::ConnectionNotEstablished }) do
      post auth_app_web_v0_in_email_otp_path, params: { state: state }, headers: { "Host" => @host }, as: :json
    end

    assert_response :service_unavailable
    assert_equal({ "resendable" => false, "retry_after" => 0 }, response.parsed_body)
    unchanged = original == ceremony.reload.email_otp_context

    assert unchanged, "connection failure before issuance must preserve the challenge"
    assert_empty ActionMailer::Base.deliveries
  end

  [ActiveRecord::LockWaitTimeout, ActiveRecord::Deadlocked].each do |failure_class|
    test "occurrence #{failure_class.name} returns unavailable without changing the challenge" do
      address = "resend-lock-failure-#{SecureRandom.hex(8)}@example.test"
      state = state_for(address)
      ceremony = current_ceremony
      original = ceremony.reload.email_otp_context.deep_dup

      Rails.error.stub(:report, ->(*, **) { }) do
        EmailOccurrence.stub(:find_by, ->(**) { raise failure_class }) do
          post auth_app_web_v0_in_email_otp_path, params: { state: state }, headers: { "Host" => @host }, as: :json
        end
      end

      assert_response :service_unavailable
      assert_equal({ "resendable" => false, "retry_after" => 0 }, response.parsed_body)
      assert_withheld { original == ceremony.reload.email_otp_context }
      assert_empty ActionMailer::Base.deliveries
    end
  end

  test "unexpected database statement errors remain visible" do
    state = state_for("resend-statement-#{SecureRandom.hex(8)}@example.test")

    EmailOccurrence.stub(:find_by, ->(**) { raise ActiveRecord::StatementInvalid, "invalid statement" }) do
      assert_raises(ActiveRecord::StatementInvalid) do
        post auth_app_web_v0_in_email_otp_path, params: { state: state }, headers: { "Host" => @host }, as: :json
      end
    end
  end

  test "queue database connection failure returns unavailable and keeps the new generation" do
    owner = Client.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL,
      id: SecureRandom.random_number(1 << 60) + 1_000_000_000, status_id: ClientStatus::ACTIVE,
    )
    email = create_verified_contact(owner: owner, address: "resend-db-after-#{SecureRandom.hex(8)}@example.test")
    state = state_for(email.address)
    ceremony = current_ceremony
    old_generation = ceremony.reload.email_otp_context.fetch("generation")
    clear_delivery_occurrences_for(email.address)

    OtpNotifierEmailDeliveryJob.stub(:set, ->(*) { raise ActiveRecord::ConnectionNotEstablished }) do
      post auth_app_web_v0_in_email_otp_path, params: { state: state }, headers: { "Host" => @host }, as: :json
    end

    assert_response :service_unavailable
    assert_not_equal old_generation, ceremony.reload.email_otp_context.fetch("generation")
    assert_empty ActionMailer::Base.deliveries
  end

  test "a released Contact cannot mint a new resend state from a stale code entry page" do
    TurnstileVerifierStub.challenge_enabled = true
    TurnstileVerifierStub.challenge_response = { "success" => true }
    address = "stale-resend-#{SecureRandom.hex(8)}@example.test"
    owner = Client.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL,
      id: SecureRandom.random_number(1 << 60) + 1_000_000_000, status_id: ClientStatus::ACTIVE,
    )
    contact = owner.client_emails.create!(
      address: address, confirm_policy: "1", user_email_status_id: ClientEmailStatus::VERIFIED,
    ).tap(&:finalize_binding!)
    post(
      "/sign/in/email", params: { :user_email => { address: address },
                                  "cf-turnstile-response" => "test",
                                  :fb => @primary_sign_in_binding, },
                        headers: { "Host" => @host },
    )

    assert_response :redirect
    entry_url = URI.parse(response.location).request_uri
    contact.release_binding!
    get(entry_url, params: { ri: "jp" }, headers: { "Host" => @host })

    assert_response :redirect
    assert_redirected_to %r{/sign/in/email/new}
    assert_predicate contact.reload, :binding_released?
  ensure
    TurnstileVerifierStub.challenge_enabled = false
    TurnstileVerifierStub.challenge_response = nil
  end

  test "a signed resend state cannot authorize a browser without confirmed admission" do
    state = SignInOtpResendState.issue(
      kind: :email, target: "unadmitted-app-#{SecureRandom.hex(8)}@example.test", surface: :app,
      browser_binding: "b" * 64,
      contact: nil,
    )
    browser = open_session
    browser.host!(@host)
    assert_no_difference "EmailOccurrence.count" do
      browser.post("/web/v0/in/email/otp", params: { state: state }, headers: { "Host" => @host }, as: :json)
    end

    assert_equal 400, browser.response.status
  end

  test "recent issued returns 429 with retry_after and header" do
    email = "retry_#{SecureRandom.hex(4)}@example.com"
    hmac = OccurrenceHmac.digest(kind: :email, body: email)

    assert_not EmailOccurrence.exists?(body: hmac)
    @occurrence_bodies << hmac
    EmailOccurrence.create!(
      body: hmac,
      status_id: EmailOccurrenceStatus::ACTIVE,
      memo: "purpose=in issued=#{Time.current.to_i}",
    )

    post auth_app_web_v0_in_email_otp_path,
         params: { state: state_for(email) },
         headers: { "Host" => @host },
         as: :json

    assert_response :too_many_requests
    assert_not response.parsed_body["resendable"]
    assert_operator response.parsed_body["retry_after"], :>, 0
    assert_equal response.parsed_body["retry_after"].to_s, response.headers["Retry-After"]
  end

  test "resend state from another admitted browser cannot reserve dispatch for its destination" do
    TurnstileVerifierStub.challenge_enabled = true
    TurnstileVerifierStub.challenge_response = { "success" => true }
    address = "bound-resend-#{SecureRandom.hex(8)}@example.test"
    candidate_body = OccurrenceHmac.digest(kind: :email, body: address)

    assert_not EmailOccurrence.exists?(body: candidate_body)
    @occurrence_bodies << candidate_body
    post(
      "/sign/in/email", params: {
        :user_email => { address: address },
        "cf-turnstile-response" => "test",
        :fb => @primary_sign_in_binding,
      }, headers: { "Host" => @host },
    )

    assert_response :redirect
    assert_redirected_to %r{/sign/in/email/edit}
    assert_not_nil SignAppInEmailAuthenticationState.load(session)
    get(URI.parse(response.location).request_uri, params: { ri: "jp" }, headers: { "Host" => @host })

    assert_response :success
    state = inertia_props.fetch("otp_resend").fetch("state")
    other = open_session
    other.host!(@host)
    admission = OidcTestEntry.issue!(
      surface: "app", intent: "sign_in", base_browser_nonce: SecureRandom.hex(32), base_token: nil,
    )
    @admissions << admission
    admit_auth_ceremony_entry!("/sign/in", reference: admission.reference, params: { ri: "jp" }, browser: other)

    assert_equal 303, other.response.status
    assert_no_difference "EmailOccurrence.count" do
      other.post("/web/v0/in/email/otp", params: { state: state }, as: :json)
    end

    assert_equal 400, other.response.status
  ensure
    TurnstileVerifierStub.challenge_enabled = false
    TurnstileVerifierStub.challenge_response = nil
  end

  test "after cooldown returns 200 and logs issued occurrence" do
    user = clients(:one)
    email = "ok_#{SecureRandom.hex(4)}@example.com"
    user.client_emails.create!(address: email, user_email_status_id: ClientEmailStatus::VERIFIED).finalize_binding!

    hmac = OccurrenceHmac.digest(kind: :email, body: email)

    assert_not EmailOccurrence.exists?(body: hmac)
    @occurrence_bodies << hmac
    EmailOccurrence.create!(
      body: hmac,
      status_id: EmailOccurrenceStatus::ACTIVE,
      memo: "purpose=in issued=#{31.seconds.ago.to_i}",
    )

    assert_difference -> { ActionMailer::Base.deliveries.count }, 1 do
      perform_enqueued_jobs do
        post auth_app_web_v0_in_email_otp_path,
             params: { state: state_for(email) },
             headers: { "Host" => @host },
             as: :json
      end
    end

    assert_response :ok
    assert response.parsed_body["resendable"]
    assert_equal 0, response.parsed_body["retry_after"]

    occurrence = EmailOccurrence.find_by(body: hmac)

    assert_not_nil occurrence
    assert_equal EmailOccurrenceStatus::ACTIVE, occurrence.status_id
    assert_includes occurrence.memo, "purpose=in"
    assert_match(/issued=[0-9,]+/, occurrence.memo)
  end

  test "a retained resend state cannot resolve a released destination to another Identity" do
    TurnstileVerifierStub.challenge_enabled = true
    TurnstileVerifierStub.challenge_response = { "success" => true }
    address = "released-resend-#{SecureRandom.hex(8)}@example.test"
    candidate_body = OccurrenceHmac.digest(kind: :email, body: address)

    assert_not EmailOccurrence.exists?(body: candidate_body)
    @occurrence_bodies << candidate_body
    owner = Client.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL,
      id: SecureRandom.random_number(1 << 60) + 1_000_000_000, status_id: ClientStatus::ACTIVE,
    )
    original = owner.client_emails.create!(
      address: address, confirm_policy: "1", user_email_status_id: ClientEmailStatus::VERIFIED,
    ).tap(&:finalize_binding!)
    post(
      "/sign/in/email", params: { :user_email => { address: address },
                                  "cf-turnstile-response" => "test",
                                  :fb => @primary_sign_in_binding, },
                        headers: { "Host" => @host },
    )

    assert_response :redirect
    get(URI.parse(response.location).request_uri, params: { ri: "jp" }, headers: { "Host" => @host })

    assert_response :success
    state = inertia_props.fetch("otp_resend").fetch("state")
    original.release_binding!
    replacement_owner = Client.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL,
      id: SecureRandom.random_number(1 << 60) + 1_000_000_000, status_id: ClientStatus::ACTIVE,
    )
    replacement = replacement_owner.client_emails.create!(
      address: address, confirm_policy: "1", user_email_status_id: ClientEmailStatus::VERIFIED,
    ).tap(&:finalize_binding!)
    unchanged = replacement.reload.attributes
    post("/web/v0/in/email/otp", params: { state: state }, headers: { "Host" => @host }, as: :json)

    assert_response :bad_request
    assert_equal unchanged, replacement.reload.attributes
    assert_predicate original.reload, :binding_released?
  ensure
    TurnstileVerifierStub.challenge_enabled = false
    TurnstileVerifierStub.challenge_response = nil
  end

  test "success replaces its Ticket OTP generation while retaining Source OTP" do
    user = clients(:one)
    email_record = user.client_emails.create!(
      address: "rotate_#{SecureRandom.hex(4)}@example.com",
      user_email_status_id: ClientEmailStatus::VERIFIED,
    ).tap(&:finalize_binding!)

    state = state_for(email_record.address)
    cookie_name = JitSessionCookieConfig.force_secure? ? "__Host-auth_sid" : "auth_sid"
    ceremony = ClientAuthCeremonySession.find_active_by_raw_sid(cookies[cookie_name])
    original = ceremony.reload.email_otp_context
    source = email_record.reload.attributes

    perform_enqueued_jobs do
      post auth_app_web_v0_in_email_otp_path,
           params: { state: state }, headers: { "Host" => @host }, as: :json
    end

    assert_response :ok

    assert_equal source, email_record.reload.attributes
    assert_not_equal original.fetch("generation"), ceremony.reload.email_otp_context.fetch("generation")
    # Boolean assertions keep proof digests out of failure output.
    proof_rotated = original.fetch("code_digest") != ceremony.email_otp_context.fetch("code_digest")

    assert proof_rotated,
           "generation binding invalidates the old stored proof even when six-digit values coincide"
    code = ActionMailer::Base.deliveries.last.text_part.body.decoded.match(/Pass Code:\s*([0-9]{6})/)[1]

    assert_predicate ceremony.verify_email_otp!(code: code), :success?
  end

  test "a blocked sign-in sentry refuses the resender with no generation or delivery" do
    Flipper.disable(FeatureFlags::REGISTRY.fetch(:sign_in_available_app).name)
    owner = Client.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL,
      id: SecureRandom.random_number(1 << 60) + 1_000_000_000, status_id: ClientStatus::ACTIVE,
    )
    email_record = create_verified_contact(owner:, address: "blocked-resend-#{SecureRandom.hex(4)}@example.test")

    ceremony = current_ceremony
    ceremony.issue_email_otp!(contact: email_record, destination: email_record.address)
    generation = ceremony.reload.email_otp_context.fetch("generation")
    state = SignInOtpResendState.issue(
      kind: :email, target: email_record.address, surface: :app,
      browser_binding: ceremony.sid_digest, contact: email_record,
    )
    clear_delivery_occurrences_for(email_record.address)

    assert_no_difference "EmailOccurrence.count" do
      post(
        auth_app_web_v0_in_email_otp_path,
        params: { state: state }, headers: { "Host" => @host }, as: :json,
      )
    end

    assert_response :service_unavailable
    assert_equal "text/plain", response.media_type
    assert_not response.parsed_body.is_a?(Hash)
    assert_empty ActionMailer::Base.deliveries
    assert_equal generation, ceremony.reload.email_otp_context.fetch("generation")
  ensure
    Flipper.enable(FeatureFlags::REGISTRY.fetch(:sign_in_available_app).name)
  end

  test "refusing an expired resend leaves the ceremony generation and delivery untouched" do
    owner = Client.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL,
      id: SecureRandom.random_number(1 << 60) + 1_000_000_000, status_id: ClientStatus::ACTIVE,
    )
    email_record = create_verified_contact(owner:, address: "expired-resend-#{SecureRandom.hex(4)}@example.test")

    ceremony = current_ceremony
    ceremony.issue_email_otp!(contact: email_record, destination: email_record.address)
    ceremony.reload
    generation = ceremony.email_otp_context.fetch("generation")
    revoked_before = ceremony.revoked_at
    state = SignInOtpResendState.issue(
      kind: :email, target: email_record.address, surface: :app,
      browser_binding: ceremony.sid_digest, contact: email_record,
    )
    clear_delivery_occurrences_for(email_record.address)
    expires_at = ceremony.reload.expires_at

    # Boundary cases one second before, exactly at, and one second past expiry; the honour of
    # `expires_at > now` is exercised through the real ceremony lookup rather than a stubbed row.
    [expires_at - 1.second, expires_at, expires_at + 1.second].each do |decision_time|
      ClientAuthCeremonySession.stub(:database_now, decision_time) do
        post auth_app_web_v0_in_email_otp_path,
             params: { state: state }, headers: { "Host" => @host }, as: :json
      end

      assert_not response.successful?, "expiry #{decision_time} must refuse"
      assert_empty ActionMailer::Base.deliveries
      ceremony.reload

      assert_equal generation, ceremony.email_otp_context.fetch("generation"),
                   "expiry #{decision_time} must not rotate the OTP generation"
      if revoked_before.nil?
        assert_nil ceremony.revoked_at, "expiry #{decision_time} must not revoke or consume the ceremony"
      else
        assert_equal revoked_before, ceremony.revoked_at,
                     "expiry #{decision_time} must not revoke or consume the ceremony"
      end
    end
  end

  private

  def create_verified_contact(owner:, address:)
    owner.client_emails.create!(
      address: address, confirm_policy: "1", user_email_status_id: ClientEmailStatus::VERIFIED,
    ).tap(&:finalize_binding!)
  end

  def current_ceremony
    cookie_name = JitSessionCookieConfig.force_secure? ? "__Host-auth_sid" : "auth_sid"
    ClientAuthCeremonySession.find_active_by_raw_sid(cookies[cookie_name])
  end

  def clear_delivery_occurrences_for(address)
    hmac = OccurrenceHmac.digest(kind: :email, body: address)

    assert_not EmailOccurrence.exists?(body: hmac)
    @occurrence_bodies << hmac
    ActionMailer::Base.deliveries.clear
  end

  def state_for(email)
    body = OccurrenceHmac.digest(kind: :email, body: email)
    unless @occurrence_bodies.include?(body)
      assert_not EmailOccurrence.exists?(body: body)
      @occurrence_bodies << body
    end
    cookie_name = JitSessionCookieConfig.force_secure? ? "__Host-auth_sid" : "auth_sid"
    ceremony = ClientAuthCeremonySession.find_active_by_raw_sid(cookies[cookie_name])
    contact = ClientEmail.effective_binding.with_address(email).take
    ceremony.issue_email_otp!(contact: contact, destination: email)
    SignInOtpResendState.issue(
      kind: :email, target: email, surface: :app, browser_binding: ceremony.sid_digest, contact: contact,
    )
  end
end
