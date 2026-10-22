# typed: false
# frozen_string_literal: true

require "test_helper"
require "webauthn/fake_client"
require "minitest/mock"
require "base64"

# The passkey stage of normal org sign-in.
#
# Every test here starts from a completed Entra ceremony, because that is now
# the only way to reach this endpoint: Entra identifies the operator, and this
# stage authenticates them. The identifier-first ceremony that used to live at
# these URLs is Emergency Access, and its tests live in
# test/controllers/auth/org/in/emergency/passkeys_controller_test.rb.
class Auth::Org::Sign::In::PasskeysControllerTest < ActionDispatch::IntegrationTest
  include OrgEntraFirstStageHelper

  fixtures :operators, :operator_statuses, :operator_passkeys, :operator_passkey_statuses

  setup do
    host! ENV.fetch("PUBLIC_AUTH_STAFF_URL")
    TurnstileVerifierStub.enabled = true
    TurnstileVerifierStub.response = { "success" => true }
    TurnstileVerifierStub.challenge_enabled = true
    TurnstileVerifierStub.challenge_response = { "success" => true }

    @staff = operators(:one)
    @staff.update!(status_id: OperatorStatus::ACTIVE)
    OperatorToken.where(staff_id: @staff.id).delete_all

    @fake = WebAuthn::FakeClient.new("https://#{ENV.fetch("PUBLIC_AUTH_STAFF_URL")}")
    @registration = WebAuthn::Credential.from_create(@fake.create(user_verified: true))
    @staff_passkey = OperatorPasskey.create!(
      staff: @staff,
      webauthn_id: @registration.id,
      external_id: SecureRandom.uuid,
      public_key: @registration.public_key,
      description: "Staff Login Key",
      status_id: OperatorPasskeyStatus::ACTIVE,
    )
  end

  teardown do
    TurnstileVerifierStub.enabled = false
    TurnstileVerifierStub.response = nil
    TurnstileVerifierStub.challenge_enabled = false
    TurnstileVerifierStub.challenge_response = nil
  end

  test "the entra callback establishes no session and hands the browser to the passkey stage" do
    begin
      admission_host = ENV.fetch("PUBLIC_AUTH_STAFF_URL")
      admission_sid = cookies["__Host-auth_sid"].presence || cookies["auth_sid"].presence
      admission_session = OperatorAuthCeremonySession.find_active_by_raw_sid(admission_sid) if admission_sid
      unless admission_session&.admitted? && admission_session.admission_purpose == "local_sign_in"
        admission_nonce = SecureRandom.urlsafe_base64(32)
        admission = BaseAuthAdmissionCoordinator.issue_local_entry!(
          surface: "org", intent: "sign_in", base_browser_nonce: admission_nonce, base_token: nil,
        )
        admission_binding = BaseAuthAdmissionCoordinator.find_admission_binding!(
          surface: "org",
          reference: admission.reference,
        )
        admission_session, admission_sid = OperatorAuthCeremonySession.issue!
        admission_binding.attach_auth_session!(auth_session: admission_session, confirmation_ref: SecureRandom.uuid)
        admission_binding.confirm_base!(
          base_token: nil,
          browser_digest: AuthAdmissionBinding.browser_digest(
            surface: "org",
            entry_ref: admission.reference,
            nonce: admission_nonce,
          ),
        )
        host!(admission_host)
        https!
        admission_cookie_name = JitSessionCookieConfig.force_secure? ? "__Host-auth_sid" : "auth_sid"
        cookies.delete("auth_sid")
        cookies.delete("__Host-auth_sid")
        store_raw_cookies(
          cookies,
          "#{admission_cookie_name}=#{Rack::Utils.escape(admission_sid)}", URI.parse("https://#{admission_host}/"),
        )
        get auth_org_sign_in_path, params: { entry_ref: admission.reference, ri: "jp" }
        admission_form = response.parsed_body.at_css("form")
        raise RuntimeError, "Auth admission continuation is missing" unless admission_form

        admission_fields = admission_form.css("input[type='hidden']").to_h { |field| [field["name"], field["value"]] }
        post admission_form["action"], params: admission_fields,
                                       headers: {
                                         "Origin" => "https://#{admission_host}",
                                         "Sec-Fetch-Site" => "same-origin",
                                       }

        assert_response :see_other
      end
      complete_org_entra_first_stage!(@staff)
    end

    assert(
      URI.parse(response.location).query.to_s.split("&").any? { |pair| pair.start_with?("fb=") },
      "expected the Entra handoff to bind the next passkey page to its sign-in flow",
    )

    transaction = session.fetch(OrgNormalSignInTransaction::SESSION_KEY)

    assert_match(/\A[A-Za-z0-9_-]{21}\z/, transaction.fetch("public_id"))
    assert_redirected_to new_auth_org_sign_in_passkey_path(ri: "jp", **org_normal_sign_in_binding_params)
    assert_equal 0, OperatorToken.where(staff_id: @staff.id).count
  end

  test "normal passkey binding refusal preserves safe requests and prevents replay artifacts" do
    begin
      admission_host = ENV.fetch("PUBLIC_AUTH_STAFF_URL")
      admission_sid = cookies["__Host-auth_sid"].presence || cookies["auth_sid"].presence
      admission_session = OperatorAuthCeremonySession.find_active_by_raw_sid(admission_sid) if admission_sid
      unless admission_session&.admitted? && admission_session.admission_purpose == "local_sign_in"
        admission_nonce = SecureRandom.urlsafe_base64(32)
        admission = BaseAuthAdmissionCoordinator.issue_local_entry!(
          surface: "org", intent: "sign_in", base_browser_nonce: admission_nonce, base_token: nil,
        )
        admission_binding = BaseAuthAdmissionCoordinator.find_admission_binding!(
          surface: "org",
          reference: admission.reference,
        )
        admission_session, admission_sid = OperatorAuthCeremonySession.issue!
        admission_binding.attach_auth_session!(auth_session: admission_session, confirmation_ref: SecureRandom.uuid)
        admission_binding.confirm_base!(
          base_token: nil,
          browser_digest: AuthAdmissionBinding.browser_digest(
            surface: "org",
            entry_ref: admission.reference,
            nonce: admission_nonce,
          ),
        )
        host!(admission_host)
        https!
        admission_cookie_name = JitSessionCookieConfig.force_secure? ? "__Host-auth_sid" : "auth_sid"
        cookies.delete("auth_sid")
        cookies.delete("__Host-auth_sid")
        store_raw_cookies(
          cookies,
          "#{admission_cookie_name}=#{Rack::Utils.escape(admission_sid)}", URI.parse("https://#{admission_host}/"),
        )
        get auth_org_sign_in_path, params: { entry_ref: admission.reference, ri: "jp" }
        admission_form = response.parsed_body.at_css("form")
        raise RuntimeError, "Auth admission continuation is missing" unless admission_form

        admission_fields = admission_form.css("input[type='hidden']").to_h { |field| [field["name"], field["value"]] }
        post admission_form["action"], params: admission_fields,
                                       headers: {
                                         "Origin" => "https://#{admission_host}",
                                         "Sec-Fetch-Site" => "same-origin",
                                       }

        assert_response :see_other
      end
      complete_org_entra_first_stage!(@staff)
    end

    get new_auth_org_sign_in_passkey_url(ri: "jp", **org_normal_sign_in_binding_params)

    assert_response :success
    assert_equal "auth/org/sign/in/passkeys/new", inertia_component

    panel = inertia_props.fetch("panel")

    # The Entra transaction names the operator, so the page asks for no identifier.
    assert_equal [nil, nil], [panel.fetch("field"), panel.fetch("identifier_param")]
    options_uri = URI.parse(panel.fetch("options_url"))
    verification_uri = URI.parse(panel.fetch("verification_url"))

    assert_equal "/sign/in/passkey/options", options_uri.path
    assert_equal "/sign/in/passkey/verification", verification_uri.path
    assert_equal "jp", Rack::Utils.parse_nested_query(options_uri.query).fetch("ri")
    assert_equal "jp", Rack::Utils.parse_nested_query(verification_uri.query).fetch("ri")
    assert_equal "org", OrgNormalSignInBindingCodec.decode(
      Rack::Utils.parse_nested_query(options_uri.query).fetch("fb"),
    ).surface
    assert_equal "org", OrgNormalSignInBindingCodec.decode(
      Rack::Utils.parse_nested_query(verification_uri.query).fetch("fb"),
    ).surface
    assert_equal "jp", panel.fetch("region")
    assert_nil inertia_props["secret_link"]

    transaction = session.fetch(OrgNormalSignInTransaction::SESSION_KEY).deep_dup
    stale_binding = OrgNormalSignInBindingCodec.encode(
      transaction: transaction.merge("issued_at" => transaction.fetch("issued_at") - 1),
      surface: "org", phase: "PRIMARY_PENDING",
    )
    token_count = OperatorToken.count

    assert_nil session[:passkey_challenges]

    [nil, "", "invalid-binding", stale_binding].each do |binding|
      get new_auth_org_sign_in_passkey_path, params: { ri: "jp", fb: binding }

      assert_equal(
        { status: 409, media_type: "text/plain", body: "戻るはだめです", location: nil, no_store: true },
        {
          status: response.status,
          media_type: response.media_type,
          body: response.body,
          location: response.headers["Location"],
          no_store: response.headers["Cache-Control"].include?("no-store"),
        },
      )
      assert_equal transaction, session.fetch(OrgNormalSignInTransaction::SESSION_KEY)

      head new_auth_org_sign_in_passkey_path, params: { ri: "jp", fb: binding }

      assert_response :conflict
      assert_equal ["", nil], [response.body, response.headers["Location"]]
      assert_includes response.headers["Cache-Control"], "no-store"
      assert_equal transaction, session.fetch(OrgNormalSignInTransaction::SESSION_KEY)
    end

    assert_equal token_count, OperatorToken.count
    assert_nil session[:passkey_challenges]

    post auth_org_sign_in_passkey_options_path, params: { ri: "jp", fb: stale_binding }

    assert_response :conflict
    assert_equal "戻るはだめです", response.body
    halted_transaction = session.fetch(OrgNormalSignInTransaction::SESSION_KEY).deep_dup

    assert_equal "halted", halted_transaction.fetch("status")
    assert_equal "phase_violation", halted_transaction.fetch("halt_reason")
    assert_equal token_count, OperatorToken.count
    assert_nil session[:passkey_challenges]

    post auth_org_sign_in_passkey_options_path, params: { ri: "jp", fb: stale_binding }

    assert_equal token_count, OperatorToken.count
    assert_nil session[:passkey_challenges]
    # The user deferred the missing durable audit for this delivery on 2026-10-13.
    # Restore its positive assertion with plans/backlog/org-normal-sign-in-durable-halt-audit.md.
  end

  test "new sends the operator back to the entry when no entra transaction is pending" do
    get new_auth_org_sign_in_passkey_url(ri: "jp", **org_normal_sign_in_binding_params)

    assert_response :bad_request
  end

  test "options are refused without a pending entra transaction" do
    post auth_org_sign_in_passkey_options_url(ri: "jp", **org_normal_sign_in_binding_params),
         params: { identifier: @staff.public_id }

    assert_response :bad_request
    assert_equal I18n.t("errors.messages.invalid_request"), response.body
    assert_nil session[:passkey_challenges]
  end

  test "verification is refused without a pending entra transaction" do
    post auth_org_sign_in_passkey_verification_url(ri: "jp", **org_normal_sign_in_binding_params),
         params: { challenge_id: "anything" }

    assert_response :bad_request
    assert_equal I18n.t("errors.messages.invalid_request"), response.body
  end

  test "options bind the challenge to the entra-selected operator and ignore a submitted identifier" do
    other_staff = operators(:two)
    other_staff.update!(status_id: OperatorStatus::ACTIVE)
    begin
      admission_host = ENV.fetch("PUBLIC_AUTH_STAFF_URL")
      admission_sid = cookies["__Host-auth_sid"].presence || cookies["auth_sid"].presence
      admission_session = OperatorAuthCeremonySession.find_active_by_raw_sid(admission_sid) if admission_sid
      unless admission_session&.admitted? && admission_session.admission_purpose == "local_sign_in"
        admission_nonce = SecureRandom.urlsafe_base64(32)
        admission = BaseAuthAdmissionCoordinator.issue_local_entry!(
          surface: "org", intent: "sign_in", base_browser_nonce: admission_nonce, base_token: nil,
        )
        admission_binding = BaseAuthAdmissionCoordinator.find_admission_binding!(
          surface: "org",
          reference: admission.reference,
        )
        admission_session, admission_sid = OperatorAuthCeremonySession.issue!
        admission_binding.attach_auth_session!(auth_session: admission_session, confirmation_ref: SecureRandom.uuid)
        admission_binding.confirm_base!(
          base_token: nil,
          browser_digest: AuthAdmissionBinding.browser_digest(
            surface: "org",
            entry_ref: admission.reference,
            nonce: admission_nonce,
          ),
        )
        host!(admission_host)
        https!
        admission_cookie_name = JitSessionCookieConfig.force_secure? ? "__Host-auth_sid" : "auth_sid"
        cookies.delete("auth_sid")
        cookies.delete("__Host-auth_sid")
        store_raw_cookies(
          cookies,
          "#{admission_cookie_name}=#{Rack::Utils.escape(admission_sid)}", URI.parse("https://#{admission_host}/"),
        )
        get auth_org_sign_in_path, params: { entry_ref: admission.reference, ri: "jp" }
        admission_form = response.parsed_body.at_css("form")
        raise RuntimeError, "Auth admission continuation is missing" unless admission_form

        admission_fields = admission_form.css("input[type='hidden']").to_h { |field| [field["name"], field["value"]] }
        post admission_form["action"], params: admission_fields,
                                       headers: {
                                         "Origin" => "https://#{admission_host}",
                                         "Sec-Fetch-Site" => "same-origin",
                                       }

        assert_response :see_other
      end
      complete_org_entra_first_stage!(@staff)
    end

    post auth_org_sign_in_passkey_options_url(ri: "jp", **org_normal_sign_in_binding_params),
         params: { identifier: other_staff.public_id }

    assert_response :ok
    json = response.parsed_body
    challenge = session[:passkey_challenges].fetch(json.fetch("challenge_id"))

    assert_equal "authentication", challenge["purpose"]
    assert_equal "org:#{@staff.id}", challenge["actor_global_key"]
    assert(
      json.dig("options", "allowCredentials").any? { |c| c["id"] == @staff_passkey.webauthn_id },
      "expected the Entra-selected operator's credential, not the submitted identifier's",
    )
  end

  test "verification returns error if challenge_id blank" do
    begin
      admission_host = ENV.fetch("PUBLIC_AUTH_STAFF_URL")
      admission_sid = cookies["__Host-auth_sid"].presence || cookies["auth_sid"].presence
      admission_session = OperatorAuthCeremonySession.find_active_by_raw_sid(admission_sid) if admission_sid
      unless admission_session&.admitted? && admission_session.admission_purpose == "local_sign_in"
        admission_nonce = SecureRandom.urlsafe_base64(32)
        admission = BaseAuthAdmissionCoordinator.issue_local_entry!(
          surface: "org", intent: "sign_in", base_browser_nonce: admission_nonce, base_token: nil,
        )
        admission_binding = BaseAuthAdmissionCoordinator.find_admission_binding!(
          surface: "org",
          reference: admission.reference,
        )
        admission_session, admission_sid = OperatorAuthCeremonySession.issue!
        admission_binding.attach_auth_session!(auth_session: admission_session, confirmation_ref: SecureRandom.uuid)
        admission_binding.confirm_base!(
          base_token: nil,
          browser_digest: AuthAdmissionBinding.browser_digest(
            surface: "org",
            entry_ref: admission.reference,
            nonce: admission_nonce,
          ),
        )
        host!(admission_host)
        https!
        admission_cookie_name = JitSessionCookieConfig.force_secure? ? "__Host-auth_sid" : "auth_sid"
        cookies.delete("auth_sid")
        cookies.delete("__Host-auth_sid")
        store_raw_cookies(
          cookies,
          "#{admission_cookie_name}=#{Rack::Utils.escape(admission_sid)}", URI.parse("https://#{admission_host}/"),
        )
        get auth_org_sign_in_path, params: { entry_ref: admission.reference, ri: "jp" }
        admission_form = response.parsed_body.at_css("form")
        raise RuntimeError, "Auth admission continuation is missing" unless admission_form

        admission_fields = admission_form.css("input[type='hidden']").to_h { |field| [field["name"], field["value"]] }
        post admission_form["action"], params: admission_fields,
                                       headers: {
                                         "Origin" => "https://#{admission_host}",
                                         "Sec-Fetch-Site" => "same-origin",
                                       }

        assert_response :see_other
      end
      complete_org_entra_first_stage!(@staff)
    end

    post auth_org_sign_in_passkey_verification_url(ri: "jp", **org_normal_sign_in_binding_params),
         params: { challenge_id: "" }

    assert_response :bad_request
    assert_includes response.body, I18n.t("errors.webauthn.challenge_id_required")
  end

  test "verification returns error if challenge invalid" do
    begin
      admission_host = ENV.fetch("PUBLIC_AUTH_STAFF_URL")
      admission_sid = cookies["__Host-auth_sid"].presence || cookies["auth_sid"].presence
      admission_session = OperatorAuthCeremonySession.find_active_by_raw_sid(admission_sid) if admission_sid
      unless admission_session&.admitted? && admission_session.admission_purpose == "local_sign_in"
        admission_nonce = SecureRandom.urlsafe_base64(32)
        admission = BaseAuthAdmissionCoordinator.issue_local_entry!(
          surface: "org", intent: "sign_in", base_browser_nonce: admission_nonce, base_token: nil,
        )
        admission_binding = BaseAuthAdmissionCoordinator.find_admission_binding!(
          surface: "org",
          reference: admission.reference,
        )
        admission_session, admission_sid = OperatorAuthCeremonySession.issue!
        admission_binding.attach_auth_session!(auth_session: admission_session, confirmation_ref: SecureRandom.uuid)
        admission_binding.confirm_base!(
          base_token: nil,
          browser_digest: AuthAdmissionBinding.browser_digest(
            surface: "org",
            entry_ref: admission.reference,
            nonce: admission_nonce,
          ),
        )
        host!(admission_host)
        https!
        admission_cookie_name = JitSessionCookieConfig.force_secure? ? "__Host-auth_sid" : "auth_sid"
        cookies.delete("auth_sid")
        cookies.delete("__Host-auth_sid")
        store_raw_cookies(
          cookies,
          "#{admission_cookie_name}=#{Rack::Utils.escape(admission_sid)}", URI.parse("https://#{admission_host}/"),
        )
        get auth_org_sign_in_path, params: { entry_ref: admission.reference, ri: "jp" }
        admission_form = response.parsed_body.at_css("form")
        raise RuntimeError, "Auth admission continuation is missing" unless admission_form

        admission_fields = admission_form.css("input[type='hidden']").to_h { |field| [field["name"], field["value"]] }
        post admission_form["action"], params: admission_fields,
                                       headers: {
                                         "Origin" => "https://#{admission_host}",
                                         "Sec-Fetch-Site" => "same-origin",
                                       }

        assert_response :see_other
      end
      complete_org_entra_first_stage!(@staff)
    end

    post auth_org_sign_in_passkey_verification_url(ri: "jp", **org_normal_sign_in_binding_params),
         params: { challenge_id: "invalid_challenge" }

    assert_response :bad_request
    assert_includes response.body, I18n.t("errors.webauthn.challenge_invalid")
  end

  test "verification returns bad request on challenge purpose mismatch" do
    begin
      admission_host = ENV.fetch("PUBLIC_AUTH_STAFF_URL")
      admission_sid = cookies["__Host-auth_sid"].presence || cookies["auth_sid"].presence
      admission_session = OperatorAuthCeremonySession.find_active_by_raw_sid(admission_sid) if admission_sid
      unless admission_session&.admitted? && admission_session.admission_purpose == "local_sign_in"
        admission_nonce = SecureRandom.urlsafe_base64(32)
        admission = BaseAuthAdmissionCoordinator.issue_local_entry!(
          surface: "org", intent: "sign_in", base_browser_nonce: admission_nonce, base_token: nil,
        )
        admission_binding = BaseAuthAdmissionCoordinator.find_admission_binding!(
          surface: "org",
          reference: admission.reference,
        )
        admission_session, admission_sid = OperatorAuthCeremonySession.issue!
        admission_binding.attach_auth_session!(auth_session: admission_session, confirmation_ref: SecureRandom.uuid)
        admission_binding.confirm_base!(
          base_token: nil,
          browser_digest: AuthAdmissionBinding.browser_digest(
            surface: "org",
            entry_ref: admission.reference,
            nonce: admission_nonce,
          ),
        )
        host!(admission_host)
        https!
        admission_cookie_name = JitSessionCookieConfig.force_secure? ? "__Host-auth_sid" : "auth_sid"
        cookies.delete("auth_sid")
        cookies.delete("__Host-auth_sid")
        store_raw_cookies(
          cookies,
          "#{admission_cookie_name}=#{Rack::Utils.escape(admission_sid)}", URI.parse("https://#{admission_host}/"),
        )
        get auth_org_sign_in_path, params: { entry_ref: admission.reference, ri: "jp" }
        admission_form = response.parsed_body.at_css("form")
        raise RuntimeError, "Auth admission continuation is missing" unless admission_form

        admission_fields = admission_form.css("input[type='hidden']").to_h { |field| [field["name"], field["value"]] }
        post admission_form["action"], params: admission_fields,
                                       headers: {
                                         "Origin" => "https://#{admission_host}",
                                         "Sec-Fetch-Site" => "same-origin",
                                       }

        assert_response :see_other
      end
      complete_org_entra_first_stage!(@staff)
    end
    challenge_id = issue_challenge!
    mismatch_error = Webauthn::ChallengeStore::ChallengePurposeMismatchError.new("purpose mismatch")

    original_method =
      Auth::Org::Sign::In::Passkey::VerificationsController
        .instance_method(:consume_passkey_challenge_with_actor!)
    Auth::Org::Sign::In::Passkey::VerificationsController
      .define_method(:consume_passkey_challenge_with_actor!) do |*_args, **_kwargs|
      raise mismatch_error
    end

    begin
      post(
        auth_org_sign_in_passkey_verification_url(ri: "jp", **org_normal_sign_in_binding_params),
        params: verification_params(challenge_id),
      )
    ensure
      Auth::Org::Sign::In::Passkey::VerificationsController
        .define_method(:consume_passkey_challenge_with_actor!, original_method)
    end

    assert_response :bad_request
    assert_includes response.body, I18n.t("errors.webauthn.challenge_invalid")
  end

  test "verification records evidence without establishing an Auth session" do
    begin
      admission_host = ENV.fetch("PUBLIC_AUTH_STAFF_URL")
      admission_sid = cookies["__Host-auth_sid"].presence || cookies["auth_sid"].presence
      admission_session = OperatorAuthCeremonySession.find_active_by_raw_sid(admission_sid) if admission_sid
      unless admission_session&.admitted? && admission_session.admission_purpose == "local_sign_in"
        admission_nonce = SecureRandom.urlsafe_base64(32)
        admission = BaseAuthAdmissionCoordinator.issue_local_entry!(
          surface: "org", intent: "sign_in", base_browser_nonce: admission_nonce, base_token: nil,
        )
        admission_binding = BaseAuthAdmissionCoordinator.find_admission_binding!(
          surface: "org",
          reference: admission.reference,
        )
        admission_session, admission_sid = OperatorAuthCeremonySession.issue!
        admission_binding.attach_auth_session!(auth_session: admission_session, confirmation_ref: SecureRandom.uuid)
        admission_binding.confirm_base!(
          base_token: nil,
          browser_digest: AuthAdmissionBinding.browser_digest(
            surface: "org",
            entry_ref: admission.reference,
            nonce: admission_nonce,
          ),
        )
        host!(admission_host)
        https!
        admission_cookie_name = JitSessionCookieConfig.force_secure? ? "__Host-auth_sid" : "auth_sid"
        cookies.delete("auth_sid")
        cookies.delete("__Host-auth_sid")
        store_raw_cookies(
          cookies,
          "#{admission_cookie_name}=#{Rack::Utils.escape(admission_sid)}", URI.parse("https://#{admission_host}/"),
        )
        get auth_org_sign_in_path, params: { entry_ref: admission.reference, ri: "jp" }
        admission_form = response.parsed_body.at_css("form")
        raise RuntimeError, "Auth admission continuation is missing" unless admission_form

        admission_fields = admission_form.css("input[type='hidden']").to_h { |field| [field["name"], field["value"]] }
        post admission_form["action"], params: admission_fields,
                                       headers: {
                                         "Origin" => "https://#{admission_host}",
                                         "Sec-Fetch-Site" => "same-origin",
                                       }

        assert_response :see_other
      end
      complete_org_entra_first_stage!(@staff)
    end
    challenge_id = issue_challenge!

    Time.current

    post(
      auth_org_sign_in_passkey_verification_url(
        ri: "jp", pt: "/settings/passkeys", **org_normal_sign_in_binding_params,
      ),
      params: verification_params(challenge_id),
    )

    assert_response :ok
    json = response.parsed_body

    assert_equal "ok", json["status"]
    assert_nil json["access_token"]
    assert_nil json["token_type"]
    assert_nil json["expires_in"]
    redirect_uri = URI.parse(json.fetch("redirect_url"))

    assert_equal URI.parse(auth_org_sign_in_check_path).path, redirect_uri.path
    binding = SignInFlowBindingCodec.decode(
      Rack::Utils.parse_nested_query(redirect_uri.query.to_s).fetch("fb"),
    )

    assert_equal "org", binding.surface
    assert_equal "CHECKPOINT_PENDING", binding.phase

    assert_equal 1, @staff_passkey.reload.sign_count
    assert_not_nil @staff_passkey.reload.last_used_at

    assert_empty OperatorToken.where(staff_id: @staff.id)
  end

  test "the pending transaction is one-shot: a replayed second stage has nothing to continue" do
    begin
      admission_host = ENV.fetch("PUBLIC_AUTH_STAFF_URL")
      admission_sid = cookies["__Host-auth_sid"].presence || cookies["auth_sid"].presence
      admission_session = OperatorAuthCeremonySession.find_active_by_raw_sid(admission_sid) if admission_sid
      unless admission_session&.admitted? && admission_session.admission_purpose == "local_sign_in"
        admission_nonce = SecureRandom.urlsafe_base64(32)
        admission = BaseAuthAdmissionCoordinator.issue_local_entry!(
          surface: "org", intent: "sign_in", base_browser_nonce: admission_nonce, base_token: nil,
        )
        admission_binding = BaseAuthAdmissionCoordinator.find_admission_binding!(
          surface: "org",
          reference: admission.reference,
        )
        admission_session, admission_sid = OperatorAuthCeremonySession.issue!
        admission_binding.attach_auth_session!(auth_session: admission_session, confirmation_ref: SecureRandom.uuid)
        admission_binding.confirm_base!(
          base_token: nil,
          browser_digest: AuthAdmissionBinding.browser_digest(
            surface: "org",
            entry_ref: admission.reference,
            nonce: admission_nonce,
          ),
        )
        host!(admission_host)
        https!
        admission_cookie_name = JitSessionCookieConfig.force_secure? ? "__Host-auth_sid" : "auth_sid"
        cookies.delete("auth_sid")
        cookies.delete("__Host-auth_sid")
        store_raw_cookies(
          cookies,
          "#{admission_cookie_name}=#{Rack::Utils.escape(admission_sid)}", URI.parse("https://#{admission_host}/"),
        )
        get auth_org_sign_in_path, params: { entry_ref: admission.reference, ri: "jp" }
        admission_form = response.parsed_body.at_css("form")
        raise RuntimeError, "Auth admission continuation is missing" unless admission_form

        admission_fields = admission_form.css("input[type='hidden']").to_h { |field| [field["name"], field["value"]] }
        post admission_form["action"], params: admission_fields,
                                       headers: {
                                         "Origin" => "https://#{admission_host}",
                                         "Sec-Fetch-Site" => "same-origin",
                                       }

        assert_response :see_other
      end
      complete_org_entra_first_stage!(@staff)
    end
    challenge_id = issue_challenge!

    post auth_org_sign_in_passkey_verification_url(ri: "jp", **org_normal_sign_in_binding_params),
         params: verification_params(challenge_id)

    assert_response :ok

    # The credential ceremony is one-shot; the consumed/cleared transaction has
    # no second-stage challenge to replay.
    post auth_org_sign_in_passkey_options_url(ri: "jp", **org_normal_sign_in_binding_params), params: {}

    assert_response :unprocessable_content
    assert_includes response.headers["Cache-Control"], "no-store"
    assert_nil session[OrgNormalSignInTransaction::SESSION_KEY]
  end

  test "a credential belonging to another operator is refused after the entra stage" do
    begin
      admission_host = ENV.fetch("PUBLIC_AUTH_STAFF_URL")
      admission_sid = cookies["__Host-auth_sid"].presence || cookies["auth_sid"].presence
      admission_session = OperatorAuthCeremonySession.find_active_by_raw_sid(admission_sid) if admission_sid
      unless admission_session&.admitted? && admission_session.admission_purpose == "local_sign_in"
        admission_nonce = SecureRandom.urlsafe_base64(32)
        admission = BaseAuthAdmissionCoordinator.issue_local_entry!(
          surface: "org", intent: "sign_in", base_browser_nonce: admission_nonce, base_token: nil,
        )
        admission_binding = BaseAuthAdmissionCoordinator.find_admission_binding!(
          surface: "org",
          reference: admission.reference,
        )
        admission_session, admission_sid = OperatorAuthCeremonySession.issue!
        admission_binding.attach_auth_session!(auth_session: admission_session, confirmation_ref: SecureRandom.uuid)
        admission_binding.confirm_base!(
          base_token: nil,
          browser_digest: AuthAdmissionBinding.browser_digest(
            surface: "org",
            entry_ref: admission.reference,
            nonce: admission_nonce,
          ),
        )
        host!(admission_host)
        https!
        admission_cookie_name = JitSessionCookieConfig.force_secure? ? "__Host-auth_sid" : "auth_sid"
        cookies.delete("auth_sid")
        cookies.delete("__Host-auth_sid")
        store_raw_cookies(
          cookies,
          "#{admission_cookie_name}=#{Rack::Utils.escape(admission_sid)}", URI.parse("https://#{admission_host}/"),
        )
        get auth_org_sign_in_path, params: { entry_ref: admission.reference, ri: "jp" }
        admission_form = response.parsed_body.at_css("form")
        raise RuntimeError, "Auth admission continuation is missing" unless admission_form

        admission_fields = admission_form.css("input[type='hidden']").to_h { |field| [field["name"], field["value"]] }
        post admission_form["action"], params: admission_fields,
                                       headers: {
                                         "Origin" => "https://#{admission_host}",
                                         "Sec-Fetch-Site" => "same-origin",
                                       }

        assert_response :see_other
      end
      complete_org_entra_first_stage!(@staff)
    end
    challenge_id = issue_challenge!

    other_staff = operators(:two)
    other_staff.update!(status_id: OperatorStatus::ACTIVE)
    other_passkey = OperatorPasskey.create!(
      staff: other_staff,
      webauthn_id: Base64.urlsafe_encode64("other_staff_key_#{SecureRandom.hex(4)}", padding: false),
      external_id: SecureRandom.uuid,
      public_key: "other_staff_key",
      description: "Other Staff Key",
      status_id: OperatorPasskeyStatus::ACTIVE,
    )
    tokens_before = OperatorToken.where(staff_id: other_staff.id).count

    post auth_org_sign_in_passkey_verification_url(ri: "jp", **org_normal_sign_in_binding_params),
         params: verification_params(challenge_id, credential_id: other_passkey.webauthn_id)

    assert_response :unauthorized
    assert_includes response.body, I18n.t("errors.webauthn.verification_failed")
    assert_equal tokens_before, OperatorToken.where(staff_id: other_staff.id).count
  end

  test "verification returns unauthorized for credential mismatch" do
    begin
      admission_host = ENV.fetch("PUBLIC_AUTH_STAFF_URL")
      admission_sid = cookies["__Host-auth_sid"].presence || cookies["auth_sid"].presence
      admission_session = OperatorAuthCeremonySession.find_active_by_raw_sid(admission_sid) if admission_sid
      unless admission_session&.admitted? && admission_session.admission_purpose == "local_sign_in"
        admission_nonce = SecureRandom.urlsafe_base64(32)
        admission = BaseAuthAdmissionCoordinator.issue_local_entry!(
          surface: "org", intent: "sign_in", base_browser_nonce: admission_nonce, base_token: nil,
        )
        admission_binding = BaseAuthAdmissionCoordinator.find_admission_binding!(
          surface: "org",
          reference: admission.reference,
        )
        admission_session, admission_sid = OperatorAuthCeremonySession.issue!
        admission_binding.attach_auth_session!(auth_session: admission_session, confirmation_ref: SecureRandom.uuid)
        admission_binding.confirm_base!(
          base_token: nil,
          browser_digest: AuthAdmissionBinding.browser_digest(
            surface: "org",
            entry_ref: admission.reference,
            nonce: admission_nonce,
          ),
        )
        host!(admission_host)
        https!
        admission_cookie_name = JitSessionCookieConfig.force_secure? ? "__Host-auth_sid" : "auth_sid"
        cookies.delete("auth_sid")
        cookies.delete("__Host-auth_sid")
        store_raw_cookies(
          cookies,
          "#{admission_cookie_name}=#{Rack::Utils.escape(admission_sid)}", URI.parse("https://#{admission_host}/"),
        )
        get auth_org_sign_in_path, params: { entry_ref: admission.reference, ri: "jp" }
        admission_form = response.parsed_body.at_css("form")
        raise RuntimeError, "Auth admission continuation is missing" unless admission_form

        admission_fields = admission_form.css("input[type='hidden']").to_h { |field| [field["name"], field["value"]] }
        post admission_form["action"], params: admission_fields,
                                       headers: {
                                         "Origin" => "https://#{admission_host}",
                                         "Sec-Fetch-Site" => "same-origin",
                                       }

        assert_response :see_other
      end
      complete_org_entra_first_stage!(@staff)
    end
    challenge_id = issue_challenge!

    post auth_org_sign_in_passkey_verification_url(ri: "jp", **org_normal_sign_in_binding_params),
         params: verification_params(
           challenge_id,
           credential_id: Base64.urlsafe_encode64("unknown_credential", padding: false),
         )

    assert_response :unauthorized
    assert_includes response.body, I18n.t("errors.webauthn.verification_failed")
  end

  test "verification returns 422 when login result status is unknown" do
    begin
      admission_host = ENV.fetch("PUBLIC_AUTH_STAFF_URL")
      admission_sid = cookies["__Host-auth_sid"].presence || cookies["auth_sid"].presence
      admission_session = OperatorAuthCeremonySession.find_active_by_raw_sid(admission_sid) if admission_sid
      unless admission_session&.admitted? && admission_session.admission_purpose == "local_sign_in"
        admission_nonce = SecureRandom.urlsafe_base64(32)
        admission = BaseAuthAdmissionCoordinator.issue_local_entry!(
          surface: "org", intent: "sign_in", base_browser_nonce: admission_nonce, base_token: nil,
        )
        admission_binding = BaseAuthAdmissionCoordinator.find_admission_binding!(
          surface: "org",
          reference: admission.reference,
        )
        admission_session, admission_sid = OperatorAuthCeremonySession.issue!
        admission_binding.attach_auth_session!(auth_session: admission_session, confirmation_ref: SecureRandom.uuid)
        admission_binding.confirm_base!(
          base_token: nil,
          browser_digest: AuthAdmissionBinding.browser_digest(
            surface: "org",
            entry_ref: admission.reference,
            nonce: admission_nonce,
          ),
        )
        host!(admission_host)
        https!
        admission_cookie_name = JitSessionCookieConfig.force_secure? ? "__Host-auth_sid" : "auth_sid"
        cookies.delete("auth_sid")
        cookies.delete("__Host-auth_sid")
        store_raw_cookies(
          cookies,
          "#{admission_cookie_name}=#{Rack::Utils.escape(admission_sid)}", URI.parse("https://#{admission_host}/"),
        )
        get auth_org_sign_in_path, params: { entry_ref: admission.reference, ri: "jp" }
        admission_form = response.parsed_body.at_css("form")
        raise RuntimeError, "Auth admission continuation is missing" unless admission_form

        admission_fields = admission_form.css("input[type='hidden']").to_h { |field| [field["name"], field["value"]] }
        post admission_form["action"], params: admission_fields,
                                       headers: {
                                         "Origin" => "https://#{admission_host}",
                                         "Sec-Fetch-Site" => "same-origin",
                                       }

        assert_response :see_other
      end
      complete_org_entra_first_stage!(@staff)
    end
    challenge_id = issue_challenge!

    original_method = Auth::Org::Sign::In::Passkey::VerificationsController.instance_method(:perform_passkey_sign_in)
    Auth::Org::Sign::In::Passkey::VerificationsController.define_method(:perform_passkey_sign_in) do |*_args|
      { status: :unknown_status }
    end

    begin
      post(
        auth_org_sign_in_passkey_verification_url(ri: "jp", **org_normal_sign_in_binding_params),
        params: verification_params(challenge_id),
      )
    ensure
      Auth::Org::Sign::In::Passkey::VerificationsController.define_method(:perform_passkey_sign_in, original_method)
    end

    assert_response :unprocessable_content
    assert_includes response.body, I18n.t("errors.login_failed")
  end

  test "verification for staff with mfa enabled succeeds (MFA not enforced for staff)" do
    @staff.reload.update!(mfa_level_enabled: true)
    begin
      admission_host = ENV.fetch("PUBLIC_AUTH_STAFF_URL")
      admission_sid = cookies["__Host-auth_sid"].presence || cookies["auth_sid"].presence
      admission_session = OperatorAuthCeremonySession.find_active_by_raw_sid(admission_sid) if admission_sid
      unless admission_session&.admitted? && admission_session.admission_purpose == "local_sign_in"
        admission_nonce = SecureRandom.urlsafe_base64(32)
        admission = BaseAuthAdmissionCoordinator.issue_local_entry!(
          surface: "org", intent: "sign_in", base_browser_nonce: admission_nonce, base_token: nil,
        )
        admission_binding = BaseAuthAdmissionCoordinator.find_admission_binding!(
          surface: "org",
          reference: admission.reference,
        )
        admission_session, admission_sid = OperatorAuthCeremonySession.issue!
        admission_binding.attach_auth_session!(auth_session: admission_session, confirmation_ref: SecureRandom.uuid)
        admission_binding.confirm_base!(
          base_token: nil,
          browser_digest: AuthAdmissionBinding.browser_digest(
            surface: "org",
            entry_ref: admission.reference,
            nonce: admission_nonce,
          ),
        )
        host!(admission_host)
        https!
        admission_cookie_name = JitSessionCookieConfig.force_secure? ? "__Host-auth_sid" : "auth_sid"
        cookies.delete("auth_sid")
        cookies.delete("__Host-auth_sid")
        store_raw_cookies(
          cookies,
          "#{admission_cookie_name}=#{Rack::Utils.escape(admission_sid)}", URI.parse("https://#{admission_host}/"),
        )
        get auth_org_sign_in_path, params: { entry_ref: admission.reference, ri: "jp" }
        admission_form = response.parsed_body.at_css("form")
        raise RuntimeError, "Auth admission continuation is missing" unless admission_form

        admission_fields = admission_form.css("input[type='hidden']").to_h { |field| [field["name"], field["value"]] }
        post admission_form["action"], params: admission_fields,
                                       headers: {
                                         "Origin" => "https://#{admission_host}",
                                         "Sec-Fetch-Site" => "same-origin",
                                       }

        assert_response :see_other
      end
      complete_org_entra_first_stage!(@staff)
    end
    challenge_id = issue_challenge!

    post auth_org_sign_in_passkey_verification_url(ri: "jp", **org_normal_sign_in_binding_params),
         params: verification_params(challenge_id)

    assert_response :ok
    assert_equal "ok", response.parsed_body["status"]
  end

  test "verification hands an at-limit local result to Base for durable resolution" do
    base_browser = open_session
    base_browser.host!(ENV.fetch("PUBLIC_BASE_STAFF_URL"))
    base_browser.https!
    base_browser.post("/sign", params: { ri: "jp" })
    # The authorize endpoint shares this origin, so the start moves by path without a Jump rt.
    authorization = URI.parse(base_browser.response.location)

    assert_equal ENV.fetch("PUBLIC_BASE_STAFF_URL"), authorization.host
    assert_nil Rack::Utils.parse_query(authorization.query)["rt"]
    base_browser.get(authorization.request_uri)
    authorization_form = base_browser.response.parsed_body.at_css("form#base-authorization-ceremony-start-form")
    fields = authorization_form.css("input[name]").to_h { |input| [input["name"], input["value"]] }
    base_browser.post(
      authorization_form["action"], params: fields,
                                    headers: { "Origin" => "https://#{ENV.fetch("PUBLIC_BASE_STAFF_URL")}" },
    )

    assert_equal 303, base_browser.response.status
    original_base_nonce = base_browser.session.fetch(BaseAdmissionBrowserBinding::BROWSER_NONCE_SESSION_KEY)
    base_request = base_browser.request
    base_session = base_browser.session.to_hash
    host! ENV.fetch("PUBLIC_AUTH_STAFF_URL")
    create_rotated_active_staff_session(@staff, rotations: 4)
    begin
      admission_host = ENV.fetch("PUBLIC_AUTH_STAFF_URL")
      admission_sid = cookies["__Host-auth_sid"].presence || cookies["auth_sid"].presence
      admission_session = OperatorAuthCeremonySession.find_active_by_raw_sid(admission_sid) if admission_sid
      unless admission_session&.admitted? && admission_session.admission_purpose == "local_sign_in"
        admission_nonce = original_base_nonce
        flow_nonce = SecureRandom.urlsafe_base64(SignInCycleLocator::NONCE_BYTES)
        admission = BaseAuthAdmissionCoordinator.issue_local_entry!(
          surface: "org", intent: "sign_in", base_browser_nonce: admission_nonce, base_token: nil,
          nonce_digest: OperatorSignInFlow.digest_nonce(flow_nonce),
        )
        SignInCycleLocator.new(base_session, surface: "org").issue!(admission.transaction, nonce: flow_nonce)
        session_key = JitSessionCookieConfig.cookie_key(force_secure: JitSessionCookieConfig.force_secure?)
        jar = ActionDispatch::Cookies::CookieJar.build(base_request, base_request.cookies)
        jar.encrypted[session_key] = { value: base_session.stringify_keys }
        base_browser.cookies.delete(session_key)
        _merged_cookies = base_browser.cookies.merge(
          "#{session_key}=#{Rack::Utils.escape(jar[session_key])}",
          URI.parse("https://#{ENV.fetch("PUBLIC_BASE_STAFF_URL")}/"),
        )
        admission_binding = BaseAuthAdmissionCoordinator.find_admission_binding!(
          surface: "org",
          reference: admission.reference,
        )
        admission_session, admission_sid = OperatorAuthCeremonySession.issue!
        admission_binding.attach_auth_session!(auth_session: admission_session, confirmation_ref: SecureRandom.uuid)
        admission_binding.confirm_base!(
          base_token: nil,
          browser_digest: AuthAdmissionBinding.browser_digest(
            surface: "org",
            entry_ref: admission.reference,
            nonce: admission_nonce,
          ),
        )
        host!(admission_host)
        https!
        admission_cookie_name = JitSessionCookieConfig.force_secure? ? "__Host-auth_sid" : "auth_sid"
        cookies.delete("auth_sid")
        cookies.delete("__Host-auth_sid")
        store_raw_cookies(
          cookies,
          "#{admission_cookie_name}=#{Rack::Utils.escape(admission_sid)}", URI.parse("https://#{admission_host}/"),
        )
        get auth_org_sign_in_path, params: { entry_ref: admission.reference, ri: "jp" }
        admission_form = response.parsed_body.at_css("form")
        raise RuntimeError, "Auth admission continuation is missing" unless admission_form

        admission_fields = admission_form.css("input[type='hidden']").to_h { |field| [field["name"], field["value"]] }
        post admission_form["action"], params: admission_fields,
                                       headers: {
                                         "Origin" => "https://#{admission_host}",
                                         "Sec-Fetch-Site" => "same-origin",
                                       }

        assert_response :see_other
      end
      complete_org_entra_first_stage!(@staff)
    end
    challenge_id = issue_challenge!

    post auth_org_sign_in_passkey_verification_url(ri: "jp", **org_normal_sign_in_binding_params),
         params: verification_params(challenge_id)

    assert_response :ok
    json = response.parsed_body

    assert_equal "ok", json["status"]
    assert_nil json["access_token"]

    get json.fetch("redirect_url")
    follow_redirect! if response.redirect?
    post auth_org_sign_handoff_path(ri: "jp"), params: { ri: "jp" }

    assert_response :see_other
    base_uri = URI.parse(response.location)
    base_browser.get(base_uri.request_uri)

    assert_equal 200, base_browser.response.status
    result_form = base_browser.response.parsed_body.at_css("form")
    result_fields = result_form.css("input[name]").to_h { |field| [field["name"], field["value"]] }
    base_browser.post(
      result_form["action"], params: result_fields,
                             headers: { "Origin" => "https://#{ENV.fetch("PUBLIC_BASE_STAFF_URL")}" },
    )

    assert_equal 303, base_browser.response.status
    base_browser.get(base_browser.response.location)

    assert_equal 200, base_browser.response.status
    page = JSON.parse(base_browser.response.parsed_body.at_css("script[data-page='app']").text)

    assert_equal "base/org/sign/in/limitations/show", page.fetch("component")
    flow = OperatorSignInFlow.where(principal_id: @staff.id).order(created_at: :desc).first

    assert_predicate flow, :sign_in_session_issuance_pending?
    assert_predicate OperatorSessionLimitResolutionTransaction.where(sign_in_flow_id: flow.id).first, :open?
  end

  test "verification returns unauthorized for malformed credential payload" do
    begin
      admission_host = ENV.fetch("PUBLIC_AUTH_STAFF_URL")
      admission_sid = cookies["__Host-auth_sid"].presence || cookies["auth_sid"].presence
      admission_session = OperatorAuthCeremonySession.find_active_by_raw_sid(admission_sid) if admission_sid
      unless admission_session&.admitted? && admission_session.admission_purpose == "local_sign_in"
        admission_nonce = SecureRandom.urlsafe_base64(32)
        admission = BaseAuthAdmissionCoordinator.issue_local_entry!(
          surface: "org", intent: "sign_in", base_browser_nonce: admission_nonce, base_token: nil,
        )
        admission_binding = BaseAuthAdmissionCoordinator.find_admission_binding!(
          surface: "org",
          reference: admission.reference,
        )
        admission_session, admission_sid = OperatorAuthCeremonySession.issue!
        admission_binding.attach_auth_session!(auth_session: admission_session, confirmation_ref: SecureRandom.uuid)
        admission_binding.confirm_base!(
          base_token: nil,
          browser_digest: AuthAdmissionBinding.browser_digest(
            surface: "org",
            entry_ref: admission.reference,
            nonce: admission_nonce,
          ),
        )
        host!(admission_host)
        https!
        admission_cookie_name = JitSessionCookieConfig.force_secure? ? "__Host-auth_sid" : "auth_sid"
        cookies.delete("auth_sid")
        cookies.delete("__Host-auth_sid")
        store_raw_cookies(
          cookies,
          "#{admission_cookie_name}=#{Rack::Utils.escape(admission_sid)}", URI.parse("https://#{admission_host}/"),
        )
        get auth_org_sign_in_path, params: { entry_ref: admission.reference, ri: "jp" }
        admission_form = response.parsed_body.at_css("form")
        raise RuntimeError, "Auth admission continuation is missing" unless admission_form

        admission_fields = admission_form.css("input[type='hidden']").to_h { |field| [field["name"], field["value"]] }
        post admission_form["action"], params: admission_fields,
                                       headers: {
                                         "Origin" => "https://#{admission_host}",
                                         "Sec-Fetch-Site" => "same-origin",
                                       }

        assert_response :see_other
      end
      complete_org_entra_first_stage!(@staff)
    end
    challenge_id = issue_challenge!

    post auth_org_sign_in_passkey_verification_url(ri: "jp", **org_normal_sign_in_binding_params), params: {
      challenge_id: challenge_id,
      credential: { invalid: "payload" },
    }

    assert_response :unauthorized
    assert_includes response.body, I18n.t("errors.webauthn.verification_failed")
  end

  private

  def issue_challenge!
    post(auth_org_sign_in_passkey_options_url(ri: "jp", **org_normal_sign_in_binding_params), params: {})

    assert_response :ok
    @challenge = response.parsed_body.fetch("options").fetch("challenge")
    response.parsed_body.fetch("challenge_id")
  end

  def verification_params(challenge_id, credential_id: @staff_passkey.webauthn_id)
    assertion = @fake.get(challenge: @challenge, user_verified: true, sign_count: @staff_passkey.reload.sign_count + 1)
    assertion["id"] = credential_id
    { challenge_id: challenge_id, credential: assertion }
  end

  def create_rotated_active_staff_session(staff, rotations:)
    token = OperatorToken.create!(staff: staff, staff_token_status_id: OperatorTokenStatus::ACTIVE)
    refresh = token.rotate_refresh_token!

    rotations.times do
      refresh = SignRefreshTokenIssuer.call(refresh_token: refresh)[:refresh_token]
    end
  end
end
