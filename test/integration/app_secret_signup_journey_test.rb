# frozen_string_literal: true

require "test_helper"
require "webauthn/fake_client"

class AppSecretSignupJourneyTest < ActionDispatch::IntegrationTest
  setup do
    @previous_forgery_protection = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    ENV["APP_SECRET_ISSUANCE_TTL_SECONDS"] = "600"
    ENV["APP_SECRET_PURGE_DELAY_SECONDS"] = "86400"
    TurnstileVerifierStub.challenge_enabled = true
    TurnstileVerifierStub.challenge_response = { "success" => true }
  end

  teardown do
    ActionController::Base.allow_forgery_protection = @previous_forgery_protection
    TurnstileVerifierStub.challenge_enabled = false
    TurnstileVerifierStub.challenge_response = nil
  end

  ((0..20).map { |count| [count, :completed] } + [[0, :canceled], [0, :expired]]).each do |active_count, outcome|
    test "telephone signup with A=#{active_count} saves its fixed Secret set and handles #{outcome}" do
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
      host!(host)
      https!
      headers = { "Origin" => "https://#{host}", "Sec-Fetch-Site" => "same-origin" }
      get target.request_uri
      csrf = response.parsed_body.at_css('input[name="authenticity_token"]')["value"]
      post auth_app_sign_in_path(ri: "jp"), headers: headers.merge("X-CSRF-Token" => csrf), params: {
        entry_ref: Rack::Utils.parse_query(target.query).fetch("entry_ref"), authenticity_token: csrf,
      }
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
      otp = telephone.get_otp
      patch auth_app_sign_up_check_telephone_otp_path(ri: "jp"), headers: headers.merge("X-CSRF-Token" => csrf), params: {
        user_telephone: { pass_code: ROTP::HOTP.new(otp.fetch(:otp_private_key)).at(otp.fetch(:otp_counter)) },
      }

      assert_response :redirect
      get auth_app_sign_up_guard_telephone_path(ri: "jp")
      flow = ClientSignUpFlow.find_by!(public_id: session[:auth_app_up_sequence_id])
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
          lookup_digest: SignSecretLookupDigest.digest(raw), confirmed_at: now,
        )
      end
      get auth_app_sign_up_check_telephone_passkey_path(ri: "jp")

      assert_response :success
      csrf = response.parsed_body.at_css('meta[name="csrf-token"]')["content"]
      post auth_app_sign_up_check_telephone_passkey_path(ri: "jp"), headers: headers.merge("X-CSRF-Token" => csrf),
                                                                    as: :json

      assert_response :success
      options = response.parsed_body
      credential = WebAuthn::FakeClient.new("https://#{host}", encoding: :base64url).create(
        challenge: options.fetch("options").fetch("challenge"), user_verified: true,
      )
      patch auth_app_sign_up_check_telephone_passkey_path(ri: "jp"), headers: headers.merge("X-CSRF-Token" => csrf), params: {
        challenge_id: options.fetch("challenge_id"), credential: credential, checkpoint_version: flow.checkpoint_version,
      }, as: :json

      assert_response :created
      assert_not flow.reload.requirement_cleared?(:passkey)
      issuance = ClientSecretIssuance.find_by!(sign_up_flow_ref: flow.public_id)
      expected_count = [2, 20 - active_count].min

      assert_equal expected_count, issuance.planned_count
      assert_nil issuance.encrypted_payload
      destination = response.parsed_body.fetch("redirect_url")
      assert_no_difference(["ClientSecretIssuance.count", "ClientPasskey.count", "ClientSecretCredential.count"]) do
        patch auth_app_sign_up_check_telephone_passkey_path(ri: "jp"), headers: headers.merge("X-CSRF-Token" => csrf), params: {
          challenge_id: options.fetch("challenge_id"), credential: credential, checkpoint_version: flow.checkpoint_version,
        }, as: :json
      end
      assert_response :created
      assert_equal destination, response.parsed_body.fetch("redirect_url")
      get destination

      assert_response :success
      assert_no_difference("ClientSecretCredential.count") {
        get auth_app_sign_up_check_telephone_secret_path(ri: "jp")
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
          post auth_app_sign_up_check_telephone_secret_path(ri: "jp"), headers: headers.merge("X-CSRF-Token" => csrf)
        end
        assert_response :forbidden
        assert_nil issuance.reload.encrypted_payload
      else
        assert_nil page.fetch("props").fetch("notice")
      end
      values = []
      if expected_count.positive?
        post auth_app_sign_up_check_telephone_secret_path(ri: "jp"), headers: headers.merge("X-CSRF-Token" => csrf)

        assert_response :success
        values = response.parsed_body.css("[data-secret-value] code").map(&:text)
        cancel_form = response.parsed_body.at_css('form input[name="_method"][value="delete"]')

        assert cancel_form, "single-delivery cancellation must submit the protected DELETE endpoint"
        assert_equal expected_count, values.length
        values.each { |value| assert_nil ClientSecretLookupQuery.call(secret: value) }
        csrf = response.parsed_body.at_css('input[name="authenticity_token"]')["value"]
      end
      confirmation = { checkpoint_version: flow.checkpoint_version }
      confirmation[:stored] = "1" if expected_count.positive?
      patch auth_app_sign_up_check_telephone_secret_path(ri: "jp"), headers: headers.merge("X-CSRF-Token" => csrf),
                                                                    params: confirmation

      assert_response :see_other
      assert flow.reload.requirement_cleared?(:passkey)
      assert issuance.reload.confirmed_at if expected_count.positive?

      assert_equal active_count + expected_count,
                   ClientSecretCapacityQuery.call(client: actor, at: Client.database_now).active_count
      values.each { |value| assert_nil ClientSecretLookupQuery.call(secret: value) }
      assert_equal ClientStatus::UNVERIFIED_WITH_SIGN_UP, telephone.user.reload.status_id
      get auth_app_sign_up_check_telephone_birthdate_path(ri: "jp")

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
          delete auth_app_sign_up_check_telephone_birthdate_path(ri: "jp"),
                 headers: headers.merge("X-CSRF-Token" => csrf)

          assert_response :see_other
          assert_predicate flow.reload, :sign_up_cancelled?
        else
          travel_to(flow.expires_at + 1.second) { SignUpExpiryJob.perform_now }

          assert_equal ClientSignUpFlowStatus::EXPIRED, flow.reload.status_id
        end

        assert_nil issuance.reload.signup_completed_at
        assert_nil issuance.encrypted_payload
        assert_operator issuance.discard_at, :<=, Client.database_now + 1.day
        values.each { |value| assert_nil ClientSecretLookupQuery.call(secret: value) }
        assert_equal 0, ClientSecretCapacityQuery.call(client: telephone.user, at: Client.database_now).active_count
        reason = (outcome == :canceled) ? "flow_canceled" : "flow_expired"

        assert_equal 2, ClientSecretAuditOutbox.where(
          operation_ref: issuance.origin_operation_id, event_name: "secret.discarded", reason: reason,
        ).where.not(credential_ref: nil).count
        next
      end
      assert_no_difference("ClientToken.count") do
        patch auth_app_sign_up_check_telephone_birthdate_path(ri: "jp"), headers: headers.merge("X-CSRF-Token" => csrf), params: {
          requirement: "birthdate",
          checkpoint_version: flow.reload.checkpoint_version,
          birthdate_year: "1990",
          birthdate_month: "01",
          birthdate_day: "15",
        }
      end
      assert_response :redirect
      assert_predicate flow.reload, :sign_up_completed?
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

      values.each { |value| assert ClientSecretLookupQuery.call(secret: value) }
    end
  end
end
