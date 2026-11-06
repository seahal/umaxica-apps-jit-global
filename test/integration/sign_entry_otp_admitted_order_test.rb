# typed: false
# frozen_string_literal: true

require "test_helper"

class SignEntryOtpAdmittedOrderTest < ActionDispatch::IntegrationTest
  NAVIGATION_HEADERS = { "Sec-Fetch-Mode" => "navigate", "Sec-Fetch-Dest" => "document" }.freeze

  self.fixture_table_names = []
  uses_transaction "test_an_admitted_sign-in_can_resend_after_the_sentry_and_admission_checks",
                   "test_a_delivery_failure_leaves_a_usable_resend_handle_for_the_same_admitted_ceremony"

  test "switch refuses when email authentication starts after the first page check" do
    feature = FeatureFlags::REGISTRY.fetch(:sign_in_available_app).name
    enabled = Flipper.enabled?(feature)
    Flipper.enable(feature)
    host!(ENV.fetch("PUBLIC_AUTH_SERVICE_URL"))
    https!
    client = OidcClientRegistry.find!("core-app-jp")
    parent = OidcAuthorizationTransactionCoordinator.issue!(
      surface: "app", intent: "authentication",
      params: {
        response_type: "code",
        client_id: client.client_id,
        redirect_uri: client.redirect_uris_by_realm.fetch("client").first,
        code_challenge: SecureRandom.urlsafe_base64(32),
        code_challenge_method: "S256",
        scope: "openid profile",
        state: SecureRandom.urlsafe_base64(24),
        nonce: SecureRandom.urlsafe_base64(24),
      },
    ).transaction
    issuance = BaseAuthAdmissionCoordinator.issue_handoff!(
      transaction: parent, base_browser_nonce: SecureRandom.urlsafe_base64(32), base_token: nil,
    )
    get("/sign/in", params: { entry_ref: issuance.reference, ri: "jp" }, headers: NAVIGATION_HEADERS)
    get(response.location, headers: NAVIGATION_HEADERS)
    binding = ClientAuthAdmissionBinding.find_by!(entry_ref: issuance.reference)
    binding.confirm_base!(base_token: nil, browser_digest: binding.base_browser_digest)
    get("/sign/in", params: { entry_ref: issuance.reference, ri: "jp" }, headers: NAVIGATION_HEADERS)
    sid_name = JitSessionCookieConfig.force_secure? ? "__Host-auth_sid" : "auth_sid"
    sid = cookies[sid_name]
    ceremony = ClientAuthCeremonySession.find_active_by_raw_sid(sid)
    now = ClientOidcAuthorizationTransaction.database_now
    started = false
    clock =
      lambda do
        unless started
          started = true
          ceremony.issue_email_otp!(contact: nil, destination: "unknown-#{SecureRandom.hex(8)}@example.test")
        end
        now
      end

    ClientOidcAuthorizationTransaction.stub(:database_now, clock) do
      post(auth_app_sign_switch_path(ri: "jp"), params: { to: "sign_up" })
    end

    assert started
    assert_response :conflict
    assert_equal I18n.t("errors.messages.phase_violation_refused"), response.body
    assert_includes response.headers.fetch("Cache-Control"), "no-store"
    assert_nil response.location
    assert_predicate ceremony.reload.email_otp_context, :present?
    assert_not_predicate ceremony, :cancelled?
    assert_equal OidcAuthorizationTransactionable::STATUS_PENDING, parent.reload.status_id
    assert_equal sid, cookies[sid_name]
    assert_not_includes response.headers["Set-Cookie"].to_s, "#{sid_name}="
  ensure
    if feature
      enabled ? Flipper.enable(feature) : Flipper.disable(feature)
    end
  end

  test "going Back from a flowless Email OTP attempt is refused without mutation" do
    feature = FeatureFlags::REGISTRY.fetch(:sign_in_available_app).name
    enabled = Flipper.enabled?(feature)
    Flipper.enable(feature)
    host!(ENV.fetch("PUBLIC_AUTH_SERVICE_URL"))
    https!
    client = OidcClientRegistry.find!("core-app-jp")
    parent = OidcAuthorizationTransactionCoordinator.issue!(
      surface: "app", intent: "authentication",
      params: {
        response_type: "code",
        client_id: client.client_id,
        redirect_uri: client.redirect_uris_by_realm.fetch("client").first,
        code_challenge: SecureRandom.urlsafe_base64(32),
        code_challenge_method: "S256",
        scope: "openid profile",
        state: SecureRandom.urlsafe_base64(24),
        nonce: SecureRandom.urlsafe_base64(24),
      },
    ).transaction
    issuance = BaseAuthAdmissionCoordinator.issue_handoff!(
      transaction: parent, base_browser_nonce: SecureRandom.urlsafe_base64(32), base_token: nil,
    )
    get("/sign/in", params: { entry_ref: issuance.reference, ri: "jp" }, headers: NAVIGATION_HEADERS)
    get(response.location, headers: NAVIGATION_HEADERS)
    binding = ClientAuthAdmissionBinding.find_by!(entry_ref: issuance.reference)
    binding.confirm_base!(base_token: nil, browser_digest: binding.base_browser_digest)
    get("/sign/in", params: { entry_ref: issuance.reference, ri: "jp" }, headers: NAVIGATION_HEADERS)

    assert_response :see_other
    follow_redirect!

    assert_response :success
    sid_name = JitSessionCookieConfig.force_secure? ? "__Host-auth_sid" : "auth_sid"
    sid = cookies[sid_name]
    ceremony = ClientAuthCeremonySession.find_active_by_raw_sid(sid)
    ceremony.issue_email_otp!(contact: nil, destination: "unknown-#{SecureRandom.hex(8)}@example.test")

    assert_nil parent.reload.secret_sign_in_flow_id, "OTP progress exists before a SignInFlow is created"
    before = [parent.reload.attributes, binding.reload.attributes, ceremony.reload.attributes]
    session_before = session.to_hash

    get(new_auth_app_sign_in_email_path(ri: "jp"), headers: NAVIGATION_HEADERS)

    assert_response :conflict
    assert_equal I18n.t("errors.messages.phase_violation_refused"), response.body
    assert_equal before, [parent.reload.attributes, binding.reload.attributes, ceremony.reload.attributes]
    assert_equal session_before, session.to_hash
    assert_equal sid, cookies[sid_name]
    forbidden_names = (AuthPhaseRefusalResponseBoundary::COOKIE_NAMES + AuthPhaseRefusalResponseBoundary::DBSC_HEADERS)
      .map(&:downcase)
    cookie_lines = Array(response.headers["Set-Cookie"]).flat_map { |header| header.to_s.split("\n") }
    cookie_names = cookie_lines.map { |header| header.split("=", 2).first.downcase }
    response_names = cookie_names + response.headers.to_h.keys.map(&:downcase)

    assert_empty forbidden_names & response_names

    get(auth_app_sign_in_path(ri: "jp"), headers: NAVIGATION_HEADERS)

    assert_equal [409, nil, I18n.t("errors.messages.phase_violation_refused"), "private, no-store"], [
      response.status, response.location, response.body, response.headers["Cache-Control"],
    ]
    assert_equal before, [parent.reload.attributes, binding.reload.attributes, ceremony.reload.attributes]
    assert_equal session_before, session.to_hash
    assert_equal sid, cookies[sid_name]
    forbidden_names = (AuthPhaseRefusalResponseBoundary::COOKIE_NAMES + AuthPhaseRefusalResponseBoundary::DBSC_HEADERS)
      .map(&:downcase)
    cookie_lines = Array(response.headers["Set-Cookie"]).flat_map { |header| header.to_s.split("\n") }
    cookie_names = cookie_lines.map { |header| header.split("=", 2).first.downcase }
    response_names = cookie_names + response.headers.to_h.keys.map(&:downcase)

    assert_empty forbidden_names & response_names
  ensure
    if feature
      enabled ? Flipper.enable(feature) : Flipper.disable(feature)
    end
  end

  test "switch handoff failure rolls back ceremony cancellation" do
    feature = FeatureFlags::REGISTRY.fetch(:sign_in_available_app).name
    enabled = Flipper.enabled?(feature)
    Flipper.enable(feature)
    host!(ENV.fetch("PUBLIC_AUTH_SERVICE_URL"))
    https!
    client = OidcClientRegistry.find!("core-app-jp")
    parent = OidcAuthorizationTransactionCoordinator.issue!(
      surface: "app", intent: "authentication",
      params: {
        response_type: "code",
        client_id: client.client_id,
        redirect_uri: client.redirect_uris_by_realm.fetch("client").first,
        code_challenge: SecureRandom.urlsafe_base64(32),
        code_challenge_method: "S256",
        scope: "openid profile",
        state: SecureRandom.urlsafe_base64(24),
        nonce: SecureRandom.urlsafe_base64(24),
      },
    ).transaction
    issuance = BaseAuthAdmissionCoordinator.issue_handoff!(
      transaction: parent, base_browser_nonce: SecureRandom.urlsafe_base64(32), base_token: nil,
    )
    get("/sign/in", params: { entry_ref: issuance.reference, ri: "jp" }, headers: NAVIGATION_HEADERS)
    get(response.location, headers: NAVIGATION_HEADERS)
    binding = ClientAuthAdmissionBinding.find_by!(entry_ref: issuance.reference)
    binding.confirm_base!(base_token: nil, browser_digest: binding.base_browser_digest)
    get("/sign/in", params: { entry_ref: issuance.reference, ri: "jp" }, headers: NAVIGATION_HEADERS)

    assert_response :see_other
    sid_name = JitSessionCookieConfig.force_secure? ? "__Host-auth_sid" : "auth_sid"
    sid = cookies[sid_name]
    ceremony = ClientAuthCeremonySession.find_active_by_raw_sid(sid)
    handoff_attempted = false
    failure =
      lambda do |**|
        handoff_attempted = true
        raise BaseAuthAdmissionCoordinator::Denied.new("unavailable", code: "invalid_admission")
      end
    BaseAuthAdmissionCoordinator.stub(:issue_switch_handoff!, failure) do
      post(auth_app_sign_switch_path(ri: "jp"), params: { to: "sign_up" })
    end

    assert_response :conflict
    assert handoff_attempted
    assert_not_predicate ceremony.reload, :cancelled?
    assert_equal OidcAuthorizationTransactionable::STATUS_PENDING, parent.reload.status_id
    assert_equal sid, cookies[sid_name]
    assert_not_includes response.headers["Set-Cookie"].to_s, "#{sid_name}="

    post(auth_app_sign_switch_path(ri: "jp"), params: { to: "sign_up" })

    assert_response :see_other
    assert_predicate ceremony.reload, :cancelled?
    assert_equal OidcAuthorizationTransactionable::STATUS_PENDING, parent.reload.status_id
  ensure
    if feature
      enabled ? Flipper.enable(feature) : Flipper.disable(feature)
    end
  end

  test "a delivery failure returns 503 while preserving the issued email challenge" do
    feature = FeatureFlags::REGISTRY.fetch(:sign_in_available_app).name
    enabled = Flipper.enabled?(feature)
    Flipper.enable(feature)
    TurnstileVerifierStub.challenge_enabled = true
    TurnstileVerifierStub.challenge_response = { "success" => true }
    host!(ENV.fetch("PUBLIC_AUTH_SERVICE_URL"))
    https!
    client = OidcClientRegistry.find!("core-app-jp")
    transaction = OidcAuthorizationTransactionCoordinator.issue!(
      surface: "app", intent: "sign_in",
      params: {
        response_type: "code",
        client_id: client.client_id,
        redirect_uri: client.redirect_uris_by_realm.fetch("client").first,
        code_challenge: SecureRandom.urlsafe_base64(32),
        code_challenge_method: "S256",
        scope: "openid profile",
        state: SecureRandom.urlsafe_base64(24),
        nonce: SecureRandom.urlsafe_base64(24),
      },
    ).transaction
    issuance = BaseAuthAdmissionCoordinator.issue_handoff!(
      transaction: transaction, base_browser_nonce: SecureRandom.urlsafe_base64(32), base_token: nil,
    )
    get("/sign/in", params: { entry_ref: issuance.reference, ri: "jp" }, headers: NAVIGATION_HEADERS)
    get(response.location, headers: NAVIGATION_HEADERS)
    binding = ClientAuthAdmissionBinding.find_by!(entry_ref: issuance.reference)
    binding.confirm_base!(base_token: nil, browser_digest: binding.base_browser_digest)
    get("/sign/in", params: { entry_ref: issuance.reference, ri: "jp" }, headers: NAVIGATION_HEADERS)

    assert_response :see_other
    sid_name = JitSessionCookieConfig.force_secure? ? "__Host-auth_sid" : "auth_sid"
    ceremony = ClientAuthCeremonySession.find_active_by_raw_sid(cookies[sid_name])
    actor = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
    email = actor.client_emails.create!(
      address: "otp-#{SecureRandom.hex(8)}@example.test", confirm_policy: "1",
      user_email_status_id: ClientEmailStatus::VERIFIED,
    ).tap(&:finalize_binding!)
    issued_code = nil
    failure =
      lambda do |otp_code:, **|
        issued_code = otp_code
        raise ActiveJob::EnqueueError, "queue unavailable"
      end

    Notify::App::OtpNotifier.stub(:issue, failure) do
      post(
        auth_app_sign_in_email_path(ri: "jp"),
        params: { :user_email => { address: email.address }, "cf-turnstile-response" => "test" },
        headers: { "X-Inertia" => "true", "X-Requested-With" => "XMLHttpRequest" },
      )
    end

    assert_response :service_unavailable
    assert_equal "true", response.headers["X-Inertia"]
    page = response.parsed_body

    assert_equal I18n.t("sign.app.authentication.email.edit.delivery_unavailable"),
                 page.fetch("props").fetch("description")
    assert_predicate page.fetch("props").fetch("otp_resend").fetch("state"), :present?
    assert_predicate ceremony.reload.email_otp_context.fetch("generation"), :present?
    assert_nil ceremony.email_otp_context.fetch("cancelled_at")
    assert_nil ceremony.email_otp_context.fetch("verified_at")
    assert_nil cookies[AuthenticationBase::ACCESS_COOKIE_KEY]
    get(edit_auth_app_sign_in_email_path(ri: "jp"))

    assert_response :success
    result = ceremony.verify_email_otp!(code: issued_code)

    assert_predicate result, :success?
    assert_equal email, result.contact
  ensure
    TurnstileVerifierStub.challenge_enabled = false
    TurnstileVerifierStub.challenge_response = nil
    if feature
      enabled ? Flipper.enable(feature) : Flipper.disable(feature)
    end
  end

  test "an admitted sign-in can resend after the sentry and admission checks" do
    feature = FeatureFlags::REGISTRY.fetch(:sign_in_available_app).name
    enabled = Flipper.enabled?(feature)
    Flipper.enable(feature)
    host!(ENV.fetch("PUBLIC_AUTH_SERVICE_URL"))
    https!
    client_id = "core-app-jp"
    client = OidcClientRegistry.find!(client_id)
    transaction = OidcAuthorizationTransactionCoordinator.issue!(
      surface: "app", intent: "sign_in",
      params: {
        response_type: "code",
        client_id: client_id,
        redirect_uri: client.redirect_uris_by_realm.fetch(client.resource_type).first,
        code_challenge: SecureRandom.urlsafe_base64(32),
        code_challenge_method: "S256",
        scope: "openid profile",
        state: SecureRandom.urlsafe_base64(24),
        nonce: SecureRandom.urlsafe_base64(24),
      },
    ).transaction
    issuance = BaseAuthAdmissionCoordinator.issue_handoff!(
      transaction: transaction, base_browser_nonce: SecureRandom.urlsafe_base64(32), base_token: nil,
    )
    get("/sign/in", params: { entry_ref: issuance.reference, ri: "jp" }, headers: NAVIGATION_HEADERS)

    assert_response :see_other
    get(response.location, headers: NAVIGATION_HEADERS)

    assert_response :see_other
    binding = ClientAuthAdmissionBinding.find_by!(entry_ref: issuance.reference)
    binding.confirm_base!(base_token: nil, browser_digest: binding.base_browser_digest)
    get("/sign/in", params: { entry_ref: issuance.reference, ri: "jp" }, headers: NAVIGATION_HEADERS)

    assert_response :see_other
    sid_name = JitSessionCookieConfig.force_secure? ? "__Host-auth_sid" : "auth_sid"
    ceremony = ClientAuthCeremonySession.find_active_by_raw_sid(cookies[sid_name])
    address = "unknown-#{SecureRandom.hex(8)}@example.test"
    candidate_body = OccurrenceHmac.digest(kind: :email, body: address)

    assert_not EmailOccurrence.exists?(body: candidate_body)
    occurrence_body = candidate_body
    ceremony.issue_email_otp!(contact: nil, destination: address)
    previous_generation = ceremony.reload.email_otp_context.fetch("generation")
    state = SignInOtpResendState.issue(
      kind: :email, target: address, surface: :app, browser_binding: ceremony.sid_digest, contact: nil,
    )
    post("/web/v0/in/email/otp", params: { state: state }, as: :json)

    assert_response :ok
    assert response.parsed_body.fetch("resendable")
    assert_not_equal previous_generation, ceremony.reload.email_otp_context.fetch("generation")

    blocked_generation = ceremony.email_otp_context.fetch("generation")
    blocked_occurrences = EmailOccurrence.count
    Flipper.disable(feature)
    post("/web/v0/in/email/otp", params: { state: state }, as: :json)

    assert_response :service_unavailable
    assert_equal blocked_generation, ceremony.reload.email_otp_context.fetch("generation")
    assert_equal blocked_occurrences, EmailOccurrence.count
    assert_not_includes response.headers["Set-Cookie"].to_s, "auth_sid="
  ensure
    EmailOccurrence.where(body: occurrence_body).delete_all if occurrence_body
    if transaction
      ClientAuthAdmissionBinding.where(authorization_transaction_id: transaction.id).delete_all
      ceremony&.delete
      transaction.delete
    end
    if feature
      enabled ? Flipper.enable(feature) : Flipper.disable(feature)
    end
  end

  test "a delivery failure leaves a usable resend handle for the same admitted ceremony" do
    feature = FeatureFlags::REGISTRY.fetch(:sign_in_available_app).name
    enabled = Flipper.enabled?(feature)
    Flipper.enable(feature)
    TurnstileVerifierStub.challenge_enabled = true
    TurnstileVerifierStub.challenge_response = { "success" => true }
    host!(ENV.fetch("PUBLIC_AUTH_SERVICE_URL"))
    https!
    client = OidcClientRegistry.find!("core-app-jp")
    parent = OidcAuthorizationTransactionCoordinator.issue!(
      surface: "app", intent: "sign_in",
      params: {
        response_type: "code",
        client_id: client.client_id,
        redirect_uri: client.redirect_uris_by_realm.fetch("client").first,
        code_challenge: SecureRandom.urlsafe_base64(32),
        code_challenge_method: "S256",
        scope: "openid profile",
        state: SecureRandom.urlsafe_base64(24),
        nonce: SecureRandom.urlsafe_base64(24),
      },
    ).transaction
    issuance = BaseAuthAdmissionCoordinator.issue_handoff!(
      transaction: parent, base_browser_nonce: SecureRandom.urlsafe_base64(32), base_token: nil,
    )
    get("/sign/in", params: { entry_ref: issuance.reference, ri: "jp" }, headers: NAVIGATION_HEADERS)
    get(response.location, headers: NAVIGATION_HEADERS)
    binding = ClientAuthAdmissionBinding.find_by!(entry_ref: issuance.reference)
    binding.confirm_base!(base_token: nil, browser_digest: binding.base_browser_digest)
    get("/sign/in", params: { entry_ref: issuance.reference, ri: "jp" }, headers: NAVIGATION_HEADERS)
    sid_name = JitSessionCookieConfig.force_secure? ? "__Host-auth_sid" : "auth_sid"
    ceremony = ClientAuthCeremonySession.find_active_by_raw_sid(cookies[sid_name])
    actor = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
    email = actor.client_emails.create!(
      address: "otp-#{SecureRandom.hex(8)}@example.test", confirm_policy: "1",
      user_email_status_id: ClientEmailStatus::VERIFIED,
    ).tap(&:finalize_binding!)
    candidate_body = OccurrenceHmac.digest(kind: :email, body: email.address)

    assert_not EmailOccurrence.exists?(body: candidate_body)
    occurrence_body = candidate_body
    original_code = nil
    failure =
      lambda do |otp_code:, **|
        original_code = otp_code
        raise ActiveJob::EnqueueError, "queue unavailable"
      end

    Notify::App::OtpNotifier.stub(:issue, failure) do
      post(
        auth_app_sign_in_email_path(ri: "jp"),
        params: { :user_email => { address: email.address }, "cf-turnstile-response" => "test" },
        headers: { "X-Inertia" => "true", "X-Requested-With" => "XMLHttpRequest" },
      )
    end

    assert_response :service_unavailable
    resend_state = response.parsed_body.fetch("props").fetch("otp_resend").fetch("state")
    previous_generation = ceremony.reload.email_otp_context.fetch("generation")
    delivered_code = nil
    accepted = ->(otp_code:, **) { delivered_code = otp_code }
    next_number = (original_code == "000001") ? 2 : 1
    random_number = ->(limit) { [next_number, limit - 1].min }
    SecureRandom.stub(:random_number, random_number) do
      Notify::App::OtpNotifier.stub(:issue, accepted) do
        post("/web/v0/in/email/otp", params: { state: resend_state }, as: :json)
      end
    end

    assert_response :ok
    assert response.parsed_body.fetch("resendable")
    assert_not_equal previous_generation, ceremony.reload.email_otp_context.fetch("generation")
    assert_not_equal original_code, delivered_code
    assert_not ceremony.verify_email_otp!(code: original_code).success?
    assert_predicate ceremony.verify_email_otp!(code: delivered_code), :success?
  ensure
    EmailOccurrence.where(body: occurrence_body).delete_all if occurrence_body
    if parent
      ClientAuthAdmissionBinding.where(authorization_transaction_id: parent.id).delete_all
      ceremony&.delete
      parent.delete
    end
    email&.delete
    actor&.delete
    TurnstileVerifierStub.challenge_enabled = false
    TurnstileVerifierStub.challenge_response = nil
    if feature
      enabled ? Flipper.enable(feature) : Flipper.disable(feature)
    end
  end

  test "Cancel after delivery failure ends only the email challenge and leaves the parent pending" do
    feature = FeatureFlags::REGISTRY.fetch(:sign_in_available_app).name
    enabled = Flipper.enabled?(feature)
    Flipper.enable(feature)
    TurnstileVerifierStub.challenge_enabled = true
    TurnstileVerifierStub.challenge_response = { "success" => true }
    host!(ENV.fetch("PUBLIC_AUTH_SERVICE_URL"))
    https!
    client = OidcClientRegistry.find!("core-app-jp")
    parent = OidcAuthorizationTransactionCoordinator.issue!(
      surface: "app", intent: "sign_in",
      params: {
        response_type: "code",
        client_id: client.client_id,
        redirect_uri: client.redirect_uris_by_realm.fetch("client").first,
        code_challenge: SecureRandom.urlsafe_base64(32),
        code_challenge_method: "S256",
        scope: "openid profile",
        state: SecureRandom.urlsafe_base64(24),
        nonce: SecureRandom.urlsafe_base64(24),
      },
    ).transaction
    issuance = BaseAuthAdmissionCoordinator.issue_handoff!(
      transaction: parent, base_browser_nonce: SecureRandom.urlsafe_base64(32), base_token: nil,
    )
    get("/sign/in", params: { entry_ref: issuance.reference, ri: "jp" }, headers: NAVIGATION_HEADERS)
    get(response.location, headers: NAVIGATION_HEADERS)
    binding = ClientAuthAdmissionBinding.find_by!(entry_ref: issuance.reference)
    binding.confirm_base!(base_token: nil, browser_digest: binding.base_browser_digest)
    get("/sign/in", params: { entry_ref: issuance.reference, ri: "jp" }, headers: NAVIGATION_HEADERS)
    sid_name = JitSessionCookieConfig.force_secure? ? "__Host-auth_sid" : "auth_sid"
    ceremony = ClientAuthCeremonySession.find_active_by_raw_sid(cookies[sid_name])
    actor = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
    email = actor.client_emails.create!(
      address: "otp-#{SecureRandom.hex(8)}@example.test", confirm_policy: "1",
      user_email_status_id: ClientEmailStatus::VERIFIED,
    ).tap(&:finalize_binding!)
    code = nil
    failure =
      lambda do |otp_code:, **|
        code = otp_code
        raise ActiveJob::EnqueueError, "queue unavailable"
      end

    Notify::App::OtpNotifier.stub(:issue, failure) do
      post(
        auth_app_sign_in_email_path(ri: "jp"),
        params: { :user_email => { address: email.address }, "cf-turnstile-response" => "test" },
        headers: { "X-Inertia" => "true", "X-Requested-With" => "XMLHttpRequest" },
      )
    end

    assert_response :service_unavailable
    assert_equal I18n.t("actions.cancel"), response.parsed_body.fetch("props").fetch("cancel_button").fetch("label")
    cancel_button_props = response.parsed_body.fetch("props").fetch("cancel_button")

    assert_equal "/sign/cancellation?ri=jp", cancel_button_props.fetch("parent_action")
    delete(auth_app_sign_in_email_path(ri: "jp"))

    assert_response :see_other
    assert_predicate ceremony.reload.email_otp_context.fetch("cancelled_at"), :present?
    assert_not ceremony.verify_email_otp!(code: code).success?
    assert_equal OidcAuthorizationTransactionable::STATUS_PENDING, parent.reload.status_id
    assert_nil cookies[AuthenticationBase::ACCESS_COOKIE_KEY]
    sid = cookies[sid_name]
    post(auth_app_sign_switch_path(ri: "jp"), params: { to: "sign_up" })

    assert_response :conflict
    assert_equal sid, cookies[sid_name]
    assert_not_includes response.headers["Set-Cookie"].to_s, "#{sid_name}="
    assert_equal OidcAuthorizationTransactionable::STATUS_PENDING, parent.reload.status_id
    assert_not_predicate ceremony.reload, :cancelled?
  ensure
    TurnstileVerifierStub.challenge_enabled = false
    TurnstileVerifierStub.challenge_response = nil
    if feature
      enabled ? Flipper.enable(feature) : Flipper.disable(feature)
    end
  end
end
