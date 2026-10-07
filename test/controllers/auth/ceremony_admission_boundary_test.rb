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
          actor = Client.create!(status_id: ClientStatus::ACTIVE)
          [actor, ClientToken.create!(user: actor), ENV.fetch("PUBLIC_AUTH_SERVICE_URL")]
        when "com"
          actor = Visitor.create!(status_id: VisitorStatus::ACTIVE)
          [actor, VisitorToken.create!(visitor: actor), ENV.fetch("PUBLIC_AUTH_CORPORATE_URL")]
        when "org"
          actor = Operator.create!
          [actor, OperatorToken.create!(staff: actor), ENV.fetch("PUBLIC_AUTH_STAFF_URL")]
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
      admitted = binding.reload.admitted_auth_ceremony_session
      replacement = BaseStepUpCancelAndStartCommitter.call!(
        actor:, token:, previous_transaction: first.transaction,
        requirement: StepUpRequirement.new(**requirement.to_h.merge(scope: "settings_email")),
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
          actor = Client.create!(status_id: ClientStatus::ACTIVE)
          [actor, ClientToken.create!(user: actor), ENV.fetch("PUBLIC_AUTH_SERVICE_URL")]
        when "com"
          actor = Visitor.create!(status_id: VisitorStatus::ACTIVE)
          [actor, VisitorToken.create!(visitor: actor), ENV.fetch("PUBLIC_AUTH_CORPORATE_URL")]
        when "org"
          actor = Operator.create!
          [actor, OperatorToken.create!(staff: actor), ENV.fetch("PUBLIC_AUTH_STAFF_URL")]
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
      continuity = binding.auth_ceremony_session
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
      [ENV.fetch("PUBLIC_AUTH_SERVICE_URL"), auth_app_sign_up_email_path(ri: "jp"),
       ClientEmail, Client, :client_email, { raw_address: "unadmitted-#{SecureRandom.hex(6)}@example.com" },],
      [ENV.fetch("PUBLIC_AUTH_CORPORATE_URL"), auth_com_sign_up_email_path(ri: "jp"),
       VisitorEmail, Visitor, :visitor_email, { raw_address: "unadmitted-#{SecureRandom.hex(6)}@example.com" },],
      [ENV.fetch("PUBLIC_AUTH_SERVICE_URL"), auth_app_sign_up_telephone_path(ri: "jp"),
       ClientTelephone, Client, :client_telephone, { raw_number: "+819012345678", confirm_using_mfa: "1" },],
      [ENV.fetch("PUBLIC_AUTH_CORPORATE_URL"), auth_com_sign_up_telephone_path(ri: "jp"),
       VisitorTelephone, Visitor, :visitor_telephone, { raw_number: "+819012345678", confirm_using_mfa: "1" },],
    ].each do |host, path, contact_model, actor_model, contact_key, input|
      browser = open_session
      browser.host!(host)
      browser.https!
      headers = { "Origin" => "https://#{host}", "Sec-Fetch-Site" => "same-origin" }
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
          actor = Client.create!(status_id: ClientStatus::ACTIVE)
          [actor, ClientToken.create!(user: actor), ENV.fetch("PUBLIC_AUTH_SERVICE_URL")]
        when "com"
          actor = Visitor.create!(status_id: VisitorStatus::ACTIVE)
          [actor, VisitorToken.create!(visitor: actor), ENV.fetch("PUBLIC_AUTH_CORPORATE_URL")]
        when "org"
          actor = Operator.create!
          [actor, OperatorToken.create!(staff: actor), ENV.fetch("PUBLIC_AUTH_STAFF_URL")]
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
                   [browser.response.status, binding.reload.admitted_auth_ceremony_session&.admission_purpose,
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
      admitted = binding.admitted_auth_ceremony_session
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
      issuance = BaseAuthAdmissionCoordinator.issue_local_entry!(
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
      issuance = BaseAuthAdmissionCoordinator.issue_local_entry!(
        surface:, intent: "sign_in", base_browser_nonce: "test-browser-nonce", base_token: nil,
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
      assert_predicate issuance.transaction.reload, :sign_in_primary_pending?
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
      first = BaseAuthAdmissionCoordinator.issue_local_entry!(
        surface:, intent: "sign_in", base_browser_nonce: "test-browser-nonce", base_token: nil,
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
      restarted = BaseAuthAdmissionCoordinator.issue_local_entry!(
        surface:, intent: "sign_in", base_browser_nonce: "test-browser-nonce", base_token: nil,
        restart_of: first.reference,
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
          surface:, entry_ref: restarted.reference, nonce: "test-browser-nonce",
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
      original = BaseAuthAdmissionCoordinator.issue_local_entry!(
        surface: surface, intent: "sign_in", base_browser_nonce: SecureRandom.hex(32), base_token: nil,
      )
      continuity, raw_sid = session_model.rotate_and_admit!(
        admission_purpose: "local_sign_in", local_sign_in_flow_ref: original.transaction.public_id,
      )
      incoming = BaseAuthAdmissionCoordinator.issue_local_entry!(
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
      assert_equal original.transaction.public_id, continuity.local_sign_in_flow_ref
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
      client_id: "core-app",
      redirect_uri: OidcClientRegistry.find!("core-app").redirect_uris_by_realm.fetch("client").first,
      code_challenge: "a" * 43,
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
        issuance = BaseAuthAdmissionCoordinator.issue_local_entry!(
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
        assert_predicate issuance.transaction.reload, :sign_in_primary_pending?
      ensure
        ActionController::Base.allow_forgery_protection = protection
      end

      test "#{surface} redemption at deadline #{microseconds} microseconds rotates only before expiry" do
        protection = ActionController::Base.allow_forgery_protection
        ActionController::Base.allow_forgery_protection = true
        host = ENV.fetch(host_key)
        issuance = BaseAuthAdmissionCoordinator.issue_local_entry!(
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
        continuity = binding.auth_ceremony_session
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
          assert_predicate binding.admitted_auth_ceremony_session, :admitted?
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
        assert_predicate issuance.transaction.reload, :sign_in_primary_pending?
      ensure
        ActionController::Base.allow_forgery_protection = protection
      end
    end
  end

  [
    ["app", "PUBLIC_BASE_SERVICE_URL", "PUBLIC_AUTH_SERVICE_URL", "core-app", "client",
     ClientAuthAdmissionBinding,],
    ["com", "PUBLIC_BASE_CORPORATE_URL", "PUBLIC_AUTH_CORPORATE_URL", "core-com", "visitor",
     VisitorAuthAdmissionBinding,],
    ["org", "PUBLIC_BASE_STAFF_URL", "PUBLIC_AUTH_STAFF_URL", "core-org", "operator",
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
        code_challenge: "a" * 43,
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
      assert_not_predicate binding.auth_ceremony_session, :admitted?
      assert_equal "pending", binding.authorization_transaction.reload.status
      assert_equal "pending", sibling.authorization_transaction.reload.status
    ensure
      ActionController::Base.allow_forgery_protection = protection
    end
  end

  test "confirmation GET refuses a foreign Base browser that initiated its own admission in every realm" do
    protection = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    [
      ["app", ENV.fetch("PUBLIC_BASE_SERVICE_URL"), ENV.fetch("PUBLIC_AUTH_SERVICE_URL"),
       "core-app", "client", ClientOidcAuthorizationTransaction, ClientAuthAdmissionBinding, "sign_in", "/sign/in",],
      ["app", ENV.fetch("PUBLIC_BASE_SERVICE_URL"), ENV.fetch("PUBLIC_AUTH_SERVICE_URL"),
       "core-app", "client", ClientOidcAuthorizationTransaction, ClientAuthAdmissionBinding, "sign_up", "/sign/in",],
      ["com", ENV.fetch("PUBLIC_BASE_CORPORATE_URL"), ENV.fetch("PUBLIC_AUTH_CORPORATE_URL"),
       "core-com", "visitor", VisitorOidcAuthorizationTransaction, VisitorAuthAdmissionBinding, "sign_in", "/sign/in",],
      ["com", ENV.fetch("PUBLIC_BASE_CORPORATE_URL"), ENV.fetch("PUBLIC_AUTH_CORPORATE_URL"),
       "core-com", "visitor", VisitorOidcAuthorizationTransaction, VisitorAuthAdmissionBinding, "sign_up", "/sign/in",],
      ["org", ENV.fetch("PUBLIC_BASE_STAFF_URL"), ENV.fetch("PUBLIC_AUTH_STAFF_URL"),
       "core-org", "operator", OperatorOidcAuthorizationTransaction, OperatorAuthAdmissionBinding,
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
          code_challenge: "a" * 43,
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
      continuity = owner_binding.auth_ceremony_session
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
                   [owner_binding.reload.redeemed?, owner_binding.admitted_auth_ceremony_session.admitted?,
                    owner_binding.auth_ceremony_session.active?,],
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
      client_id: "core-app",
      realm: "client",
      sign_in: :auth_app_sign_in_url,
    },
    {
      name: "com",
      host_env: "PUBLIC_AUTH_CORPORATE_URL",
      client_id: "core-com",
      realm: "visitor",
      sign_in: :auth_com_sign_in_url,
    },
    {
      name: "org",
      host_env: "PUBLIC_AUTH_STAFF_URL",
      client_id: "core-org",
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
    assert_valid_admission_challenge!(SURFACES.fetch(0))
  end

  test "valid com admission stores the transaction challenge" do
    assert_valid_admission_challenge!(SURFACES.fetch(1))
  end

  test "valid org admission stores the transaction challenge" do
    assert_valid_admission_challenge!(SURFACES.fetch(2))
  end

  test "admission rejects a transaction expired by the writer database clock" do
    surface = SURFACES.first
    host = ENV.fetch(surface.fetch(:host_env))
    host! host
    issuance = issue_transaction!(surface)
    reference = handoff_reference(issuance)
    binding = BaseAuthAdmissionCoordinator.find_admission_binding!(surface: "app", reference: reference)
    _continuity, raw_sid = prepare_admission_binding_for_consumption!(binding, base_token: nil)
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
    host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL", "auth.app.localhost")
    issuance = issue_transaction!(SURFACES.first)
    reference = handoff_reference(issuance)
    token_count = ClientToken.count

    open_session do |first|
      first.host!(host)
      redeem_auth_ceremony_session!(
        first, auth_app_sign_in_path(ri: "jp"), reference: reference,
                                                headers: { "Host" => host },
      )

      assert_equal 303, first.response.status
    end

    open_session do |second|
      second.host!(host)
      redeem_auth_ceremony_session!(
        second, auth_app_sign_in_path(ri: "jp"), reference: reference,
                                                 headers: { "Host" => host },
      )

      assert_equal 400, second.response.status
      assert_nil second.session[:oidc_authorization_login_challenge]
      assert_equal token_count, ClientToken.count
    end
  end

  test "wrong-purpose admission is rejected" do
    host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL", "auth.app.localhost")
    host! host
    issuance = OidcAuthorizationTransactionCoordinator.issue!(
      surface: "app",
      intent: "sign_up",
      params: authorize_params("app").merge(screen_hint: "signup"),
    )

    redeem_auth_ceremony_entry!(
      auth_app_sign_in_path(ri: "jp"), reference: handoff_reference(issuance),
                                       params: { ri: "jp" }, headers: { "Host" => host },
    )

    assert_response :bad_request
    assert_nil session[:oidc_authorization_login_challenge]
  end

  test "wrong-surface admission is rejected" do
    host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL", "auth.app.localhost")
    host! host
    issuance = issue_transaction!(SURFACES.fetch(1))

    redeem_auth_ceremony_entry!(
      auth_app_sign_in_path(ri: "jp"), reference: handoff_reference(issuance),
                                       params: { ri: "jp" }, headers: { "Host" => host },
    )

    assert_response :bad_request
    assert_nil session[:oidc_authorization_login_challenge]
  end

  test "email OTP leaf without admission does not create a ClientToken" do
    host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL", "auth.app.localhost")
    host! host
    token_count = ClientToken.count

    patch auth_app_sign_in_email_url(ri: "jp"),
          params: { client_email: { pass_code: "000000" } },
          headers: { "Host" => host }

    assert_not_equal 200, response.status
    assert_equal token_count, ClientToken.count
  end

  private

  def assert_valid_admission_challenge!(surface)
    host = ENV.fetch(surface.fetch(:host_env))
    host!(host)
    issuance = issue_transaction!(surface)

    redeem_auth_ceremony_entry!(
      public_send(surface.fetch(:sign_in)), reference: handoff_reference(issuance),
                                            params: { ri: "jp" }, headers: { "Host" => host },
    )

    assert_response :see_other
    follow_redirect!

    assert_response :success

    record = auth_ceremony_record_for(surface.fetch(:name))

    assert_predicate record, :admitted?
    assert_equal issuance.transaction.transaction_id, record.authorization_transaction_ref
    assert_nil session[:oidc_authorization_login_challenge]
    assert_nil session[:oidc_authorization_intent]
  end

  def issue_transaction!(surface)
    OidcAuthorizationTransactionCoordinator.issue!(
      surface: surface.fetch(:name),
      intent: "sign_in",
      params: authorize_params(surface.fetch(:name)),
    )
  end

  def handoff_reference(issuance)
    BaseAuthAdmissionCoordinator.issue_handoff!(
      transaction: issuance.transaction, base_browser_nonce: "test-browser-nonce", base_token: nil,
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
      code_challenge: "challenge",
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
