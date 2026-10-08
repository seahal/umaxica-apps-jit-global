# frozen_string_literal: true

require "test_helper"
require "webauthn/fake_client"
require "minitest/mock"

# Boolean snapshots prevent disclosure of proof, credentials and browser material.
# rubocop:disable Minitest/AssertEqual, Minitest/AssertOperator, Minitest/AssertIncludes, Minitest/MultipleAssertions
class ContactRegistrationOtpHttpResendTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  %i(cooldown_before cooldown_at cooldown_after verified_source_fault).each do |scenario|
    test "APP email HTTP resend #{scenario} retains original flow proof and failure budgets" do
      protection = ActionController::Base.allow_forgery_protection
      previous_turnstile = [TurnstileVerifierStub.enabled, TurnstileVerifierStub.response]
      previous_challenge = [TurnstileVerifierStub.challenge_enabled, TurnstileVerifierStub.challenge_response]
      ActionController::Base.allow_forgery_protection = true
      TurnstileVerifierStub.enabled = true
      TurnstileVerifierStub.response = { "success" => true }
      TurnstileVerifierStub.challenge_enabled = true
      TurnstileVerifierStub.challenge_response = { "success" => true }
      base_host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
      auth_host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
      actor = Client.create!(status_id: ClientStatus::ACTIVE)
      token = ClientToken.create!(
        user: actor, established_authentication_method: "passkey", root_login_established_at: ClientToken.database_now,
        discard_at: 1.day.from_now,
      )
      origin = "https://#{auth_host}"
      authenticator = WebAuthn::FakeClient.new(origin, encoding: :base64url)
      registration = authenticator.create(challenge: SecureRandom.urlsafe_base64(32), user_verified: true)
      rp_config = WebAuthn::RelyingParty.new(id: auth_host, allowed_origins: [origin], encoding: :base64url)
      registered = WebAuthn::Credential.from_create(registration, relying_party: rp_config)
      passkey = actor.client_passkeys.create!(
        webauthn_id: registered.id, public_key: registered.public_key,
        sign_count: 0,
      )
      previous = actor.client_emails.create!(
        raw_address: "old-resend-#{SecureRandom.hex(8)}@example.test", confirm_policy: "1",
        user_email_status_id: ClientEmailStatus::VERIFIED,
      )
      previous.finalize_binding!
      BaseSelectorBootstrapAuthority.call(surface: :app, principal: actor)
      BaseSelectorAuthority.prepare(surface: :app, principal: actor, session: token)
      token.rotate_refresh_token!
      client = OidcClientRegistry.find!("base-app-ww")
      rp = ClientRpSession.create!(
        client_token: token, oidc_client_id: client.client_id, oidc_scope: "openid profile",
        oidc_jti: SecureRandom.uuid,
        oidc_nonce: SecureRandom.hex(16), oidc_auth_time: Time.current, refresh_token_expires_at: 10.minutes.from_now,
      )
      access = AuthenticationTokenService.encode(
        actor, host: base_host, resource_type: "client", session_public_id: token.public_id,
               base_session_public_id: token.public_id, oidc_sid: rp.public_id, oidc_jti: rp.oidc_jti,
               expires_at: 10.minutes.from_now, scopes: %w(openid profile), issuer: OidcIssuer.for_client(client),
               audiences: [client.aud], jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(client),
               subject: OidcSubject.for(actor, resource_type: "client"), client_id: client.client_id,
      )
      browser = open_session
      browser.host!(base_host)
      browser.https!
      _installed = browser.cookies.merge(
        ["#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(access)}",
         "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(rp.issue_refresh_token!)}",
         "#{AuthenticationBase::ACCESS_COOKIE_KEY}=#{Rack::Utils.escape(
           AuthenticationToken.encode(
             actor, host: base_host, session_public_id: token.public_id, resource_type: "client",
                    jwt_issuer_id: "surface:BASE_APP",
           ),
         )}",], URI.parse("https://#{base_host}/"),
      )
      base_headers = { "Origin" => "https://#{base_host}", "Sec-Fetch-Site" => "same-origin" }
      auth_headers = { "Origin" => origin, "Sec-Fetch-Site" => "same-origin" }
      browser.get("/identity/emails/registration/new", params: { ri: "jp" })

      assert_equal 302, browser.response.status
      browser.get(URI.parse(browser.response.location).request_uri)

      assert_equal 200, browser.response.status
      props = JSON.parse(browser.response.parsed_body.at_css("script[data-page='app']").text).fetch("props")
      form = props.fetch("form")
      csrf = browser.response.parsed_body.at_css('meta[name="csrf-token"]')["content"]
      browser.post(
        "/verification", params: {
          scope: form.fetch("scope"), pt: form.fetch("pt"), ri: "jp", authenticity_token: csrf,
        }, headers: base_headers,
      )

      assert_equal 303, browser.response.status
      issuer = JitSecurityJwtRegistry.surface("BASE_APP")
      rt = Rack::Utils.parse_query(URI.parse(browser.response.location).query).fetch("rt")
      claims, = JWT.decode(
        rt, JitSecurityJwtRegistry.public_key_for(issuer.id, issuer.current_kid), true,
        algorithms: ["ES384"], verify_iss: true, iss: "https://#{base_host}", verify_aud: true,
        aud: Rails.configuration.x.boot_config.fetch(:jump).audience,
      )
      target = URI.parse(claims.fetch("url"))

      assert target.host == auth_host, "Step-Up must reach the configured Auth surface"
      browser.host!(auth_host)
      browser.get(target.request_uri)
      3.times do |step|
        form = browser.response.parsed_body.at_css("form")

        assert_not_nil form
        fields = form.css("input[name]").to_h { |input| [input["name"], input["value"]] }
        browser.post(
          form["action"], params: fields, headers: {
            "Origin" => "https://#{browser.host}", "Sec-Fetch-Site" => "same-origin",
          },
        )

        assert_equal 303, browser.response.status
        next if step == 2

        target = URI.parse(browser.response.location)

        assert target.host == (step.zero? ? base_host : auth_host),
               "Admission must retain its original browser surfaces"
        browser.host!(target.host)
        browser.get(target.request_uri)
      end
      browser.get("/verification/passkey/new", params: { ri: "jp" })

      assert_equal 200, browser.response.status
      props = JSON.parse(browser.response.parsed_body.at_css("script[data-page='app']").text).fetch("props")
      panel = props.fetch("panel")
      csrf = browser.response.parsed_body.at_css('meta[name="csrf-token"]')["content"]
      browser.post(
        panel.fetch("options_url"), params: { "cf-turnstile-response" => "test" },
                                    headers: auth_headers.merge("X-CSRF-Token" => csrf), as: :json,
      )

      assert_equal 200, browser.response.status
      options = browser.response.parsed_body
      assertion = authenticator.get(
        challenge: options.fetch("options").fetch("challenge"), user_verified: true,
        sign_count: 1,
      )
      browser.post(
        panel.fetch("verification_url"), params: {
          credential: assertion, challenge_id: options.fetch("challenge_id"),
        }, headers: auth_headers.merge("X-CSRF-Token" => csrf), as: :json,
      )

      assert_equal 200, browser.response.status
      assert_nil token.reload.last_step_up_at
      browser.get(browser.response.parsed_body.fetch("redirect_url"))
      form = browser.response.parsed_body.at_css("form")
      browser.post(
        form["action"], params: {
          authenticity_token: form.at_css('input[name="authenticity_token"]')["value"],
        }, headers: auth_headers,
      )

      assert_equal 303, browser.response.status
      completion = URI.parse(browser.response.location)

      assert completion.host == base_host, "Freshness must be committed at the original Base surface"
      browser.host!(base_host)
      browser.get(completion.request_uri)

      assert_equal 200, browser.response.status
      form = browser.response.parsed_body.at_css("form")
      fields = form.css("input[name]").to_h { |input| [input["name"], input["value"]] }
      browser.post(form["action"], params: fields, headers: base_headers)

      assert_equal 303, browser.response.status
      assert_equal "settings_email", token.reload.last_step_up_scope
      assert token.last_step_up_credential_ref == passkey.public_id, "Freshness must come from the real signed passkey"
      browser.get("/identity/emails/registration/new", params: { ri: "jp" })

      assert_equal 200, browser.response.status
      csrf = browser.response.parsed_body.at_css('meta[name="csrf-token"]')["content"]
      destination = "http-resend-#{SecureRandom.hex(8)}@example.test"
      clear_enqueued_jobs
      browser.post(
        "/identity/emails/registration", params: {
          :client_email => { raw_address: destination,
                             confirm_policy: "1", },
          "cf-turnstile-response" => "test",
          :ri => "jp",
        }, headers: base_headers.merge("X-CSRF-Token" => csrf),
      )

      assert_equal 302, browser.response.status
      original_job = enqueued_jobs.find { |job| job.fetch(:job) == OtpNotifierEmailDeliveryJob }

      assert_not_nil original_job
      original_params = ActiveJob::Arguments.deserialize(original_job.fetch(:args)).last.fetch(:params).symbolize_keys
      candidate = actor.client_emails.where.not(id: previous.id).order(:id).last

      assert_not_nil candidate
      code = OutboundSensitivePayload.decrypt_email_otp(original_params.fetch(:encrypted_hotp_token))
      flow = ClientEmailCeremonyTransaction.find_by!(
        transaction_id: browser.request.session.fetch(:email_registration_transaction_ref),
      )

      assert original_params.fetch(:contact_ceremony_transaction_ref) == flow.transaction_id,
             "Queued delivery must retain the original registration transaction"
      assert original_params.fetch(:contact_otp_generation) == flow.otp_generation,
             "Queued delivery must retain the independent Email generation"
      assert_not original_job.fetch(:args).to_s.include?(code), "Original queue must not expose the random code"
      browser.get(URI.parse(browser.response.location).request_uri, params: { ri: "jp" })

      assert_equal 200, browser.response.status
      props = JSON.parse(browser.response.parsed_body.at_css("script[data-page='app']").text).fetch("props")
      resend_path = props.fetch("resend").fetch("url")
      csrf = browser.response.parsed_body.at_css('meta[name="csrf-token"]')["content"]
      headers = base_headers.merge("X-CSRF-Token" => csrf)
      wrong_code = (code == "000000") ? "000001" : "000000"
      3.times do
        browser.patch(
          "/identity/emails/registration", params: {
            :client_email => { pass_code: wrong_code }, "cf-turnstile-response" => "test", :ri => "jp",
          }, headers:,
        )

        assert_equal 422, browser.response.status
      end
      if scenario == :verified_source_fault
        fault =
          lambda do |event|
            sql = event.payload.fetch(:sql)
            next unless sql.start_with?("UPDATE") && sql.include?(ClientEmail.table_name) &&
              sql.include?("binding_finalized_at")

            raise ActiveRecord::StatementInvalid, "injected HTTP resend Source finalization failure"
          end

        ActiveSupport::Notifications.subscribed(fault, "sql.active_record") do
          assert_raises(ActiveRecord::StatementInvalid) do
            browser.patch(
              "/identity/emails/registration", params: {
                :client_email => { pass_code: code }, "cf-turnstile-response" => "test", :ri => "jp",
              }, headers:,
            )
          end
        end

        assert_nil flow.reload.otp_verifier
        assert_not_nil flow.otp_consumed_at
        assert_not_nil flow.otp_receipt_verifier
      end
      candidate_facts = candidate.reload.attributes
      context = flow.reload.attributes
      previous_facts = previous.reload.attributes
      root_facts = token.reload.attributes
      ticket_facts = flow.reload.attributes
      decision_time =
        if scenario == :verified_source_fault
          ClientEmail.database_now
        else
          # Existing email cooldown is thirty seconds; timestamptz(6) supplies its nearest neighbors.
          offset = { cooldown_before: -1, cooldown_at: 0, cooldown_after: 1 }.fetch(scenario)
          candidate.otp_last_sent_at + 30.seconds + Rational(offset, 1_000_000)
        end
      clear_enqueued_jobs
      ClientEmail.stub(:database_now, decision_time) do
        ClientEmailCeremonyTransaction.stub(:database_now, decision_time) do
          browser.post(resend_path, params: { "cf-turnstile-response" => "test", :ri => "jp" }, headers:)

          assert_equal 302, browser.response.status
          if %i(cooldown_at cooldown_after).include?(scenario)
            candidate.reload
            updated = flow.reload.attributes
            new_job = enqueued_jobs.find { |job| job.fetch(:job) == OtpNotifierEmailDeliveryJob }

            assert_not_nil new_job
            new_params = ActiveJob::Arguments.deserialize(new_job.fetch(:args)).last.fetch(:params).symbolize_keys
            new_code = OutboundSensitivePayload.decrypt_email_otp(new_params.fetch(:encrypted_hotp_token))

            assert_equal 1, enqueued_jobs.count { |job| job.fetch(:job) == OtpNotifierEmailDeliveryJob }
            assert context.except("otp_generation", "otp_verifier", "updated_at", "lock_version") ==
              updated.except("otp_generation", "otp_verifier", "updated_at", "lock_version"),
                   "HTTP resend must preserve original flow, browser, owner, root, destination and deadlines"
            assert_equal context.fetch("lock_version") + 1, updated.fetch("lock_version"),
                         "Reissuance must advance the Ticket optimistic lock exactly once"
            assert_not_equal context.fetch("otp_generation"), updated.fetch("otp_generation"),
                             "Resend must supersede the original Email generation"
            assert_not_equal context.fetch("otp_verifier"), updated.fetch("otp_verifier"),
                             "Resend must bind its verifier to the new generation"
            assert_equal 3, candidate.otp_attempts_count
            assert candidate_facts.except("otp_last_sent_at", "updated_at") ==
              candidate.attributes.except("otp_last_sent_at", "updated_at"),
                   "Resend must preserve every Source fact except the issuance timestamp"
            assert_equal decision_time, candidate.otp_last_sent_at
            assert new_params.fetch(:contact_ceremony_transaction_ref) == flow.transaction_id,
                   "Queued resend must retain the original Ticket UUID"
            assert new_params.fetch(:contact_otp_generation) == updated.fetch("otp_generation"),
                   "Queued generation must match the independent Email transaction"
            assert OutboundSensitivePayload.decrypt_email_otp(new_params.fetch(:encrypted_hotp_token)) == new_code,
                   "Queued ciphertext must contain the real reissued random code"
            assert_not new_job.fetch(:args).to_s.include?(new_code), "Resend queue must not expose the plaintext code"
            before = ActionMailer::Base.deliveries.length
            Email::App::OtpMailer.with(original_params.merge(email_address: candidate.address)).create.deliver_now

            assert_equal before, ActionMailer::Base.deliveries.length
            Email::App::OtpMailer.with(new_params.merge(email_address: candidate.address)).create.deliver_now

            assert_equal before + 1, ActionMailer::Base.deliveries.length
            mail = ActionMailer::Base.deliveries.last

            assert_not_nil mail.text_part
            assert mail.text_part.body.decoded.include?(new_code),
                   "The accepted generation must deliver its actual code"
          else
            assert_equal 0, enqueued_jobs.count { |job| job.fetch(:job) == OtpNotifierEmailDeliveryJob }
            assert candidate_facts == candidate.reload.attributes,
                   "Refused resend must preserve Source issuance or proof"
            if scenario == :verified_source_fault
              before = ActionMailer::Base.deliveries.length
              Email::App::OtpMailer.with(original_params.merge(email_address: candidate.address)).create.deliver_now

              assert_equal before, ActionMailer::Base.deliveries.length
              assert context == flow.reload.attributes,
                     "Queued original mail must refuse consumed proof without rewriting retained evidence"
            end
          end
        end
      end

      assert previous_facts == previous.reload.attributes, "Resend must preserve the previous effective binding"
      if %i(cooldown_at cooldown_after).include?(scenario)
        assert ticket_facts.except("otp_generation", "otp_verifier", "updated_at", "lock_version") ==
          flow.reload.attributes.except("otp_generation", "otp_verifier", "updated_at", "lock_version"),
               "Resend may change only the Email generation and its verifier on the original pending Ticket"
        assert_equal ticket_facts.fetch("lock_version") + 1, flow.lock_version
      else
        assert ticket_facts == flow.reload.attributes, "Refused resend must preserve the complete original Ticket"
      end

      assert root_facts == token.reload.attributes, "Resend must preserve the original Root authority"
      assert_equal :invalid_code, EmailOtpVerificationFailureBudget.new.verify!(
        surface: :app, purpose: :credential_registration, channel: :email,
        destination_digest: candidate.address_digest, valid: false,
      )
      assert_equal :locked, EmailOtpVerificationFailureBudget.new.verify!(
        surface: :app, purpose: :credential_registration, channel: :email,
        destination_digest: candidate.address_digest, valid: false,
      )
    ensure
      ActionController::Base.allow_forgery_protection = protection
      TurnstileVerifierStub.enabled, TurnstileVerifierStub.response = previous_turnstile
      TurnstileVerifierStub.challenge_enabled, TurnstileVerifierStub.challenge_response = previous_challenge
    end
  end
end
# rubocop:enable Minitest/AssertEqual, Minitest/AssertOperator, Minitest/AssertIncludes, Minitest/MultipleAssertions
