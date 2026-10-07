# frozen_string_literal: true

require "test_helper"
require "webauthn/fake_client"

# Proof, cookies and Contact digests must stay out of assertion failure output.
# The real Step-Up and fault/retry journey intentionally has more than thirty assertions.
# rubocop:disable Minitest/AssertEqual, Minitest/AssertOperator, Minitest/MultipleAssertions
class ContactSettingsOtpAtomicCommitTest < ActionDispatch::IntegrationTest
  %w(app com).each do |surface|
    %w(email telephone).each do |channel|
      test "#{surface} settings #{channel} binding failure preserves verification and identical HTTP retry" do
        protection = ActionController::Base.allow_forgery_protection
        previous_turnstile = [TurnstileVerifierStub.enabled, TurnstileVerifierStub.response]
        previous_challenge = [TurnstileVerifierStub.challenge_enabled, TurnstileVerifierStub.challenge_response]
        ActionController::Base.allow_forgery_protection = true
        TurnstileVerifierStub.enabled = true
        TurnstileVerifierStub.response = { "success" => true }
        TurnstileVerifierStub.challenge_enabled = true
        TurnstileVerifierStub.challenge_response = { "success" => true }
        base_host, auth_host, resource_type, client_id, issuer_name, actor, token, rp_model, rp_token_key,
          contact_model, status_key, owner_key, verified_status, parameter_scope =
          case [surface, channel]
          when ["app", "email"], ["app", "telephone"]
            principal = Client.create!(status_id: ClientStatus::ACTIVE)
            root = ClientToken.create!(
              user: principal, established_authentication_method: "passkey",
              root_login_established_at: ClientToken.database_now, discard_at: 1.day.from_now,
            )
            [ENV.fetch("PUBLIC_BASE_SERVICE_URL"), ENV.fetch("PUBLIC_AUTH_SERVICE_URL"),
             "client", "base-app-ww", "BASE_APP", principal, root, ClientRpSession, :client_token,
             (channel == "email") ? ClientEmail : ClientTelephone,
             (channel == "email") ? :user_email_status_id : :user_telephone_status_id, :user_id,
             (channel == "email") ? ClientEmailStatus::VERIFIED : ClientTelephoneStatus::VERIFIED,
             (channel == "email") ? :client_email : :user_telephone,]
          when ["com", "email"], ["com", "telephone"]
            principal = Visitor.create!
            root = VisitorToken.create!(
              visitor: principal, established_authentication_method: "passkey",
              root_login_established_at: VisitorToken.database_now, discard_at: 1.day.from_now,
            )
            [ENV.fetch("PUBLIC_BASE_CORPORATE_URL"), ENV.fetch("PUBLIC_AUTH_CORPORATE_URL"),
             "visitor", "base-com-ww", "BASE_COM", principal, root, VisitorRpSession, :visitor_token,
             (channel == "email") ? VisitorEmail : VisitorTelephone,
             (channel == "email") ? :visitor_email_status_id : :visitor_telephone_status_id, :visitor_id,
             (channel == "email") ? VisitorEmailStatus::VERIFIED : VisitorTelephoneStatus::VERIFIED,
             (channel == "email") ? :visitor_email : :visitor_telephone,]
          end
        origin = "https://#{auth_host}"
        authenticator = WebAuthn::FakeClient.new(origin, encoding: :base64url)
        registration = authenticator.create(challenge: SecureRandom.urlsafe_base64(32), user_verified: true)
        relying_party = WebAuthn::RelyingParty.new(id: auth_host, allowed_origins: [origin], encoding: :base64url)
        credential = WebAuthn::Credential.from_create(registration, relying_party: relying_party)
        passkey =
          if surface == "app"
            actor.client_passkeys.create!(webauthn_id: credential.id, public_key: credential.public_key, sign_count: 0)
          else
            actor.visitor_passkeys.create!(webauthn_id: credential.id, public_key: credential.public_key, sign_count: 0)
          end
        old_contact = contact_model.create!(
          owner_key => actor.id, status_key => verified_status, :confirm_policy => "1",
          (channel == "email") ? :raw_address : :raw_number => (channel == "email") ?
            "old-settings-#{SecureRandom.hex(8)}@example.test" :
            "+8190#{SecureRandom.random_number(10**8).to_s.rjust(8, "0")}",
        )
        old_contact.finalize_binding!
        other_actor = (surface == "app") ? Client.create!(status_id: ClientStatus::ACTIVE) : Visitor.create!
        other_contact = contact_model.create!(
          owner_key => other_actor.id, status_key => verified_status, :confirm_policy => "1",
          (channel == "email") ? :raw_address : :raw_number => (channel == "email") ?
            "other-settings-#{SecureRandom.hex(8)}@example.test" :
            "+8190#{SecureRandom.random_number(10**8).to_s.rjust(8, "0")}",
        )
        other_contact.finalize_binding!
        other_facts = other_contact.reload.attributes
        BaseSelectorBootstrapAuthority.call(surface: surface.to_sym, principal: actor)
        BaseSelectorAuthority.prepare(surface: surface.to_sym, principal: actor, session: token)
        token.rotate_refresh_token!
        client = OidcClientRegistry.find!(client_id)
        rp = rp_model.create!(
          rp_token_key => token, :oidc_client_id => client.client_id, :oidc_scope => "openid profile",
          :oidc_jti => SecureRandom.uuid, :oidc_nonce => SecureRandom.hex(16), :oidc_auth_time => Time.current,
          :refresh_token_expires_at => 10.minutes.from_now,
        )
        access = AuthenticationTokenService.encode(
          actor, host: base_host, resource_type:, session_public_id: token.public_id,
                 base_session_public_id: token.public_id, oidc_sid: rp.public_id, oidc_jti: rp.oidc_jti,
                 expires_at: 10.minutes.from_now, scopes: %w(openid profile), issuer: OidcIssuer.for_client(client),
                 audiences: [client.aud], jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(client),
                 subject: OidcSubject.for(actor, resource_type:), client_id: client.client_id,
        )
        browser = open_session
        browser.host!(base_host)
        browser.https!
        _installed = browser.cookies.merge(
          ["#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(access)}",
           "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(rp.issue_refresh_token!)}",
           "#{AuthenticationBase::ACCESS_COOKIE_KEY}=#{Rack::Utils.escape(
             AuthenticationToken.encode(
               actor, host: base_host, session_public_id: token.public_id, resource_type:,
                      jwt_issuer_id: "surface:#{issuer_name}",
             ),
           )}",], URI.parse("https://#{base_host}/"),
        )
        base_headers = { "Origin" => "https://#{base_host}", "Sec-Fetch-Site" => "same-origin" }
        auth_headers = { "Origin" => origin, "Sec-Fetch-Site" => "same-origin" }
        registration_path = "/identity/#{(channel == "email") ? "emails" : "telephones"}/registration"
        browser.get("#{registration_path}/new", params: { ri: "jp" })

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
        issuer = JitSecurityJwtRegistry.surface(issuer_name)
        rt = Rack::Utils.parse_query(URI.parse(browser.response.location).query).fetch("rt")
        payload, = JWT.decode(
          rt, JitSecurityJwtRegistry.public_key_for(issuer.id, issuer.current_kid), true,
          algorithms: ["ES384"], verify_iss: true, iss: "https://#{base_host}",
          verify_aud: true, aud: Rails.configuration.x.boot_config.fetch(:jump).audience,
        )
        target = URI.parse(payload.fetch("url"))

        assert_equal auth_host, target.host
        browser.host!(auth_host)
        browser.get(target.request_uri)
        3.times do |step|
          form = browser.response.parsed_body.at_css("form")

          assert_not_nil form, "Step-Up admission must render its real continuation form"
          fields = form.css("input[name]").to_h { |input| [input["name"], input["value"]] }
          browser.post(
            form["action"], params: fields, headers: {
              "Origin" => "https://#{browser.host}", "Sec-Fetch-Site" => "same-origin",
            },
          )

          assert_equal 303, browser.response.status
          next if step == 2

          target = URI.parse(browser.response.location)

          assert_equal(step.zero? ? base_host : auth_host, target.host)
          browser.host!(target.host)
          browser.get(target.request_uri)
        end
        browser.get("/verification/passkey/new", params: { ri: "jp" })

        assert_equal 200, browser.response.status
        page = browser.response.parsed_body
        panel = JSON.parse(page.at_css("script[data-page='app']").text).fetch("props").fetch("panel")
        csrf = page.at_css('meta[name="csrf-token"]')["content"]
        browser.post(
          panel.fetch("options_url"), params: { "cf-turnstile-response" => "test" },
                                      headers: auth_headers.merge("X-CSRF-Token" => csrf), as: :json,
        )

        assert_equal 200, browser.response.status
        options = browser.response.parsed_body
        assertion = authenticator.get(
          challenge: options.fetch("options").fetch("challenge"), user_verified: true, sign_count: 1,
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

        assert_equal base_host, completion.host
        browser.host!(base_host)
        browser.get(completion.request_uri)

        assert_equal 200, browser.response.status
        form = browser.response.parsed_body.at_css("form")
        fields = form.css("input[name]").to_h { |input| [input["name"], input["value"]] }
        browser.post(form["action"], params: fields, headers: base_headers)

        assert_equal 303, browser.response.status
        assert_equal "settings_#{channel}", token.reload.last_step_up_scope
        assert_equal passkey.public_id, token.last_step_up_credential_ref
        browser.get("#{registration_path}/new", params: { ri: "jp" })

        assert_equal 200, browser.response.status
        csrf = browser.response.parsed_body.at_css('meta[name="csrf-token"]')["content"]
        input_key = (channel == "email") ? :raw_address : :raw_number
        destination =
          (channel == "email") ? "new-settings-#{SecureRandom.hex(8)}@example.test" :
                   "+8190#{SecureRandom.random_number(10**8).to_s.rjust(8, "0")}"
        contact_fields = { input_key => destination }
        contact_fields[:confirm_policy] = "1" if surface == "app"
        browser.post(
          registration_path, params: {
            parameter_scope => contact_fields,
            "cf-turnstile-response" => "test",
            :ri => "jp",
          }, headers: base_headers.merge("X-CSRF-Token" => csrf),
        )

        assert_equal 302, browser.response.status
        candidate = contact_model.where(owner_key => actor.id).where.not(id: old_contact.id).order(:created_at).last

        assert_not_nil candidate
        candidate_ref = candidate.public_id
        otp = candidate.get_otp
        code = ROTP::HOTP.new(otp.fetch(:otp_private_key)).at(otp.fetch(:otp_counter)).to_s
        old_facts = old_contact.reload.attributes
        browser.get(URI.parse(browser.response.location).request_uri, params: { ri: "jp" })

        assert_equal 200, browser.response.status
        csrf = browser.response.parsed_body.at_css('meta[name="csrf-token"]')["content"]
        submission = { parameter_scope => { pass_code: code }, "cf-turnstile-response" => "test", :ri => "jp" }
        headers = base_headers.merge("X-CSRF-Token" => csrf)
        failures = 0
        failure =
          lambda do |_name, _started, _finished, _identity, sql_event|
            if sql_event[:name] == "#{contact_model} Update" && sql_event[:sql].include?('"binding_finalized_at"')
              failures += 1
              raise ActiveRecord::StatementInvalid, "settings Contact binding persistence unavailable"
            end
          end

        ActiveSupport::Notifications.subscribed(failure, "sql.active_record") do
          assert_raises(ActiveRecord::StatementInvalid) do
            browser.patch(registration_path, params: submission, headers: headers)
          end
        end
        assert_equal 1, failures
        assert_nil candidate.reload.binding_finalized_at
        assert old_facts == old_contact.reload.attributes, "Failure must preserve the original effective binding"
        assert other_facts == other_contact.reload.attributes, "Failure must preserve another owner's binding"
        assert_nil candidate.get_otp, "Verification consumes the OTP before independent binding finalization"
        proof = candidate.credential_registration_otp_context.deep_dup

        assert_not_nil proof, "Failed binding persistence must retain the original flow-specific verification result"
        assert_not_nil proof.fetch("verified_at")
        assert_operator Time.iso8601(proof.fetch("result_expires_at")), :>, candidate.class.database_now
        flow_model =
          case [surface, channel]
          when ["app", "email"] then ClientEmailCeremonyTransaction
          when ["app", "telephone"] then ClientTelephoneCeremonyTransaction
          when ["com", "email"] then VisitorEmailCeremonyTransaction
          when ["com", "telephone"] then VisitorTelephoneCeremonyTransaction
          end
        flow = flow_model.find_by!(transaction_id: proof.fetch("flow_ref"))

        assert_not flow.consumed?
        assert_equal [Time.iso8601(proof.fetch("verified_at")) + 60.seconds, flow.expires_at].min,
                     Time.iso8601(proof.fetch("result_expires_at"))
        browser.patch(registration_path, params: submission, headers: headers)

        assert_includes [302, 303], browser.response.status
        assert_equal candidate_ref, candidate.reload.public_id
        assert_equal actor.id, candidate[owner_key]
        assert_predicate candidate, :binding_effective?,
                         "The original candidate must be finalized by the identical retry"
        assert_nil candidate.get_otp
        assert proof == candidate.credential_registration_otp_context,
               "Identical HTTP retry must preserve the original immutable verification result"
        assert_predicate flow.reload, :consumed?
        assert_not_nil old_contact.reload.binding_released_at
        assert_equal 1, contact_model.effective_binding.where(owner_key => actor.id).count
        assert other_facts == other_contact.reload.attributes, "Retry must not mutate another owner's binding"
      ensure
        ActionController::Base.allow_forgery_protection = protection
        TurnstileVerifierStub.enabled, TurnstileVerifierStub.response = previous_turnstile
        TurnstileVerifierStub.challenge_enabled, TurnstileVerifierStub.challenge_response = previous_challenge
      end
    end
  end
end
# rubocop:enable Minitest/AssertEqual, Minitest/AssertOperator, Minitest/MultipleAssertions
