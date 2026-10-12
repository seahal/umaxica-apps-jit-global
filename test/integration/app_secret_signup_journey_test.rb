# frozen_string_literal: true

require "test_helper"
require "webauthn/fake_client"

class AppSecretSignupJourneyTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  SECRET_LIFETIME_VALUES = {
    "APP_SECRET_ISSUANCE_TTL_SECONDS" => "600",
    "APP_SECRET_PURGE_DELAY_SECONDS" => "86400",
    "APP_SECRET_OUTBOX_RETENTION_SECONDS" => "604800",
    "APP_SECRET_PROOF_RETENTION_SECONDS" => "2592000",
  }.freeze

  setup do
    ClientSignUpFlowStatus::DEFAULTS.each { |id| ClientSignUpFlowStatus.find_or_create_by!(id: id) }
    ClientSignUpFlowCleanupStatus::DEFAULTS.each { |id| ClientSignUpFlowCleanupStatus.find_or_create_by!(id: id) }
    @previous_forgery_protection = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    @previous_lifetimes = ENV.to_h.slice(*SECRET_LIFETIME_VALUES.keys)
    SECRET_LIFETIME_VALUES.each { |key, value| ENV[key] = value }
    TurnstileVerifierStub.challenge_enabled = true
    TurnstileVerifierStub.challenge_response = { "success" => true }
  end

  teardown do
    ActionController::Base.allow_forgery_protection = @previous_forgery_protection
    SECRET_LIFETIME_VALUES.each_key do |key|
      @previous_lifetimes.key?(key) ? ENV[key] = @previous_lifetimes.fetch(key) : ENV.delete(key)
    end
    TurnstileVerifierStub.challenge_enabled = false
    TurnstileVerifierStub.challenge_response = nil
  end

  ((0..20).map { |count| [count, :completed] } +
    [[0, :canceled], [0, :expired], [0, :payload_unavailable]]).each do |active_count, outcome|
    test "telephone signup with A=#{active_count} saves its fixed Secret set and handles #{outcome}" do # rubocop:disable Minitest/MultipleAssertions -- Verifies each observable boundary in one signup journey.
      host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
      base_host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
      host!(base_host)
      https!
      get "/sign", params: { ri: "jp" }
      csrf = response.parsed_body.at_css('input[name="authenticity_token"]')["value"]
      post "/sign", params: { ri: "jp", authenticity_token: csrf }, headers: {
        "Origin" => "https://#{base_host}", "Sec-Fetch-Site" => "same-origin",
      }
      rt = Rack::Utils.parse_query(URI.parse(response.location).query).fetch("rt")
      issuer = JitSecurityJwtRegistry.surface("BASE_APP")
      payload, = JWT.decode(
        rt, JitSecurityJwtRegistry.public_key_for(issuer.id, issuer.current_kid), true,
        algorithms: ["ES384"], verify_iss: true, iss: "https://#{base_host}",
        verify_aud: true, aud: Rails.configuration.x.boot_config.fetch(:jump).audience,
      )
      target = URI.parse(payload.fetch("url"))
      host!(target.host)
      https!
      headers = { "Origin" => "https://#{host}", "Sec-Fetch-Site" => "same-origin" }
      get target.request_uri
      form = response.parsed_body.at_css("form#base-authorization-ceremony-start-form")
      base_params = form.css("input[name]").to_h { |input| [input["name"], input["value"]] }
      post form["action"], headers: { "Origin" => "https://#{target.host}", "Sec-Fetch-Site" => "same-origin" },
                           params: base_params
      gateway = URI.parse(response.location)
      second_rt = Rack::Utils.parse_query(gateway.query).fetch("rt")
      second_payload, = JWT.decode(
        second_rt, JitSecurityJwtRegistry.public_key_for(issuer.id, issuer.current_kid), true,
        algorithms: ["ES384"], verify_iss: true, iss: "https://#{base_host}",
        verify_aud: true, aud: Rails.configuration.x.boot_config.fetch(:jump).audience,
      )
      auth_uri = URI.parse(second_payload.fetch("url"))
      host!(auth_uri.host)
      entry_ref = Rack::Utils.parse_query(auth_uri.query).fetch("entry_ref")
      begin
        fv5063 = auth_uri.path
        fv5062 = entry_ref
        fv5061 = :entry_ref
        fv5060 = { ri: "jp" }
        fv5059 = headers
        fv5058 = true
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
            fv5004.post(fv5047, params: fv5046.merge(authenticity_token: fv5045), headers: fv5013)
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

      assert_response :see_other
      get new_auth_app_sign_up_telephone_path(ri: "jp")

      assert_response :success
      csrf = response.parsed_body.at_css('meta[name="csrf-token"]')["content"]
      post auth_app_sign_up_telephone_path(ri: "jp"), headers: headers.merge("X-CSRF-Token" => csrf), params: {
        :user_telephone => { raw_number: "+819012345678", confirm_policy: "1", confirm_using_mfa: "1" },
        "cf-turnstile-response" => "synthetic",
      }

      assert_response :redirect
      registration = session[:user_telephone_registration].stringify_keys
      telephone = ClientTelephone.find_by!(public_id: registration.fetch("public_id"))
      flow = ClientSignUpFlow.find_by!(public_id: session[:auth_app_up_sequence_id])
      flow_binding = SignFlowBindingCodec.encode(flow: flow, surface: :app)
      transaction = ClientTelephoneCeremonyTransaction.find_by!(telephone_candidate_ref: telephone.public_id)
      delivery =
        (enqueued_jobs + performed_jobs).reverse.find do |entry|
          next false unless entry.fetch(:job) == Outbound::SmsDeliveryJob

          encrypted = entry.fetch(:args).fetch(0).fetch("encrypted_payload")
          OutboundSensitivePayload.decrypt_sms_delivery(encrypted).fetch(:otp_binding)[3] == transaction.transaction_id
        end
      delivery_params = OutboundSensitivePayload.decrypt_sms_delivery(
        delivery.fetch(:args).fetch(0).fetch("encrypted_payload"),
      )
      code = delivery_params.fetch(:otp_code)

      assert_equal ["app", "sign_up", flow.public_id, transaction.transaction_id,
                    transaction.otp_generation,], delivery_params.fetch(:otp_binding)
      queued_contains_code = JSON.generate(delivery.fetch(:args)).include?(code)

      assert_not queued_contains_code, "Queued SMS must not contain the plaintext signup code"
      patch auth_app_sign_up_check_telephone_otp_path(ri: "jp", fb: flow_binding),
            headers: headers.merge("X-CSRF-Token" => csrf), params: {
              user_telephone: { pass_code: code },
            }

      assert_response :redirect
      flow_binding = Rack::Utils.parse_query(URI.parse(response.location).query).fetch("fb")

      assert_predicate transaction.reload.otp_consumed_at, :present?
      assert_nil transaction.otp_verifier
      flow.reload
      get auth_app_sign_up_guard_telephone_path(ri: "jp", fb: flow_binding)
      actor = telephone.user
      now = Client.database_now
      active_count.times do
        # Holdings are setup facts; the HTTP registration allocates its own batch.
        prior = ClientSecretIssuance.create!(
          client: actor, origin: "manual", origin_operation_id: SecureRandom.uuid, attempt_number: 1,
          browser_session_ref: SecureRandom.base58(21), planned_count: 1, expires_at: now + 1.minute,
          presented_at: now, confirmed_at: now,
        )
        raw = SecureRandom.base58(32)
        ClientSecretCredential.create!(
          client: actor, issuance: prior, name: "Existing", password: raw,
          confirmed_at: now,
        )
      end
      get auth_app_sign_up_check_telephone_passkey_path(ri: "jp", fb: flow_binding)

      assert_response :success
      csrf = response.parsed_body.at_css('meta[name="csrf-token"]')["content"]
      post auth_app_sign_up_check_telephone_passkey_path(ri: "jp", fb: flow_binding),
           headers: headers.merge("X-CSRF-Token" => csrf),
           as: :json

      assert_response :success
      options = response.parsed_body
      credential = WebAuthn::FakeClient.new("https://#{host}", encoding: :base64url).create(
        challenge: options.fetch("options").fetch("challenge"), user_verified: true,
      )
      patch auth_app_sign_up_check_telephone_passkey_path(ri: "jp", fb: flow_binding),
            headers: headers.merge("X-CSRF-Token" => csrf), params: {
              challenge_id: options.fetch("challenge_id"),
              credential: credential,
              checkpoint_version: flow.checkpoint_version,
            }, as: :json

      assert_response :created
      assert_not flow.reload.requirement_cleared?(:passkey)
      issuance = ClientSecretIssuance.find_by!(sign_up_flow_ref: flow.public_id)
      expected_count = [2, 20 - active_count].min

      assert_equal expected_count, issuance.planned_count
      assert_nil issuance.encrypted_payload
      destination = response.parsed_body.fetch("redirect_url")
      assert_no_difference(["ClientSecretIssuance.count", "ClientPasskey.count", "ClientSecretCredential.count"]) do
        patch auth_app_sign_up_check_telephone_passkey_path(ri: "jp", fb: flow_binding),
              headers: headers.merge("X-CSRF-Token" => csrf), params: {
                challenge_id: options.fetch("challenge_id"),
                credential: credential,
                checkpoint_version: flow.checkpoint_version,
              }, as: :json
      end
      assert_response :created
      assert_equal destination, response.parsed_body.fetch("redirect_url")
      get destination

      assert_response :success
      assert_no_difference("ClientSecretCredential.count") {
        get auth_app_sign_up_check_telephone_secret_path(ri: "jp", fb: flow_binding)
      }
      csrf = response.parsed_body.at_css('meta[name="csrf-token"]')["content"]
      page = JSON.parse(response.parsed_body.at_css("script[data-page='app']").text)
      if active_count == 19
        assert_equal I18n.t("base.app.secrets.distribution_one_present"), page.fetch("props").fetch("notice")
      elsif active_count == 20
        assert_equal I18n.t("base.app.secrets.distribution_omitted"), page.fetch("props").fetch("notice")
        assert_equal "omitted", page.fetch("props").fetch("state")
        assert_nil issuance.expires_at
        assert_nil issuance.encrypted_payload
        assert_equal 0, ClientSecretCredential.where(issuance_id: issuance.id).count
        assert_equal 0, ClientSecretCapacityQuery.call(client: actor, at: Client.database_now).reserved_count
        assert_no_difference("ClientSecretCredential.count") do
          post auth_app_sign_up_check_telephone_secret_path(ri: "jp", fb: flow_binding),
               headers: headers.merge("X-CSRF-Token" => csrf)
        end
        assert_response :forbidden
        assert_nil issuance.reload.encrypted_payload
      else
        assert_nil page.fetch("props").fetch("notice")
      end
      values = []
      if outcome == :payload_unavailable
        nonce = SignUpSessionState.for(session, surface: :app).cycle_payload.stringify_keys.fetch("nonce")
        ClientSecretPresentationIssuer.prepare_for_sign_up!(flow: flow, nonce: nonce, issuance: issuance)
        issuance.reload.update!(encrypted_payload: nil)
        passkey_ids = actor.client_passkeys.pluck(:public_id)
        assert_no_difference ["ClientSecretCredential.count", "ClientPasskey.count", "ClientToken.count"] do
          post auth_app_sign_up_check_telephone_secret_path(ri: "jp", fb: flow_binding),
               headers: headers.merge("X-CSRF-Token" => csrf)
        end

        assert_not flow.reload.requirement_cleared?(:passkey)
        assert_equal ClientStatus::UNVERIFIED_WITH_SIGN_UP, actor.reload.status_id
        assert_equal passkey_ids, actor.client_passkeys.pluck(:public_id)
        assert_not_nil issuance.reload.canceled_at
        assert_equal 0, ClientSecretCapacityQuery.call(client: actor, at: Client.database_now).reserved_count
        assert_response :gone
        assert_equal 2, ClientSecretCredential.where(issuance_id: issuance.id).where.not(discard_at: Float::INFINITY).count
        assert_equal ["payload_unavailable"], ClientSecretAuditOutbox.where(
          operation_ref: issuance.origin_operation_id,
          event_name: %w(secret.issuance_canceled secret.discarded),
        ).distinct.pluck(:reason)
        patch auth_app_sign_up_check_telephone_secret_path(ri: "jp", fb: flow_binding),
              headers: headers.merge("X-CSRF-Token" => csrf),
              params: { checkpoint_version: flow.checkpoint_version, stored: "1" }

        assert_response :forbidden
        assert_not flow.reload.requirement_cleared?(:passkey)
        assert_nil issuance.reload.confirmed_at
        next
      end
      if expected_count.positive?
        post auth_app_sign_up_check_telephone_secret_path(ri: "jp", fb: flow_binding),
             headers: headers.merge("X-CSRF-Token" => csrf)

        assert_response :success
        values = response.parsed_body.css("[data-secret-value] code").map(&:text)
        cancel_form = response.parsed_body.at_css('form input[name="_method"][value="delete"]')

        assert cancel_form, "single-delivery cancellation must submit the protected DELETE endpoint"
        assert_equal expected_count, values.length
        values.each { |value| assert_nil ClientSecretLookupQuery.call(client: actor, secret: value) }
        csrf = response.parsed_body.at_css('input[name="authenticity_token"]')["value"]
      end
      confirmation = { checkpoint_version: flow.checkpoint_version }
      confirmation[:stored] = "1" if expected_count.positive?
      patch auth_app_sign_up_check_telephone_secret_path(ri: "jp", fb: flow_binding),
            headers: headers.merge("X-CSRF-Token" => csrf),
            params: confirmation

      assert_response :see_other
      flow_binding = Rack::Utils.parse_query(URI.parse(response.location).query).fetch("fb")

      assert flow.reload.requirement_cleared?(:passkey)
      assert issuance.reload.confirmed_at if expected_count.positive?

      assert_equal active_count + expected_count,
                   ClientSecretCapacityQuery.call(client: actor, at: Client.database_now).active_count
      values.each { |value| assert_nil ClientSecretLookupQuery.call(client: actor, secret: value) }
      assert_equal ClientStatus::UNVERIFIED_WITH_SIGN_UP, telephone.user.reload.status_id
      get auth_app_sign_up_check_telephone_birthdate_path(ri: "jp", fb: flow_binding)

      assert_response :success
      completed_page = JSON.parse(response.parsed_body.at_css("script[data-page='app']").text)
      expected_notice =
        case active_count
        when 19 then I18n.t("base.app.secrets.distribution_one_confirmed")
        when 20 then I18n.t("base.app.secrets.distribution_omitted")
        end
      if expected_notice
        assert_equal expected_notice, completed_page.fetch("props").fetch("notice")
      else
        assert_nil completed_page.fetch("props").fetch("notice")
      end
      csrf = response.parsed_body.at_css('meta[name="csrf-token"]')["content"]
      if outcome != :completed
        if outcome == :canceled
          delete auth_app_sign_up_check_telephone_birthdate_path(ri: "jp", fb: flow_binding),
                 headers: headers.merge("X-CSRF-Token" => csrf)

          assert_response :see_other
          assert_predicate flow.reload, :sign_up_cancelled?
        else
          overdue_at = Client.database_now - 1.second
          flow.update_columns(
            issued_at: overdue_at - 1.second,
            expires_at: overdue_at,
          ) # Test setup: make the DB-clock deadline overdue.
          SignUpExpiryJob.perform_now

          assert_equal ClientSignUpFlowStatus::EXPIRED, flow.reload.status_id
        end

        assert_nil issuance.reload.signup_completed_at
        assert_nil issuance.encrypted_payload
        assert_operator issuance.discard_at, :<=, Client.database_now + 1.day
        values.each { |value| assert_nil ClientSecretLookupQuery.call(client: actor, secret: value) }
        assert_equal 0, ClientSecretCapacityQuery.call(client: telephone.user, at: Client.database_now).active_count
        reason = (outcome == :canceled) ? "flow_canceled" : "flow_expired"

        assert_equal 2, ClientSecretAuditOutbox.where(
          operation_ref: issuance.origin_operation_id, event_name: "secret.discarded", reason: reason,
        ).where.not(credential_ref: nil).count
        next
      end
      assert_no_difference("ClientToken.count") do
        patch auth_app_sign_up_check_telephone_birthdate_path(ri: "jp", fb: flow_binding),
              headers: headers.merge("X-CSRF-Token" => csrf), params: {
                requirement: "birthdate",
                checkpoint_version: flow.reload.checkpoint_version,
                birthdate_year: "1990",
                birthdate_month: "01",
                birthdate_day: "15",
              }
      end
      assert_response :redirect
      assert_predicate flow.reload, :sign_up_completed?
      contact_intent = ClientContactAuditOutbox.find_by!(operation_ref: flow.public_id)

      assert_equal "finalized", contact_intent.event_name
      assert_equal "telephone", contact_intent.contact_kind
      assert_equal telephone.public_id, contact_intent.contact_ref
      assert_equal actor.public_id, contact_intent.owner_ref
      assert_nil contact_intent.actor_ref
      assert_nil contact_intent.acknowledged_at
      assert_equal ClientStatus::VERIFIED_WITH_SIGN_UP, telephone.user.reload.status_id
      assert_equal active_count + expected_count, ClientSecretCapacityQuery.call(
        client: actor, at: Client.database_now,
      ).active_count
      assert issuance.reload.signup_completed_at
      assert_equal 1, ClientSecretAuditOutbox.where(
        operation_ref: issuance.origin_operation_id, event_name: "secret.signup_completed",
      ).count
      assert_no_difference("ClientSecretAuditOutbox.count") do
        ClientSecretPasskeyReservationIssuer.complete_sign_up!(flow: flow)
      end
      assert_raises(ActiveRecord::ReadonlyAttributeError) { issuance.update!(signup_completed_at: nil) }
      flow.destroy!

      values.each { |value| assert ClientSecretLookupQuery.call(client: actor, secret: value) }
    end
  end
end
