# frozen_string_literal: true

require "test_helper"
require "webauthn/fake_client"

class TelephoneSignupHttpDeliveryTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper
  include SignInFlowCleanup
  include SignUpJourneyCleanup

  self.use_transactional_tests = false
  self.fixture_table_names = []

  setup do
    ClientSignUpFlowStatus::DEFAULTS.each { |id| ClientSignUpFlowStatus.find_or_create_by!(id: id) }
    ClientSignUpFlowCleanupStatus::DEFAULTS.each { |id| ClientSignUpFlowCleanupStatus.find_or_create_by!(id: id) }
  end

  [
    [:app, "PUBLIC_BASE_SERVICE_URL", "PUBLIC_AUTH_SERVICE_URL", "BASE_APP", ClientSignUpFlow,
     ClientTelephone, ClientToken, :client_telephone, :user_id,],
  ].each do |surface, base_key, auth_key, _issuer_name, flow_class, contact_class, token_class, scope, owner_key|
    %w(current cancelled expired reissued).each do |state|
      test "#{surface} actual Telephone signup queues encrypted code and refuses #{state} stale transport" do
        previous_protection = ActionController::Base.allow_forgery_protection
        previous_turnstile = [TurnstileVerifierStub.enabled, TurnstileVerifierStub.response]
        previous_challenge = [TurnstileVerifierStub.challenge_enabled, TurnstileVerifierStub.challenge_response]
        ActionController::Base.allow_forgery_protection = true
        TurnstileVerifierStub.enabled = true
        TurnstileVerifierStub.response = { "success" => true }
        TurnstileVerifierStub.challenge_enabled = true
        TurnstileVerifierStub.challenge_response = { "success" => true }
        base_host = ENV.fetch(base_key)
        auth_host = ENV.fetch(auth_key)
        browser = open_session
        browser.host!(base_host)
        browser.https!
        browser.get("/sign", params: { ri: "jp" })

        assert_equal 200, browser.response.status
        csrf = browser.response.parsed_body.at_css('input[name="authenticity_token"]')["value"]
        browser.post(
          "/sign", params: { ri: "jp", authenticity_token: csrf }, headers: {
            "Origin" => "https://#{base_host}", "Sec-Fetch-Site" => "same-origin",
          },
        )

        assert_equal 303, browser.response.status
        boot = Rails.configuration.x.boot_config
        jump_host = URI.parse(boot.fetch(:jump).origin.to_s).host
        visa_host = (surface == :app) ? boot.fetch(:hosts).visa_service.host : boot.fetch(:hosts).visa_corporate.host
        12.times do
          break unless browser.response.redirect?

          target = URI.parse(browser.response.location)
          target = URI.parse("https://#{browser.host}#{target}") if target.host.blank?
          if target.host == jump_host
            token = Rack::Utils.parse_nested_query(target.query.to_s).fetch("rt")
            source =
              case browser.host
              when base_host then "BASE_#{surface.to_s.upcase}"
              when visa_host then "VISA_#{surface.to_s.upcase}"
              when auth_host then "AUTH_#{surface.to_s.upcase}"
              else raise ArgumentError, "unexpected handoff source"
              end
            issuer = JitSecurityJwtRegistry.surface(source)
            payload, = JWT.decode(
              token, JitSecurityJwtRegistry.public_key_for(issuer.id, issuer.current_kid), true,
              algorithms: ["ES384"], verify_iss: true, iss: "https://#{browser.host}",
              verify_aud: true, aud: boot.fetch(:jump).audience,
            )
            target = URI.parse(payload.fetch("url"))
          end

          assert_includes [base_host, visa_host, auth_host], target.host
          browser.host!(target.host)
          browser.https!
          browser.get(
            target.request_uri, headers: {
              "Sec-Fetch-Mode" => "navigate", "Sec-Fetch-Dest" => "document", "Sec-Fetch-Site" => "cross-site",
            },
          )
        end

        assert_equal 200, browser.response.status
        assert_equal auth_host, browser.host
        switch_browser_to_sign_up!(browser, surface: surface.to_s)
        browser.get("/sign/up/telephone/new", params: { ri: "jp" })

        assert_equal 200, browser.response.status
        csrf = browser.response.parsed_body.at_css('meta[name="csrf-token"]')["content"]
        headers = { "Origin" => "https://#{auth_host}", "Sec-Fetch-Site" => "same-origin", "X-CSRF-Token" => csrf }
        number = "+8190#{SecureRandom.random_number(100_000_000).to_s.rjust(8, "0")}"
        clear_enqueued_jobs
        browser.post(
          "/sign/up/telephone", params: {
            scope => { raw_number: number,
                       confirm_policy: "1",
                       confirm_using_mfa: "1", },
            "cf-turnstile-response" => "test",
            :ri => "jp",
          }, headers: headers,
        )

        assert_equal 302, browser.response.status
        otp_uri = URI.parse(browser.response.location)
        signed_binding = Rack::Utils.parse_query(otp_uri.query).fetch("fb")
        decoded = SignFlowBindingCodec.decode(signed_binding)
        flow = flow_class.find_by!(public_id: decoded.flow_public_id)
        contact = contact_class.find(flow.pending_contact_id)
        owner_id = contact[owner_key]

        assert_equal flow_class::STATUS_MODEL::CONTACT_PENDING, flow.reload.status_id
        assert_nil contact.binding_finalized_at
        assert_equal 0, token_class.where(owner_key => owner_id).count
        transaction_model = ClientTelephoneCeremonyTransaction
        transaction = transaction_model.find_by!(telephone_candidate_ref: contact.public_id)

        assert_instance_of transaction_model, transaction
        assert_predicate transaction.otp_verifier, :present?
        assert_nil transaction.otp_consumed_at
        job_arguments = enqueued_jobs.find { |job| job.fetch(:job) == Outbound::SmsDeliveryJob }.fetch(:args)
        encrypted = job_arguments.fetch(0).fetch("encrypted_payload")
        payload = OutboundSensitivePayload.decrypt_sms_delivery(encrypted)
        code = payload.fetch(:otp_code)

        assert_not JSON.generate(job_arguments).include?(code)
        assert_not JSON.generate(job_arguments).include?(contact.number)
        assert_equal [surface.to_s, "sign_up", flow.public_id, transaction.transaction_id,
                      transaction.otp_generation,], payload.fetch(:otp_binding)

        original_generation = transaction.otp_generation
        if state == "cancelled"
          browser.delete(otp_uri.request_uri, headers: headers)

          assert_equal 303, browser.response.status
          assert_predicate flow.reload, :sign_up_terminal?
        end
        if state == "reissued"
          contact_class.stub(:database_now, contact.otp_last_sent_at + TelephoneOtpPolicy::SEND_COOLDOWN) do
            browser.post(otp_uri.request_uri, headers: headers)
          end

          assert_equal 302, browser.response.status
          assert_not_equal original_generation, transaction.reload.otp_generation
        end
        sent = []
        at = (state == "expired") ? transaction.otp_expires_at : transaction_model.database_now
        if state == "current"
          assert transaction.telephone_otp_deliverable?(generation: original_generation, at: at)
          assert TelephoneSignUpOtpDeliveryGuard.call(
            flow: flow, telephone: contact, transaction: transaction, generation: original_generation,
            destination: payload.fetch(:to), code: code,
          ) { true }
        end
        transaction_model.stub(:database_now, at) do
          OutboundSms.stub(:deliver_now, ->(**message) { sent << message }) do
            Outbound::SmsDeliveryJob.perform_now(encrypted_payload: encrypted)
          end
        end

        assert_equal (state == "current") ? 1 : 0, sent.length
        assert_nil transaction.reload.otp_consumed_at, "Delivery cannot consume the ceremony proof"
        assert_equal 0, contact.reload.otp_attempts_count
        assert_equal 0, token_class.where(owner_key => owner_id).count
      ensure
        ActionController::Base.allow_forgery_protection = previous_protection
        TurnstileVerifierStub.enabled, TurnstileVerifierStub.response = previous_turnstile
        TurnstileVerifierStub.challenge_enabled, TurnstileVerifierStub.challenge_response = previous_challenge
        cleanup_signup_records(number) if number
      end
    end
  end

  test "APP signup after abandoning sign-in cannot use a registered telephone code or reach birthdate commit" do
    previous_protection = ActionController::Base.allow_forgery_protection
    previous_turnstile = [TurnstileVerifierStub.enabled, TurnstileVerifierStub.response]
    previous_challenge = [TurnstileVerifierStub.challenge_enabled, TurnstileVerifierStub.challenge_response]
    ActionController::Base.allow_forgery_protection = true
    TurnstileVerifierStub.enabled = true
    TurnstileVerifierStub.response = { "success" => true }
    TurnstileVerifierStub.challenge_enabled = true
    TurnstileVerifierStub.challenge_response = { "success" => true }
    sign_up_journey_watermarks!
    ClientSignUpFlowStatus::DEFAULTS.each { |id| ClientSignUpFlowStatus.find_or_create_by!(id: id) }
    ClientSignUpFlowCleanupStatus::DEFAULTS.each { |id| ClientSignUpFlowCleanupStatus.find_or_create_by!(id: id) }
    base_host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    auth_host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    browser = open_session
    browser.host!(base_host)
    browser.https!
    browser.get("/sign", params: { ri: "jp" })

    assert_equal 200, browser.response.status
    csrf = browser.response.parsed_body.at_css('input[name="authenticity_token"]')["value"]
    browser.post(
      "/sign", params: { ri: "jp", authenticity_token: csrf }, headers: {
        "Origin" => "https://#{base_host}", "Sec-Fetch-Site" => "same-origin",
      },
    )

    assert_equal 303, browser.response.status
    boot = Rails.configuration.x.boot_config
    jump_host = URI.parse(boot.fetch(:jump).origin.to_s).host
    boot.fetch(:hosts).visa_service.host
    12.times do
      break unless browser.response.redirect?

      target = URI.parse(browser.response.location)
      target = URI.parse("https://#{browser.host}#{target}") if target.host.blank?
      if target.host == jump_host
        token = Rack::Utils.parse_nested_query(target.query).fetch("rt")
        issuer = JitSecurityJwtRegistry.surface((browser.host == base_host) ? "BASE_APP" : "VISA_APP")
        payload, = JWT.decode(
          token, JitSecurityJwtRegistry.public_key_for(issuer.id, issuer.current_kid), true,
          algorithms: ["ES384"], verify_iss: true, iss: "https://#{browser.host}",
          verify_aud: true, aud: boot.fetch(:jump).audience,
        )
        target = URI.parse(payload.fetch("url"))
      end
      browser.host!(target.host)
      browser.https!
      browser.get(
        target.request_uri, headers: {
          "Sec-Fetch-Mode" => "navigate", "Sec-Fetch-Dest" => "document", "Sec-Fetch-Site" => "cross-site",
        },
      )
    end

    assert_equal auth_host, browser.host
    assert_equal 200, browser.response.status
    switch_browser_to_sign_up!(browser, surface: "app")
    browser.get("/sign/up/telephone/new", params: { ri: "jp" })

    assert_equal 200, browser.response.status
    existing_owner = Client.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL,
      status_id: ClientStatus::VERIFIED_WITH_SIGN_UP,
      visibility_id: ClientVisibility::USER,
    )
    number = "+8190#{SecureRandom.random_number(100_000_000).to_s.rjust(8, "0")}"
    existing = existing_owner.client_telephones.create!(
      raw_number: number,
      confirm_policy: true,
      confirm_using_mfa: true,
      user_telephone_status_id: ClientTelephoneStatus::VERIFIED,
      binding_finalized_at: ClientTelephone.database_now,
    )
    existing_facts = existing.reload.attributes
    owner_facts = existing_owner.reload.attributes
    original_token_count = ClientToken.count
    clear_enqueued_jobs
    csrf = browser.response.parsed_body.at_css('meta[name="csrf-token"]')["content"]
    browser.post(
      "/sign/up/telephone", params: {
        :client_telephone => { raw_number: number, confirm_policy: "1", confirm_using_mfa: "1" },
        "cf-turnstile-response" => "test",
        :ri => "jp",
      }, headers: {
        "Origin" => "https://#{auth_host}", "Sec-Fetch-Site" => "same-origin", "X-CSRF-Token" => csrf,
      },
    )

    assert_equal 302, browser.response.status
    otp_uri = URI.parse(browser.response.location)
    flow_binding = Rack::Utils.parse_query(otp_uri.query).fetch("fb")
    flow = ClientSignUpFlow.find_by!(public_id: SignFlowBindingCodec.decode(flow_binding).flow_public_id)
    candidate = ClientTelephone.find(flow.pending_contact_id)
    candidate_facts = candidate.reload.attributes
    candidate_owner_facts = Client.find(candidate.user_id).attributes
    flow_facts = flow.reload.attributes
    browser.get(otp_uri.request_uri)

    assert_equal 200, browser.response.status
    csrf = browser.response.parsed_body.at_css('meta[name="csrf-token"]')["content"]
    assert_raises(AppRegisteredContactDestinationGuard::RegisteredDestinationIncident) do
      browser.patch(
        otp_uri.request_uri,
        params: { :client_telephone => { pass_code: "123456" }, "cf-turnstile-response" => "test" },
        headers: { "Origin" => "https://#{auth_host}", "Sec-Fetch-Site" => "same-origin", "X-CSRF-Token" => csrf },
      )
    end
    assert_equal candidate_facts, candidate.reload.attributes
    assert_equal candidate_owner_facts, Client.find(candidate.user_id).reload.attributes
    assert_equal flow_facts, flow.reload.attributes
    assert_equal existing_facts, existing.reload.attributes
    assert_equal owner_facts, existing_owner.reload.attributes

    browser.patch(
      auth_app_sign_up_check_telephone_birthdate_path(ri: "jp", fb: flow_binding),
      params: { requirement: "birthdate", birthdate: "1990-01-15", checkpoint_version: flow.checkpoint_version },
      headers: { "Origin" => "https://#{auth_host}", "Sec-Fetch-Site" => "same-origin", "X-CSRF-Token" => csrf },
    )

    assert_equal 409, browser.response.status
    assert_empty enqueued_jobs.select { |job| job.fetch(:job) == Outbound::SmsDeliveryJob }
    assert_equal existing_facts, existing.reload.attributes
    assert_equal owner_facts, existing_owner.reload.attributes
    assert_equal original_token_count, ClientToken.count
    assert_equal 0, ClientToken.where(user_id: existing_owner.id).count
  ensure
    ActionController::Base.allow_forgery_protection = previous_protection
    TurnstileVerifierStub.enabled, TurnstileVerifierStub.response = previous_turnstile
    TurnstileVerifierStub.challenge_enabled, TurnstileVerifierStub.challenge_response = previous_challenge
    delete_sign_up_journey_rows! if @sign_up_journey_client_ids
  end

  private

  def cleanup_signup_records(number)
    # `number` is a non-deterministically encrypted attribute, so `find_by(number:)` compares the
    # plaintext against ciphertext and never matches; the cleanup then returned early and left the
    # telephone, its ceremony rows and the client behind for the next fixture load. `with_number`
    # is the digest-based scope the Telephone concern provides for this.
    contact = ClientTelephone.with_number(number).first
    return unless contact

    owner = Client.find(contact.user_id)
    flows = ClientSignUpFlow.where(pending_contact_type: "telephone", pending_contact_id: contact.id).to_a
    ClientTelephoneCeremonyTransaction.where(telephone_candidate_ref: contact.public_id).delete_all
    bindings = ClientAuthAdmissionBinding.where(id: flows.map(&:auth_admission_binding_id).compact).to_a
    # One sign-up request leaves two admission bindings behind: the flow's own binding and the
    # entry binding the browser created when it switched into sign-up. They share the OIDC
    # authorization transaction, so the transaction id is what ties the second one in; without it
    # the entry binding survives and pins the sessions and transaction this cleanup deletes.
    parent_ids = bindings.filter_map(&:authorization_transaction_id)
    bindings =
      (bindings + ClientAuthAdmissionBinding.where(authorization_transaction_id: parent_ids).to_a).uniq
    ClientSignUpFlow.where(id: flows.map(&:id)).delete_all
    session_ids = bindings.flat_map do |binding|
      [binding.auth_ceremony_session_id, binding.admitted_auth_ceremony_session_id]
    end.compact
    ClientAuthAdmissionBinding.where(id: bindings.map(&:id)).delete_all
    ClientAuthCeremonySession.where(id: session_ids).delete_all
    ClientOidcAuthorizationTransaction.where(id: parent_ids).delete_all
    ClientContactAuditOutbox.where(owner_ref: owner.public_id).delete_all
    ClientTelephone.where(id: contact.id).delete_all
    ClientAuthorityLock.where(client_id: owner.id).delete_all
    Client.where(id: owner.id).delete_all
  end
end
