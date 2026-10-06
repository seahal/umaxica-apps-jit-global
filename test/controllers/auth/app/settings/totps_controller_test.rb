# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"
require "minitest/mock"

class Auth::App::Settings::TotpsControllerTest < ActionDispatch::IntegrationTest
  fixtures :clients,
           :client_statuses,
           :client_token_statuses,
           :client_token_kinds,
           :client_totp_credential_statuses,
           :app_preference_chronicle_levels,
           :client_chronicle_events,
           :client_chronicle_levels

  setup do
    host! ENV.fetch("PUBLIC_AUTH_SERVICE_URL", "auth.app.localhost")
    @user = clients(:one)
    # Clear existing TOTPs to avoid limit error
    @user.client_totp_credentials.destroy_all
    ClientEmail.create!(
      user: @user,
      address: "totp-config-test@example.com",
      user_email_status_id: ClientEmailStatus::VERIFIED,
    )

    @token = ClientToken.create!(user_id: @user.id, root_login_established_at: Time.current)
    @token.rotate_refresh_token!
    access_token = AuthenticationToken.encode(
      @user,
      host: ENV.fetch("PUBLIC_AUTH_SERVICE_URL", "auth.app.localhost"),
      session_public_id: @token.public_id,
      jwt_issuer_id: jwt_issuer_id_for_test_host(ENV.fetch("PUBLIC_AUTH_SERVICE_URL", "auth.app.localhost"), "client"),
    )
    @headers = {
      "Host" => ENV.fetch("PUBLIC_AUTH_SERVICE_URL", "auth.app.localhost"),
      "Authorization" => "Bearer #{access_token}",
      "X-TEST-SESSION-PUBLIC-ID" => @token.public_id,
    }.freeze
    @token.update!(last_step_up_at: 5.minutes.ago, last_step_up_scope: "settings_totp")
    cookies["csrf_token"] = "test_csrf_token"
    cookies[AuthenticationBase::ACCESS_COOKIE_KEY] = access_token
    satisfy_user_verification(@token)
    @headers.freeze

    @totp = ClientTotpCredential.create!(
      user: @user,
      private_key: ROTP::Base32.random_base32,
      last_otp_at: Time.zone.at(0),
      title: "Main TOTP",
      user_totp_credential_status_id: ClientTotpCredentialStatus::ACTIVE,
    )

    TurnstileVerifierStub.challenge_enabled = true
    TurnstileVerifierStub.challenge_response = { "success" => true }
  end

  teardown do
    TurnstileVerifierStub.challenge_enabled = false
    TurnstileVerifierStub.challenge_response = nil
    TurnstileVerifierStub.enabled = false
    TurnstileVerifierStub.response = nil
  end

  def with_prosopite_paused
    Prosopite.pause { yield }
  end

  def headers_for_client_token(token, scope:, step_up_at: Time.current)
    Actor.clear if defined?(Actor)
    mark_settings_step_up_satisfied!(token, scope: scope, at: step_up_at)
    access_token = AuthenticationToken.encode(
      token.user,
      host: ENV.fetch("PUBLIC_AUTH_SERVICE_URL", "auth.app.localhost"),
      session_public_id: token.public_id,
      resource_type: "client",
      jwt_issuer_id: jwt_issuer_id_for_test_host(ENV.fetch("PUBLIC_AUTH_SERVICE_URL", "auth.app.localhost"), "client"),
    )
    cookies[AuthenticationBase::ACCESS_COOKIE_KEY] = access_token
    @headers.merge(
      "Authorization" => "Bearer #{access_token}",
      "X-TEST-SESSION-PUBLIC-ID" => token.public_id,
    )
  end

  def mark_settings_step_up_satisfied!(token, scope:, at:)
    token.update_columns(
      last_step_up_at: at,
      last_step_up_scope: scope,
      last_step_up_aal: "aal2",
      last_step_up_method: "passkey",
      last_step_up_session_public_id: token.public_id,
      last_step_up_purpose: "step_up",
      last_step_up_audience: "step_up:app",
      updated_at: Time.current,
    )
  end

  test "retired TOTP management paths have no route or redirect" do
    %w(
      /settings/totps
      /settings/totps/1
      /settings/totps/1/edit
    ).each do |path|
      get path

      assert_response :not_found, path
      assert_nil response.headers["Location"], path
    end
  end

  # ===================================================================
  # Enrollment lifecycle: GET new only displays; POST /settings/totps/enrollment starts an enrollment
  # with a fresh secret; DELETE ends it; a successful first code consumes it.
  # ===================================================================

  # Explicit identities isolate these admissions from retained rows in the copied fixture database.
  test "admitted GET new starts no candidate and preserves the deadline" do
    reset!
    host! ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    actor = Client.create!(id: 9_104_000_000_000, status_id: ClientStatus::ACTIVE)

    assert_equal 0, actor.client_passkeys.count
    assert_equal 0, actor.client_totp_credentials.count
    assert_equal 0, actor.client_emails.count
    token = ClientToken.create!(user: actor, root_login_established_at: Time.current)
    requirement = StepUpRequirement.new(
      scope: "settings_birthdate", purpose: "bootstrap", step_up_required: false,
      phishing_resistant_required: false, user_verification_required: false,
      full_reauthentication_required: false, ttl: 15.minutes,
      allowed_methods: [:totp], audience: "step_up:app", session_binding: token.public_id,
      token_binding: token.public_id, require_session_binding: true, actor_ref: actor.public_id,
      resource_ref: nil, tenant_ref: nil,
    )
    issuance = issue_confirmed_base_step_up_admission!(
      actor: actor, token: token, requirement: requirement, return_to: "/identity/birthdate",
    )
    get new_auth_app_verification_setup_path(ri: "jp", entry_ref: issuance.reference)
    csrf = response.parsed_body.at_css('input[name="authenticity_token"]')["value"]
    post auth_app_verification_setup_path(ri: "jp"), params: { entry_ref: issuance.reference, authenticity_token: csrf }

    assert_response :see_other
    assert_nil cookies[AuthenticationBase::ACCESS_COOKIE_KEY]
    get new_auth_app_settings_totp_path(ri: "jp")
    deadline = issuance.transaction.expires_at
    record = ClientStepUpSession.find_by!(step_up_ceremony_transaction_ref: issuance.transaction.transaction_id)
    record.update!(attempt_count: 2)
    assert_no_difference("IdentityTotpCeremonyCandidate.count") do
      2.times do
        get new_auth_app_settings_totp_path(ri: "jp")

        assert_response :success
        page = JSON.parse(response.parsed_body.at_css("script[data-page='app']").text).fetch("props")

        assert_nil page.fetch("qr_code_image")
        assert_equal auth_app_settings_totps_enrollment_path(ri: "jp"), page.fetch("start").fetch("action")
      end
    end
    assert_nil session[:private_key]
    assert_nil session[:totp_enrollment]
    assert_equal deadline, issuance.transaction.reload.expires_at
    assert_equal 2, record.reload.attempt_count
  end

  test "the cancel link of the old flow no longer leaves a reusable secret behind" do
    with_prosopite_paused do
      get new_auth_app_settings_totp_url(ri: "jp"), headers: @headers
      get auth_app_settings_totps_url(ri: "jp"), headers: @headers
    end

    assert_nil session[:private_key]
    assert_nil session[:totp_enrollment]
  end

  test "admitted enrollment POST and redisplay retain the same encrypted candidate" do
    reset!
    host! ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    actor = Client.create!(id: 9_104_000_000_001, status_id: ClientStatus::ACTIVE)

    assert_equal 0, actor.client_passkeys.count
    assert_equal 0, actor.client_totp_credentials.count
    assert_equal 0, actor.client_emails.count
    token = ClientToken.create!(user: actor, root_login_established_at: Time.current)
    requirement = StepUpRequirement.new(
      scope: "settings_birthdate", purpose: "bootstrap", step_up_required: false,
      phishing_resistant_required: false, user_verification_required: false,
      full_reauthentication_required: false, ttl: 15.minutes,
      allowed_methods: [:totp], audience: "step_up:app", session_binding: token.public_id,
      token_binding: token.public_id, require_session_binding: true, actor_ref: actor.public_id,
      resource_ref: nil, tenant_ref: nil,
    )
    issuance = issue_confirmed_base_step_up_admission!(
      actor: actor, token: token, requirement: requirement, return_to: "/identity/birthdate",
    )
    get new_auth_app_verification_setup_path(ri: "jp", entry_ref: issuance.reference)
    csrf = response.parsed_body.at_css('input[name="authenticity_token"]')["value"]
    post auth_app_verification_setup_path(ri: "jp"), params: { entry_ref: issuance.reference, authenticity_token: csrf }

    assert_response :see_other
    assert_nil cookies[AuthenticationBase::ACCESS_COOKIE_KEY]
    get new_auth_app_settings_totp_path(ri: "jp")
    props = JSON.parse(response.parsed_body.at_css("script[data-page='app']").text).fetch("props")
    post props.fetch("start").fetch("action"), params: { authenticity_token: csrf }

    assert_redirected_to new_auth_app_settings_totp_path(ri: "jp")
    follow_redirect!
    props = JSON.parse(response.parsed_body.at_css("script[data-page='app']").text).fetch("props")
    candidate = IdentityTotpCeremonyCandidate.find_by!(ref: props.fetch("form").fetch("enrollment_id"))
    initial_image_digest = Digest::SHA256.hexdigest(props.fetch("qr_code_image"))
    initial_deadline = candidate.expires_at
    initial_ref = candidate.ref
    parent_deadline = issuance.transaction.expires_at
    2.times do
      assert_no_difference("IdentityTotpCeremonyCandidate.count") do
        post auth_app_settings_totps_enrollment_path(ri: "jp"), params: { authenticity_token: csrf }
        follow_redirect!
      end
      page = JSON.parse(response.parsed_body.at_css("script[data-page='app']").text).fetch("props")

      assert_equal initial_image_digest, Digest::SHA256.hexdigest(page.fetch("qr_code_image"))
      assert_equal initial_ref, page.fetch("form").fetch("enrollment_id")
      assert_equal initial_deadline, candidate.reload.expires_at
      assert_equal parent_deadline, issuance.transaction.reload.expires_at
    end
    assert_nil session[:private_key]
    assert_nil session[:totp_enrollment]
    assert_nil token.reload.last_step_up_at
  end

  test "canceling admission requires a new Base permission and a new candidate" do
    reset!
    host! ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    actor = Client.create!(id: 9_104_000_000_002, status_id: ClientStatus::ACTIVE)

    assert_equal 0, actor.client_passkeys.count
    assert_equal 0, actor.client_totp_credentials.count
    assert_equal 0, actor.client_emails.count
    token = ClientToken.create!(user: actor, root_login_established_at: Time.current)
    requirement = StepUpRequirement.new(
      scope: "settings_birthdate", purpose: "bootstrap", step_up_required: false,
      phishing_resistant_required: false, user_verification_required: false,
      full_reauthentication_required: false, ttl: 15.minutes,
      allowed_methods: [:totp], audience: "step_up:app", session_binding: token.public_id,
      token_binding: token.public_id, require_session_binding: true, actor_ref: actor.public_id,
      resource_ref: nil, tenant_ref: nil,
    )
    issuance = issue_confirmed_base_step_up_admission!(
      actor: actor, token: token, requirement: requirement, return_to: "/identity/birthdate",
    )
    get new_auth_app_verification_setup_path(ri: "jp", entry_ref: issuance.reference)
    csrf = response.parsed_body.at_css('input[name="authenticity_token"]')["value"]
    post auth_app_verification_setup_path(ri: "jp"), params: { entry_ref: issuance.reference, authenticity_token: csrf }

    assert_response :see_other
    assert_nil cookies[AuthenticationBase::ACCESS_COOKIE_KEY]
    get new_auth_app_settings_totp_path(ri: "jp")
    props = JSON.parse(response.parsed_body.at_css("script[data-page='app']").text).fetch("props")
    post props.fetch("start").fetch("action"), params: { authenticity_token: csrf }

    assert_redirected_to new_auth_app_settings_totp_path(ri: "jp")
    follow_redirect!
    props = JSON.parse(response.parsed_body.at_css("script[data-page='app']").text).fetch("props")
    candidate = IdentityTotpCeremonyCandidate.find_by!(ref: props.fetch("form").fetch("enrollment_id"))
    first_ref = candidate.ref
    first_secret_digest = Digest::SHA256.hexdigest(candidate.private_key)
    delete auth_app_settings_totps_enrollment_path(ri: "jp"), params: { authenticity_token: csrf }

    assert_response :see_other
    gateway = URI.parse(response.location)
    redirect_payload, = JWT.decode(Rack::Utils.parse_nested_query(gateway.query).fetch("rt"), nil, false)

    assert_equal base_app_dashboard_url(host: ENV.fetch("PUBLIC_BASE_SERVICE_URL"), protocol: "https", ri: "jp"),
                 redirect_payload.fetch("url")
    assert_equal "canceled", issuance.transaction.reload.status
    assert_nil session[:totp_enrollment]
    assert_nil session[:private_key]
    assert_nil token.reload.last_step_up_at
    assert_no_difference("IdentityTotpCeremonyCandidate.count") do
      post auth_app_settings_totps_enrollment_path(ri: "jp"), params: { authenticity_token: csrf }

      assert_response :bad_request
    end
    replacement = issue_confirmed_base_step_up_admission!(
      actor: actor, token: token, requirement: requirement, return_to: "/identity/birthdate",
    )
    get new_auth_app_verification_setup_path(ri: "jp", entry_ref: replacement.reference)
    csrf = response.parsed_body.at_css('input[name="authenticity_token"]')["value"]
    post auth_app_verification_setup_path(ri: "jp"),
         params: { entry_ref: replacement.reference, authenticity_token: csrf }
    get new_auth_app_settings_totp_path(ri: "jp")
    props = JSON.parse(response.parsed_body.at_css("script[data-page='app']").text).fetch("props")
    post props.fetch("start").fetch("action"), params: { authenticity_token: csrf }
    follow_redirect!
    props = JSON.parse(response.parsed_body.at_css("script[data-page='app']").text).fetch("props")
    next_candidate = IdentityTotpCeremonyCandidate.find_by!(ref: props.fetch("form").fetch("enrollment_id"))

    assert_not_equal issuance.transaction.transaction_id, replacement.transaction.transaction_id
    assert_not_equal first_ref, next_candidate.ref
    assert_not_equal first_secret_digest, Digest::SHA256.hexdigest(next_candidate.private_key)
    assert_nil cookies[AuthenticationBase::ACCESS_COOKIE_KEY]
    assert_nil token.reload.last_step_up_at
  end

  test "a canceled candidate cannot confirm a replacement Base permission" do
    reset!
    host! ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    actor = Client.create!(id: 9_104_000_000_003, status_id: ClientStatus::ACTIVE)

    assert_equal 0, actor.client_passkeys.count
    assert_equal 0, actor.client_totp_credentials.count
    assert_equal 0, actor.client_emails.count
    token = ClientToken.create!(user: actor, root_login_established_at: Time.current)
    requirement = StepUpRequirement.new(
      scope: "settings_birthdate", purpose: "bootstrap", step_up_required: false,
      phishing_resistant_required: false, user_verification_required: false,
      full_reauthentication_required: false, ttl: 15.minutes,
      allowed_methods: [:totp], audience: "step_up:app", session_binding: token.public_id,
      token_binding: token.public_id, require_session_binding: true, actor_ref: actor.public_id,
      resource_ref: nil, tenant_ref: nil,
    )
    issuance = issue_confirmed_base_step_up_admission!(
      actor: actor, token: token, requirement: requirement, return_to: "/identity/birthdate",
    )
    get new_auth_app_verification_setup_path(ri: "jp", entry_ref: issuance.reference)
    csrf = response.parsed_body.at_css('input[name="authenticity_token"]')["value"]
    post auth_app_verification_setup_path(ri: "jp"), params: { entry_ref: issuance.reference, authenticity_token: csrf }

    assert_response :see_other
    assert_nil cookies[AuthenticationBase::ACCESS_COOKIE_KEY]
    get new_auth_app_settings_totp_path(ri: "jp")
    props = JSON.parse(response.parsed_body.at_css("script[data-page='app']").text).fetch("props")
    post props.fetch("start").fetch("action"), params: { authenticity_token: csrf }

    assert_redirected_to new_auth_app_settings_totp_path(ri: "jp")
    follow_redirect!
    props = JSON.parse(response.parsed_body.at_css("script[data-page='app']").text).fetch("props")
    candidate = IdentityTotpCeremonyCandidate.find_by!(ref: props.fetch("form").fetch("enrollment_id"))
    stale_ref = candidate.ref
    stale_code = ROTP::TOTP.new(candidate.private_key).now
    delete auth_app_settings_totps_enrollment_path(ri: "jp"), params: { authenticity_token: csrf }

    assert_response :see_other
    gateway = URI.parse(response.location)
    redirect_payload, = JWT.decode(Rack::Utils.parse_nested_query(gateway.query).fetch("rt"), nil, false)

    assert_equal base_app_dashboard_url(host: ENV.fetch("PUBLIC_BASE_SERVICE_URL"), protocol: "https", ri: "jp"),
                 redirect_payload.fetch("url")
    assert_equal "canceled", issuance.transaction.reload.status
    assert_nil session[:totp_enrollment]
    assert_nil session[:private_key]
    assert_nil token.reload.last_step_up_at
    replacement = issue_confirmed_base_step_up_admission!(
      actor: actor, token: token, requirement: requirement, return_to: "/identity/birthdate",
    )
    get new_auth_app_verification_setup_path(ri: "jp", entry_ref: replacement.reference)
    csrf = response.parsed_body.at_css('input[name="authenticity_token"]')["value"]
    post auth_app_verification_setup_path(ri: "jp"),
         params: { entry_ref: replacement.reference, authenticity_token: csrf }
    get new_auth_app_settings_totp_path(ri: "jp")
    props = JSON.parse(response.parsed_body.at_css("script[data-page='app']").text).fetch("props")
    post props.fetch("start").fetch("action"), params: { authenticity_token: csrf }
    follow_redirect!
    props = JSON.parse(response.parsed_body.at_css("script[data-page='app']").text).fetch("props")
    current_ref = props.fetch("form").fetch("enrollment_id")
    assert_no_difference("ClientTotpCredential.count") do
      post auth_app_settings_totps_path(ri: "jp"), params: {
        authenticity_token: csrf, user_totp_credential: { enrollment_id: stale_ref, first_token: stale_code },
      }
    end

    assert_response :conflict
    assert_equal "pending", replacement.transaction.reload.status
    assert_nil IdentityTotpCeremonyCandidate.find_by!(ref: current_ref).consumed_at
    assert_nil token.reload.last_step_up_at
  end

  test "cancelled admission refuses confirmation and retains no Auth root credentials" do
    reset!
    host! ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    actor = Client.create!(id: 9_104_000_000_004, status_id: ClientStatus::ACTIVE)

    assert_equal 0, actor.client_passkeys.count
    assert_equal 0, actor.client_totp_credentials.count
    assert_equal 0, actor.client_emails.count
    token = ClientToken.create!(user: actor, root_login_established_at: Time.current)
    requirement = StepUpRequirement.new(
      scope: "settings_birthdate", purpose: "bootstrap", step_up_required: false,
      phishing_resistant_required: false, user_verification_required: false,
      full_reauthentication_required: false, ttl: 15.minutes,
      allowed_methods: [:totp], audience: "step_up:app", session_binding: token.public_id,
      token_binding: token.public_id, require_session_binding: true, actor_ref: actor.public_id,
      resource_ref: nil, tenant_ref: nil,
    )
    issuance = issue_confirmed_base_step_up_admission!(
      actor: actor, token: token, requirement: requirement, return_to: "/identity/birthdate",
    )
    get new_auth_app_verification_setup_path(ri: "jp", entry_ref: issuance.reference)
    csrf = response.parsed_body.at_css('input[name="authenticity_token"]')["value"]
    post auth_app_verification_setup_path(ri: "jp"), params: { entry_ref: issuance.reference, authenticity_token: csrf }

    assert_response :see_other
    assert_nil cookies[AuthenticationBase::ACCESS_COOKIE_KEY]
    get new_auth_app_settings_totp_path(ri: "jp")
    props = JSON.parse(response.parsed_body.at_css("script[data-page='app']").text).fetch("props")
    post props.fetch("start").fetch("action"), params: { authenticity_token: csrf }

    assert_redirected_to new_auth_app_settings_totp_path(ri: "jp")
    follow_redirect!
    props = JSON.parse(response.parsed_body.at_css("script[data-page='app']").text).fetch("props")
    candidate = IdentityTotpCeremonyCandidate.find_by!(ref: props.fetch("form").fetch("enrollment_id"))
    code = ROTP::TOTP.new(candidate.private_key).now
    candidate_ref = candidate.ref
    delete auth_app_settings_totps_enrollment_path(ri: "jp"), params: { authenticity_token: csrf }

    assert_response :see_other
    gateway = URI.parse(response.location)
    redirect_payload, = JWT.decode(Rack::Utils.parse_nested_query(gateway.query).fetch("rt"), nil, false)

    assert_equal base_app_dashboard_url(host: ENV.fetch("PUBLIC_BASE_SERVICE_URL"), protocol: "https", ri: "jp"),
                 redirect_payload.fetch("url")
    assert_equal "canceled", issuance.transaction.reload.status
    assert_nil session[:totp_enrollment]
    assert_nil session[:private_key]
    assert_nil token.reload.last_step_up_at
    assert_no_difference("ClientTotpCredential.count") do
      post auth_app_settings_totps_path(ri: "jp"), params: {
        authenticity_token: csrf, user_totp_credential: { enrollment_id: candidate_ref, first_token: code },
      }
    end

    assert_response :bad_request
    assert_equal "canceled", issuance.transaction.reload.status
    assert_nil candidate.reload.consumed_at
    assert_nil cookies[AuthenticationBase::ACCESS_COOKIE_KEY]
  end

  test "enrollment endpoints are not reachable by GET" do
    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path(
        "http://#{ENV.fetch("PUBLIC_AUTH_SERVICE_URL", "auth.app.localhost")}/settings/totps/enrollment",
        method: :get,
      )
    end
  end

  test "com and org hosts do not serve a TOTP enrollment" do
    %w(PUBLIC_AUTH_CORPORATE_URL PUBLIC_AUTH_STAFF_URL).each do |key|
      host = ENV.fetch(key)

      assert_raises(ActionController::RoutingError) do
        Rails.application.routes.recognize_path("http://#{host}/settings/totps/enrollment", method: :post)
      end
    end
  end

  test "admitted TOTP page uses scoped actions and no store QR presentation" do
    reset!
    host! ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    actor = Client.create!(id: 9_104_000_000_005, status_id: ClientStatus::ACTIVE)

    assert_equal 0, actor.client_passkeys.count
    assert_equal 0, actor.client_totp_credentials.count
    assert_equal 0, actor.client_emails.count
    token = ClientToken.create!(user: actor, root_login_established_at: Time.current)
    requirement = StepUpRequirement.new(
      scope: "settings_birthdate", purpose: "bootstrap", step_up_required: false,
      phishing_resistant_required: false, user_verification_required: false,
      full_reauthentication_required: false, ttl: 15.minutes,
      allowed_methods: [:totp], audience: "step_up:app", session_binding: token.public_id,
      token_binding: token.public_id, require_session_binding: true, actor_ref: actor.public_id,
      resource_ref: nil, tenant_ref: nil,
    )
    issuance = issue_confirmed_base_step_up_admission!(
      actor: actor, token: token, requirement: requirement, return_to: "/identity/birthdate",
    )
    get new_auth_app_verification_setup_path(ri: "jp", entry_ref: issuance.reference)
    csrf = response.parsed_body.at_css('input[name="authenticity_token"]')["value"]
    post auth_app_verification_setup_path(ri: "jp"), params: { entry_ref: issuance.reference, authenticity_token: csrf }

    assert_response :see_other
    assert_nil cookies[AuthenticationBase::ACCESS_COOKIE_KEY]
    get new_auth_app_settings_totp_path(ri: "jp")
    props = JSON.parse(response.parsed_body.at_css("script[data-page='app']").text).fetch("props")
    post props.fetch("start").fetch("action"), params: { authenticity_token: csrf }

    assert_redirected_to new_auth_app_settings_totp_path(ri: "jp")
    follow_redirect!
    props = JSON.parse(response.parsed_body.at_css("script[data-page='app']").text).fetch("props")
    IdentityTotpCeremonyCandidate.find_by!(ref: props.fetch("form").fetch("enrollment_id"))

    assert_response :success
    assert_equal "text/html", response.media_type
    assert_equal new_auth_app_verification_setup_path(ri: "jp"), props.fetch("back_link").fetch("href")
    assert_equal auth_app_settings_totps_path(ri: "jp"), props.fetch("form").fetch("action")
    assert_equal "user_totp_credential", props.fetch("form").fetch("scope")
    assert_equal I18n.t("views.sign.app.settings.totps.new.first_token_delivery_help"),
                 props.fetch("form").fetch("first_token_delivery_help")
    assert props.fetch("qr_code_image").start_with?("data:image/png;base64,")
    assert_includes response.headers.fetch("Cache-Control"), "no-store"
    assert_nil cookies[AuthenticationBase::ACCESS_COOKIE_KEY]
  end

  test "admitted GET displays the two slot limit after a competing registration" do
    reset!
    host! ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    actor = Client.create!(id: 9_104_000_000_006, status_id: ClientStatus::ACTIVE)

    assert_equal 0, actor.client_passkeys.count
    assert_equal 0, actor.client_totp_credentials.count
    assert_equal 0, actor.client_emails.count
    token = ClientToken.create!(user: actor, root_login_established_at: Time.current)
    requirement = StepUpRequirement.new(
      scope: "settings_birthdate", purpose: "bootstrap", step_up_required: false,
      phishing_resistant_required: false, user_verification_required: false,
      full_reauthentication_required: false, ttl: 15.minutes,
      allowed_methods: [:totp], audience: "step_up:app", session_binding: token.public_id,
      token_binding: token.public_id, require_session_binding: true, actor_ref: actor.public_id,
      resource_ref: nil, tenant_ref: nil,
    )
    issuance = issue_confirmed_base_step_up_admission!(
      actor: actor, token: token, requirement: requirement, return_to: "/identity/birthdate",
    )
    get new_auth_app_verification_setup_path(ri: "jp", entry_ref: issuance.reference)
    csrf = response.parsed_body.at_css('input[name="authenticity_token"]')["value"]
    post auth_app_verification_setup_path(ri: "jp"), params: { entry_ref: issuance.reference, authenticity_token: csrf }

    assert_response :see_other
    assert_nil cookies[AuthenticationBase::ACCESS_COOKIE_KEY]
    get new_auth_app_settings_totp_path(ri: "jp")
    JSON.parse(response.parsed_body.at_css("script[data-page='app']").text).fetch("props")
    ClientTotpCredential.create_for_user!(user: actor, user_identity_totp_credential_status_id: ClientTotpCredentialStatus::ACTIVE)
    get new_auth_app_settings_totp_path(ri: "jp")

    assert_response :success
    ClientTotpCredential.create_for_user!(user: actor, user_identity_totp_credential_status_id: ClientTotpCredentialStatus::ACTIVE)
    assert_raises(ClientTotpCredential::SlotLimitExceeded) do
      ClientTotpCredential.create_for_user!(user: actor, user_identity_totp_credential_status_id: ClientTotpCredentialStatus::ACTIVE)
    end
    assert_no_difference("IdentityTotpCeremonyCandidate.count") do
      get new_auth_app_settings_totp_path(ri: "jp")

      assert_response :success
      assert_equal I18n.t("session_limit.totp_limit_reached", count: 2), response.body
    end
    assert_equal 2, actor.client_totp_credentials.slot_consuming.count
    assert_equal "pending", issuance.transaction.reload.status
  end

  test "admitted enrollment POST refuses the two slot limit after a competing registration" do
    reset!
    host! ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    actor = Client.create!(id: 9_104_000_000_007, status_id: ClientStatus::ACTIVE)

    assert_equal 0, actor.client_passkeys.count
    assert_equal 0, actor.client_totp_credentials.count
    assert_equal 0, actor.client_emails.count
    token = ClientToken.create!(user: actor, root_login_established_at: Time.current)
    requirement = StepUpRequirement.new(
      scope: "settings_birthdate", purpose: "bootstrap", step_up_required: false,
      phishing_resistant_required: false, user_verification_required: false,
      full_reauthentication_required: false, ttl: 15.minutes,
      allowed_methods: [:totp], audience: "step_up:app", session_binding: token.public_id,
      token_binding: token.public_id, require_session_binding: true, actor_ref: actor.public_id,
      resource_ref: nil, tenant_ref: nil,
    )
    issuance = issue_confirmed_base_step_up_admission!(
      actor: actor, token: token, requirement: requirement, return_to: "/identity/birthdate",
    )
    get new_auth_app_verification_setup_path(ri: "jp", entry_ref: issuance.reference)
    csrf = response.parsed_body.at_css('input[name="authenticity_token"]')["value"]
    post auth_app_verification_setup_path(ri: "jp"), params: { entry_ref: issuance.reference, authenticity_token: csrf }

    assert_response :see_other
    assert_nil cookies[AuthenticationBase::ACCESS_COOKIE_KEY]
    get new_auth_app_settings_totp_path(ri: "jp")
    props = JSON.parse(response.parsed_body.at_css("script[data-page='app']").text).fetch("props")
    2.times do
      ClientTotpCredential.create_for_user!(user: actor, user_identity_totp_credential_status_id: ClientTotpCredentialStatus::ACTIVE)
    end
    assert_raises(ClientTotpCredential::SlotLimitExceeded) do
      ClientTotpCredential.create_for_user!(user: actor, user_identity_totp_credential_status_id: ClientTotpCredentialStatus::ACTIVE)
    end
    assert_no_difference("IdentityTotpCeremonyCandidate.count") do
      post props.fetch("start").fetch("action"), params: { authenticity_token: csrf }

      assert_response :unprocessable_content
    end
    assert_equal 2, actor.client_totp_credentials.slot_consuming.count
    assert_nil token.reload.last_step_up_at
  end

  test "admitted initial registration is available without Secret credentials" do
    reset!
    host! ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    actor = Client.create!(id: 9_104_000_000_008, status_id: ClientStatus::ACTIVE)

    assert_equal 0, actor.client_passkeys.count
    assert_equal 0, actor.client_totp_credentials.count
    assert_equal 0, actor.client_emails.count
    token = ClientToken.create!(user: actor, root_login_established_at: Time.current)
    requirement = StepUpRequirement.new(
      scope: "settings_birthdate", purpose: "bootstrap", step_up_required: false,
      phishing_resistant_required: false, user_verification_required: false,
      full_reauthentication_required: false, ttl: 15.minutes,
      allowed_methods: [:totp], audience: "step_up:app", session_binding: token.public_id,
      token_binding: token.public_id, require_session_binding: true, actor_ref: actor.public_id,
      resource_ref: nil, tenant_ref: nil,
    )
    issuance = issue_confirmed_base_step_up_admission!(
      actor: actor, token: token, requirement: requirement, return_to: "/identity/birthdate",
    )
    get new_auth_app_verification_setup_path(ri: "jp", entry_ref: issuance.reference)
    csrf = response.parsed_body.at_css('input[name="authenticity_token"]')["value"]
    post auth_app_verification_setup_path(ri: "jp"), params: { entry_ref: issuance.reference, authenticity_token: csrf }

    assert_response :see_other
    assert_nil cookies[AuthenticationBase::ACCESS_COOKIE_KEY]
    get new_auth_app_settings_totp_path(ri: "jp")
    props = JSON.parse(response.parsed_body.at_css("script[data-page='app']").text).fetch("props")
    post props.fetch("start").fetch("action"), params: { authenticity_token: csrf }

    assert_redirected_to new_auth_app_settings_totp_path(ri: "jp")
    follow_redirect!
    props = JSON.parse(response.parsed_body.at_css("script[data-page='app']").text).fetch("props")
    IdentityTotpCeremonyCandidate.find_by!(ref: props.fetch("form").fetch("enrollment_id"))

    assert_equal 0, ClientSecretCredential.where(client_id: actor.id).count
    assert_equal "text/html", response.media_type
    assert_response :success
    assert_nil token.reload.last_step_up_at
  end

  test "admitted TOTP registration creates no Secret credentials" do
    reset!
    host! ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    actor = Client.create!(id: 9_104_000_000_009, status_id: ClientStatus::ACTIVE)

    assert_equal 0, actor.client_passkeys.count
    assert_equal 0, actor.client_totp_credentials.count
    assert_equal 0, actor.client_emails.count
    token = ClientToken.create!(user: actor, root_login_established_at: Time.current)
    requirement = StepUpRequirement.new(
      scope: "settings_birthdate", purpose: "bootstrap", step_up_required: false,
      phishing_resistant_required: false, user_verification_required: false,
      full_reauthentication_required: false, ttl: 15.minutes,
      allowed_methods: [:totp], audience: "step_up:app", session_binding: token.public_id,
      token_binding: token.public_id, require_session_binding: true, actor_ref: actor.public_id,
      resource_ref: nil, tenant_ref: nil,
    )
    issuance = issue_confirmed_base_step_up_admission!(
      actor: actor, token: token, requirement: requirement, return_to: "/identity/birthdate",
    )
    get new_auth_app_verification_setup_path(ri: "jp", entry_ref: issuance.reference)
    csrf = response.parsed_body.at_css('input[name="authenticity_token"]')["value"]
    post auth_app_verification_setup_path(ri: "jp"), params: { entry_ref: issuance.reference, authenticity_token: csrf }

    assert_response :see_other
    assert_nil cookies[AuthenticationBase::ACCESS_COOKIE_KEY]
    get new_auth_app_settings_totp_path(ri: "jp")
    props = JSON.parse(response.parsed_body.at_css("script[data-page='app']").text).fetch("props")
    post props.fetch("start").fetch("action"), params: { authenticity_token: csrf }

    assert_redirected_to new_auth_app_settings_totp_path(ri: "jp")
    follow_redirect!
    props = JSON.parse(response.parsed_body.at_css("script[data-page='app']").text).fetch("props")
    candidate = IdentityTotpCeremonyCandidate.find_by!(ref: props.fetch("form").fetch("enrollment_id"))
    TurnstileVerifierStub.enabled = true
    TurnstileVerifierStub.response = { "success" => true }
    now = ClientStepUpCeremonyTransaction.database_now
    code = ROTP::TOTP.new(candidate.private_key).at(now.to_i)
    before_secrets = ClientSecretCredential.where(client_id: actor.id).count
    assert_no_difference("ClientTotpCredential.count") do
      ClientStepUpCeremonyTransaction.stub(:database_now, now) do
        post props.fetch("form").fetch("action"), params: {
          :authenticity_token => csrf,
          :user_totp_credential => { enrollment_id: candidate.ref, first_token: code, title: "New TOTP" },
          "cf-turnstile-response" => "test-only",
        }
      end
    end
    assert_redirected_to auth_app_settings_totps_handoff_path(ri: "jp")
    assert_equal "verified", issuance.transaction.reload.status
    assert_nil issuance.transaction.verified_credential_ref
    assert_nil token.reload.last_step_up_at
    assert_nil cookies[AuthenticationBase::ACCESS_COOKIE_KEY]
    follow_redirect!
    post auth_app_settings_totps_handoff_path(ri: "jp"), params: { authenticity_token: csrf }
    raw_result = Rack::Utils.parse_nested_query(URI.parse(response.location).query).fetch("result_ref")
    credential = nil
    assert_difference("ClientTotpCredential.count", 1) do
      credential = IdentityTotpEnrollmentFinalCommitter.call!(
        actor: actor, token: token, transaction: issuance.transaction.reload, result_reference: raw_result,
      )
    end

    assert_equal actor.id, credential.user_id
    assert_equal "New TOTP", credential.title
    assert_equal candidate.reload.last_otp_at, credential.last_otp_at
    assert_equal "consumed", issuance.transaction.reload.status
    assert_nil token.reload.last_step_up_at
    assert_equal before_secrets, ClientSecretCredential.where(client_id: actor.id).count
  end

  test "admitted valid first code creates a credential only at Base finalization" do
    reset!
    host! ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    actor = Client.create!(id: 9_104_000_000_010, status_id: ClientStatus::ACTIVE)

    assert_equal 0, actor.client_passkeys.count
    assert_equal 0, actor.client_totp_credentials.count
    assert_equal 0, actor.client_emails.count
    token = ClientToken.create!(user: actor, root_login_established_at: Time.current)
    requirement = StepUpRequirement.new(
      scope: "settings_birthdate", purpose: "bootstrap", step_up_required: false,
      phishing_resistant_required: false, user_verification_required: false,
      full_reauthentication_required: false, ttl: 15.minutes,
      allowed_methods: [:totp], audience: "step_up:app", session_binding: token.public_id,
      token_binding: token.public_id, require_session_binding: true, actor_ref: actor.public_id,
      resource_ref: nil, tenant_ref: nil,
    )
    issuance = issue_confirmed_base_step_up_admission!(
      actor: actor, token: token, requirement: requirement, return_to: "/identity/birthdate",
    )
    get new_auth_app_verification_setup_path(ri: "jp", entry_ref: issuance.reference)
    csrf = response.parsed_body.at_css('input[name="authenticity_token"]')["value"]
    post auth_app_verification_setup_path(ri: "jp"), params: { entry_ref: issuance.reference, authenticity_token: csrf }

    assert_response :see_other
    assert_nil cookies[AuthenticationBase::ACCESS_COOKIE_KEY]
    get new_auth_app_settings_totp_path(ri: "jp")
    props = JSON.parse(response.parsed_body.at_css("script[data-page='app']").text).fetch("props")
    post props.fetch("start").fetch("action"), params: { authenticity_token: csrf }

    assert_redirected_to new_auth_app_settings_totp_path(ri: "jp")
    follow_redirect!
    props = JSON.parse(response.parsed_body.at_css("script[data-page='app']").text).fetch("props")
    candidate = IdentityTotpCeremonyCandidate.find_by!(ref: props.fetch("form").fetch("enrollment_id"))
    TurnstileVerifierStub.enabled = true
    TurnstileVerifierStub.response = { "success" => true }
    now = ClientStepUpCeremonyTransaction.database_now
    code = ROTP::TOTP.new(candidate.private_key).at(now.to_i)
    assert_no_difference("ClientTotpCredential.count") do
      ClientStepUpCeremonyTransaction.stub(:database_now, now) do
        post props.fetch("form").fetch("action"), params: {
          :authenticity_token => csrf,
          :user_totp_credential => { enrollment_id: candidate.ref, first_token: code, title: "New TOTP" },
          "cf-turnstile-response" => "test-only",
        }
      end
    end
    assert_redirected_to auth_app_settings_totps_handoff_path(ri: "jp")
    assert_equal "verified", issuance.transaction.reload.status
    assert_nil issuance.transaction.verified_credential_ref
    assert_nil token.reload.last_step_up_at
    assert_nil cookies[AuthenticationBase::ACCESS_COOKIE_KEY]
    follow_redirect!
    post auth_app_settings_totps_handoff_path(ri: "jp"), params: { authenticity_token: csrf }
    raw_result = Rack::Utils.parse_nested_query(URI.parse(response.location).query).fetch("result_ref")
    credential = nil
    assert_difference("ClientTotpCredential.count", 1) do
      credential = IdentityTotpEnrollmentFinalCommitter.call!(
        actor: actor, token: token, transaction: issuance.transaction.reload, result_reference: raw_result,
      )
    end

    assert_equal actor.id, credential.user_id
    assert_equal "New TOTP", credential.title
    assert_equal candidate.reload.last_otp_at, credential.last_otp_at
    assert_equal "consumed", issuance.transaction.reload.status
    assert_nil token.reload.last_step_up_at
  end

  test "Base finalization preserves the admitted TOTP title and first accepted window" do
    reset!
    host! ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    actor = Client.create!(id: 9_104_000_000_011, status_id: ClientStatus::ACTIVE)

    assert_equal 0, actor.client_passkeys.count
    assert_equal 0, actor.client_totp_credentials.count
    assert_equal 0, actor.client_emails.count
    token = ClientToken.create!(user: actor, root_login_established_at: Time.current)
    requirement = StepUpRequirement.new(
      scope: "settings_birthdate", purpose: "bootstrap", step_up_required: false,
      phishing_resistant_required: false, user_verification_required: false,
      full_reauthentication_required: false, ttl: 15.minutes,
      allowed_methods: [:totp], audience: "step_up:app", session_binding: token.public_id,
      token_binding: token.public_id, require_session_binding: true, actor_ref: actor.public_id,
      resource_ref: nil, tenant_ref: nil,
    )
    issuance = issue_confirmed_base_step_up_admission!(
      actor: actor, token: token, requirement: requirement, return_to: "/identity/birthdate",
    )
    get new_auth_app_verification_setup_path(ri: "jp", entry_ref: issuance.reference)
    csrf = response.parsed_body.at_css('input[name="authenticity_token"]')["value"]
    post auth_app_verification_setup_path(ri: "jp"), params: { entry_ref: issuance.reference, authenticity_token: csrf }

    assert_response :see_other
    assert_nil cookies[AuthenticationBase::ACCESS_COOKIE_KEY]
    get new_auth_app_settings_totp_path(ri: "jp")
    props = JSON.parse(response.parsed_body.at_css("script[data-page='app']").text).fetch("props")
    post props.fetch("start").fetch("action"), params: { authenticity_token: csrf }

    assert_redirected_to new_auth_app_settings_totp_path(ri: "jp")
    follow_redirect!
    props = JSON.parse(response.parsed_body.at_css("script[data-page='app']").text).fetch("props")
    candidate = IdentityTotpCeremonyCandidate.find_by!(ref: props.fetch("form").fetch("enrollment_id"))
    TurnstileVerifierStub.enabled = true
    TurnstileVerifierStub.response = { "success" => true }
    now = ClientStepUpCeremonyTransaction.database_now
    code = ROTP::TOTP.new(candidate.private_key).at(now.to_i)
    assert_no_difference("ClientTotpCredential.count") do
      ClientStepUpCeremonyTransaction.stub(:database_now, now) do
        post props.fetch("form").fetch("action"), params: {
          :authenticity_token => csrf,
          :user_totp_credential => { enrollment_id: candidate.ref, first_token: code, title: "New TOTP" },
          "cf-turnstile-response" => "test-only",
        }
      end
    end
    assert_redirected_to auth_app_settings_totps_handoff_path(ri: "jp")
    assert_equal "verified", issuance.transaction.reload.status
    assert_nil issuance.transaction.verified_credential_ref
    assert_nil token.reload.last_step_up_at
    assert_nil cookies[AuthenticationBase::ACCESS_COOKIE_KEY]
    follow_redirect!
    post auth_app_settings_totps_handoff_path(ri: "jp"), params: { authenticity_token: csrf }
    raw_result = Rack::Utils.parse_nested_query(URI.parse(response.location).query).fetch("result_ref")
    credential = nil
    assert_difference("ClientTotpCredential.count", 1) do
      credential = IdentityTotpEnrollmentFinalCommitter.call!(
        actor: actor, token: token, transaction: issuance.transaction.reload, result_reference: raw_result,
      )
    end

    assert_equal actor.id, credential.user_id
    assert_equal "New TOTP", credential.title
    assert_equal candidate.reload.last_otp_at, credential.last_otp_at
    assert_equal "consumed", issuance.transaction.reload.status
    assert_nil token.reload.last_step_up_at
    assert_no_difference("ClientTotpCredential.count") do
      repeated = IdentityTotpEnrollmentFinalCommitter.call!(
        actor: actor, token: token, transaction: issuance.transaction.reload, result_reference: raw_result,
      )

      assert_equal credential.id, repeated.id
      assert_equal credential.last_otp_at, repeated.last_otp_at
    end
  end

  test "admitted first code accepts the existing space separated paste format" do
    reset!
    host! ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    actor = Client.create!(id: 9_104_000_000_012, status_id: ClientStatus::ACTIVE)

    assert_equal 0, actor.client_passkeys.count
    assert_equal 0, actor.client_totp_credentials.count
    assert_equal 0, actor.client_emails.count
    token = ClientToken.create!(user: actor, root_login_established_at: Time.current)
    requirement = StepUpRequirement.new(
      scope: "settings_birthdate", purpose: "bootstrap", step_up_required: false,
      phishing_resistant_required: false, user_verification_required: false,
      full_reauthentication_required: false, ttl: 15.minutes,
      allowed_methods: [:totp], audience: "step_up:app", session_binding: token.public_id,
      token_binding: token.public_id, require_session_binding: true, actor_ref: actor.public_id,
      resource_ref: nil, tenant_ref: nil,
    )
    issuance = issue_confirmed_base_step_up_admission!(
      actor: actor, token: token, requirement: requirement, return_to: "/identity/birthdate",
    )
    get new_auth_app_verification_setup_path(ri: "jp", entry_ref: issuance.reference)
    csrf = response.parsed_body.at_css('input[name="authenticity_token"]')["value"]
    post auth_app_verification_setup_path(ri: "jp"), params: { entry_ref: issuance.reference, authenticity_token: csrf }

    assert_response :see_other
    assert_nil cookies[AuthenticationBase::ACCESS_COOKIE_KEY]
    get new_auth_app_settings_totp_path(ri: "jp")
    props = JSON.parse(response.parsed_body.at_css("script[data-page='app']").text).fetch("props")
    post props.fetch("start").fetch("action"), params: { authenticity_token: csrf }

    assert_redirected_to new_auth_app_settings_totp_path(ri: "jp")
    follow_redirect!
    props = JSON.parse(response.parsed_body.at_css("script[data-page='app']").text).fetch("props")
    candidate = IdentityTotpCeremonyCandidate.find_by!(ref: props.fetch("form").fetch("enrollment_id"))
    TurnstileVerifierStub.enabled = true
    TurnstileVerifierStub.response = { "success" => true }
    now = ClientStepUpCeremonyTransaction.database_now
    code = ROTP::TOTP.new(candidate.private_key).at(now.to_i)
    code = "#{code.first(3)} #{code.last(3)}"
    assert_no_difference("ClientTotpCredential.count") do
      ClientStepUpCeremonyTransaction.stub(:database_now, now) do
        post props.fetch("form").fetch("action"), params: {
          :authenticity_token => csrf,
          :user_totp_credential => { enrollment_id: candidate.ref, first_token: code, title: "New TOTP" },
          "cf-turnstile-response" => "test-only",
        }
      end
    end
    assert_redirected_to auth_app_settings_totps_handoff_path(ri: "jp")
    assert_equal "verified", issuance.transaction.reload.status
    assert_nil issuance.transaction.verified_credential_ref
    assert_nil token.reload.last_step_up_at
    assert_nil cookies[AuthenticationBase::ACCESS_COOKIE_KEY]
    follow_redirect!
    post auth_app_settings_totps_handoff_path(ri: "jp"), params: { authenticity_token: csrf }
    raw_result = Rack::Utils.parse_nested_query(URI.parse(response.location).query).fetch("result_ref")
    credential = nil
    assert_difference("ClientTotpCredential.count", 1) do
      credential = IdentityTotpEnrollmentFinalCommitter.call!(
        actor: actor, token: token, transaction: issuance.transaction.reload, result_reference: raw_result,
      )
    end

    assert_equal actor.id, credential.user_id
    assert_equal "New TOTP", credential.title
    assert_equal candidate.reload.last_otp_at, credential.last_otp_at
    assert_equal "consumed", issuance.transaction.reload.status
    assert_nil token.reload.last_step_up_at
  end

  test "admitted incorrect first code preserves the candidate and records one failure" do
    reset!
    host! ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    actor = Client.create!(id: 9_104_000_000_013, status_id: ClientStatus::ACTIVE)

    assert_equal 0, actor.client_passkeys.count
    assert_equal 0, actor.client_totp_credentials.count
    assert_equal 0, actor.client_emails.count
    token = ClientToken.create!(user: actor, root_login_established_at: Time.current)
    requirement = StepUpRequirement.new(
      scope: "settings_birthdate", purpose: "bootstrap", step_up_required: false,
      phishing_resistant_required: false, user_verification_required: false,
      full_reauthentication_required: false, ttl: 15.minutes,
      allowed_methods: [:totp], audience: "step_up:app", session_binding: token.public_id,
      token_binding: token.public_id, require_session_binding: true, actor_ref: actor.public_id,
      resource_ref: nil, tenant_ref: nil,
    )
    issuance = issue_confirmed_base_step_up_admission!(
      actor: actor, token: token, requirement: requirement, return_to: "/identity/birthdate",
    )
    get new_auth_app_verification_setup_path(ri: "jp", entry_ref: issuance.reference)
    csrf = response.parsed_body.at_css('input[name="authenticity_token"]')["value"]
    post auth_app_verification_setup_path(ri: "jp"), params: { entry_ref: issuance.reference, authenticity_token: csrf }

    assert_response :see_other
    assert_nil cookies[AuthenticationBase::ACCESS_COOKIE_KEY]
    get new_auth_app_settings_totp_path(ri: "jp")
    props = JSON.parse(response.parsed_body.at_css("script[data-page='app']").text).fetch("props")
    post props.fetch("start").fetch("action"), params: { authenticity_token: csrf }

    assert_redirected_to new_auth_app_settings_totp_path(ri: "jp")
    follow_redirect!
    props = JSON.parse(response.parsed_body.at_css("script[data-page='app']").text).fetch("props")
    candidate = IdentityTotpCeremonyCandidate.find_by!(ref: props.fetch("form").fetch("enrollment_id"))
    TurnstileVerifierStub.enabled = true
    TurnstileVerifierStub.response = { "success" => true }
    now = ClientStepUpCeremonyTransaction.database_now
    valid = ROTP::TOTP.new(candidate.private_key).at(now.to_i)
    incorrect = format("%06d", (valid.to_i + 1) % 1_000_000)
    assert_no_difference("ClientTotpCredential.count") do
      ClientStepUpCeremonyTransaction.stub(:database_now, now) do
        post props.fetch("form").fetch("action"), params: {
          authenticity_token: csrf,
          user_totp_credential: { enrollment_id: candidate.ref, first_token: incorrect },
        }
      end
    end

    assert_response :unprocessable_content
    assert_equal "pending", issuance.transaction.reload.status
    assert_nil candidate.reload.last_otp_at
    assert_nil token.reload.last_step_up_at
    record = ClientStepUpSession.find_by!(step_up_ceremony_transaction_ref: issuance.transaction.transaction_id)

    assert_equal 1, record.attempt_count
  end

  test "admitted empty first code returns localized failure without confirming the candidate" do
    reset!
    host! ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    actor = Client.create!(id: 9_104_000_000_014, status_id: ClientStatus::ACTIVE)

    assert_equal 0, actor.client_passkeys.count
    assert_equal 0, actor.client_totp_credentials.count
    assert_equal 0, actor.client_emails.count
    token = ClientToken.create!(user: actor, root_login_established_at: Time.current)
    requirement = StepUpRequirement.new(
      scope: "settings_birthdate", purpose: "bootstrap", step_up_required: false,
      phishing_resistant_required: false, user_verification_required: false,
      full_reauthentication_required: false, ttl: 15.minutes,
      allowed_methods: [:totp], audience: "step_up:app", session_binding: token.public_id,
      token_binding: token.public_id, require_session_binding: true, actor_ref: actor.public_id,
      resource_ref: nil, tenant_ref: nil,
    )
    issuance = issue_confirmed_base_step_up_admission!(
      actor: actor, token: token, requirement: requirement, return_to: "/identity/birthdate",
    )
    get new_auth_app_verification_setup_path(ri: "jp", entry_ref: issuance.reference)
    csrf = response.parsed_body.at_css('input[name="authenticity_token"]')["value"]
    post auth_app_verification_setup_path(ri: "jp"), params: { entry_ref: issuance.reference, authenticity_token: csrf }

    assert_response :see_other
    assert_nil cookies[AuthenticationBase::ACCESS_COOKIE_KEY]
    get new_auth_app_settings_totp_path(ri: "jp")
    props = JSON.parse(response.parsed_body.at_css("script[data-page='app']").text).fetch("props")
    post props.fetch("start").fetch("action"), params: { authenticity_token: csrf }

    assert_redirected_to new_auth_app_settings_totp_path(ri: "jp")
    follow_redirect!
    props = JSON.parse(response.parsed_body.at_css("script[data-page='app']").text).fetch("props")
    candidate = IdentityTotpCeremonyCandidate.find_by!(ref: props.fetch("form").fetch("enrollment_id"))
    TurnstileVerifierStub.enabled = true
    TurnstileVerifierStub.response = { "success" => true }
    assert_no_difference("ClientTotpCredential.count") do
      post props.fetch("form").fetch("action"), params: {
        authenticity_token: csrf,
        user_totp_credential: { enrollment_id: candidate.ref, first_token: "", title: "" },
      }
    end

    assert_response :unprocessable_content
    page = JSON.parse(response.parsed_body.at_css("script[data-page='app']").text)

    assert_equal "auth/app/settings/totps/new", page.fetch("component")
    assert_includes page.fetch("props").fetch("error_messages").join("\n"),
                    I18n.t("sign.app.settings.totps.invalid_code")
    assert_nil candidate.reload.last_otp_at
    assert_nil token.reload.last_step_up_at
  end

  test "Turnstile refusal does not verify an admitted correct first code" do
    reset!
    host! ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    actor = Client.create!(id: 9_104_000_000_015, status_id: ClientStatus::ACTIVE)

    assert_equal 0, actor.client_passkeys.count
    assert_equal 0, actor.client_totp_credentials.count
    assert_equal 0, actor.client_emails.count
    token = ClientToken.create!(user: actor, root_login_established_at: Time.current)
    requirement = StepUpRequirement.new(
      scope: "settings_birthdate", purpose: "bootstrap", step_up_required: false,
      phishing_resistant_required: false, user_verification_required: false,
      full_reauthentication_required: false, ttl: 15.minutes,
      allowed_methods: [:totp], audience: "step_up:app", session_binding: token.public_id,
      token_binding: token.public_id, require_session_binding: true, actor_ref: actor.public_id,
      resource_ref: nil, tenant_ref: nil,
    )
    issuance = issue_confirmed_base_step_up_admission!(
      actor: actor, token: token, requirement: requirement, return_to: "/identity/birthdate",
    )
    get new_auth_app_verification_setup_path(ri: "jp", entry_ref: issuance.reference)
    csrf = response.parsed_body.at_css('input[name="authenticity_token"]')["value"]
    post auth_app_verification_setup_path(ri: "jp"), params: { entry_ref: issuance.reference, authenticity_token: csrf }

    assert_response :see_other
    assert_nil cookies[AuthenticationBase::ACCESS_COOKIE_KEY]
    get new_auth_app_settings_totp_path(ri: "jp")
    props = JSON.parse(response.parsed_body.at_css("script[data-page='app']").text).fetch("props")
    post props.fetch("start").fetch("action"), params: { authenticity_token: csrf }

    assert_redirected_to new_auth_app_settings_totp_path(ri: "jp")
    follow_redirect!
    props = JSON.parse(response.parsed_body.at_css("script[data-page='app']").text).fetch("props")
    candidate = IdentityTotpCeremonyCandidate.find_by!(ref: props.fetch("form").fetch("enrollment_id"))
    TurnstileVerifierStub.enabled = true
    TurnstileVerifierStub.response = { "success" => false }
    TurnstileVerifierStub.challenge_enabled = true
    TurnstileVerifierStub.challenge_response = { "success" => false }
    now = ClientStepUpCeremonyTransaction.database_now
    code = ROTP::TOTP.new(candidate.private_key).at(now.to_i)
    assert_no_difference("ClientTotpCredential.count") do
      ClientStepUpCeremonyTransaction.stub(:database_now, now) do
        post props.fetch("form").fetch("action"), params: {
          :authenticity_token => csrf,
          :user_totp_credential => { enrollment_id: candidate.ref, first_token: code },
          "cf-turnstile-response" => "test-only",
        }
      end
    end

    assert_response :unprocessable_content
    page = JSON.parse(response.parsed_body.at_css("script[data-page='app']").text)

    assert_includes page.fetch("props").fetch("error_messages").join("\n"), I18n.t("turnstile_error")
    assert_equal "pending", issuance.transaction.reload.status
    assert_nil candidate.reload.last_otp_at
    record = ClientStepUpSession.find_by!(step_up_ceremony_transaction_ref: issuance.transaction.transaction_id)

    assert_equal 0, record.attempt_count
  end

  test "first TOTP registration uses explicit bootstrap without granting step up freshness" do
    reset!
    host! ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    actor = Client.create!(id: 9_104_000_000_016, status_id: ClientStatus::ACTIVE)

    assert_equal 0, actor.client_passkeys.count
    assert_equal 0, actor.client_totp_credentials.count
    assert_equal 0, actor.client_emails.count
    token = ClientToken.create!(user: actor, root_login_established_at: Time.current)
    requirement = StepUpRequirement.new(
      scope: "settings_birthdate", purpose: "bootstrap", step_up_required: false,
      phishing_resistant_required: false, user_verification_required: false,
      full_reauthentication_required: false, ttl: 15.minutes,
      allowed_methods: [:totp], audience: "step_up:app", session_binding: token.public_id,
      token_binding: token.public_id, require_session_binding: true, actor_ref: actor.public_id,
      resource_ref: nil, tenant_ref: nil,
    )
    issuance = issue_confirmed_base_step_up_admission!(
      actor: actor, token: token, requirement: requirement, return_to: "/identity/birthdate",
    )
    get new_auth_app_verification_setup_path(ri: "jp", entry_ref: issuance.reference)
    csrf = response.parsed_body.at_css('input[name="authenticity_token"]')["value"]
    post auth_app_verification_setup_path(ri: "jp"), params: { entry_ref: issuance.reference, authenticity_token: csrf }

    assert_response :see_other
    assert_nil cookies[AuthenticationBase::ACCESS_COOKIE_KEY]
    get new_auth_app_settings_totp_path(ri: "jp")
    props = JSON.parse(response.parsed_body.at_css("script[data-page='app']").text).fetch("props")
    post props.fetch("start").fetch("action"), params: { authenticity_token: csrf }

    assert_redirected_to new_auth_app_settings_totp_path(ri: "jp")
    follow_redirect!
    props = JSON.parse(response.parsed_body.at_css("script[data-page='app']").text).fetch("props")
    candidate = IdentityTotpCeremonyCandidate.find_by!(ref: props.fetch("form").fetch("enrollment_id"))
    TurnstileVerifierStub.enabled = true
    TurnstileVerifierStub.response = { "success" => true }
    now = ClientStepUpCeremonyTransaction.database_now
    code = ROTP::TOTP.new(candidate.private_key).at(now.to_i)
    assert_no_difference("ClientTotpCredential.count") do
      ClientStepUpCeremonyTransaction.stub(:database_now, now) do
        post props.fetch("form").fetch("action"), params: {
          :authenticity_token => csrf,
          :user_totp_credential => { enrollment_id: candidate.ref, first_token: code, title: "New TOTP" },
          "cf-turnstile-response" => "test-only",
        }
      end
    end
    assert_redirected_to auth_app_settings_totps_handoff_path(ri: "jp")
    assert_equal "verified", issuance.transaction.reload.status
    assert_nil issuance.transaction.verified_credential_ref
    assert_nil token.reload.last_step_up_at
    assert_nil cookies[AuthenticationBase::ACCESS_COOKIE_KEY]
    follow_redirect!
    post auth_app_settings_totps_handoff_path(ri: "jp"), params: { authenticity_token: csrf }
    raw_result = Rack::Utils.parse_nested_query(URI.parse(response.location).query).fetch("result_ref")
    credential = nil
    assert_difference("ClientTotpCredential.count", 1) do
      credential = IdentityTotpEnrollmentFinalCommitter.call!(
        actor: actor, token: token, transaction: issuance.transaction.reload, result_reference: raw_result,
      )
    end

    assert_equal actor.id, credential.user_id
    assert_equal "New TOTP", credential.title
    assert_equal candidate.reload.last_otp_at, credential.last_otp_at
    assert_equal "consumed", issuance.transaction.reload.status
    assert_nil token.reload.last_step_up_at
    assert_equal "bootstrap", issuance.transaction.purpose
    assert_equal "none", issuance.transaction.aal
    assert_not issuance.transaction.phishing_resistant
    assert_equal credential.public_id, issuance.transaction.verified_credential_ref
  end

  private

  private

  # Starts an enrolment the way the page does (POST), then shows it, keeping its id for the form.
  private

  def jwt_issuer_id_for_test_host(host, resource_type)
    normalized = host.to_s
    service = normalized.include?("acme") ? "ACME" : (normalized.include?("core") ? "CORE" : "AUTH")
    surface =
      if service == "AUTH"
        case resource_type
        when "operator" then "ORG"
        when "visitor" then "COM"
        else "APP"
        end
      elsif normalized.include?(".org") || normalized.include?("org.")
        "ORG"
      elsif normalized.include?(".com") || normalized.include?("com.")
        "COM"
      else
        "APP"
      end
    "surface:#{service}_#{surface}"
  end

  def ensure_user_reference_records!
    ClientStatus.find_or_create_by!(id: ClientStatus::NOTHING)
    ClientVisibility.find_or_create_by!(id: ClientVisibility::USER)
    ClientMfaLevel.find_or_create_by!(id: ClientMfaLevel::NOTHING)
    ClientMfaStatus.find_or_create_by!(id: ClientMfaStatus::NOTHING)
    ClientMfaStatus.find_or_create_by!(id: ClientMfaStatus::ACTIVE)
    ClientMfaStatus.find_or_create_by!(id: ClientMfaStatus::UNCONFIGURED)
    ClientEmailStatus.find_or_create_by!(id: ClientEmailStatus::VERIFIED)
    ClientTelephoneStatus.find_or_create_by!(id: ClientTelephoneStatus::VERIFIED)
    ClientPasskeyStatus.find_or_create_by!(id: ClientPasskeyStatus::ACTIVE)
  end

  def create_verified_user_with_email(email_address: "user-#{SecureRandom.hex(4)}@example.com")
    ensure_user_reference_records!
    user = Client.create!(status_id: ClientStatus::NOTHING, visibility_id: ClientVisibility::USER)
    insert_verified_user_email!(user_id: user.id, address: email_address)
    user.reload
  end

  def insert_verified_user_email!(user_id:, address:)
    ClientEmail.create!(
      user_id: user_id,
      address: address,
      address_digest: IdentifierBlindIndex.bidx_for_email(address),
      user_email_status_id: ClientEmailStatus::VERIFIED,
      otp_private_key: SecureRandom.base64(24),
      otp_counter: "",
      otp_attempts_count: 0,
      public_id: SecureRandom.alphanumeric(21),
    )
  end

  def satisfy_user_verification(token, scope: nil)
    _verification, raw_token = ClientVerification.issue_for_token!(token: token)
    cookies[ClientVerification.cookie_name] = raw_token
    mark_token_step_up_satisfied_for_test(token, scope: scope)
    true
  end

  def step_up_test_audience_for_token(token)
    case token.class.name
    when "OperatorToken" then "step_up:org"
    when "VisitorToken" then "step_up:com"
    else "step_up:app"
    end
  end
end

# DAMP local helper copy on the test class.
class Auth::App::Settings::TotpsControllerTest
  private

  def mark_token_step_up_satisfied_for_test(token, scope: nil, at: Time.current)
    return unless token.respond_to?(:update_columns)

    attrs = {
      last_step_up_at: at,
      last_step_up_scope: scope.presence || token.try(:last_step_up_scope).presence || "verification",
      last_step_up_aal: ("aal2" if token.has_attribute?(:last_step_up_aal)),
      last_step_up_method: ("passkey" if token.has_attribute?(:last_step_up_method)),
      last_step_up_session_public_id: (token.public_id if token.has_attribute?(:last_step_up_session_public_id)),
      last_step_up_purpose: ("step_up" if token.has_attribute?(:last_step_up_purpose)),
      last_step_up_audience: (step_up_test_audience_for_token(token) if token.has_attribute?(:last_step_up_audience)),
      updated_at: Time.current,
    }.compact
    token.update_columns(attrs)
  end
end
