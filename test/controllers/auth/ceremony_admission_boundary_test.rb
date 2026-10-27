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
      attach_auth_ceremony_entry!("/verification", reference: first.reference, params: { ri: "jp" }, browser:)
      # The independent Base HTTP matrix covers confirmation; isolate cancellation after real Auth redemption.
      binding.reload.confirm_base!(base_token: token, browser_digest: binding.base_browser_digest)
      browser.get("/verification", params: { entry_ref: first.reference, ri: "jp" })

      assert_equal 303, browser.response.status
      browser.get("/verification", params: { ri: "jp" })

      assert_equal 200, browser.response.status
      csrf = browser.response.parsed_body.at_css('meta[name="csrf-token"]')["content"]
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
      attach_auth_ceremony_entry!("/verification", reference: issuance.reference, params: { ri: "jp" }, browser:)
      # Independent HTTP cases cover Base confirmation; isolate root revocation after confirmation here.
      binding.reload.confirm_base!(base_token: token, browser_digest: binding.base_browser_digest)
      continuity = auth_ceremony_session_for_test(binding)
      original_facts = binding.attributes
      before = continuity.class.count
      cookie_name = JitSessionCookieConfig.force_secure? ? "__Host-auth_sid" : "auth_sid"
      original_cookie = browser.cookies[cookie_name]
      token.device_session.revoke!
      browser.get("/verification", params: { entry_ref: issuance.reference, ri: "jp" })

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
      OidcTestEntry.issue!(
        surface:, intent: "sign_in", base_browser_nonce: SecureRandom.urlsafe_base64(32), base_token: nil,
      )
      browser.get("/")
      3.times do
        break unless browser.response.redirect?

        browser.get(browser.response.location)
      end

      assert_equal 200, browser.response.status
      csrf_token = browser.response.parsed_body.at_css('meta[name="csrf-token"]')["content"]
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
      attach_auth_ceremony_entry!("/verification", reference: issuance.reference, params: { ri: "jp" }, browser:)

      assert_equal [true, nil], [binding.reload.auth_ceremony_session_id.present?, token.reload.last_step_up_at]
      # Public model confirmation isolates Auth purpose selection; separate HTTP tests cover the Base receiver.
      binding.reload.confirm_base!(base_token: token, browser_digest: binding.base_browser_digest)
      browser.get("/verification", params: { entry_ref: issuance.reference, ri: "jp" })

      assert_equal [303, "reauthentication_handoff", "pending", nil],
                   [browser.response.status,
                    admitted_auth_ceremony_session_for_test(binding.reload)&.admission_purpose,
                    issuance.transaction.reload.status, token.reload.last_step_up_at,]
      browser.get("/verification", params: { ri: "jp" })

      assert_equal 200, browser.response.status
      csrf = browser.response.parsed_body.at_css('meta[name="csrf-token"]')["content"]
      headers = { "Origin" => "https://#{host}", "Sec-Fetch-Site" => "same-origin" }
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
      headers = { "Origin" => "https://#{host}", "Sec-Fetch-Site" => "same-origin" }
      browser.get("/sign/in", params: { entry_ref: issuance.reference, ri: "jp" })

      assert_equal [303, "/ceremony_bindings", nil],
                   [browser.response.status, URI.parse(browser.response.location).path,
                    binding.reload.auth_ceremony_session_id,]
      browser.get("/sign/in?entry_ref=#{issuance.reference}&entry_ref=#{issuance.reference}&ri=jp", headers:)

      assert_equal [400, nil, nil],
                   [browser.response.status, browser.response.location, binding.reload.auth_ceremony_session_id]

      encoded_reference = URI.encode_www_form(entry_ref: issuance.reference, ri: "jp")
      targets = [
        ["/ceremony_bindings", "#{encoded_reference}&entry_ref=#{issuance.reference}"],
        ["/ceremony_bindings?entry_ref=#{issuance.reference}", encoded_reference],
      ].concat(
        [nil, "", " ", "0", "\0", issuance.reference[0...-1], "#{issuance.reference}0",
         "#{issuance.reference[0, 14]}1#{issuance.reference[15..]}", SecureRandom.uuid,
         [issuance.reference], { "ref" => issuance.reference },].map do |reference|
          fields = { ri: "jp" }
          fields[:entry_ref] = reference unless reference.nil?
          ["/ceremony_bindings", Rack::Utils.build_nested_query(fields)]
        end,
      ).concat(
        %w(
          auth_sid sid auth_ceremony_session_id admitted_auth_ceremony_session_id base_token_id
          base_browser_digest confirmation_ref sign_in_flow_id authorization_transaction_id
          step_up_ceremony_transaction_id parent_kind purpose browser_nonce
        ).map do |proof|
          ["/ceremony_bindings", "#{encoded_reference}&#{URI.encode_www_form_component(proof)}="]
        end,
      )

      targets.each do |path, query|
        target = path.include?("?") ? "#{path}&#{query}" : "#{path}?#{query}"
        assert_no_difference -> { binding.class.auth_admission_session_class.count } do
          browser.get(target, headers:)

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
      headers = { "Origin" => "https://#{host}", "Sec-Fetch-Site" => "same-origin" }
      count = continuity.class.count
      failing_write =
        lambda do |_name, _started, _finished, _identity, payload|
          if payload[:name] == "#{binding.class} Update" && payload[:sql].include?('"redeemed_at"')
            raise ActiveRecord::StatementInvalid, "admission write unavailable"
          end
        end

      ActiveSupport::Notifications.subscribed(failing_write, "sql.active_record") do
        assert_raises(ActiveRecord::StatementInvalid) do
          browser.get("/sign/in", params: { entry_ref: first.reference, ri: "jp" }, headers:)
        end
      end

      assert_equal count, continuity.class.count
      assert_predicate continuity.reload, :active?
      assert_equal raw_sid, browser.cookies[cookie_name]
      assert_nil binding.reload.redeemed_at
      assert_nil binding.admitted_auth_ceremony_session_id
      burned = Valkey::AuthState::OpaqueAdmissionStore.new.read_reference!(reference: first.reference)

      assert_equal "consumed", burned.fetch("state")
      browser.get("/sign/in", params: { entry_ref: first.reference, ri: "jp" }, headers:)

      assert_equal [400, nil, raw_sid, count],
                   [browser.response.status, browser.response.location, browser.cookies[cookie_name],
                    continuity.class.count,]
      restarted = BaseAuthAdmissionCoordinator.issue_handoff!(
        transaction: first.transaction, base_browser_nonce: "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn",
        base_token: nil, restart_of: first.reference,
      )

      assert_equal first.transaction.id, restarted.transaction.id
      assert_predicate binding.reload, :retired?
      browser.get("/sign/in", params: { entry_ref: restarted.reference, ri: "jp" }, headers:)

      assert_equal 303, browser.response.status
      browser.get(browser.response.location, headers:)

      assert_equal 303, browser.response.status
      replacement = BaseAuthAdmissionCoordinator.find_admission_binding!(surface:, reference: restarted.reference)

      assert_equal continuity.id, replacement.auth_ceremony_session_id
      replacement.confirm_base!(base_token: nil, browser_digest: replacement.base_browser_digest)
      browser.get("/sign/in", params: { entry_ref: restarted.reference, ri: "jp" }, headers:)

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
        surface:, intent: "sign_in", base_browser_nonce: SecureRandom.hex(32), base_token: nil,
      )
      continuity, raw_sid = session_model.rotate_and_admit!(
        admission_purpose: "authentication_handoff",
        authorization_transaction_ref: original.transaction.transaction_id,
      )
      incoming = OidcTestEntry.issue!(
        surface:, intent: "sign_in", base_browser_nonce: SecureRandom.hex(32), base_token: nil,
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

      assert_equal [303, "/ceremony_bindings"],
                   [browser.response.status, URI.parse(browser.response.location).path]
      before = session_model.count
      proof_fields = %w(
        auth_sid sid auth_ceremony_session_id admitted_auth_ceremony_session_id base_token_id
        base_browser_digest confirmation_ref sign_in_flow_id authorization_transaction_id
        step_up_ceremony_transaction_id parent_kind purpose browser_nonce
      )
      proof_fields.each do |field|
        browser.get(
          "/ceremony_bindings",
          params: { :entry_ref => incoming.reference, :ri => "jp", field => "injected" },
          headers: { "Origin" => "https://#{host}", "Sec-Fetch-Site" => "same-origin" },
        )

        assert_equal [400, nil, before, nil, raw_sid],
                     [browser.response.status, browser.response.location, session_model.count,
                      binding.reload.auth_ceremony_session_id, browser.cookies[cookie_name],],
                     "client-supplied #{field} cannot become browser proof in #{surface}"
      end

      browser.get(
        "/ceremony_bindings", params: { entry_ref: incoming.reference, ri: "jp" },
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

  test "anonymous Visa confirmation refuses an expired OIDC parent even while its binding remains live" do
    protection = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    base_host = ENV.fetch("PUBLIC_VISA_SERVICE_URL")
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

    assert_equal 303, browser.response.status
    transaction = ClientOidcAuthorizationTransaction.find_by!(state: authorization.fetch(:state))
    binding = ClientAuthAdmissionBinding.find_by!(authorization_transaction_id: transaction.id)
    browser.host!(auth_host)
    attach_auth_ceremony_entry!(
      "/sign/in", reference: binding.entry_ref, params: { ri: "jp" }, browser:,
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

        assert_equal 303, browser.response.status
        binding = binding_model.find_by!(entry_ref: issuance.reference)
        deadline = binding.expires_at
        decision_time = deadline + Rational(microseconds, 1_000_000)
        before = session_model.count
        binding_model.stub(:database_now, decision_time) do
          browser.get(browser.response.location)
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

        assert_equal 303, browser.response.status
        headers = { "Origin" => "https://#{host}", "Sec-Fetch-Site" => "same-origin" }
        browser.get(browser.response.location, headers:)

        assert_equal 303, browser.response.status
        binding = binding_model.find_by!(entry_ref: issuance.reference)
        # Base confirmation has independent HTTP coverage; use its public transition to isolate redemption expiry.
        binding.confirm_base!(base_token: nil, browser_digest: binding.base_browser_digest)
        continuity = auth_ceremony_session_for_test(binding)
        cookie_name = JitSessionCookieConfig.force_secure? ? "__Host-auth_sid" : "auth_sid"
        original_cookie = browser.cookies[cookie_name]
        deadline = binding.expires_at
        confirmed_at = binding.base_confirmed_at
        before = session_model.count
        decision_time = deadline + Rational(microseconds, 1_000_000)
        binding_model.stub(:database_now, decision_time) do
          browser.get("/sign/in", params: { entry_ref: issuance.reference, ri: "jp" }, headers:)
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
    test "#{surface} Visa cookie loss and new nonce cannot confirm an old attached operation" do
      protection = ActionController::Base.allow_forgery_protection
      ActionController::Base.allow_forgery_protection = true
      base_host = ENV.fetch(base_key.sub("BASE", "VISA"))
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

      assert_equal 303, browser.response.status
      binding = binding_model.order(:id).last
      browser.host!(auth_host)
      browser.get("/sign/in", params: { entry_ref: binding.entry_ref, ri: "jp" })

      assert_equal 303, browser.response.status
      browser.get(browser.response.location)

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

      assert_equal 303, browser.response.status

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

  test "confirmation GET refuses a foreign Visa browser that initiated its own admission in every realm" do
    protection = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    [
      ["app", ENV.fetch("PUBLIC_VISA_SERVICE_URL"), ENV.fetch("PUBLIC_AUTH_SERVICE_URL"),
       "core-app-jp", "client", ClientOidcAuthorizationTransaction, ClientAuthAdmissionBinding, "sign_in", "/sign/in",],
      ["app", ENV.fetch("PUBLIC_VISA_SERVICE_URL"), ENV.fetch("PUBLIC_AUTH_SERVICE_URL"),
       "core-app-jp", "client", ClientOidcAuthorizationTransaction, ClientAuthAdmissionBinding, "sign_up", "/sign/in",],
      ["com", ENV.fetch("PUBLIC_VISA_CORPORATE_URL"), ENV.fetch("PUBLIC_AUTH_CORPORATE_URL"),
       "core-com-jp", "visitor", VisitorOidcAuthorizationTransaction,
       VisitorAuthAdmissionBinding, "sign_in", "/sign/in",],
      ["com", ENV.fetch("PUBLIC_VISA_CORPORATE_URL"), ENV.fetch("PUBLIC_AUTH_CORPORATE_URL"),
       "core-com-jp", "visitor", VisitorOidcAuthorizationTransaction,
       VisitorAuthAdmissionBinding, "sign_up", "/sign/in",],
      ["org", ENV.fetch("PUBLIC_VISA_STAFF_URL"), ENV.fetch("PUBLIC_AUTH_STAFF_URL"),
       "core-org-jp", "operator", OperatorOidcAuthorizationTransaction, OperatorAuthAdmissionBinding,
       "sign_in", "/sign/in",],
    ].each do |surface, visa_host, auth_host, client_id, realm, transaction_model, binding_model, intent, entry_path|
      owner = open_session
      foreign = open_session
      owner_binding = nil
      [owner, foreign].each do |browser|
        browser.https!
        browser.host!(visa_host)
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

        assert_equal 303, browser.response.status, surface
        assert_equal before + 1, binding_model.count, "Visa authorization GET issues its Base/Auth admission"
        assert_predicate browser.response, :redirect?, surface
        transaction = transaction_model.find_by!(state: authorization.fetch(:state))

        assert_equal "authentication", transaction.intent, "first-party screen hints cannot change neutral intent"
        binding = binding_model.find_by!(authorization_transaction_id: transaction.id)
        owner_binding = binding if browser == owner
      end

      owner.host!(auth_host)
      owner.get(entry_path, params: { entry_ref: owner_binding.entry_ref, ri: "jp" })

      assert_equal 303, owner.response.status, surface
      owner.get(owner.response.location)

      assert_equal 303, owner.response.status, surface
      confirmation_url = owner.response.location

      assert_equal visa_host, URI.parse(confirmation_url).host
      assert_nil owner_binding.reload.base_confirmed_at
      foreign.host!(visa_host)
      foreign.get(confirmation_url)

      assert_equal 400, foreign.response.status, surface
      assert_nil foreign.response.location
      assert_nil owner_binding.reload.base_confirmed_at
      assert_nil owner_binding.redeemed_at
      assert_includes foreign.response.headers.fetch("Cache-Control"), "no-store"
      owner.host!(visa_host)
      owner.get(confirmation_url)

      assert_equal 200, owner.response.status, surface
      assert_nil owner_binding.reload.base_confirmed_at, "the original browser's GET is also read-only"
      owner.get(
        confirmation_url,
        headers: {
          "Sec-Fetch-Mode" => "navigate", "Sec-Fetch-Dest" => "document", "Sec-Fetch-Site" => "same-origin",
        },
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
      continuity = auth_ceremony_session_for_test(owner_binding)
      original_cookie = owner.cookies["__Host-auth_sid"] || owner.cookies["auth_sid"]
      unavailable_store = Valkey::AuthState::OpaqueAdmissionStore.new
      unavailable_store.stub(:consume_reference!, ->(**) { raise Umaxica::Valkey::Unavailable, "unavailable" }) do
        Valkey::AuthState::OpaqueAdmissionStore.stub(:new, unavailable_store) do
          owner.get(entry_url, headers: { "Origin" => "https://#{auth_host}", "Sec-Fetch-Site" => "same-origin" })
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
      owner.get(entry_url, headers: { "Origin" => "https://#{auth_host}", "Sec-Fetch-Site" => "same-origin" })

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
      owner.get(entry_url, headers: { "Origin" => "https://#{auth_host}", "Sec-Fetch-Site" => "same-origin" })

      assert_equal [303, admitted_id, admitted_cookie, session_count],
                   [owner.response.status, owner_binding.reload.admitted_auth_ceremony_session_id,
                    owner.cookies["__Host-auth_sid"] || owner.cookies["auth_sid"], continuity.class.count,],
                   "exact redemption retry returns its original outcome without another rotation"
      cookie_name = JitSessionCookieConfig.force_secure? ? "__Host-auth_sid" : "auth_sid"
      _restored_cookie = owner.cookies.merge(
        "#{cookie_name}=#{Rack::Utils.escape(original_cookie)}", URI.parse("https://#{auth_host}/"),
      )
      owner.get(entry_url, headers: { "Origin" => "https://#{auth_host}", "Sec-Fetch-Site" => "same-origin" })

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
    assert_valid_auth_admission!("app")
  end

  test "valid com admission stores the transaction challenge" do
    assert_valid_auth_admission!("com")
  end

  test "valid org admission stores the transaction challenge" do
    assert_valid_auth_admission!("org")
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
    issuance.transaction.update!(login_challenge_expires_at: issuance.transaction.class.database_now - 1.second)
    get auth_app_sign_in_path(ri: "jp"), params: { entry_ref: reference }, headers: { "Host" => host }

    assert_response :bad_request
    assert_nil response.location
    assert_nil session[:oidc_authorization_login_challenge]
    assert_predicate auth_ceremony_record_for(surface.fetch(:name)), :present?
    assert_not_predicate auth_ceremony_record_for(surface.fetch(:name)), :admitted?
  end

  test "A12-4: a consumed admission relay is refused without re-minting its next-hop binding" do
    host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    issuance = OidcTestEntry.issue!(
      surface: "app", intent: "sign_in", base_browser_nonce: SecureRandom.hex(32), base_token: nil,
    )
    token_count = ClientToken.count
    first = open_session
    first.host!(host)
    first.https!
    binding = attach_auth_ceremony_entry!(
      "/sign/in", reference: issuance.reference, params: { ri: "jp" }, browser: first,
    )
    binding.confirm_base!(base_token: nil, browser_digest: binding.base_browser_digest)
    first.get("/sign/in", params: { entry_ref: issuance.reference, ri: "jp" })

    assert_equal 303, first.response.status, first.response.location
    first.get(first.response.location)

    assert_equal 200, first.response.status
    assert_predicate binding.reload, :redeemed?
    assert_predicate admitted_auth_ceremony_session_for_test(binding), :admitted?

    second = open_session
    second.host!(host)
    second.https!
    bindings_before_replay = binding.class.count
    assert_no_difference -> { binding.class.count } do
      second.get("/sign/in", params: { entry_ref: issuance.reference, ri: "jp" })
    end

    assert_equal 400, second.response.status
    assert_nil second.session[:oidc_authorization_login_challenge]
    assert_equal token_count, ClientToken.count
    assert_equal bindings_before_replay, binding.class.count
  end

  test "wrong-purpose entry relays without attaching continuity" do
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

    # Design D preserves the entry GET as a relay; the unrelated path cannot attach or redeem it.
    get auth_app_sign_in_path(ri: "jp"), params: { entry_ref: handoff.reference }

    assert_response :see_other
    assert_equal "/ceremony_bindings", URI.parse(response.location).path
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

  def assert_valid_auth_admission!(surface_name)
    surface = SURFACES.find { |row| row.fetch(:name) == surface_name }
    host = ENV.fetch(surface.fetch(:host_env))
    host!(host)
    https!
    issuance = issue_transaction!(surface)
    reference = handoff_reference(issuance)
    entry_path = public_send(surface.fetch(:sign_in), ri: "jp")
    binding = attach_auth_ceremony_entry!(entry_path, reference:, params: { ri: "jp" })

    assert_predicate binding, :attached?
    assert_not_predicate binding, :confirmed?
    assert_not_predicate binding, :redeemed?

    binding.confirm_base!(base_token: nil, browser_digest: binding.base_browser_digest)
    get(entry_path, params: { entry_ref: reference, ri: "jp" }, headers: { "Host" => host })

    assert_response :see_other
    follow_redirect!

    assert_response :success
    record = auth_ceremony_record_for(surface_name)

    assert_predicate record, :admitted?
    assert_equal issuance.transaction.transaction_id, record.authorization_transaction_ref
    assert_predicate binding.reload, :redeemed?
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
