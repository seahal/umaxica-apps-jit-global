# typed: false
# frozen_string_literal: true

require "test_helper"

class AuthCeremonyAdmissionBoundaryTest < ActionDispatch::IntegrationTest
  %w(app com org).each do |surface|
    test "#{surface} cancel-and-start refuses the old admitted tab without changing replacement authority" do
      protection = ActionController::Base.allow_forgery_protection
      ActionController::Base.allow_forgery_protection = true
      actor, token, host =
        case surface
        when "app"
          actor = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
          [actor, ClientToken.create!(authentication_epoch: 0, user: actor), ENV.fetch("PUBLIC_AUTH_SERVICE_URL")]
        when "com"
          actor = Visitor.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: VisitorStatus::ACTIVE)
          [actor, VisitorToken.create!(authentication_epoch: 0, visitor: actor), ENV.fetch("PUBLIC_AUTH_CORPORATE_URL")]
        when "org"
          actor = Operator.create!(security_mode_id: SecurityModeConfigurable::ADVANCED)
          [actor, OperatorToken.create!(authentication_epoch: 0, staff: actor), ENV.fetch("PUBLIC_AUTH_STAFF_URL")]
        end
      requirement = StepUpRequirement.new(
        scope: "settings_passkey", purpose: "step_up", step_up_required: true, allowed_methods: [:passkey],
        phishing_resistant_required: false, user_verification_required: false, full_reauthentication_required: false,
        audience: "step_up:#{surface}", session_binding: token.public_id, token_binding: token.public_id,
        require_session_binding: true, ttl: 15.minutes, actor_ref: actor.public_id, resource_ref: nil, tenant_ref: nil,
      )
      nonce = SecureRandom.hex(32)
      first = BaseStepUpAdmissionIssuer.call!(
        actor:, token:, requirement:, return_to: "/identity/passkeys", base_browser_nonce: nonce, base_token: token,
      )
      binding = BaseAuthAdmissionCoordinator.find_admission_binding!(surface:, reference: first.reference)
      browser = open_session
      browser.https!
      browser.host!(host)
      headers = { "Origin" => "https://#{host}", "Sec-Fetch-Site" => "same-origin" }
      browser.get("/verification", params: { entry_ref: first.reference, ri: "jp" })

      assert_equal 200, browser.response.status
      csrf = browser.response.parsed_body.at_css('input[name="authenticity_token"]')["value"]
      browser.post(
        "/ceremony_bindings", params: { entry_ref: first.reference, authenticity_token: csrf, ri: "jp" }, headers:,
      )

      assert_equal 303, browser.response.status
      # The independent Base HTTP matrix covers confirmation; isolate cancellation after real Auth redemption.
      binding.reload.confirm_base!(base_token: token, browser_digest: binding.base_browser_digest)
      browser.get("/verification", params: { entry_ref: first.reference, ri: "jp" })

      assert_equal 200, browser.response.status
      csrf = browser.response.parsed_body.at_css('input[name="authenticity_token"]')["value"]
      browser.post(
        "/verification", params: { entry_ref: first.reference, authenticity_token: csrf, ri: "jp" }, headers:,
      )

      assert_equal 303, browser.response.status
      admitted = admitted_auth_ceremony_session_for_test(binding.reload)
      replacement = BaseStepUpCancelAndStartCommitter.call!(
        actor:, token:, previous_transaction: first.transaction,
        requirement: StepUpRequirement.new(
          step_up_required: true,
          phishing_resistant_required: false,
          user_verification_required: false,
          full_reauthentication_required: false,
          **requirement.to_h.merge(scope: "settings_email"),
        ),
        return_to: "/identity/emails", base_browser_nonce: nonce, base_token: token,
      )

      assert_not_equal first.transaction.transaction_id, replacement.transaction.transaction_id
      assert_equal ["canceled", "pending", nil],
                   [first.transaction.reload.status, replacement.transaction.reload.status,
                    token.reload.last_step_up_at,]
      old_facts = first.transaction.attributes
      replacement_facts = replacement.transaction.attributes
      replacement_binding = BaseAuthAdmissionCoordinator.find_admission_binding!(
        surface:, reference: replacement.reference,
      )
      replacement_binding_facts = replacement_binding.attributes
      session_model =
        case surface
        when "app" then ClientStepUpSession
        when "com" then VisitorStepUpSession
        when "org" then OperatorStepUpSession
        end
      replacement_session = session_model.find_by!(
        step_up_ceremony_transaction_ref: replacement.transaction.transaction_id,
      )
      replacement_session_facts = replacement_session.attributes

      assert_nil replacement_session.passkey_challenge_ref
      browser.get("/verification", params: { ri: "jp" })

      assert_equal [400, nil], [browser.response.status, browser.response.location]
      browser.post(
        "/verification/passkey/options", params: { authenticity_token: csrf, ri: "jp" }, headers:,
      )

      assert_equal [400, nil], [browser.response.status, browser.response.location]
      assert_equal old_facts, first.transaction.reload.attributes
      assert_equal replacement_facts, replacement.transaction.reload.attributes
      assert_equal replacement_binding_facts, replacement_binding.reload.attributes
      assert_equal replacement_session_facts, replacement_session.reload.attributes
      assert_nil replacement_binding.auth_ceremony_session_id
      assert_nil token.reload.last_step_up_at
      assert_not_predicate admitted.reload, :active?
    ensure
      ActionController::Base.allow_forgery_protection = protection
    end
  end

  %w(app com org).each do |surface|
    test "#{surface} revoked Base device prevents confirmed verification redemption without rotating Auth continuity" do
      protection = ActionController::Base.allow_forgery_protection
      ActionController::Base.allow_forgery_protection = true
      actor, token, host =
        case surface
        when "app"
          actor = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
          [actor, ClientToken.create!(authentication_epoch: 0, user: actor), ENV.fetch("PUBLIC_AUTH_SERVICE_URL")]
        when "com"
          actor = Visitor.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: VisitorStatus::ACTIVE)
          [actor, VisitorToken.create!(authentication_epoch: 0, visitor: actor), ENV.fetch("PUBLIC_AUTH_CORPORATE_URL")]
        when "org"
          actor = Operator.create!(security_mode_id: SecurityModeConfigurable::ADVANCED)
          [actor, OperatorToken.create!(authentication_epoch: 0, staff: actor), ENV.fetch("PUBLIC_AUTH_STAFF_URL")]
        end
      requirement = StepUpRequirement.new(
        scope: "settings_passkey", purpose: "reauthentication", step_up_required: true, allowed_methods: [:passkey],
        phishing_resistant_required: true, user_verification_required: true, full_reauthentication_required: true,
        audience: "step_up:#{surface}", session_binding: token.public_id, token_binding: token.public_id,
        require_session_binding: true, ttl: 15.minutes, actor_ref: actor.public_id,
        resource_ref: nil, tenant_ref: nil,
      )
      issuance = BaseStepUpAdmissionIssuer.call!(
        actor:, token:, requirement:, return_to: "/identity/passkeys",
        base_browser_nonce: SecureRandom.hex(32), base_token: token,
      )
      binding = BaseAuthAdmissionCoordinator.find_admission_binding!(surface:, reference: issuance.reference)
      browser = open_session
      browser.https!
      browser.host!(host)
      browser.get("/verification", params: { entry_ref: issuance.reference, ri: "jp" })

      assert_equal 200, browser.response.status
      csrf = browser.response.parsed_body.at_css('input[name="authenticity_token"]')["value"]
      headers = { "Origin" => "https://#{host}", "Sec-Fetch-Site" => "same-origin" }
      browser.post(
        "/ceremony_bindings", params: { entry_ref: issuance.reference, authenticity_token: csrf, ri: "jp" }, headers:,
      )

      assert_equal 303, browser.response.status
      # Independent HTTP cases cover Base confirmation; isolate root revocation after confirmation here.
      binding.reload.confirm_base!(base_token: token, browser_digest: binding.base_browser_digest)
      browser.get("/verification", params: { entry_ref: issuance.reference, ri: "jp" })

      assert_equal 200, browser.response.status
      csrf = browser.response.parsed_body.at_css('input[name="authenticity_token"]')["value"]
      continuity = auth_ceremony_session_for_test(binding)
      original_facts = binding.attributes
      before = continuity.class.count
      cookie_name = JitSessionCookieConfig.force_secure? ? "__Host-auth_sid" : "auth_sid"
      original_cookie = browser.cookies[cookie_name]
      token.device_session.revoke!
      browser.post(
        "/verification", params: { entry_ref: issuance.reference, authenticity_token: csrf, ri: "jp" }, headers:,
      )

      assert_equal [400, nil, before, original_cookie],
                   [browser.response.status, browser.response.location,
                    continuity.class.count, browser.cookies[cookie_name],]
      assert_equal original_facts, binding.reload.attributes
      assert_predicate continuity.reload, :active?
      assert_not_predicate continuity, :admitted?
      assert_equal ["pending", nil], [issuance.transaction.reload.status, token.reload.last_step_up_at]
      assert_predicate token.device_session.reload, :revoked?
    ensure
      ActionController::Base.allow_forgery_protection = protection
    end
  end

  test "direct sign-up contact POST cannot create an email or telephone OTP or actor before confirmed redemption" do
    protection = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    TurnstileVerifierStub.challenge_enabled = true
    TurnstileVerifierStub.challenge_response = { "success" => true }
    [
      ["app", ENV.fetch("PUBLIC_AUTH_SERVICE_URL"), auth_app_sign_up_email_path(ri: "jp"),
       ClientEmail, Client, :client_email, { raw_address: "unadmitted-#{SecureRandom.hex(6)}@example.com" },],
      ["com", ENV.fetch("PUBLIC_AUTH_CORPORATE_URL"), auth_com_sign_up_email_path(ri: "jp"),
       VisitorEmail, Visitor, :visitor_email, { raw_address: "unadmitted-#{SecureRandom.hex(6)}@example.com" },],
      ["app", ENV.fetch("PUBLIC_AUTH_SERVICE_URL"), auth_app_sign_up_telephone_path(ri: "jp"),
       ClientTelephone, Client, :client_telephone, { raw_number: "+819012345678", confirm_using_mfa: "1" },],
      ["com", ENV.fetch("PUBLIC_AUTH_CORPORATE_URL"), auth_com_sign_up_telephone_path(ri: "jp"),
       VisitorTelephone, Visitor, :visitor_telephone, { raw_number: "+819012345678", confirm_using_mfa: "1" },],
    ].each do |surface, host, path, contact_model, actor_model, contact_key, input|
      browser = open_session
      browser.host!(host)
      browser.https!
      issuance = OidcTestEntry.issue!(
        surface:, intent: "sign_in", base_browser_nonce: SecureRandom.urlsafe_base64(32), base_token: nil,
      )
      browser.get("/sign/in", params: { entry_ref: issuance.reference, ri: "jp" })
      csrf_token = browser.response.parsed_body.at_css('input[name="authenticity_token"]')["value"]
      headers = {
        "Origin" => "https://#{host}",
        "Sec-Fetch-Site" => "same-origin",
        "X-CSRF-Token" => csrf_token,
      }
      assert_no_difference [-> { contact_model.count }, -> { actor_model.count }] do
        browser.post(
          path, params: {
            contact_key => input.merge(confirm_policy: "1"),
            "cf-turnstile-response" => "test",
          }, headers:,
        )

        assert_equal [400, nil, I18n.t("errors.messages.invalid_request")],
                     [browser.response.status, browser.response.location, browser.response.body]
      end
    end
  ensure
    ActionController::Base.allow_forgery_protection = protection
    TurnstileVerifierStub.challenge_enabled = false
    TurnstileVerifierStub.challenge_response = nil
  end

  test "each realm verification entry admits full reauthentication through its exact persisted purpose" do
    protection = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    %w(app com org).each do |surface|
      actor, token, host =
        case surface
        when "app"
          actor = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
          [actor, ClientToken.create!(authentication_epoch: 0, user: actor), ENV.fetch("PUBLIC_AUTH_SERVICE_URL")]
        when "com"
          actor = Visitor.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: VisitorStatus::ACTIVE)
          [actor, VisitorToken.create!(authentication_epoch: 0, visitor: actor), ENV.fetch("PUBLIC_AUTH_CORPORATE_URL")]
        when "org"
          actor = Operator.create!(security_mode_id: SecurityModeConfigurable::ADVANCED)
          [actor, OperatorToken.create!(authentication_epoch: 0, staff: actor), ENV.fetch("PUBLIC_AUTH_STAFF_URL")]
        end
      requirement = StepUpRequirement.new(
        scope: "settings_passkey", purpose: "reauthentication", step_up_required: true, allowed_methods: [:passkey],
        phishing_resistant_required: true, user_verification_required: true, full_reauthentication_required: true,
        audience: "step_up:#{surface}", session_binding: token.public_id, token_binding: token.public_id,
        require_session_binding: true, ttl: 15.minutes, actor_ref: actor.public_id,
        resource_ref: nil, tenant_ref: nil,
      )
      base_nonce = SecureRandom.urlsafe_base64(32)
      issuance = BaseStepUpAdmissionIssuer.call!(
        actor:, token:, requirement:, return_to: "/identity/passkeys",
        base_browser_nonce: base_nonce, base_token: token,
      )
      binding = BaseAuthAdmissionCoordinator.find_admission_binding!(surface:, reference: issuance.reference)
      browser = open_session
      browser.host!(host)
      browser.https!
      browser.get("/verification", params: { entry_ref: issuance.reference, ri: "jp" })

      assert_equal [200, nil, nil],
                   [browser.response.status, binding.reload.auth_ceremony_session_id, token.reload.last_step_up_at]
      csrf = browser.response.parsed_body.at_css('input[name="authenticity_token"]')["value"]
      headers = { "Origin" => "https://#{host}", "Sec-Fetch-Site" => "same-origin" }
      browser.post(
        "/ceremony_bindings", params: { entry_ref: issuance.reference, authenticity_token: csrf, ri: "jp" },
                              headers:,
      )

      assert_equal 303, browser.response.status
      # Public model confirmation isolates Auth purpose selection; separate HTTP tests cover the Base receiver.
      binding.reload.confirm_base!(base_token: token, browser_digest: binding.base_browser_digest)
      browser.get("/verification", params: { entry_ref: issuance.reference, ri: "jp" })

      assert_equal 200, browser.response.status
      csrf = browser.response.parsed_body.at_css('input[name="authenticity_token"]')["value"]
      browser.post(
        "/verification", params: { entry_ref: issuance.reference, authenticity_token: csrf, ri: "jp" },
                         headers:,
      )

      assert_equal [303, "reauthentication_handoff", "pending", nil],
                   [browser.response.status,
                    admitted_auth_ceremony_session_for_test(binding.reload)&.admission_purpose,
                    issuance.transaction.reload.status, token.reload.last_step_up_at,]
      if surface != "org"
        contact_model = (surface == "app") ? ClientEmail : VisitorEmail
        actor_model = (surface == "app") ? Client : Visitor
        contact_key = (surface == "app") ? :client_email : :visitor_email
        admitted_id = binding.admitted_auth_ceremony_session_id
        assert_no_difference [-> { contact_model.count }, -> { actor_model.count }] do
          browser.post(
            "/sign/up/email", params: {
              contact_key => { raw_address: "wrong-purpose-#{SecureRandom.hex(6)}@example.test", confirm_policy: "1" },
              :authenticity_token => csrf,
              "cf-turnstile-response" => "test",
              :ri => "jp",
            }, headers:,
          )

          assert_equal [400, nil, admitted_id, "pending", nil],
                       [browser.response.status, browser.response.location,
                        binding.reload.admitted_auth_ceremony_session_id,
                        issuance.transaction.reload.status, token.reload.last_step_up_at,],
                       "reauthentication admission cannot authorize signup candidate or OTP creation"
        end
      end
      original_facts = issuance.transaction.reload.attributes
      session_model =
        case surface
        when "app" then ClientStepUpSession
        when "com" then VisitorStepUpSession
        when "org" then OperatorStepUpSession
        end
      ceremony = session_model.find_by!(step_up_ceremony_transaction_ref: issuance.transaction.transaction_id)

      assert_nil ceremony.passkey_challenge_ref
      browser.post(
        "/verification/registration/passkey/options",
        params: { authenticity_token: csrf, "cf-turnstile-response": "test", ri: "jp" }, headers:,
      )

      assert_equal [400, nil], [browser.response.status, browser.response.location],
                   "full reauthentication cannot allocate a registration challenge"
      assert_equal original_facts, issuance.transaction.reload.attributes
      assert_nil ceremony.reload.passkey_challenge_ref
      replacement = BaseStepUpCancelAndStartCommitter.call!(
        actor: actor, token: token, previous_transaction: issuance.transaction, requirement: requirement,
        return_to: "/identity/passkeys?ri=jp", base_browser_nonce: base_nonce, base_token: token,
      )
      admitted = admitted_auth_ceremony_session_for_test(binding)
      terminal_facts = [issuance.transaction.reload.status, issuance.transaction.canceled_at]
      browser.get("/verification", params: { transaction_ref: issuance.transaction.transaction_id, ri: "jp" })

      assert_equal 400, browser.response.status
      assert_equal ["canceled", "pending", false, nil],
                   [issuance.transaction.reload.status, replacement.transaction.reload.status,
                    admitted.reload.active?(now: admitted.class.database_now), token.reload.last_step_up_at,]
      assert_equal terminal_facts, [issuance.transaction.status, issuance.transaction.canceled_at]
      assert_nil replacement.transaction.verified_at
      assert_nil replacement.transaction.consumed_at
    end
  ensure
    ActionController::Base.allow_forgery_protection = protection
  end

  test "a sign-in binding cannot render a Step-Up admission form in any realm" do
    protection = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    %w(app com org).each do |surface|
      host =
        case surface
        when "app" then ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
        when "com" then ENV.fetch("PUBLIC_AUTH_CORPORATE_URL")
        when "org" then ENV.fetch("PUBLIC_AUTH_STAFF_URL")
        end
      issuance = OidcTestEntry.issue!(
        surface:, intent: "sign_in", base_browser_nonce: SecureRandom.hex(32), base_token: nil,
      )
      binding = BaseAuthAdmissionCoordinator.find_admission_binding!(surface:, reference: issuance.reference)
      browser = open_session
      browser.host!(host)
      browser.https!
      browser.get("/verification", params: { entry_ref: issuance.reference, ri: "jp" })

      assert_equal [400, nil, nil],
                   [browser.response.status, browser.response.location, binding.reload.auth_ceremony_session_id]
      assert_nil binding.base_confirmed_at
      assert_nil binding.redeemed_at
    end
  ensure
    ActionController::Base.allow_forgery_protection = protection
  end

  test "duplicate malformed and proof-injected entry references never attach continuity in any realm" do
    protection = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    %w(app com org).each do |surface|
      host =
        case surface
        when "app" then ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
        when "com" then ENV.fetch("PUBLIC_AUTH_CORPORATE_URL")
        when "org" then ENV.fetch("PUBLIC_AUTH_STAFF_URL")
        end
      issuance = OidcTestEntry.issue!(
        surface:, intent: "sign_in", base_browser_nonce: "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn", base_token: nil,
      )
      binding = BaseAuthAdmissionCoordinator.find_admission_binding!(surface:, reference: issuance.reference)
      browser = open_session
      browser.host!(host)
      browser.https!
      browser.get("/sign/in", params: { entry_ref: issuance.reference, ri: "jp" })
      csrf = browser.response.parsed_body.at_css('input[name="authenticity_token"]')["value"]
      headers = { "Origin" => "https://#{host}",
                  "Sec-Fetch-Site" => "same-origin",
                  "Content-Type" => "application/x-www-form-urlencoded", }
      form = URI.encode_www_form(entry_ref: issuance.reference, authenticity_token: csrf)

      browser.get(
        "/sign/in?entry_ref=#{issuance.reference}&entry_ref=#{issuance.reference}&ri=jp",
      )

      assert_equal [400, nil, nil],
                   [browser.response.status, browser.response.location, binding.reload.auth_ceremony_session_id]

      [
        ["/ceremony_bindings", "#{form}&entry_ref=#{issuance.reference}"],
        ["/ceremony_bindings?entry_ref=#{issuance.reference}", form],
      ].concat(
        [
          nil, "", " ", "0", "\0", issuance.reference[0...-1], "#{issuance.reference}0",
          "#{issuance.reference[0, 14]}1#{issuance.reference[15..]}", SecureRandom.uuid,
          [issuance.reference], { "ref" => issuance.reference },
        ].map do |reference|
          fields = { authenticity_token: csrf, ri: "jp" }
          fields[:entry_ref] = reference unless reference.nil?
          ["/ceremony_bindings", Rack::Utils.build_nested_query(fields)]
        end,
      ).concat(
        %w(
          auth_sid sid auth_ceremony_session_id admitted_auth_ceremony_session_id base_token_id
          base_browser_digest confirmation_ref sign_in_flow_id authorization_transaction_id
          step_up_ceremony_transaction_id parent_kind purpose browser_nonce
        ).map { |proof| ["/ceremony_bindings", "#{form}&#{URI.encode_www_form_component(proof)}="] },
      ).each do |path, body|
        assert_no_difference -> { binding.class.auth_admission_session_class.count } do
          browser.post(path, params: body, headers:)

          assert_equal [400, nil, nil],
                       [browser.response.status, browser.response.location, binding.reload.auth_ceremony_session_id]
        end
      end

      assert_equal [nil, nil, nil],
                   [binding.reload.base_confirmed_at, binding.redeemed_at,
                    binding.admitted_auth_ceremony_session_id,]
      assert_equal "pending", issuance.transaction.reload.status
    end
  ensure
    ActionController::Base.allow_forgery_protection = protection
  end

  test "post-consumption Ticket write failure rolls back rotation and permits explicit restart in every realm" do
    protection = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    %w(app com org).each do |surface|
      host =
        case surface
        when "app" then ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
        when "com" then ENV.fetch("PUBLIC_AUTH_CORPORATE_URL")
        when "org" then ENV.fetch("PUBLIC_AUTH_STAFF_URL")
        end
      first = OidcTestEntry.issue!(
        surface:, intent: "sign_in", base_browser_nonce: "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn", base_token: nil,
      )
      binding = BaseAuthAdmissionCoordinator.find_admission_binding!(surface:, reference: first.reference)
      continuity, raw_sid = binding.class.auth_admission_session_class.issue!
      binding.attach_auth_session!(auth_session: continuity, confirmation_ref: SecureRandom.uuid)
      binding.confirm_base!(base_token: nil, browser_digest: binding.base_browser_digest)
      browser = open_session
      browser.host!(host)
      browser.https!
      cookie_name = JitSessionCookieConfig.force_secure? ? "__Host-auth_sid" : "auth_sid"
      installed = browser.cookies.merge(
        "#{cookie_name}=#{Rack::Utils.escape(raw_sid)}", URI.parse("https://#{host}/"),
      )

      assert_equal ["#{cookie_name}=#{Rack::Utils.escape(raw_sid)}"], installed
      browser.get("/sign/in", params: { entry_ref: first.reference, ri: "jp" })
      csrf = browser.response.parsed_body.at_css('input[name="authenticity_token"]')["value"]
      headers = { "Origin" => "https://#{host}", "Sec-Fetch-Site" => "same-origin" }
      count = continuity.class.count
      failing_write =
        lambda do |_name, _started, _finished, _identity, payload|
          if payload[:name] == "#{binding.class} Update" && payload[:sql].include?('"redeemed_at"')
            raise ActiveRecord::StatementInvalid, "admission write unavailable"
          end
        end
      # Fail the SQL boundary; real domain transitions and transaction rollback remain in use.
      ActiveSupport::Notifications.subscribed(failing_write, "sql.active_record") do
        assert_raises(ActiveRecord::StatementInvalid) do
          browser.post(
            "/sign/in", params: { entry_ref: first.reference, authenticity_token: csrf, ri: "jp" }, headers:,
          )
        end
      end

      assert_equal count, continuity.class.count
      assert_predicate continuity.reload, :active?
      assert_equal raw_sid, browser.cookies[cookie_name]
      assert_nil binding.reload.redeemed_at
      assert_nil binding.admitted_auth_ceremony_session_id
      burned = Valkey::AuthState::OpaqueAdmissionStore.new.read_reference!(reference: first.reference)

      assert_equal "consumed", burned.fetch("state")
      browser.post(
        "/sign/in", params: { entry_ref: first.reference, authenticity_token: csrf, ri: "jp" }, headers:,
      )

      assert_equal [400, nil, raw_sid, count],
                   [browser.response.status, browser.response.location, browser.cookies[cookie_name],
                    continuity.class.count,]
      restarted = BaseAuthAdmissionCoordinator.issue_handoff!(
        transaction: first.transaction, base_browser_nonce: "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn",
        base_token: nil, restart_of: first.reference,
      )

      assert_equal first.transaction.id, restarted.transaction.id
      assert_predicate binding.reload, :retired?
      browser.get("/sign/in", params: { entry_ref: restarted.reference, ri: "jp" })
      csrf = browser.response.parsed_body.at_css('input[name="authenticity_token"]')["value"]
      browser.post(
        "/ceremony_bindings", params: { entry_ref: restarted.reference, authenticity_token: csrf, ri: "jp" }, headers:,
      )

      assert_equal 303, browser.response.status
      replacement = BaseAuthAdmissionCoordinator.find_admission_binding!(surface:, reference: restarted.reference)

      assert_equal continuity.id, replacement.auth_ceremony_session_id
      replacement.confirm_base!(
        base_token: nil,
        browser_digest: AuthAdmissionBinding.browser_digest(
          surface:, entry_ref: restarted.reference, nonce: "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn",
        ),
      )
      browser.get("/sign/in", params: { entry_ref: restarted.reference, ri: "jp" })
      csrf = browser.response.parsed_body.at_css('input[name="authenticity_token"]')["value"]
      browser.post(
        "/sign/in", params: { entry_ref: restarted.reference, authenticity_token: csrf, ri: "jp" }, headers:,
      )

      assert_equal 303, browser.response.status
      assert_predicate replacement.reload, :redeemed?
      assert_not_equal raw_sid, browser.cookies[cookie_name]
    end
  ensure
    ActionController::Base.allow_forgery_protection = protection
  end

  test "unattached entry reuses active previously admitted continuity without granting its new purpose" do
    protection = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    [
      ["app", ENV.fetch("PUBLIC_AUTH_SERVICE_URL"), ClientAuthAdmissionBinding, ClientAuthCeremonySession],
      ["com", ENV.fetch("PUBLIC_AUTH_CORPORATE_URL"), VisitorAuthAdmissionBinding, VisitorAuthCeremonySession],
      ["org", ENV.fetch("PUBLIC_AUTH_STAFF_URL"), OperatorAuthAdmissionBinding, OperatorAuthCeremonySession],
    ].each do |surface, host, binding_model, session_model|
      original = OidcTestEntry.issue!(
        surface: surface, intent: "sign_in", base_browser_nonce: SecureRandom.hex(32), base_token: nil,
      )
      continuity, raw_sid = session_model.rotate_and_admit!(
        admission_purpose: "authentication_handoff", authorization_transaction_ref: original.transaction.transaction_id,
      )
      incoming = OidcTestEntry.issue!(
        surface: surface, intent: "sign_in", base_browser_nonce: SecureRandom.hex(32), base_token: nil,
      )
      binding = binding_model.find_by!(entry_ref: incoming.reference)
      browser = open_session
      browser.https!
      browser.host!(host)
      cookie_name = JitSessionCookieConfig.force_secure? ? "__Host-auth_sid" : "auth_sid"
      installed = browser.cookies.merge(
        "#{cookie_name}=#{Rack::Utils.escape(raw_sid)}", URI.parse("https://#{host}/"),
      )

      assert_equal ["#{cookie_name}=#{Rack::Utils.escape(raw_sid)}"], installed
      browser.get("/sign/in", params: { entry_ref: incoming.reference, ri: "jp" })

      assert_equal 200, browser.response.status, surface
      csrf = browser.response.parsed_body.at_css('input[name="authenticity_token"]')["value"]
      before = session_model.count
      %w(
        auth_sid sid auth_ceremony_session_id admitted_auth_ceremony_session_id base_token_id
        base_browser_digest confirmation_ref sign_in_flow_id authorization_transaction_id
        step_up_ceremony_transaction_id parent_kind purpose browser_nonce
      ).each do |field|
        browser.post(
          "/ceremony_bindings",
          params: { :entry_ref => incoming.reference, :authenticity_token => csrf, :ri => "jp", field => "injected" },
          headers: { "Origin" => "https://#{host}", "Sec-Fetch-Site" => "same-origin" },
        )

        assert_equal [400, nil, before, nil, raw_sid],
                     [browser.response.status, browser.response.location, session_model.count,
                      binding.reload.auth_ceremony_session_id, browser.cookies[cookie_name],],
                     "client-supplied #{field} cannot become browser proof in #{surface}"
      end
      browser.post(
        "/ceremony_bindings", params: { entry_ref: incoming.reference, authenticity_token: csrf, ri: "jp" },
                              headers: { "Origin" => "https://#{host}", "Sec-Fetch-Site" => "same-origin" },
      )

      assert_equal 303, browser.response.status, surface
      assert_equal before, session_model.count,
                   "attachment reuses active continuity regardless of its earlier admission"
      assert_equal continuity.id, binding.reload.auth_ceremony_session_id
      assert_nil binding.base_confirmed_at
      assert_nil binding.redeemed_at
      assert_predicate continuity.reload, :active?
      assert_equal original.transaction.transaction_id, continuity.authorization_transaction_ref
      assert_not_includes browser.response.headers["Set-Cookie"].to_s, "#{cookie_name}="
    end
  ensure
    ActionController::Base.allow_forgery_protection = protection
  end

  test "anonymous Base confirmation refuses an expired OIDC parent even while its binding remains live" do
    protection = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    base_host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    auth_host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    browser = open_session
    browser.https!
    browser.host!(base_host)
    authorization = {
      response_type: "code",
      client_id: "core-app-jp",
      redirect_uri: OidcClientRegistry.find!("core-app-jp").redirect_uris_by_realm.fetch("client").first,
      code_challenge: "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM",
      code_challenge_method: "S256",
      scope: "openid",
      state: SecureRandom.urlsafe_base64(32),
      nonce: SecureRandom.urlsafe_base64(32),
      ri: "jp",
    }
    browser.get("/oauth/authorize", params: authorization)

    assert_equal 200, browser.response.status
    csrf = browser.response.parsed_body.at_css('input[name="authenticity_token"]')["value"]
    browser.post(
      "/oauth/authorize", params: authorization.merge(ceremony_action: "start", authenticity_token: csrf),
                          headers: { "Origin" => "https://#{base_host}", "Sec-Fetch-Site" => "same-origin" },
    )
    transaction = ClientOidcAuthorizationTransaction.find_by!(state: authorization.fetch(:state))
    binding = ClientAuthAdmissionBinding.find_by!(authorization_transaction_id: transaction.id)
    browser.host!(auth_host)
    browser.get("/sign/in", params: { entry_ref: binding.entry_ref, ri: "jp" })
    csrf = browser.response.parsed_body.at_css('input[name="authenticity_token"]')["value"]
    browser.post(
      "/ceremony_bindings", params: { entry_ref: binding.entry_ref, authenticity_token: csrf, ri: "jp" },
                            headers: { "Origin" => "https://#{auth_host}", "Sec-Fetch-Site" => "same-origin" },
    )

    assert_equal 303, browser.response.status
    confirmation_url = browser.response.location
    # A shorter authoritative parent deadline must dominate the still-live child capability.
    transaction.update_columns(expires_at: transaction.class.database_now - 1.second)

    assert_predicate binding.reload, :live?
    browser.host!(base_host)
    browser.get(confirmation_url)

    assert_equal 400, browser.response.status
    assert_nil browser.response.location
    assert_nil binding.reload.base_confirmed_at
    assert_nil binding.redeemed_at
  ensure
    ActionController::Base.allow_forgery_protection = protection
  end

  [
    ["app", "PUBLIC_AUTH_SERVICE_URL", ClientAuthAdmissionBinding, ClientAuthCeremonySession],
    ["com", "PUBLIC_AUTH_CORPORATE_URL", VisitorAuthAdmissionBinding, VisitorAuthCeremonySession],
    ["org", "PUBLIC_AUTH_STAFF_URL", OperatorAuthAdmissionBinding, OperatorAuthCeremonySession],
  ].each do |surface, host_key, binding_model, session_model|
    [-1, 0, 1].each do |microseconds|
      test "#{surface} attachment at deadline #{microseconds} microseconds allocates only before expiry" do
        protection = ActionController::Base.allow_forgery_protection
        ActionController::Base.allow_forgery_protection = true
        host = ENV.fetch(host_key)
        issuance = OidcTestEntry.issue!(
          surface: surface, intent: "sign_in", base_browser_nonce: SecureRandom.hex(32), base_token: nil,
        )
        browser = open_session
        browser.https!
        browser.host!(host)
        browser.get("/sign/in", params: { entry_ref: issuance.reference, ri: "jp" })

        assert_equal 200, browser.response.status
        csrf = browser.response.parsed_body.at_css('input[name="authenticity_token"]')["value"]
        binding = binding_model.find_by!(entry_ref: issuance.reference)
        deadline = binding.expires_at
        decision_time = deadline + Rational(microseconds, 1_000_000)
        before = session_model.count
        binding_model.stub(:database_now, decision_time) do
          browser.post(
            "/ceremony_bindings",
            params: { entry_ref: issuance.reference, authenticity_token: csrf, ri: "jp" },
            headers: { "Origin" => "https://#{host}", "Sec-Fetch-Site" => "same-origin" },
          )
        end

        if microseconds.negative?
          assert_equal 303, browser.response.status
          assert_equal before + 1, session_model.count
          assert_not_nil binding.reload.auth_ceremony_session_id
          assert_not_predicate session_model.find(binding.auth_ceremony_session_id), :admitted?
        else
          assert_equal 400, browser.response.status
          assert_equal before, session_model.count, "invalid attachment cannot create continuity"
          assert_nil browser.response.location
          cookie_name = JitSessionCookieConfig.force_secure? ? "__Host-auth_sid" : "auth_sid"

          assert_not_includes browser.response.headers["Set-Cookie"].to_s, "#{cookie_name}="
          assert_nil binding.reload.auth_ceremony_session_id
        end

        assert_equal deadline, binding.expires_at
        assert_nil binding.base_confirmed_at
        assert_nil binding.redeemed_at
        assert_equal "pending", issuance.transaction.reload.status
      ensure
        ActionController::Base.allow_forgery_protection = protection
      end

      test "#{surface} redemption at deadline #{microseconds} microseconds rotates only before expiry" do
        protection = ActionController::Base.allow_forgery_protection
        ActionController::Base.allow_forgery_protection = true
        host = ENV.fetch(host_key)
        issuance = OidcTestEntry.issue!(
          surface: surface, intent: "sign_in", base_browser_nonce: SecureRandom.hex(32), base_token: nil,
        )
        browser = open_session
        browser.https!
        browser.host!(host)
        browser.get("/sign/in", params: { entry_ref: issuance.reference, ri: "jp" })

        assert_equal 200, browser.response.status
        csrf = browser.response.parsed_body.at_css('input[name="authenticity_token"]')["value"]
        headers = { "Origin" => "https://#{host}", "Sec-Fetch-Site" => "same-origin" }
        browser.post(
          "/ceremony_bindings",
          params: { entry_ref: issuance.reference, authenticity_token: csrf, ri: "jp" }, headers:,
        )

        assert_equal 303, browser.response.status
        binding = binding_model.find_by!(entry_ref: issuance.reference)
        # Base confirmation has independent HTTP coverage; use its public transition to isolate redemption expiry.
        binding.confirm_base!(base_token: nil, browser_digest: binding.base_browser_digest)
        browser.get("/sign/in", params: { entry_ref: issuance.reference, ri: "jp" })

        assert_equal 200, browser.response.status
        csrf = browser.response.parsed_body.at_css('input[name="authenticity_token"]')["value"]
        continuity = auth_ceremony_session_for_test(binding)
        cookie_name = JitSessionCookieConfig.force_secure? ? "__Host-auth_sid" : "auth_sid"
        original_cookie = browser.cookies[cookie_name]
        deadline = binding.expires_at
        confirmed_at = binding.base_confirmed_at
        before = session_model.count
        decision_time = deadline + Rational(microseconds, 1_000_000)
        binding_model.stub(:database_now, decision_time) do
          browser.post(
            "/sign/in", params: { entry_ref: issuance.reference, authenticity_token: csrf, ri: "jp" }, headers:,
          )
        end

        if microseconds.negative?
          assert_equal 303, browser.response.status
          assert_equal before + 1, session_model.count
          assert_predicate binding.reload, :redeemed?
          assert_predicate admitted_auth_ceremony_session_for_test(binding), :admitted?
          assert_not_predicate continuity.reload, :active?
          assert_not_equal original_cookie, browser.cookies[cookie_name]
        else
          assert_equal 400, browser.response.status
          assert_equal before, session_model.count
          assert_nil browser.response.location
          assert_nil binding.reload.redeemed_at
          assert_nil binding.admitted_auth_ceremony_session_id
          assert_predicate continuity.reload, :active?
          assert_not_predicate continuity, :admitted?
          assert_equal original_cookie, browser.cookies[cookie_name]
        end

        assert_equal [deadline, confirmed_at], [binding.expires_at, binding.base_confirmed_at]
        assert_equal "pending", issuance.transaction.reload.status
      ensure
        ActionController::Base.allow_forgery_protection = protection
      end
    end
  end

  [
    ["app", "PUBLIC_BASE_SERVICE_URL", "PUBLIC_AUTH_SERVICE_URL", "core-app-jp", "client",
     ClientAuthAdmissionBinding,],
    ["com", "PUBLIC_BASE_CORPORATE_URL", "PUBLIC_AUTH_CORPORATE_URL", "core-com-jp", "visitor",
     VisitorAuthAdmissionBinding,],
    ["org", "PUBLIC_BASE_STAFF_URL", "PUBLIC_AUTH_STAFF_URL", "core-org-jp", "operator",
     OperatorAuthAdmissionBinding,],
  ].each do |surface, base_key, auth_key, client_id, realm, binding_model|
    test "#{surface} Base cookie loss and new nonce cannot confirm an old attached operation" do
      protection = ActionController::Base.allow_forgery_protection
      ActionController::Base.allow_forgery_protection = true
      base_host = ENV.fetch(base_key)
      auth_host = ENV.fetch(auth_key)
      browser = open_session
      browser.https!
      browser.host!(base_host)
      authorization = {
        response_type: "code",
        client_id: client_id,
        redirect_uri: OidcClientRegistry.find!(client_id).redirect_uris_by_realm.fetch(realm).first,
        code_challenge: "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM",
        code_challenge_method: "S256",
        scope: "openid",
        state: SecureRandom.urlsafe_base64(32),
        nonce: SecureRandom.urlsafe_base64(32),
        ri: "jp",
      }
      browser.get("/oauth/authorize", params: authorization)
      csrf = browser.response.parsed_body.at_css('input[name="authenticity_token"]')["value"]
      browser.post(
        "/oauth/authorize", params: authorization.merge(ceremony_action: "start", authenticity_token: csrf),
                            headers: { "Origin" => "https://#{base_host}", "Sec-Fetch-Site" => "same-origin" },
      )
      binding = binding_model.order(:id).last
      browser.host!(auth_host)
      browser.get("/sign/in", params: { entry_ref: binding.entry_ref, ri: "jp" })
      csrf = browser.response.parsed_body.at_css('input[name="authenticity_token"]')["value"]
      browser.post(
        "/ceremony_bindings", params: { entry_ref: binding.entry_ref, authenticity_token: csrf, ri: "jp" },
                              headers: { "Origin" => "https://#{auth_host}", "Sec-Fetch-Site" => "same-origin" },
      )

      assert_equal 303, browser.response.status
      confirmation_url = browser.response.location
      sid_key = JitSessionCookieConfig.force_secure? ? "__Host-auth_sid" : "auth_sid"
      retained_sid = browser.cookies[sid_key]
      original_facts = binding.reload.attributes
      browser.cookies.delete(Rails.application.config.session_options.fetch(:key))
      browser.host!(base_host)
      browser.get(confirmation_url)

      assert_equal [400, nil], [browser.response.status, browser.response.location]
      assert_equal original_facts, binding.reload.attributes
      authorization[:state] = SecureRandom.urlsafe_base64(32)
      browser.get("/oauth/authorize", params: authorization)
      csrf = browser.response.parsed_body.at_css('input[name="authenticity_token"]')["value"]
      browser.post(
        "/oauth/authorize", params: authorization.merge(ceremony_action: "start", authenticity_token: csrf),
                            headers: { "Origin" => "https://#{base_host}", "Sec-Fetch-Site" => "same-origin" },
      )

      assert_predicate browser.response, :redirect?
      sibling = binding_model.order(:id).last

      assert_not_equal binding.id, sibling.id
      assert_not_equal binding.base_browser_digest, sibling.base_browser_digest
      browser.get(confirmation_url)

      assert_equal [400, nil], [browser.response.status, browser.response.location]
      assert_equal original_facts, binding.reload.attributes
      assert_nil sibling.reload.auth_ceremony_session_id
      assert_nil sibling.base_confirmed_at
      assert_nil sibling.redeemed_at
      browser.host!(auth_host)

      assert_equal retained_sid, browser.cookies[sid_key]
      assert_not_predicate auth_ceremony_session_for_test(binding), :admitted?
      assert_equal "pending", authorization_transaction_for_test(binding).reload.status
      assert_equal "pending", authorization_transaction_for_test(sibling).reload.status
    ensure
      ActionController::Base.allow_forgery_protection = protection
    end
  end

  test "confirmation GET refuses a foreign Base browser that initiated its own admission in every realm" do
    protection = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    [
      ["app", ENV.fetch("PUBLIC_BASE_SERVICE_URL"), ENV.fetch("PUBLIC_AUTH_SERVICE_URL"),
       "core-app-jp", "client", ClientOidcAuthorizationTransaction, ClientAuthAdmissionBinding, "sign_in", "/sign/in",],
      ["app", ENV.fetch("PUBLIC_BASE_SERVICE_URL"), ENV.fetch("PUBLIC_AUTH_SERVICE_URL"),
       "core-app-jp", "client", ClientOidcAuthorizationTransaction, ClientAuthAdmissionBinding, "sign_up", "/sign/in",],
      ["com", ENV.fetch("PUBLIC_BASE_CORPORATE_URL"), ENV.fetch("PUBLIC_AUTH_CORPORATE_URL"),
       "core-com-jp", "visitor", VisitorOidcAuthorizationTransaction,
       VisitorAuthAdmissionBinding, "sign_in", "/sign/in",],
      ["com", ENV.fetch("PUBLIC_BASE_CORPORATE_URL"), ENV.fetch("PUBLIC_AUTH_CORPORATE_URL"),
       "core-com-jp", "visitor", VisitorOidcAuthorizationTransaction,
       VisitorAuthAdmissionBinding, "sign_up", "/sign/in",],
      ["org", ENV.fetch("PUBLIC_BASE_STAFF_URL"), ENV.fetch("PUBLIC_AUTH_STAFF_URL"),
       "core-org-jp", "operator", OperatorOidcAuthorizationTransaction, OperatorAuthAdmissionBinding,
       "sign_in", "/sign/in",],
    ].each do |surface, base_host, auth_host, client_id, realm, transaction_model, binding_model, intent, entry_path|
      owner = open_session
      foreign = open_session
      owner_binding = nil
      [owner, foreign].each do |browser|
        browser.https!
        browser.host!(base_host)
        authorization = {
          response_type: "code",
          client_id: client_id,
          redirect_uri: OidcClientRegistry.find!(client_id).redirect_uris_by_realm.fetch(realm).first,
          code_challenge: "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM",
          code_challenge_method: "S256",
          scope: "openid",
          state: SecureRandom.urlsafe_base64(32),
          nonce: SecureRandom.urlsafe_base64(32),
          ri: "jp",
          screen_hint: (intent == "sign_up") ? "signup" : "login",
        }
        before = binding_model.count
        browser.get("/oauth/authorize", params: authorization)

        assert_equal 200, browser.response.status, surface
        assert_equal before, binding_model.count, "authorization GET cannot issue a browser binding"
        csrf = browser.response.parsed_body.at_css('input[name="authenticity_token"]')["value"]
        browser.post(
          "/oauth/authorize",
          params: authorization.merge(ceremony_action: "start", authenticity_token: csrf),
          headers: { "Origin" => "https://#{base_host}", "Sec-Fetch-Site" => "same-origin" },
        )

        assert_predicate browser.response, :redirect?, surface
        transaction = transaction_model.find_by!(state: authorization.fetch(:state))

        assert_equal "authentication", transaction.intent, "first-party screen hints cannot change neutral intent"
        binding = binding_model.find_by!(authorization_transaction_id: transaction.id)
        owner_binding = binding if browser == owner
      end

      owner.host!(auth_host)
      owner.get(entry_path, params: { entry_ref: owner_binding.entry_ref, ri: "jp" })

      assert_equal 200, owner.response.status, surface
      csrf = owner.response.parsed_body.at_css('input[name="authenticity_token"]')["value"]
      owner.post(
        "/ceremony_bindings",
        params: { entry_ref: owner_binding.entry_ref, authenticity_token: csrf, ri: "jp" },
        headers: { "Origin" => "https://#{auth_host}", "Sec-Fetch-Site" => "same-origin" },
      )

      assert_equal 303, owner.response.status, surface
      confirmation_url = owner.response.location

      assert_equal base_host, URI.parse(confirmation_url).host
      assert_nil owner_binding.reload.base_confirmed_at
      foreign.host!(base_host)
      foreign.get(confirmation_url)

      assert_equal 400, foreign.response.status, surface
      assert_nil foreign.response.location
      assert_nil owner_binding.reload.base_confirmed_at
      assert_nil owner_binding.redeemed_at
      assert_includes foreign.response.headers.fetch("Cache-Control"), "no-store"
      owner.host!(base_host)
      owner.get(confirmation_url)

      assert_equal 200, owner.response.status, surface
      assert_nil owner_binding.reload.base_confirmed_at, "the original browser's GET is also read-only"
      csrf = owner.response.parsed_body.at_css('input[name="authenticity_token"]')["value"]
      owner.post(
        confirmation_url, params: { authenticity_token: csrf, ri: "jp" },
                          headers: { "Origin" => "https://#{base_host}", "Sec-Fetch-Site" => "same-origin" },
      )

      assert_equal 303, owner.response.status, surface
      assert_predicate owner_binding.reload, :confirmed?
      assert_nil owner_binding.redeemed_at
      entry_url = owner.response.location

      assert_equal [auth_host, entry_path], [URI.parse(entry_url).host, URI.parse(entry_url).path]
      foreign.host!(auth_host)
      foreign.get(entry_url)

      assert_equal [400, nil, nil],
                   [foreign.response.status, foreign.response.location, owner_binding.reload.redeemed_at],
                   "a confirmed URL in another browser cannot expose an admission form"
      owner.host!(auth_host)
      owner.get(entry_url)

      assert_equal 200, owner.response.status, surface
      assert_nil owner_binding.reload.redeemed_at
      csrf = owner.response.parsed_body.at_css('input[name="authenticity_token"]')["value"]
      continuity = auth_ceremony_session_for_test(owner_binding)
      original_cookie = owner.cookies["__Host-auth_sid"] || owner.cookies["auth_sid"]
      unavailable_store = Valkey::AuthState::OpaqueAdmissionStore.new
      unavailable_store.stub(:consume_reference!, ->(**) { raise Umaxica::Valkey::Unavailable, "unavailable" }) do
        Valkey::AuthState::OpaqueAdmissionStore.stub(:new, unavailable_store) do
          owner.post(
            entry_path, params: { entry_ref: owner_binding.entry_ref, authenticity_token: csrf, ri: "jp" },
                        headers: { "Origin" => "https://#{auth_host}", "Sec-Fetch-Site" => "same-origin" },
          )
        end
      end

      assert_equal 503, owner.response.status, surface
      assert_equal(
        { location: nil, redeemed_at: nil, active: true, cookie: original_cookie },
        { location: owner.response.location,
          redeemed_at: owner_binding.reload.redeemed_at,
          active: continuity.reload.active?,
          cookie: owner.cookies["__Host-auth_sid"] || owner.cookies["auth_sid"], },
        "backend unavailability preserves continuity and grants no admission in #{surface}",
      )
      owner.post(
        entry_path, params: { entry_ref: owner_binding.entry_ref, authenticity_token: csrf, ri: "jp" },
                    headers: { "Origin" => "https://#{auth_host}", "Sec-Fetch-Site" => "same-origin" },
      )

      assert_equal 303, owner.response.status, surface
      assert_equal [true, true, false],
                   [owner_binding.reload.redeemed?,
                    admitted_auth_ceremony_session_for_test(owner_binding).admitted?,
                    auth_ceremony_session_for_test(owner_binding).active?,],
                   "redemption atomically records admitted continuity and revokes its predecessor"
      assert_equal entry_path, URI.parse(owner.response.location).path
      assert_not_includes owner.response.location, "entry_ref"

      admitted_cookie = owner.cookies["__Host-auth_sid"] || owner.cookies["auth_sid"]
      admitted_id = owner_binding.admitted_auth_ceremony_session_id
      session_count = continuity.class.count
      owner.post(
        entry_path, params: { entry_ref: owner_binding.entry_ref, authenticity_token: csrf, ri: "jp" },
                    headers: { "Origin" => "https://#{auth_host}", "Sec-Fetch-Site" => "same-origin" },
      )

      assert_equal [303, admitted_id, admitted_cookie, session_count],
                   [owner.response.status, owner_binding.reload.admitted_auth_ceremony_session_id,
                    owner.cookies["__Host-auth_sid"] || owner.cookies["auth_sid"], continuity.class.count,],
                   "exact redemption retry returns its original outcome without another rotation"
      cookie_name = JitSessionCookieConfig.force_secure? ? "__Host-auth_sid" : "auth_sid"
      _restored_cookie = owner.cookies.merge(
        "#{cookie_name}=#{Rack::Utils.escape(original_cookie)}", URI.parse("https://#{auth_host}/"),
      )
      owner.post(
        entry_path, params: { entry_ref: owner_binding.entry_ref, authenticity_token: csrf, ri: "jp" },
                    headers: { "Origin" => "https://#{auth_host}", "Sec-Fetch-Site" => "same-origin" },
      )

      assert_equal [400, nil, admitted_id, original_cookie, session_count, false],
                   [owner.response.status, owner.response.location,
                    owner_binding.reload.admitted_auth_ceremony_session_id, owner.cookies[cookie_name],
                    continuity.class.count, continuity.reload.active?,],
                   "lost Set-Cookie delivery cannot revive the predecessor or reopen the redeemed parent"
    end
  ensure
    ActionController::Base.allow_forgery_protection = protection
  end

  SURFACES = [
    {
      name: "app",
      host_env: "PUBLIC_AUTH_SERVICE_URL",
      client_id: "core-app-jp",
      realm: "client",
      sign_in: :auth_app_sign_in_url,
    },
    {
      name: "com",
      host_env: "PUBLIC_AUTH_CORPORATE_URL",
      client_id: "core-com-jp",
      realm: "visitor",
      sign_in: :auth_com_sign_in_url,
    },
    {
      name: "org",
      host_env: "PUBLIC_AUTH_STAFF_URL",
      client_id: "core-org-jp",
      realm: "operator",
      sign_in: :auth_org_sign_in_url,
    },
  ].freeze

  # E01: Auth without a Base-issued admission is refused explicitly; it no longer bridges to Base.
  test "absent admission is refused without a redirect, a stored challenge, or a Base session token" do
    SURFACES.each do |surface|
      host = ENV.fetch(surface.fetch(:host_env))
      token_count = ClientToken.count
      open_session do |browser|
        browser.host!(host)
        browser.get(public_send(surface.fetch(:sign_in), ri: "jp"), headers: { "Host" => host })

        assert_equal 400, browser.response.status, surface.fetch(:name)
        assert_equal I18n.t("errors.messages.invalid_request"), browser.response.body, surface.fetch(:name)
        assert_nil browser.response.location, surface.fetch(:name)
        assert_nil browser.session[:oidc_authorization_login_challenge]
        assert_equal token_count, ClientToken.count
      end
    end
  end

  test "valid app admission stores the transaction challenge" do
    begin
      fv5398 = SURFACES.fetch(0)
      fv5465 = ENV.fetch(fv5398.fetch(:host_env))
      host!(fv5465)
      fv5397 = issue_transaction!(fv5398)

      begin
        fv5464 = public_send(fv5398.fetch(:sign_in))
        fv5463 = handoff_reference(fv5397)
        fv5462 = :entry_ref
        fv5461 = { ri: "jp" }
        fv5460 = { "Host" => fv5465 }
        fv5459 = false
        fv5458 = nil
        fv5457 = nil
        begin
          fv5403 = self
          fv5411 = fv5464
          fv5455 = fv5463
          fv5456 = fv5462
          fv5420 = fv5461
          fv5413 = fv5460
          fv5443 = fv5459
          fv5442 = fv5458
          fv5416 = fv5457
          fv5410 = fv5420.merge(fv5456 => fv5455)
          fv5403.get(fv5411, params: fv5410, headers: fv5413)
          fv5449 =
            begin
              fv5454 = fv5403.response.body
              fv5453 = true
              fv5452 = Nokogiri::HTML(fv5454).at_css("form")
              if fv5452.nil? && fv5453
                nil
              else
                raise RuntimeError, "Auth continuation form is missing" unless fv5452

                fv5451 = fv5452.at_css("input[name='authenticity_token']")&.[]("value")
                raise RuntimeError,
                      "Auth continuation is missing its CSRF token" if fv5451.blank?

                fv5450 = fv5452.css("input[type='hidden']").to_h do |fv5407|
                  [fv5407["name"], fv5407["value"]]
                end.except("authenticity_token")
                [fv5452["action"], fv5451, fv5450]
              end
            end
          if fv5449

            fv5448, fv5446, fv5447 = fv5449

            fv5403.session[BaseAdmissionBrowserBinding::BROWSER_NONCE_SESSION_KEY] ||=
              "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn"
            fv5403.post(
              fv5448, params: fv5447.merge(authenticity_token: fv5446),
                      headers: fv5413,
            )
            fv5445 = fv5403.response.location
            if fv5445.present?

              fv5441 = URI.parse(fv5445)
              fv5440 = fv5441.host
              fv5415 =
                begin
                  fv5444 = fv5440
                  {
                    ENV.fetch("PUBLIC_BASE_SERVICE_URL") => "app",
                    ENV.fetch("PUBLIC_BASE_CORPORATE_URL") => "com",
                    ENV.fetch("PUBLIC_BASE_STAFF_URL") => "org",
                    ENV.fetch("PUBLIC_VISA_SERVICE_URL") => "app",
                    ENV.fetch("PUBLIC_VISA_CORPORATE_URL") => "com",
                    ENV.fetch("PUBLIC_VISA_STAFF_URL") => "org",
                  }.fetch(fv5444)
                end
              fv5414 = BaseAuthAdmissionCoordinator.find_admission_binding_by_confirmation!(
                surface: fv5415, reference: fv5441.path.split("/").fetch(-2),
              )

              if fv5443
                fv5422 = fv5442 || fv5403
                fv5422.host!(fv5440)
                fv5422.https!
                fv5422.session[BaseAdmissionBrowserBinding::BROWSER_NONCE_SESSION_KEY] ||=
                  "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn"
                fv5439 = fv5441.request_uri
                fv5430 = fv5413.merge(
                  "Host" => fv5440,
                  "Origin" => "https://#{fv5440}",
                  "Sec-Fetch-Site" => "same-origin",
                )
                fv5422.get(fv5439, headers: fv5430)
                fv5433, fv5431, fv5432 =
                  begin
                    fv5438 = fv5422.response.body
                    fv5437 = false
                    fv5436 = Nokogiri::HTML(fv5438).at_css("form")
                    if fv5436.nil? && fv5437
                      nil
                    else
                      raise RuntimeError, "Auth continuation form is missing" unless fv5436

                      fv5435 = fv5436.at_css("input[name='authenticity_token']")&.[]("value")
                      raise RuntimeError,
                            "Auth continuation is missing its CSRF token" if fv5435.blank?

                      fv5434 = fv5436.css("input[type='hidden']").to_h do |fv5407|
                        [fv5407["name"], fv5407["value"]]
                      end.except("authenticity_token")
                      [fv5436["action"], fv5435, fv5434]
                    end
                  end
                fv5422.post(
                  fv5433,
                  params: fv5432.merge(authenticity_token: fv5431),
                  headers: fv5430,
                )
                begin
                  fv5423 = fv5422
                  fv5425 = "session"
                  fv5424 = fv5423.response.cookies[fv5425]
                  if fv5424.nil?
                    fv5429 = fv5423.response.headers["Set-Cookie"] || fv5423.response.headers["set-cookie"]
                    fv5428 =
                      if fv5429.is_a?(String) && fv5429.start_with?("[")
                        JSON.parse(fv5429)
                      else
                        Array(fv5429)
                      end
                    fv5426 =
                      fv5428.flat_map { |fv5427| fv5427.to_s.split("\n") }.find do |fv5427|
                        fv5427.split(";", 2).first.to_s.start_with?("#{fv5425}=")
                      end
                    if fv5426

                      _, fv5424 = fv5426.split(";", 2).first.to_s.split("=", 2)
                      fv5424 = Rack::Utils.unescape(fv5424.to_s)
                    end
                  end

                  unless fv5424.nil?
                    fv5423.cookies.delete(fv5425)
                    # Rack::Test's []= uses its default host. The current request may target a
                    # different surface, so install the cookie against the browser's active host.
                    fv5423.cookies.merge(
                      "#{fv5425}=#{Rack::Utils.escape(fv5424)}",
                      URI.parse("https://#{fv5423.host}/"),
                    )
                  end
                end
                fv5421 = fv5422.response.location
                raise RuntimeError, "Base confirmation did not return to Auth" if fv5421.blank?

                fv5418 = URI.parse(fv5421)
                if fv5420[:ri].present?
                  fv5419 = Rack::Utils.parse_nested_query(fv5418.query.to_s)
                  fv5419["ri"] ||= fv5420[:ri].to_s
                  fv5418.query = URI.encode_www_form(fv5419)
                end
                fv5403.host!(fv5418.host)
                fv5403.https!
                fv5417 = fv5418.request_uri
                fv5399 = fv5413.merge("Host" => fv5418.host)
                fv5403.get(fv5417, headers: fv5399)
              else
                fv5414.confirm_base!(
                  base_token: fv5416,
                  browser_digest: AuthAdmissionBinding.browser_digest(
                    surface: fv5415,
                    entry_ref: fv5414.entry_ref,
                    nonce: "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn",
                  ),
                )
                fv5412 = fv5403.host
                fv5403.host!(fv5412)
                fv5403.https!
                fv5399 = fv5413.merge("Host" => fv5412)
                fv5403.get(
                  fv5411, params: fv5410,
                          headers: fv5399,
                )
              end
              fv5402, fv5400, fv5401 =
                begin
                  fv5409 = fv5403.response.body
                  fv5408 = false
                  fv5406 = Nokogiri::HTML(fv5409).at_css("form")
                  if fv5406.nil? && fv5408
                    nil
                  else
                    raise RuntimeError, "Auth continuation form is missing" unless fv5406

                    fv5405 = fv5406.at_css("input[name='authenticity_token']")&.[]("value")
                    raise RuntimeError,
                          "Auth continuation is missing its CSRF token" if fv5405.blank?

                    fv5404 = fv5406.css("input[type='hidden']").to_h do |fv5407|
                      [fv5407["name"], fv5407["value"]]
                    end.except("authenticity_token")
                    [fv5406["action"], fv5405, fv5404]
                  end
                end
              fv5403.post(
                fv5402,
                params: fv5401.merge(authenticity_token: fv5400),
                headers: fv5399,
              )
            end
          end
        end
      end

      assert_response :see_other
      follow_redirect!

      assert_response :success

      fv5396 = auth_ceremony_record_for(fv5398.fetch(:name))

      assert_predicate fv5396, :admitted?
      assert_equal fv5397.transaction.transaction_id, fv5396.authorization_transaction_ref
      assert_nil session[:oidc_authorization_login_challenge]
      assert_nil session[:oidc_authorization_intent]
    end
  end

  test "valid com admission stores the transaction challenge" do
    begin
      fv5328 = SURFACES.fetch(1)
      fv5395 = ENV.fetch(fv5328.fetch(:host_env))
      host!(fv5395)
      fv5327 = issue_transaction!(fv5328)

      begin
        fv5394 = public_send(fv5328.fetch(:sign_in))
        fv5393 = handoff_reference(fv5327)
        fv5392 = :entry_ref
        fv5391 = { ri: "jp" }
        fv5390 = { "Host" => fv5395 }
        fv5389 = false
        fv5388 = nil
        fv5387 = nil
        begin
          fv5333 = self
          fv5341 = fv5394
          fv5385 = fv5393
          fv5386 = fv5392
          fv5350 = fv5391
          fv5343 = fv5390
          fv5373 = fv5389
          fv5372 = fv5388
          fv5346 = fv5387
          fv5340 = fv5350.merge(fv5386 => fv5385)
          fv5333.get(fv5341, params: fv5340, headers: fv5343)
          fv5379 =
            begin
              fv5384 = fv5333.response.body
              fv5383 = true
              fv5382 = Nokogiri::HTML(fv5384).at_css("form")
              if fv5382.nil? && fv5383
                nil
              else
                raise RuntimeError, "Auth continuation form is missing" unless fv5382

                fv5381 = fv5382.at_css("input[name='authenticity_token']")&.[]("value")
                raise RuntimeError,
                      "Auth continuation is missing its CSRF token" if fv5381.blank?

                fv5380 = fv5382.css("input[type='hidden']").to_h do |fv5337|
                  [fv5337["name"], fv5337["value"]]
                end.except("authenticity_token")
                [fv5382["action"], fv5381, fv5380]
              end
            end
          if fv5379

            fv5378, fv5376, fv5377 = fv5379

            fv5333.session[BaseAdmissionBrowserBinding::BROWSER_NONCE_SESSION_KEY] ||=
              "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn"
            fv5333.post(
              fv5378, params: fv5377.merge(authenticity_token: fv5376),
                      headers: fv5343,
            )
            fv5375 = fv5333.response.location
            if fv5375.present?

              fv5371 = URI.parse(fv5375)
              fv5370 = fv5371.host
              fv5345 =
                begin
                  fv5374 = fv5370
                  {
                    ENV.fetch("PUBLIC_BASE_SERVICE_URL") => "app",
                    ENV.fetch("PUBLIC_BASE_CORPORATE_URL") => "com",
                    ENV.fetch("PUBLIC_BASE_STAFF_URL") => "org",
                    ENV.fetch("PUBLIC_VISA_SERVICE_URL") => "app",
                    ENV.fetch("PUBLIC_VISA_CORPORATE_URL") => "com",
                    ENV.fetch("PUBLIC_VISA_STAFF_URL") => "org",
                  }.fetch(fv5374)
                end
              fv5344 = BaseAuthAdmissionCoordinator.find_admission_binding_by_confirmation!(
                surface: fv5345, reference: fv5371.path.split("/").fetch(-2),
              )

              if fv5373
                fv5352 = fv5372 || fv5333
                fv5352.host!(fv5370)
                fv5352.https!
                fv5352.session[BaseAdmissionBrowserBinding::BROWSER_NONCE_SESSION_KEY] ||=
                  "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn"
                fv5369 = fv5371.request_uri
                fv5360 = fv5343.merge(
                  "Host" => fv5370,
                  "Origin" => "https://#{fv5370}",
                  "Sec-Fetch-Site" => "same-origin",
                )
                fv5352.get(fv5369, headers: fv5360)
                fv5363, fv5361, fv5362 =
                  begin
                    fv5368 = fv5352.response.body
                    fv5367 = false
                    fv5366 = Nokogiri::HTML(fv5368).at_css("form")
                    if fv5366.nil? && fv5367
                      nil
                    else
                      raise RuntimeError, "Auth continuation form is missing" unless fv5366

                      fv5365 = fv5366.at_css("input[name='authenticity_token']")&.[]("value")
                      raise RuntimeError,
                            "Auth continuation is missing its CSRF token" if fv5365.blank?

                      fv5364 = fv5366.css("input[type='hidden']").to_h do |fv5337|
                        [fv5337["name"], fv5337["value"]]
                      end.except("authenticity_token")
                      [fv5366["action"], fv5365, fv5364]
                    end
                  end
                fv5352.post(
                  fv5363,
                  params: fv5362.merge(authenticity_token: fv5361),
                  headers: fv5360,
                )
                begin
                  fv5353 = fv5352
                  fv5355 = "session"
                  fv5354 = fv5353.response.cookies[fv5355]
                  if fv5354.nil?
                    fv5359 = fv5353.response.headers["Set-Cookie"] || fv5353.response.headers["set-cookie"]
                    fv5358 =
                      if fv5359.is_a?(String) && fv5359.start_with?("[")
                        JSON.parse(fv5359)
                      else
                        Array(fv5359)
                      end
                    fv5356 =
                      fv5358.flat_map { |fv5357| fv5357.to_s.split("\n") }.find do |fv5357|
                        fv5357.split(";", 2).first.to_s.start_with?("#{fv5355}=")
                      end
                    if fv5356

                      _, fv5354 = fv5356.split(";", 2).first.to_s.split("=", 2)
                      fv5354 = Rack::Utils.unescape(fv5354.to_s)
                    end
                  end

                  unless fv5354.nil?
                    fv5353.cookies.delete(fv5355)
                    # Rack::Test's []= uses its default host. The current request may target a
                    # different surface, so install the cookie against the browser's active host.
                    fv5353.cookies.merge(
                      "#{fv5355}=#{Rack::Utils.escape(fv5354)}",
                      URI.parse("https://#{fv5353.host}/"),
                    )
                  end
                end
                fv5351 = fv5352.response.location
                raise RuntimeError, "Base confirmation did not return to Auth" if fv5351.blank?

                fv5348 = URI.parse(fv5351)
                if fv5350[:ri].present?
                  fv5349 = Rack::Utils.parse_nested_query(fv5348.query.to_s)
                  fv5349["ri"] ||= fv5350[:ri].to_s
                  fv5348.query = URI.encode_www_form(fv5349)
                end
                fv5333.host!(fv5348.host)
                fv5333.https!
                fv5347 = fv5348.request_uri
                fv5329 = fv5343.merge("Host" => fv5348.host)
                fv5333.get(fv5347, headers: fv5329)
              else
                fv5344.confirm_base!(
                  base_token: fv5346,
                  browser_digest: AuthAdmissionBinding.browser_digest(
                    surface: fv5345,
                    entry_ref: fv5344.entry_ref,
                    nonce: "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn",
                  ),
                )
                fv5342 = fv5333.host
                fv5333.host!(fv5342)
                fv5333.https!
                fv5329 = fv5343.merge("Host" => fv5342)
                fv5333.get(
                  fv5341, params: fv5340,
                          headers: fv5329,
                )
              end
              fv5332, fv5330, fv5331 =
                begin
                  fv5339 = fv5333.response.body
                  fv5338 = false
                  fv5336 = Nokogiri::HTML(fv5339).at_css("form")
                  if fv5336.nil? && fv5338
                    nil
                  else
                    raise RuntimeError, "Auth continuation form is missing" unless fv5336

                    fv5335 = fv5336.at_css("input[name='authenticity_token']")&.[]("value")
                    raise RuntimeError,
                          "Auth continuation is missing its CSRF token" if fv5335.blank?

                    fv5334 = fv5336.css("input[type='hidden']").to_h do |fv5337|
                      [fv5337["name"], fv5337["value"]]
                    end.except("authenticity_token")
                    [fv5336["action"], fv5335, fv5334]
                  end
                end
              fv5333.post(
                fv5332,
                params: fv5331.merge(authenticity_token: fv5330),
                headers: fv5329,
              )
            end
          end
        end
      end

      assert_response :see_other
      follow_redirect!

      assert_response :success

      fv5326 = auth_ceremony_record_for(fv5328.fetch(:name))

      assert_predicate fv5326, :admitted?
      assert_equal fv5327.transaction.transaction_id, fv5326.authorization_transaction_ref
      assert_nil session[:oidc_authorization_login_challenge]
      assert_nil session[:oidc_authorization_intent]
    end
  end

  test "valid org admission stores the transaction challenge" do
    begin
      fv5258 = SURFACES.fetch(2)
      fv5325 = ENV.fetch(fv5258.fetch(:host_env))
      host!(fv5325)
      fv5257 = issue_transaction!(fv5258)

      begin
        fv5324 = public_send(fv5258.fetch(:sign_in))
        fv5323 = handoff_reference(fv5257)
        fv5322 = :entry_ref
        fv5321 = { ri: "jp" }
        fv5320 = { "Host" => fv5325 }
        fv5319 = false
        fv5318 = nil
        fv5317 = nil
        begin
          fv5263 = self
          fv5271 = fv5324
          fv5315 = fv5323
          fv5316 = fv5322
          fv5280 = fv5321
          fv5273 = fv5320
          fv5303 = fv5319
          fv5302 = fv5318
          fv5276 = fv5317
          fv5270 = fv5280.merge(fv5316 => fv5315)
          fv5263.get(fv5271, params: fv5270, headers: fv5273)
          fv5309 =
            begin
              fv5314 = fv5263.response.body
              fv5313 = true
              fv5312 = Nokogiri::HTML(fv5314).at_css("form")
              if fv5312.nil? && fv5313
                nil
              else
                raise RuntimeError, "Auth continuation form is missing" unless fv5312

                fv5311 = fv5312.at_css("input[name='authenticity_token']")&.[]("value")
                raise RuntimeError,
                      "Auth continuation is missing its CSRF token" if fv5311.blank?

                fv5310 = fv5312.css("input[type='hidden']").to_h do |fv5267|
                  [fv5267["name"], fv5267["value"]]
                end.except("authenticity_token")
                [fv5312["action"], fv5311, fv5310]
              end
            end
          if fv5309

            fv5308, fv5306, fv5307 = fv5309

            fv5263.session[BaseAdmissionBrowserBinding::BROWSER_NONCE_SESSION_KEY] ||=
              "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn"
            fv5263.post(
              fv5308, params: fv5307.merge(authenticity_token: fv5306),
                      headers: fv5273,
            )
            fv5305 = fv5263.response.location
            if fv5305.present?

              fv5301 = URI.parse(fv5305)
              fv5300 = fv5301.host
              fv5275 =
                begin
                  fv5304 = fv5300
                  {
                    ENV.fetch("PUBLIC_BASE_SERVICE_URL") => "app",
                    ENV.fetch("PUBLIC_BASE_CORPORATE_URL") => "com",
                    ENV.fetch("PUBLIC_BASE_STAFF_URL") => "org",
                    ENV.fetch("PUBLIC_VISA_SERVICE_URL") => "app",
                    ENV.fetch("PUBLIC_VISA_CORPORATE_URL") => "com",
                    ENV.fetch("PUBLIC_VISA_STAFF_URL") => "org",
                  }.fetch(fv5304)
                end
              fv5274 = BaseAuthAdmissionCoordinator.find_admission_binding_by_confirmation!(
                surface: fv5275, reference: fv5301.path.split("/").fetch(-2),
              )

              if fv5303
                fv5282 = fv5302 || fv5263
                fv5282.host!(fv5300)
                fv5282.https!
                fv5282.session[BaseAdmissionBrowserBinding::BROWSER_NONCE_SESSION_KEY] ||=
                  "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn"
                fv5299 = fv5301.request_uri
                fv5290 = fv5273.merge(
                  "Host" => fv5300,
                  "Origin" => "https://#{fv5300}",
                  "Sec-Fetch-Site" => "same-origin",
                )
                fv5282.get(fv5299, headers: fv5290)
                fv5293, fv5291, fv5292 =
                  begin
                    fv5298 = fv5282.response.body
                    fv5297 = false
                    fv5296 = Nokogiri::HTML(fv5298).at_css("form")
                    if fv5296.nil? && fv5297
                      nil
                    else
                      raise RuntimeError, "Auth continuation form is missing" unless fv5296

                      fv5295 = fv5296.at_css("input[name='authenticity_token']")&.[]("value")
                      raise RuntimeError,
                            "Auth continuation is missing its CSRF token" if fv5295.blank?

                      fv5294 = fv5296.css("input[type='hidden']").to_h do |fv5267|
                        [fv5267["name"], fv5267["value"]]
                      end.except("authenticity_token")
                      [fv5296["action"], fv5295, fv5294]
                    end
                  end
                fv5282.post(
                  fv5293,
                  params: fv5292.merge(authenticity_token: fv5291),
                  headers: fv5290,
                )
                begin
                  fv5283 = fv5282
                  fv5285 = "session"
                  fv5284 = fv5283.response.cookies[fv5285]
                  if fv5284.nil?
                    fv5289 = fv5283.response.headers["Set-Cookie"] || fv5283.response.headers["set-cookie"]
                    fv5288 =
                      if fv5289.is_a?(String) && fv5289.start_with?("[")
                        JSON.parse(fv5289)
                      else
                        Array(fv5289)
                      end
                    fv5286 =
                      fv5288.flat_map { |fv5287| fv5287.to_s.split("\n") }.find do |fv5287|
                        fv5287.split(";", 2).first.to_s.start_with?("#{fv5285}=")
                      end
                    if fv5286

                      _, fv5284 = fv5286.split(";", 2).first.to_s.split("=", 2)
                      fv5284 = Rack::Utils.unescape(fv5284.to_s)
                    end
                  end

                  unless fv5284.nil?
                    fv5283.cookies.delete(fv5285)
                    # Rack::Test's []= uses its default host. The current request may target a
                    # different surface, so install the cookie against the browser's active host.
                    fv5283.cookies.merge(
                      "#{fv5285}=#{Rack::Utils.escape(fv5284)}",
                      URI.parse("https://#{fv5283.host}/"),
                    )
                  end
                end
                fv5281 = fv5282.response.location
                raise RuntimeError, "Base confirmation did not return to Auth" if fv5281.blank?

                fv5278 = URI.parse(fv5281)
                if fv5280[:ri].present?
                  fv5279 = Rack::Utils.parse_nested_query(fv5278.query.to_s)
                  fv5279["ri"] ||= fv5280[:ri].to_s
                  fv5278.query = URI.encode_www_form(fv5279)
                end
                fv5263.host!(fv5278.host)
                fv5263.https!
                fv5277 = fv5278.request_uri
                fv5259 = fv5273.merge("Host" => fv5278.host)
                fv5263.get(fv5277, headers: fv5259)
              else
                fv5274.confirm_base!(
                  base_token: fv5276,
                  browser_digest: AuthAdmissionBinding.browser_digest(
                    surface: fv5275,
                    entry_ref: fv5274.entry_ref,
                    nonce: "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn",
                  ),
                )
                fv5272 = fv5263.host
                fv5263.host!(fv5272)
                fv5263.https!
                fv5259 = fv5273.merge("Host" => fv5272)
                fv5263.get(
                  fv5271, params: fv5270,
                          headers: fv5259,
                )
              end
              fv5262, fv5260, fv5261 =
                begin
                  fv5269 = fv5263.response.body
                  fv5268 = false
                  fv5266 = Nokogiri::HTML(fv5269).at_css("form")
                  if fv5266.nil? && fv5268
                    nil
                  else
                    raise RuntimeError, "Auth continuation form is missing" unless fv5266

                    fv5265 = fv5266.at_css("input[name='authenticity_token']")&.[]("value")
                    raise RuntimeError,
                          "Auth continuation is missing its CSRF token" if fv5265.blank?

                    fv5264 = fv5266.css("input[type='hidden']").to_h do |fv5267|
                      [fv5267["name"], fv5267["value"]]
                    end.except("authenticity_token")
                    [fv5266["action"], fv5265, fv5264]
                  end
                end
              fv5263.post(
                fv5262,
                params: fv5261.merge(authenticity_token: fv5260),
                headers: fv5259,
              )
            end
          end
        end
      end

      assert_response :see_other
      follow_redirect!

      assert_response :success

      fv5256 = auth_ceremony_record_for(fv5258.fetch(:name))

      assert_predicate fv5256, :admitted?
      assert_equal fv5257.transaction.transaction_id, fv5256.authorization_transaction_ref
      assert_nil session[:oidc_authorization_login_challenge]
      assert_nil session[:oidc_authorization_intent]
    end
  end

  test "admission rejects a transaction expired by the writer database clock" do
    surface = SURFACES.first
    host = ENV.fetch(surface.fetch(:host_env))
    host! host
    issuance = issue_transaction!(surface)
    reference = handoff_reference(issuance)
    binding = BaseAuthAdmissionCoordinator.find_admission_binding!(surface: "app", reference: reference)
    _continuity, raw_sid =
      begin
        admission_binding = binding
        admission_session, admission_raw_sid = admission_binding.class.auth_admission_session_class.issue!
        admission_binding.attach_auth_session!(
          auth_session: admission_session,
          confirmation_ref: SecureRandom.uuid,
        )
        admission_binding.confirm_base!(
          base_token: nil,
          browser_digest: AuthAdmissionBinding.browser_digest(
            surface: admission_binding.class.auth_admission_surface_name,
            entry_ref: admission_binding.entry_ref,
            nonce: "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn",
          ),
        )
        [admission_session, admission_raw_sid]
      end
    cookie_name = JitSessionCookieConfig.force_secure? ? "__Host-auth_sid" : "auth_sid"
    installed = cookies.merge("#{cookie_name}=#{Rack::Utils.escape(raw_sid)}", URI.parse("https://#{host}/"))

    assert_equal ["#{cookie_name}=#{Rack::Utils.escape(raw_sid)}"], installed
    get auth_app_sign_in_path(ri: "jp"), params: { entry_ref: reference }, headers: { "Host" => host }
    csrf = response.parsed_body.at_css('input[name="authenticity_token"]')["value"]
    issuance.transaction.update!(login_challenge_expires_at: issuance.transaction.class.database_now - 1.second)
    get auth_app_sign_in_path(ri: "jp"), params: { entry_ref: reference }, headers: { "Host" => host }

    assert_response :bad_request
    assert_nil response.location
    post(
      auth_app_sign_in_path(ri: "jp"), params: { entry_ref: reference, authenticity_token: csrf },
                                       headers: { "Host" => host },
    )

    assert_response :bad_request
    assert_nil session[:oidc_authorization_login_challenge]
    assert_predicate auth_ceremony_record_for(surface.fetch(:name)), :present?
    assert_not_predicate auth_ceremony_record_for(surface.fetch(:name)), :admitted?
  end

  test "replayed admission is rejected and does not create a Base session token" do
    host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    issuance = issue_transaction!(SURFACES.first)
    reference = handoff_reference(issuance)
    token_count = ClientToken.count

    open_session do |first|
      first.host!(host)
      begin
        fv5255 = first
        fv5254 = auth_app_sign_in_path(ri: "jp")
        fv5253 = reference
        fv5252 = :entry_ref
        fv5251 = {}
        fv5250 = { "Host" => host }
        fv5249 = false
        fv5248 = nil
        begin
          fv5196 = fv5255
          fv5203 = fv5254
          fv5246 = fv5253
          fv5247 = fv5252
          fv5212 = fv5251
          fv5205 = fv5250
          fv5234 = fv5249
          fv5233 = fv5248
          fv5208 = nil
          fv5202 = fv5212.merge(fv5247 => fv5246)
          fv5196.get(fv5203, params: fv5202, headers: fv5205)
          fv5240 =
            begin
              fv5245 = fv5196.response.body
              fv5244 = true
              fv5243 = Nokogiri::HTML(fv5245).at_css("form")
              if fv5243.nil? && fv5244
                nil
              else
                raise RuntimeError, "Auth continuation form is missing" unless fv5243

                fv5242 = fv5243.at_css("input[name='authenticity_token']")&.[]("value")
                raise RuntimeError,
                      "Auth continuation is missing its CSRF token" if fv5242.blank?

                fv5241 = fv5243.css("input[type='hidden']").to_h do |input|
                  [input["name"], input["value"]]
                end.except("authenticity_token")
                [fv5243["action"], fv5242, fv5241]
              end
            end
          if fv5240

            fv5239, fv5237, fv5238 = fv5240

            fv5196.session[BaseAdmissionBrowserBinding::BROWSER_NONCE_SESSION_KEY] ||=
              "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn"
            fv5196.post(
              fv5239,
              params: fv5238.merge(authenticity_token: fv5237),
              headers: fv5205,
            )
            fv5236 = fv5196.response.location
            if fv5236.present?

              fv5232 = URI.parse(fv5236)
              fv5231 = fv5232.host
              fv5207 =
                begin
                  fv5235 = fv5231
                  {
                    ENV.fetch("PUBLIC_BASE_SERVICE_URL") => "app",
                    ENV.fetch("PUBLIC_BASE_CORPORATE_URL") => "com",
                    ENV.fetch("PUBLIC_BASE_STAFF_URL") => "org",
                    ENV.fetch("PUBLIC_VISA_SERVICE_URL") => "app",
                    ENV.fetch("PUBLIC_VISA_CORPORATE_URL") => "com",
                    ENV.fetch("PUBLIC_VISA_STAFF_URL") => "org",
                  }.fetch(fv5235)
                end
              fv5206 = BaseAuthAdmissionCoordinator.find_admission_binding_by_confirmation!(
                surface: fv5207, reference: fv5232.path.split("/").fetch(-2),
              )

              if fv5234
                fv5214 = fv5233 || fv5196
                fv5214.host!(fv5231)
                fv5214.https!
                fv5214.session[BaseAdmissionBrowserBinding::BROWSER_NONCE_SESSION_KEY] ||=
                  "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn"
                fv5230 = fv5232.request_uri
                fv5221 = fv5205.merge(
                  "Host" => fv5231,
                  "Origin" => "https://#{fv5231}",
                  "Sec-Fetch-Site" => "same-origin",
                )
                fv5214.get(fv5230, headers: fv5221)
                fv5224, fv5222, fv5223 =
                  begin
                    fv5229 = fv5214.response.body
                    fv5228 = false
                    fv5227 = Nokogiri::HTML(fv5229).at_css("form")
                    if fv5227.nil? && fv5228
                      nil
                    else
                      raise RuntimeError, "Auth continuation form is missing" unless fv5227

                      fv5226 = fv5227.at_css("input[name='authenticity_token']")&.[]("value")
                      raise RuntimeError,
                            "Auth continuation is missing its CSRF token" if fv5226.blank?

                      fv5225 = fv5227.css("input[type='hidden']").to_h do |input|
                        [input["name"], input["value"]]
                      end.except("authenticity_token")
                      [fv5227["action"], fv5226, fv5225]
                    end
                  end
                fv5214.post(
                  fv5224,
                  params: fv5223.merge(authenticity_token: fv5222),
                  headers: fv5221,
                )
                begin
                  fv5215 = fv5214
                  fv5217 = "session"
                  fv5216 = fv5215.response.cookies[fv5217]
                  if fv5216.nil?
                    fv5220 = fv5215.response.headers["Set-Cookie"] || fv5215.response.headers["set-cookie"]
                    fv5219 =
                      if fv5220.is_a?(String) && fv5220.start_with?("[")
                        JSON.parse(fv5220)
                      else
                        Array(fv5220)
                      end
                    fv5218 =
                      fv5219.flat_map { |entry| entry.to_s.split("\n") }.find do |entry|
                        entry.split(";", 2).first.to_s.start_with?("#{fv5217}=")
                      end
                    if fv5218

                      _, fv5216 = fv5218.split(";", 2).first.to_s.split("=", 2)
                      fv5216 = Rack::Utils.unescape(fv5216.to_s)
                    end
                  end

                  unless fv5216.nil?
                    fv5215.cookies.delete(fv5217)
                    # Rack::Test's []= uses its default host. The current request may target a
                    # different surface, so install the cookie against the browser's active host.
                    fv5215.cookies.merge(
                      "#{fv5217}=#{Rack::Utils.escape(fv5216)}",
                      URI.parse("https://#{fv5215.host}/"),
                    )
                  end
                end
                fv5213 = fv5214.response.location
                raise RuntimeError, "Base confirmation did not return to Auth" if fv5213.blank?

                fv5210 = URI.parse(fv5213)
                if fv5212[:ri].present?
                  fv5211 = Rack::Utils.parse_nested_query(fv5210.query.to_s)
                  fv5211["ri"] ||= fv5212[:ri].to_s
                  fv5210.query = URI.encode_www_form(fv5211)
                end
                fv5196.host!(fv5210.host)
                fv5196.https!
                fv5209 = fv5210.request_uri
                fv5192 = fv5205.merge("Host" => fv5210.host)
                fv5196.get(fv5209, headers: fv5192)
              else
                fv5206.confirm_base!(
                  base_token: fv5208,
                  browser_digest: AuthAdmissionBinding.browser_digest(
                    surface: fv5207,
                    entry_ref: fv5206.entry_ref,
                    nonce: "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn",
                  ),
                )
                fv5204 = fv5196.host
                fv5196.host!(fv5204)
                fv5196.https!
                fv5192 = fv5205.merge("Host" => fv5204)
                fv5196.get(fv5203, params: fv5202, headers: fv5192)
              end
              fv5195, fv5193, fv5194 =
                begin
                  fv5201 = fv5196.response.body
                  fv5200 = false
                  fv5199 = Nokogiri::HTML(fv5201).at_css("form")
                  if fv5199.nil? && fv5200
                    nil
                  else
                    raise RuntimeError, "Auth continuation form is missing" unless fv5199

                    fv5198 = fv5199.at_css("input[name='authenticity_token']")&.[]("value")
                    raise RuntimeError,
                          "Auth continuation is missing its CSRF token" if fv5198.blank?

                    fv5197 = fv5199.css("input[type='hidden']").to_h do |input|
                      [input["name"], input["value"]]
                    end.except("authenticity_token")
                    [fv5199["action"], fv5198, fv5197]
                  end
                end
              fv5196.post(
                fv5195,
                params: fv5194.merge(authenticity_token: fv5193),
                headers: fv5192,
              )
            end
          end
        end
      end

      assert_equal 303, first.response.status
    end

    open_session do |second|
      second.host!(host)
      begin
        fv5191 = second
        fv5190 = auth_app_sign_in_path(ri: "jp")
        fv5189 = reference
        fv5188 = :entry_ref
        fv5187 = {}
        fv5186 = { "Host" => host }
        fv5185 = false
        fv5184 = nil
        begin
          fv5132 = fv5191
          fv5139 = fv5190
          fv5182 = fv5189
          fv5183 = fv5188
          fv5148 = fv5187
          fv5141 = fv5186
          fv5170 = fv5185
          fv5169 = fv5184
          fv5144 = nil
          fv5138 = fv5148.merge(fv5183 => fv5182)
          fv5132.get(fv5139, params: fv5138, headers: fv5141)
          fv5176 =
            begin
              fv5181 = fv5132.response.body
              fv5180 = true
              fv5179 = Nokogiri::HTML(fv5181).at_css("form")
              if fv5179.nil? && fv5180
                nil
              else
                raise RuntimeError, "Auth continuation form is missing" unless fv5179

                fv5178 = fv5179.at_css("input[name='authenticity_token']")&.[]("value")
                raise RuntimeError,
                      "Auth continuation is missing its CSRF token" if fv5178.blank?

                fv5177 = fv5179.css("input[type='hidden']").to_h do |input|
                  [input["name"], input["value"]]
                end.except("authenticity_token")
                [fv5179["action"], fv5178, fv5177]
              end
            end
          if fv5176

            fv5175, fv5173, fv5174 = fv5176

            fv5132.session[BaseAdmissionBrowserBinding::BROWSER_NONCE_SESSION_KEY] ||=
              "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn"
            fv5132.post(
              fv5175,
              params: fv5174.merge(authenticity_token: fv5173),
              headers: fv5141,
            )
            fv5172 = fv5132.response.location
            if fv5172.present?

              fv5168 = URI.parse(fv5172)
              fv5167 = fv5168.host
              fv5143 =
                begin
                  fv5171 = fv5167
                  {
                    ENV.fetch("PUBLIC_BASE_SERVICE_URL") => "app",
                    ENV.fetch("PUBLIC_BASE_CORPORATE_URL") => "com",
                    ENV.fetch("PUBLIC_BASE_STAFF_URL") => "org",
                    ENV.fetch("PUBLIC_VISA_SERVICE_URL") => "app",
                    ENV.fetch("PUBLIC_VISA_CORPORATE_URL") => "com",
                    ENV.fetch("PUBLIC_VISA_STAFF_URL") => "org",
                  }.fetch(fv5171)
                end
              fv5142 = BaseAuthAdmissionCoordinator.find_admission_binding_by_confirmation!(
                surface: fv5143, reference: fv5168.path.split("/").fetch(-2),
              )

              if fv5170
                fv5150 = fv5169 || fv5132
                fv5150.host!(fv5167)
                fv5150.https!
                fv5150.session[BaseAdmissionBrowserBinding::BROWSER_NONCE_SESSION_KEY] ||=
                  "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn"
                fv5166 = fv5168.request_uri
                fv5157 = fv5141.merge(
                  "Host" => fv5167,
                  "Origin" => "https://#{fv5167}",
                  "Sec-Fetch-Site" => "same-origin",
                )
                fv5150.get(fv5166, headers: fv5157)
                fv5160, fv5158, fv5159 =
                  begin
                    fv5165 = fv5150.response.body
                    fv5164 = false
                    fv5163 = Nokogiri::HTML(fv5165).at_css("form")
                    if fv5163.nil? && fv5164
                      nil
                    else
                      raise RuntimeError, "Auth continuation form is missing" unless fv5163

                      fv5162 = fv5163.at_css("input[name='authenticity_token']")&.[]("value")
                      raise RuntimeError,
                            "Auth continuation is missing its CSRF token" if fv5162.blank?

                      fv5161 = fv5163.css("input[type='hidden']").to_h do |input|
                        [input["name"], input["value"]]
                      end.except("authenticity_token")
                      [fv5163["action"], fv5162, fv5161]
                    end
                  end
                fv5150.post(
                  fv5160,
                  params: fv5159.merge(authenticity_token: fv5158),
                  headers: fv5157,
                )
                begin
                  fv5151 = fv5150
                  fv5153 = "session"
                  fv5152 = fv5151.response.cookies[fv5153]
                  if fv5152.nil?
                    fv5156 = fv5151.response.headers["Set-Cookie"] || fv5151.response.headers["set-cookie"]
                    fv5155 =
                      if fv5156.is_a?(String) && fv5156.start_with?("[")
                        JSON.parse(fv5156)
                      else
                        Array(fv5156)
                      end
                    fv5154 =
                      fv5155.flat_map { |entry| entry.to_s.split("\n") }.find do |entry|
                        entry.split(";", 2).first.to_s.start_with?("#{fv5153}=")
                      end
                    if fv5154

                      _, fv5152 = fv5154.split(";", 2).first.to_s.split("=", 2)
                      fv5152 = Rack::Utils.unescape(fv5152.to_s)
                    end
                  end

                  unless fv5152.nil?
                    fv5151.cookies.delete(fv5153)
                    # Rack::Test's []= uses its default host. The current request may target a
                    # different surface, so install the cookie against the browser's active host.
                    fv5151.cookies.merge(
                      "#{fv5153}=#{Rack::Utils.escape(fv5152)}",
                      URI.parse("https://#{fv5151.host}/"),
                    )
                  end
                end
                fv5149 = fv5150.response.location
                raise RuntimeError, "Base confirmation did not return to Auth" if fv5149.blank?

                fv5146 = URI.parse(fv5149)
                if fv5148[:ri].present?
                  fv5147 = Rack::Utils.parse_nested_query(fv5146.query.to_s)
                  fv5147["ri"] ||= fv5148[:ri].to_s
                  fv5146.query = URI.encode_www_form(fv5147)
                end
                fv5132.host!(fv5146.host)
                fv5132.https!
                fv5145 = fv5146.request_uri
                fv5128 = fv5141.merge("Host" => fv5146.host)
                fv5132.get(fv5145, headers: fv5128)
              else
                fv5142.confirm_base!(
                  base_token: fv5144,
                  browser_digest: AuthAdmissionBinding.browser_digest(
                    surface: fv5143,
                    entry_ref: fv5142.entry_ref,
                    nonce: "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn",
                  ),
                )
                fv5140 = fv5132.host
                fv5132.host!(fv5140)
                fv5132.https!
                fv5128 = fv5141.merge("Host" => fv5140)
                fv5132.get(fv5139, params: fv5138, headers: fv5128)
              end
              fv5131, fv5129, fv5130 =
                begin
                  fv5137 = fv5132.response.body
                  fv5136 = false
                  fv5135 = Nokogiri::HTML(fv5137).at_css("form")
                  if fv5135.nil? && fv5136
                    nil
                  else
                    raise RuntimeError, "Auth continuation form is missing" unless fv5135

                    fv5134 = fv5135.at_css("input[name='authenticity_token']")&.[]("value")
                    raise RuntimeError,
                          "Auth continuation is missing its CSRF token" if fv5134.blank?

                    fv5133 = fv5135.css("input[type='hidden']").to_h do |input|
                      [input["name"], input["value"]]
                    end.except("authenticity_token")
                    [fv5135["action"], fv5134, fv5133]
                  end
                end
              fv5132.post(
                fv5131,
                params: fv5130.merge(authenticity_token: fv5129),
                headers: fv5128,
              )
            end
          end
        end
      end

      assert_equal 400, second.response.status
      assert_nil second.session[:oidc_authorization_login_challenge]
      assert_equal token_count, ClientToken.count
    end
  end

  test "wrong-purpose admission is rejected before offering a continuation or consuming it" do
    host! ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    https!
    transaction = OidcAuthorizationTransactionCoordinator.issue!(
      surface: "app", intent: "sign_up",
      params: {
        response_type: "code",
        client_id: "core-app-jp",
        redirect_uri: OidcClientRegistry.find!("core-app-jp").redirect_uris_by_realm.fetch("client").first,
        code_challenge: "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM",
        code_challenge_method: "S256",
        state: SecureRandom.hex(16),
        nonce: SecureRandom.hex(16),
        scope: "openid profile",
        prompt: "create",
      },
    ).transaction
    handoff = BaseAuthAdmissionCoordinator.issue_handoff!(
      transaction: transaction, base_browser_nonce: SecureRandom.hex(32), base_token: nil,
    )
    binding = ClientAuthAdmissionBinding.find_by!(entry_ref: handoff.reference)
    before = binding.attributes
    session_count = ClientAuthCeremonySession.count

    # WU-24b refuses on GET before a form is offered; wrong-intent POST refusal is covered by
    # EffectiveEntryIntentTest. There is no continuation to submit for this invalid entry.
    get auth_app_sign_in_path(ri: "jp"), params: { entry_ref: handoff.reference }

    assert_response :bad_request
    assert_equal before, binding.reload.attributes
    assert_equal session_count, ClientAuthCeremonySession.count
    assert_nil session[:oidc_authorization_login_challenge]
  end

  test "wrong-surface admission is rejected" do
    host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    host! host
    issuance = issue_transaction!(SURFACES.fetch(1))

    begin
      fv5063 = auth_app_sign_in_path(ri: "jp")
      fv5062 = handoff_reference(issuance)
      fv5061 = :entry_ref
      fv5060 = { ri: "jp" }
      fv5059 = { "Host" => host }
      fv5058 = false
      fv5057 = nil
      fv5056 = nil
      begin
        fv5004 = self
        fv5011 = fv5063
        fv5054 = fv5062
        fv5055 = fv5061
        fv5020 = fv5060
        fv5013 = fv5059
        fv5042 = fv5058
        fv5041 = fv5057
        fv5016 = fv5056
        fv5010 = fv5020.merge(fv5055 => fv5054)
        fv5004.get(fv5011, params: fv5010, headers: fv5013)
        fv5048 =
          begin
            fv5053 = fv5004.response.body
            fv5052 = true
            fv5051 = Nokogiri::HTML(fv5053).at_css("form")
            if fv5051.nil? && fv5052
              nil
            else
              raise RuntimeError, "Auth continuation form is missing" unless fv5051

              fv5050 = fv5051.at_css("input[name='authenticity_token']")&.[]("value")
              raise RuntimeError,
                    "Auth continuation is missing its CSRF token" if fv5050.blank?

              fv5049 = fv5051.css("input[type='hidden']").to_h do |input|
                [input["name"], input["value"]]
              end.except("authenticity_token")
              [fv5051["action"], fv5050, fv5049]
            end
          end
        if fv5048

          fv5047, fv5045, fv5046 = fv5048

          fv5004.session[BaseAdmissionBrowserBinding::BROWSER_NONCE_SESSION_KEY] ||=
            "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn"
          fv5004.post(
            fv5047, params: fv5046.merge(authenticity_token: fv5045),
                    headers: fv5013,
          )
          fv5044 = fv5004.response.location
          if fv5044.present?

            fv5040 = URI.parse(fv5044)
            fv5039 = fv5040.host
            fv5015 =
              begin
                fv5043 = fv5039
                {
                  ENV.fetch("PUBLIC_BASE_SERVICE_URL") => "app",
                  ENV.fetch("PUBLIC_BASE_CORPORATE_URL") => "com",
                  ENV.fetch("PUBLIC_BASE_STAFF_URL") => "org",
                  ENV.fetch("PUBLIC_VISA_SERVICE_URL") => "app",
                  ENV.fetch("PUBLIC_VISA_CORPORATE_URL") => "com",
                  ENV.fetch("PUBLIC_VISA_STAFF_URL") => "org",
                }.fetch(fv5043)
              end
            fv5014 = BaseAuthAdmissionCoordinator.find_admission_binding_by_confirmation!(
              surface: fv5015, reference: fv5040.path.split("/").fetch(-2),
            )

            if fv5042
              fv5022 = fv5041 || fv5004
              fv5022.host!(fv5039)
              fv5022.https!
              fv5022.session[BaseAdmissionBrowserBinding::BROWSER_NONCE_SESSION_KEY] ||=
                "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn"
              fv5038 = fv5040.request_uri
              fv5029 = fv5013.merge(
                "Host" => fv5039,
                "Origin" => "https://#{fv5039}",
                "Sec-Fetch-Site" => "same-origin",
              )
              fv5022.get(fv5038, headers: fv5029)
              fv5032, fv5030, fv5031 =
                begin
                  fv5037 = fv5022.response.body
                  fv5036 = false
                  fv5035 = Nokogiri::HTML(fv5037).at_css("form")
                  if fv5035.nil? && fv5036
                    nil
                  else
                    raise RuntimeError, "Auth continuation form is missing" unless fv5035

                    fv5034 = fv5035.at_css("input[name='authenticity_token']")&.[]("value")
                    raise RuntimeError,
                          "Auth continuation is missing its CSRF token" if fv5034.blank?

                    fv5033 = fv5035.css("input[type='hidden']").to_h do |input|
                      [input["name"], input["value"]]
                    end.except("authenticity_token")
                    [fv5035["action"], fv5034, fv5033]
                  end
                end
              fv5022.post(
                fv5032,
                params: fv5031.merge(authenticity_token: fv5030),
                headers: fv5029,
              )
              begin
                fv5023 = fv5022
                fv5025 = "session"
                fv5024 = fv5023.response.cookies[fv5025]
                if fv5024.nil?
                  fv5028 = fv5023.response.headers["Set-Cookie"] || fv5023.response.headers["set-cookie"]
                  fv5027 =
                    if fv5028.is_a?(String) && fv5028.start_with?("[")
                      JSON.parse(fv5028)
                    else
                      Array(fv5028)
                    end
                  fv5026 =
                    fv5027.flat_map { |entry| entry.to_s.split("\n") }.find do |entry|
                      entry.split(";", 2).first.to_s.start_with?("#{fv5025}=")
                    end
                  if fv5026

                    _, fv5024 = fv5026.split(";", 2).first.to_s.split("=", 2)
                    fv5024 = Rack::Utils.unescape(fv5024.to_s)
                  end
                end

                unless fv5024.nil?
                  fv5023.cookies.delete(fv5025)
                  # Rack::Test's []= uses its default host. The current request may target a
                  # different surface, so install the cookie against the browser's active host.
                  fv5023.cookies.merge(
                    "#{fv5025}=#{Rack::Utils.escape(fv5024)}",
                    URI.parse("https://#{fv5023.host}/"),
                  )
                end
              end
              fv5021 = fv5022.response.location
              raise RuntimeError, "Base confirmation did not return to Auth" if fv5021.blank?

              fv5018 = URI.parse(fv5021)
              if fv5020[:ri].present?
                fv5019 = Rack::Utils.parse_nested_query(fv5018.query.to_s)
                fv5019["ri"] ||= fv5020[:ri].to_s
                fv5018.query = URI.encode_www_form(fv5019)
              end
              fv5004.host!(fv5018.host)
              fv5004.https!
              fv5017 = fv5018.request_uri
              fv5000 = fv5013.merge("Host" => fv5018.host)
              fv5004.get(fv5017, headers: fv5000)
            else
              fv5014.confirm_base!(
                base_token: fv5016,
                browser_digest: AuthAdmissionBinding.browser_digest(
                  surface: fv5015,
                  entry_ref: fv5014.entry_ref,
                  nonce: "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn",
                ),
              )
              fv5012 = fv5004.host
              fv5004.host!(fv5012)
              fv5004.https!
              fv5000 = fv5013.merge("Host" => fv5012)
              fv5004.get(fv5011, params: fv5010, headers: fv5000)
            end
            fv5003, fv5001, fv5002 =
              begin
                fv5009 = fv5004.response.body
                fv5008 = false
                fv5007 = Nokogiri::HTML(fv5009).at_css("form")
                if fv5007.nil? && fv5008
                  nil
                else
                  raise RuntimeError, "Auth continuation form is missing" unless fv5007

                  fv5006 = fv5007.at_css("input[name='authenticity_token']")&.[]("value")
                  raise RuntimeError,
                        "Auth continuation is missing its CSRF token" if fv5006.blank?

                  fv5005 = fv5007.css("input[type='hidden']").to_h do |input|
                    [input["name"], input["value"]]
                  end.except("authenticity_token")
                  [fv5007["action"], fv5006, fv5005]
                end
              end
            fv5004.post(
              fv5003,
              params: fv5002.merge(authenticity_token: fv5001),
              headers: fv5000,
            )
          end
        end
      end
    end

    assert_response :bad_request
    assert_nil session[:oidc_authorization_login_challenge]
  end

  test "email OTP leaf without admission does not create a ClientToken" do
    host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    host! host
    token_count = ClientToken.count

    patch auth_app_sign_in_email_url(ri: "jp"),
          params: { client_email: { pass_code: "000000" } },
          headers: { "Host" => host }

    assert_not_equal 200, response.status
    assert_equal token_count, ClientToken.count
  end

  private

  def issue_transaction!(surface)
    OidcAuthorizationTransactionCoordinator.issue!(
      surface: surface.fetch(:name),
      intent: "sign_in",
      params: authorize_params(surface.fetch(:name)),
    )
  end

  def handoff_reference(issuance)
    BaseAuthAdmissionCoordinator.issue_handoff!(
      transaction: issuance.transaction,
      base_browser_nonce: "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn",
      base_token: nil,
    ).reference
  end

  def authorize_params(surface_name)
    spec = SURFACES.find { |row| row.fetch(:name) == surface_name }
    client = OidcClientRegistry.find!(spec.fetch(:client_id))
    redirect = client.redirect_uris_by_realm.fetch(spec.fetch(:realm)).first
    {
      response_type: "code",
      client_id: spec.fetch(:client_id),
      redirect_uri: redirect,
      code_challenge: "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM",
      code_challenge_method: "S256",
      state: "state-#{surface_name}",
      nonce: "nonce-#{surface_name}",
      scope: "openid profile",
    }
  end

  def auth_ceremony_record_for(surface)
    model = {
      "app" => ClientAuthCeremonySession,
      "com" => VisitorAuthCeremonySession,
      "org" => OperatorAuthCeremonySession,
    }.fetch(surface)
    raw_sid = cookies[AuthCeremonySidCookie::COOKIE_BASENAME].presence ||
      cookies["#{AuthIoKeys::HOST_COOKIE_PREFIX}#{AuthCeremonySidCookie::COOKIE_BASENAME}"].presence
    model.find_active_by_raw_sid(raw_sid)
  end
end
