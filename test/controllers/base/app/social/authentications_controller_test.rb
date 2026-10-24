# typed: false
# frozen_string_literal: true

require "test_helper"

class Base::App::Social::AuthenticationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @previous_protection = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    @previous_cooldown = Rails.application.config.x.authentication.login_cooldown
    Rails.application.config.x.authentication.login_cooldown = 0.seconds
    OmniAuth.config.test_mode = true
    TurnstileVerifierStub.enabled = true
    TurnstileVerifierStub.challenge_enabled = true
    TurnstileVerifierStub.challenge_response = { "success" => true }
  end

  teardown do
    ActionController::Base.allow_forgery_protection = @previous_protection
    Rails.application.config.x.authentication.login_cooldown = @previous_cooldown
    OmniAuth.config.mock_auth[:google] = nil
    TurnstileVerifierStub.enabled = false
    TurnstileVerifierStub.challenge_enabled = false
    TurnstileVerifierStub.challenge_response = nil
  end

  test "completion provisions and completes the actual signup graph before Root issuance" do
    subject = "new-social-#{SecureRandom.hex(8)}"
    base = self
    auth = open_session
    base_host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    auth_host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    base_headers = { "Origin" => "https://#{base_host}", "Sec-Fetch-Site" => "same-origin" }
    auth_headers = { "Origin" => "https://#{auth_host}", "Sec-Fetch-Site" => "same-origin" }
    base.host!(base_host)
    base.https!
    base.get("/sign", params: { ri: "jp" })

    assert_equal 200, base.response.status
    entry_form = Nokogiri::HTML(base.response.body).at_css("form")
    entry_fields = entry_form.css("input[name]").to_h { |input| [input["name"], input["value"]] }
    base.post(entry_form["action"], params: entry_fields, headers: base_headers)

    assert_equal 303, base.response.status
    issuer = JitSecurityJwtRegistry.surface("BASE_APP")
    target = URI.parse(base.response.location)
    # A same-origin hop moves by path; only a cross-origin hop carries a Jump rt.
    unless target.host == base_host
      target = target
      # A same-origin hop moves by path; only a cross-origin hop carries a Jump rt.
      unless target.host == base_host
        rt = Rack::Utils.parse_query(target.query).fetch("rt")
        payload, = JWT.decode(
          rt, JitSecurityJwtRegistry.public_key_for(issuer.id, issuer.current_kid), true,
          algorithms: ["ES384"], verify_iss: true, iss: "https://#{base_host}",
          verify_aud: true, aud: Rails.configuration.x.boot_config.fetch(:jump).audience,
        )
        target = URI.parse(payload.fetch("url"))
      end
    end

    assert_equal base_host, target.host
    base.get(target.request_uri)
    authorization_form = Nokogiri::HTML(base.response.body).at_css("form#base-authorization-ceremony-start-form")
    authorization_fields = authorization_form.css("input[name]").to_h { |input| [input["name"], input["value"]] }
    base.post(authorization_form["action"], params: authorization_fields, headers: base_headers)

    assert_equal 303, base.response.status
    auth_target = URI.parse(base.response.location)
    # A same-origin hop moves by path; only a cross-origin hop carries a Jump rt.
    unless auth_target.host == base_host
      auth_target = auth_target
      # A same-origin hop moves by path; only a cross-origin hop carries a Jump rt.
      unless auth_target.host == base_host
        handoff_rt = Rack::Utils.parse_query(auth_target.query).fetch("rt")
        handoff_payload, = JWT.decode(
          handoff_rt, JitSecurityJwtRegistry.public_key_for(issuer.id, issuer.current_kid), true,
          algorithms: ["ES384"], verify_iss: true, iss: "https://#{base_host}",
          verify_aud: true, aud: Rails.configuration.x.boot_config.fetch(:jump).audience,
        )
        auth_target = URI.parse(handoff_payload.fetch("url"))
      end
    end

    assert_equal auth_host, auth_target.host
    entry_reference = Rack::Utils.parse_query(auth_target.query).fetch("entry_ref")
    binding = BaseAuthAdmissionCoordinator.find_admission_binding!(surface: "app", reference: entry_reference)
    auth.host!(auth_host)
    auth.https!
    auth.get(auth_app_sign_in_path, params: { entry_ref: entry_reference, ri: "jp" })

    assert_equal 200, auth.response.status
    csrf = nil
    3.times do |admission_index|
      browser = (admission_index == 1) ? base : auth
      form = Nokogiri::HTML(browser.response.body).at_css("form")

      assert_not_nil form, "Admission step #{admission_index} must render its real continuation"
      fields = form.css("input[name]").to_h { |input| [input["name"], input["value"]] }
      csrf = fields.fetch("authenticity_token") if admission_index == 2
      assert_nil binding.reload.base_confirmed_at if admission_index == 1
      browser.post(form["action"], params: fields, headers: (admission_index == 1) ? base_headers : auth_headers)

      assert_equal 303, browser.response.status
      assert_not_nil binding.reload.base_confirmed_at if admission_index == 1
      next if admission_index == 2

      target = URI.parse(browser.response.location)
      receiver = admission_index.zero? ? base : auth

      assert_equal(admission_index.zero? ? base_host : auth_host, target.host)
      receiver.get(target.request_uri)
    end

    binding.reload
    OmniAuth.config.mock_auth[:google] = OmniAuth::AuthHash.new(
      provider: "google", uid: subject, info: { name: "Provider fixture" },
      credentials: { token: "provider-fixture", expires_at: 1.hour.from_now.to_i },
    )
    switch_browser_to_sign_up!(auth, base_browser: base)
    # The Switch admits the browser again on a new Sign Up Binding of the same parent.
    binding = binding.class.where(
      authorization_transaction_id: binding.authorization_transaction_id, entry_intent: "sign_up",
    ).order(:id).last
    auth.host!(auth_host)
    csrf = auth.response.parsed_body.at_css(%q(meta[name="csrf-token"]))&.[]("content") || csrf
    auth.post(
      auth_app_social_google_registration_path, params: { ri: "jp" },
                                                headers: auth_headers.merge("X-CSRF-Token" => csrf),
    )

    assert_equal 307, auth.response.status
    state = auth.session.fetch(SocialCallbackGuard::SOCIAL_STATE_SESSION_KEY)
    assert_no_difference("Client.count") do
      assert_no_difference("ClientExternalIdentity.count") do
        auth.get(auth_app_social_google_callback_path, params: { state:, ri: "jp" }, headers: auth_headers)
      end
    end
    assert_equal 302, auth.response.status
    auth.follow_redirect!
    auth.follow_redirect!

    signup = session_sign_up_flow(auth.session, surface: :app)

    assert_equal [200, true, nil], [auth.response.status, signup.present?, signup&.principal_id]
    fb = SignFlowBindingCodec.encode(flow: signup, surface: :app)
    # WU-05d P1: the confirmation creates the one pending Client of this Flow, without an identity.
    assert_difference("Client.count", 1) do
      assert_no_difference("ClientExternalIdentity.count") do
        auth.patch(
          auth_app_sign_up_check_google_confirmation_path(ri: "jp", fb:),
          params: { :confirm_new_social_identity => "1",
                    :checkpoint_version => signup.checkpoint_version,
                    "cf-turnstile-response" => "fixture", },
          headers: auth_headers.merge("X-CSRF-Token" => csrf),
        )
      end
    end

    assert_equal 302, auth.response.status
    pending = Client.find(signup.reload.principal_id)

    assert_equal [ClientStatus::UNVERIFIED_WITH_SIGN_UP, "social_identity"],
                 [pending.status_id, signup.pending_contact_type]
    fb = Rack::Utils.parse_query(URI.parse(auth.response.location).query).fetch("fb")
    # F3/F4: the birthdate step finalizes in Auth; no Root is issued by Auth (S1).
    assert_no_difference(["Client.count", "ClientToken.count"]) do
      assert_difference("ClientExternalIdentity.count", 1) do
        auth.patch(
          auth_app_sign_up_check_google_birthdate_path(ri: "jp", fb:),
          params: { requirement: "birthdate",
                    birthdate: "2000-02-03",
                    checkpoint_version: signup.reload.checkpoint_version, },
          headers: auth_headers.merge("X-CSRF-Token" => csrf),
        )
      end
    end

    assert_predicate auth.response, :redirect?
    assert_equal auth_host, URI.parse(auth.response.location).host || auth_host
    identity = ClientExternalIdentity.find_by!(provider: "google", subject:)

    assert_equal [pending.id, ClientStatus::VERIFIED_WITH_SIGN_UP, true, true],
                 [identity.client_id, pending.reload.status_id, signup.reload.completed?,
                  ClientIdentity.exists?(source_record_id: pending.id),]
    # S1: the handoff enters the canonical Sign In flow for the new Client.
    assert ClientSignInFlow.exists?(principal_id: pending.id)
  end

  test "completion retains the actual Auth authentication event time through the Base Root boundary" do
    actor = Client.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE,
      birthdate: "2000-01-01",
    )
    subject = "ordinary-social-#{SecureRandom.hex(8)}"
    ClientGoogleIdentity.create!(
      user: actor,
      uid: subject,
      provider: "google",
      status_id: ClientGoogleIdentityStatus::ACTIVE,
    )
    BaseSelectorBootstrapAuthority.call(surface: :app, principal: actor)
    base = self
    auth = open_session
    base_host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    auth_host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    base_headers = { "Origin" => "https://#{base_host}", "Sec-Fetch-Site" => "same-origin" }
    auth_headers = { "Origin" => "https://#{auth_host}", "Sec-Fetch-Site" => "same-origin" }
    base.host!(base_host)
    base.https!
    base.get("/sign", params: { ri: "jp" })

    assert_equal 200, base.response.status
    entry_form = Nokogiri::HTML(base.response.body).at_css("form")
    entry_fields = entry_form.css("input[name]").to_h { |input| [input["name"], input["value"]] }
    base.post(entry_form["action"], params: entry_fields, headers: base_headers)

    assert_equal 303, base.response.status
    issuer = JitSecurityJwtRegistry.surface("BASE_APP")
    target = URI.parse(base.response.location)
    # A same-origin hop moves by path; only a cross-origin hop carries a Jump rt.
    unless target.host == base_host
      target = target
      # A same-origin hop moves by path; only a cross-origin hop carries a Jump rt.
      unless target.host == base_host
        rt = Rack::Utils.parse_query(target.query).fetch("rt")
        payload, = JWT.decode(
          rt, JitSecurityJwtRegistry.public_key_for(issuer.id, issuer.current_kid), true,
          algorithms: ["ES384"], verify_iss: true, iss: "https://#{base_host}",
          verify_aud: true, aud: Rails.configuration.x.boot_config.fetch(:jump).audience,
        )
        target = URI.parse(payload.fetch("url"))
      end
    end

    assert_equal base_host, target.host
    base.get(target.request_uri)
    authorization_form = Nokogiri::HTML(base.response.body).at_css("form#base-authorization-ceremony-start-form")
    authorization_fields = authorization_form.css("input[name]").to_h { |input| [input["name"], input["value"]] }
    base.post(authorization_form["action"], params: authorization_fields, headers: base_headers)

    assert_equal 303, base.response.status
    auth_target = URI.parse(base.response.location)
    # A same-origin hop moves by path; only a cross-origin hop carries a Jump rt.
    unless auth_target.host == base_host
      auth_target = auth_target
      # A same-origin hop moves by path; only a cross-origin hop carries a Jump rt.
      unless auth_target.host == base_host
        handoff_rt = Rack::Utils.parse_query(auth_target.query).fetch("rt")
        handoff_payload, = JWT.decode(
          handoff_rt, JitSecurityJwtRegistry.public_key_for(issuer.id, issuer.current_kid), true,
          algorithms: ["ES384"], verify_iss: true, iss: "https://#{base_host}",
          verify_aud: true, aud: Rails.configuration.x.boot_config.fetch(:jump).audience,
        )
        auth_target = URI.parse(handoff_payload.fetch("url"))
      end
    end

    assert_equal auth_host, auth_target.host
    entry_reference = Rack::Utils.parse_query(auth_target.query).fetch("entry_ref")
    binding = BaseAuthAdmissionCoordinator.find_admission_binding!(surface: "app", reference: entry_reference)
    auth.host!(auth_host)
    auth.https!
    auth.get(auth_app_sign_in_path, params: { entry_ref: entry_reference, ri: "jp" })

    assert_equal 200, auth.response.status
    csrf = nil
    3.times do |admission_index|
      browser = (admission_index == 1) ? base : auth
      form = Nokogiri::HTML(browser.response.body).at_css("form")

      assert_not_nil form, "Admission step #{admission_index} must render its real continuation"
      fields = form.css("input[name]").to_h { |input| [input["name"], input["value"]] }
      csrf = fields.fetch("authenticity_token") if admission_index == 2
      assert_nil binding.reload.base_confirmed_at if admission_index == 1
      browser.post(form["action"], params: fields, headers: (admission_index == 1) ? base_headers : auth_headers)

      assert_equal 303, browser.response.status
      assert_not_nil binding.reload.base_confirmed_at if admission_index == 1
      next if admission_index == 2

      target = URI.parse(browser.response.location)
      receiver = admission_index.zero? ? base : auth

      assert_equal(admission_index.zero? ? base_host : auth_host, target.host)
      receiver.get(target.request_uri)
    end

    assert_predicate binding.reload, :redeemed?
    OmniAuth.config.mock_auth[:google] = OmniAuth::AuthHash.new(
      provider: "google", uid: subject, info: { name: "Provider fixture" },
      credentials: { token: "provider-fixture", expires_at: 1.hour.from_now.to_i },
    )
    auth.post(
      auth_app_social_google_session_path, params: { ri: "jp" },
                                           headers: auth_headers.merge("X-CSRF-Token" => csrf),
    )

    assert_equal 307, auth.response.status
    state = auth.session.fetch(SocialCallbackGuard::SOCIAL_STATE_SESSION_KEY)
    assert_no_difference("ClientToken.count") do
      auth.get(auth_app_social_google_callback_path, params: { state:, ri: "jp" }, headers: auth_headers)
    end
    assert_equal 303, auth.response.status
    ceremony = ClientAuthCeremonySession.find(binding.reload.admitted_auth_ceremony_session_id)

    assert_predicate ceremony, :authentication_evidence_recorded?
    assert_equal "google", ceremony.authentication_method
    assert_equal [true, true], [auth.cookies[AuthenticationBase::ACCESS_COOKIE_KEY].nil?,
                                auth.cookies[AuthenticationBase::REFRESH_COOKIE_KEY].nil?,]
    assert_equal "pending", ClientOidcAuthorizationTransaction.find(binding.authorization_transaction_id).reload.status

    auth.get(auth_app_sign_oidc_handoff_path, params: { ri: "jp" })

    assert_equal 200, auth.response.status
    form = Nokogiri::HTML(auth.response.body).at_css("form")
    fields = form.css("input[name]").to_h { |input| [input["name"], input["value"]] }
    auth.post(form["action"], params: fields, headers: auth_headers)

    assert_equal 303, auth.response.status
    receiver = URI.parse(auth.response.location)

    assert_equal base_host, receiver.host
    base.get(receiver.request_uri)

    assert_equal 200, base.response.status
    form = Nokogiri::HTML(base.response.body).at_css("form")
    fields = form.css("input[name]").to_h { |input| [input["name"], input["value"]] }
    assert_difference(-> { ClientToken.where(user_id: actor.id).count }, 1) do
      base.post(form["action"], params: fields, headers: base_headers)
    end
    assert_equal 303, base.response.status
    token = ClientToken.find_by!(user_id: actor.id)

    assert_equal [ceremony.authentication_event_at, "google"],
                 [token.authentication_event_at, token.established_authentication_method]
    assert_not_nil token.root_login_established_at
    transaction = ClientOidcAuthorizationTransaction.find(binding.authorization_transaction_id)

    assert_equal token.public_id, transaction.reload.browser_session_ref
    assert_predicate transaction, :consumed?
    assert_equal 0, OpAppGrant.where(client_token_id: token.id).count
  end

  test "a competing Root login after Social verification makes the original Base completion refuse cooldown" do
    Rails.application.config.x.authentication.login_cooldown = 60.seconds
    actor = Client.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE,
      birthdate: "2000-01-01",
    )
    subject = "cooldown-social-#{SecureRandom.hex(8)}"
    ClientGoogleIdentity.create!(
      user: actor,
      uid: subject,
      provider: "google",
      status_id: ClientGoogleIdentityStatus::ACTIVE,
    )
    BaseSelectorBootstrapAuthority.call(surface: :app, principal: actor)
    base_host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    auth_host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    base_headers = { "Origin" => "https://#{base_host}", "Sec-Fetch-Site" => "same-origin" }
    auth_headers = { "Origin" => "https://#{auth_host}", "Sec-Fetch-Site" => "same-origin" }
    issuer = JitSecurityJwtRegistry.surface("BASE_APP")
    OmniAuth.config.mock_auth[:google] = OmniAuth::AuthHash.new(
      provider: "google", uid: subject, info: {}, credentials: { token: "external-provider-fixture" },
    )
    pending_action = nil
    pending_fields = nil
    original_parent = nil
    [[self, open_session], [open_session, open_session]].each_with_index do |(base, auth), index|
      base.host!(base_host)
      base.https!
      auth.host!(auth_host)
      auth.https!
      base.get("/sign", params: { ri: "jp" })
      form = Nokogiri::HTML(base.response.body).at_css("form")
      fields = form.css("input[name]").to_h { |input| [input["name"], input["value"]] }
      base.post(form["action"], params: fields, headers: base_headers)
      2.times do |phase|
        target = URI.parse(base.response.location)
        # A same-origin hop moves by path; only a cross-origin hop carries a Jump rt.
        unless target.host == base_host
          target = target
          # A same-origin hop moves by path; only a cross-origin hop carries a Jump rt.
          unless target.host == base_host
            rt = Rack::Utils.parse_query(target.query).fetch("rt")
            payload, = JWT.decode(
              rt, JitSecurityJwtRegistry.public_key_for(issuer.id, issuer.current_kid), true,
              algorithms: ["ES384"], verify_iss: true, iss: "https://#{base_host}",
              verify_aud: true, aud: Rails.configuration.x.boot_config.fetch(:jump).audience,
            )
            target = URI.parse(payload.fetch("url"))
          end
        end
        if phase.zero?
          base.get(target.request_uri)
          form = Nokogiri::HTML(base.response.body).at_css("form")
          fields = form.css("input[name]").to_h { |input| [input["name"], input["value"]] }
          base.post(form["action"], params: fields, headers: base_headers)
        else
          reference = Rack::Utils.parse_query(target.query).fetch("entry_ref")
          binding = BaseAuthAdmissionCoordinator.find_admission_binding!(surface: "app", reference:)
          if index.zero?
            original_parent = ClientOidcAuthorizationTransaction.find(binding.authorization_transaction_id)
          end
          auth.get(target.request_uri)
        end
      end
      csrf = nil
      3.times do |phase|
        sender = (phase == 1) ? base : auth
        form = Nokogiri::HTML(sender.response.body).at_css("form")
        fields = form.css("input[name]").to_h { |input| [input["name"], input["value"]] }
        csrf = fields.fetch("authenticity_token") if phase == 2
        sender.post(form["action"], params: fields, headers: (phase == 1) ? base_headers : auth_headers)
        raise RuntimeError, "Admission failed" unless sender.response.status == 303
        next if phase == 2

        (phase.zero? ? base : auth).get(URI.parse(sender.response.location).request_uri)
      end
      auth.post(auth_app_social_google_session_path(ri: "jp"), headers: auth_headers.merge("X-CSRF-Token" => csrf))
      state = auth.session.fetch(SocialCallbackGuard::SOCIAL_STATE_SESSION_KEY)
      auth.get(auth_app_social_google_callback_path(ri: "jp"), params: { state: }, headers: auth_headers)
      auth.get(auth_app_sign_oidc_handoff_path(ri: "jp"))
      form = Nokogiri::HTML(auth.response.body).at_css("form")
      fields = form.css("input[name]").to_h { |input| [input["name"], input["value"]] }
      auth.post(form["action"], params: fields, headers: auth_headers)
      base.get(URI.parse(auth.response.location).request_uri)
      form = Nokogiri::HTML(base.response.body).at_css("form")
      fields = form.css("input[name]").to_h { |input| [input["name"], input["value"]] }
      if index.zero?
        pending_action = form["action"]
        pending_fields = fields
      else
        assert_difference(-> { ClientToken.where(user_id: actor.id).count }, 1) do
          base.post(form["action"], params: fields, headers: base_headers)
        end
        assert_equal 303, base.response.status
      end
    end
    root = ClientToken.find_by!(user_id: actor.id)
    anchor = root.root_login_established_at
    assert_no_difference(["ClientToken.count", "ClientDeviceSession.count"]) do
      post(pending_action, params: pending_fields, headers: base_headers)
    end
    assert_equal [429, "60", nil], [response.status, response.headers["Retry-After"], response.headers["Location"]]
    assert_equal [anchor, nil, "authenticated"],
                 [root.reload.root_login_established_at, original_parent.reload.base_finalized_at,
                  original_parent.status,]
    assert_nil cookies[AuthenticationBase::ACCESS_COOKIE_KEY]
    assert_nil cookies[AuthenticationBase::REFRESH_COOKIE_KEY]
  end
end
