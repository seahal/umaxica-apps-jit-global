# frozen_string_literal: true

require "test_helper"

# Boolean comparisons keep OTP, browser bindings and proof out of failure diagnostics.
# rubocop:disable Minitest/AssertEqual, Minitest/AssertOperator, Minitest/MultipleAssertions
class ContactRegistrationOtpBootstrapReceiptRecoveryTest < ActionDispatch::IntegrationTest
  %w(app com).each do |surface|
    %i(contact_receipt bootstrap_receipt).each do |boundary|
      test "#{surface} email bootstrap recovers #{boundary} through identical HTTP without granting freshness" do
        protection = ActionController::Base.allow_forgery_protection
        previous_turnstile = [TurnstileVerifierStub.enabled, TurnstileVerifierStub.response]
        previous_challenge = [TurnstileVerifierStub.challenge_enabled, TurnstileVerifierStub.challenge_response]
        ActionController::Base.allow_forgery_protection = true
        TurnstileVerifierStub.enabled = true
        TurnstileVerifierStub.response = { "success" => true }
        TurnstileVerifierStub.challenge_enabled = true
        TurnstileVerifierStub.challenge_response = { "success" => true }
        actor_model, token_model, contact_model, flow_model, parent_model, step_session_model, audit_model,
          rp_model, owner_key, rp_key, step_root_key, resource_type, client_id, issuer_name, base_host,
          parameter_scope =
          case surface
          when "app"
            [Client, ClientToken, ClientEmail, ClientEmailCeremonyTransaction,
             ClientStepUpCeremonyTransaction, ClientStepUpSession, ClientContactAuditOutbox,
             ClientRpSession, :user_id, :client_token, :user_token_id, "client", "base-app-ww", "BASE_APP",
             ENV.fetch("PUBLIC_BASE_SERVICE_URL"), :client_email,]
          when "com"
            [Visitor, VisitorToken, VisitorEmail, VisitorEmailCeremonyTransaction,
             VisitorStepUpCeremonyTransaction, VisitorStepUpSession, VisitorContactAuditOutbox,
             VisitorRpSession, :visitor_id, :visitor_token, :visitor_token_id, "visitor", "base-com-ww", "BASE_COM",
             ENV.fetch("PUBLIC_BASE_CORPORATE_URL"), :visitor_email,]
          else
            raise ArgumentError, "unsupported test surface"
          end
        actor = actor_model.create!(
          id: SecureRandom.random_number(1 << 60) + 1_000_000_000,
          status_id: (surface == "app") ? ClientStatus::ACTIVE : VisitorStatus::ACTIVE,
        )
        token = token_model.create!(
          owner_key => actor.id, :root_login_established_at => token_model.database_now,
          :discard_at => 1.day.from_now,
        )
        BaseSelectorBootstrapAuthority.call(surface: surface.to_sym, principal: actor)
        BaseSelectorAuthority.prepare(surface: surface.to_sym, principal: actor, session: token)
        token.rotate_refresh_token!
        client = OidcClientRegistry.find!(client_id)
        rp = rp_model.create!(
          rp_key => token, :oidc_client_id => client.client_id, :oidc_scope => "openid profile",
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
        headers = { "Origin" => "https://#{base_host}", "Sec-Fetch-Site" => "same-origin" }
        target = ActiveSupport::MessageVerifier.new(
          Rails.application.key_generator.generate_key("path_target_token", 32),
          digest: "SHA256", serializer: JSON, url_safe: true,
        ).generate(
          { "flow" => "step_up.bootstrap",
            "surface" => surface,
            "session_nonce" => token.public_id,
            "pt" => "/identity/emails", },
          purpose: :path_target, expires_in: 15.minutes,
        )

        assert_empty StepUpConfiguredMethodsQuery.call(actor)
        assert_nil token.reload.last_step_up_at
        browser.get("/verification/setup", params: { ri: "jp", scope: "settings_email", pt: target })

        assert_equal 200, browser.response.status
        page = browser.response.parsed_body
        form = JSON.parse(page.at_css("script[data-page='app']").text).fetch("props").fetch("form")
        csrf = page.at_css('meta[name="csrf-token"]')["content"]
        browser.post(
          form.fetch("action"), params: {
            scope: form.fetch("scope"),
            pt: form.fetch("pt"),
            registration_method: "email_otp",
            ri: "jp",
            authenticity_token: csrf,
          }, headers:,
        )

        assert_equal 303, browser.response.status
        assert_equal "/identity/emails/registration/new", URI.parse(browser.response.location).path
        parent = parent_model.find_by!(
          transaction_id: step_session_model.find_by!(step_root_key => token.id).step_up_ceremony_transaction_ref,
        )

        assert_equal "pending", parent.status
        assert_equal "bootstrap", parent.purpose
        assert_equal ["email_otp"], parent.allowed_methods_array
        browser.get(URI.parse(browser.response.location).request_uri)

        assert_equal 200, browser.response.status
        csrf = browser.response.parsed_body.at_css('meta[name="csrf-token"]')["content"]
        fields = { raw_address: "receipt-bootstrap-#{SecureRandom.hex(8)}@example.test" }
        fields[:confirm_policy] = "1" if surface == "app"
        browser.post(
          "/identity/emails/registration", params: {
            parameter_scope => fields, "cf-turnstile-response" => "test", :ri => "jp",
          }, headers: headers.merge("X-CSRF-Token" => csrf),
        )

        assert_equal 302, browser.response.status
        contact = contact_model.find_by!(owner_key => actor.id)
        context = contact.credential_registration_otp_context

        assert_not_nil context
        transaction = flow_model.find_by!(transaction_id: context.fetch("flow_ref"))
        otp = contact.get_otp
        code = ROTP::HOTP.new(otp.fetch(:otp_private_key)).at(otp.fetch(:otp_counter)).to_s
        browser.get(URI.parse(browser.response.location).request_uri, params: { ri: "jp" })

        assert_equal 200, browser.response.status
        nonce = browser.request.session.fetch("auth_admission_browser_nonce")
        locator = browser.request.session.fetch("base_step_up_marker_locator")
        marker = Valkey::AuthState::BaseStepUpMarkerStore.new.read(locator:, transaction_ref: parent.transaction_id)

        assert_not_nil marker
        assert marker.fetch("session_ref") == token.public_id, "Original marker must bind the current Root"
        assert context.fetch("browser_digest") == AuthAdmissionBinding.browser_digest(
          surface:, entry_ref: transaction.transaction_id, nonce:,
        ), "Contact proof must belong to the server-issued original browser"
        csrf = browser.response.parsed_body.at_css('meta[name="csrf-token"]')["content"]
        submission = { parameter_scope => { pass_code: code }, "cf-turnstile-response" => "test", :ri => "jp" }
        confirmation_headers = headers.merge("X-CSRF-Token" => csrf)
        original_ticket = transaction.reload.attributes
        original_parent = parent.reload.attributes
        failures = 0
        failing_table = (boundary == :contact_receipt) ? flow_model.table_name : parent_model.table_name
        failure =
          lambda do |event|
            sql = event.payload.fetch(:sql)
            next unless sql.start_with?("UPDATE") && sql.include?(failing_table)

            failures += 1
            raise ActiveRecord::StatementInvalid, "bootstrap receipt persistence unavailable"
          end

        ActiveSupport::Notifications.subscribed(failure, "sql.active_record") do
          assert_raises(ActiveRecord::StatementInvalid) do
            browser.patch("/identity/emails/registration", params: submission, headers: confirmation_headers)
          end
        end

        assert_equal 1, failures
        assert_predicate contact.reload, :binding_effective?
        assert_nil contact.get_otp
        proof = contact.credential_registration_otp_context.deep_dup
        source_facts = contact.attributes
        audits = audit_model.where(operation_ref: transaction.transaction_id)

        assert_not_nil proof.fetch("verified_at")
        assert_equal [Time.iso8601(proof.fetch("verified_at")) + 60.seconds, transaction.expires_at].min,
                     Time.iso8601(proof.fetch("result_expires_at"))
        assert_operator Time.iso8601(proof.fetch("result_expires_at")), :>, contact_model.database_now
        assert original_ticket == transaction.reload.attributes,
               "Failed receipt must retain the original Contact Ticket"
        assert original_parent == parent.reload.attributes, "Failed receipt must retain the original Bootstrap parent"
        assert_equal "pending", transaction.status
        assert_equal "pending", parent.status
        assert_equal 1, audits.where(event_name: "finalized", contact_ref: contact.public_id).count
        audit_facts = audits.first.attributes

        assert_includes StepUpConfiguredMethodsQuery.call(actor), :email_otp
        assert_nil token.reload.last_step_up_at
        pending_marker = Valkey::AuthState::BaseStepUpMarkerStore.new.read(
          locator:, transaction_ref: parent.transaction_id,
        )

        assert marker == pending_marker, "Persistence failure must retain the original Root/browser marker"
        wrong_code = ((code.to_i + 1) % 1_000_000).to_s.rjust(6, "0")
        attempt_started_at = contact_model.database_now
        browser.patch(
          "/identity/emails/registration",
          params: submission.merge(parameter_scope => { pass_code: wrong_code }), headers: confirmation_headers,
        )

        assert_equal 422, browser.response.status
        assert_equal "pending", transaction.reload.status
        assert_equal "pending", parent.reload.status
        assert proof == contact.reload.credential_registration_otp_context,
               "Receipt-only authorization must still verify the original submitted code"
        assert_equal source_facts.fetch("otp_attempts_count") + 1, contact.otp_attempts_count
        assert_operator contact.otp_last_sent_at, :>=, attempt_started_at
        assert_operator contact.otp_last_sent_at, :<=, contact_model.database_now
        assert source_facts.except("otp_attempts_count", "otp_last_sent_at", "updated_at") ==
          contact.attributes.except("otp_attempts_count", "otp_last_sent_at", "updated_at"),
               "Wrong-code refusal updates only the existing failure counter and attempt-window anchor"
        source_facts = contact.attributes
        browser.patch("/identity/emails/registration", params: submission, headers: confirmation_headers)

        assert_equal 302, browser.response.status
        assert_equal "/identity/emails", URI.parse(browser.response.location).path,
                     "Receipt recovery must return to the original target, not ordinary verification"
        assert source_facts == contact.reload.attributes, "Receipt-only retry must not rewrite committed Source facts"
        assert proof == contact.credential_registration_otp_context, "Retry must retain the exact bounded proof"
        assert_predicate transaction.reload, :consumed?
        assert_equal "consumed", parent.reload.status
        assert parent.verified_credential_ref == contact.public_id, "Original parent must consume the original Contact"
        assert_equal 1, audits.count
        assert audit_facts == audits.first.attributes, "Retry must not rewrite the original Source audit"
        assert nonce == browser.request.session.fetch("auth_admission_browser_nonce"),
               "Retry must retain original nonce"
        assert locator == browser.request.session.fetch("base_step_up_marker_locator"),
               "Retry must retain original locator"
        completed_marker = Valkey::AuthState::BaseStepUpMarkerStore.new.read(
          locator:, transaction_ref: parent.transaction_id,
        )

        assert marker == completed_marker,
               "Retry must not replace the original Root/browser marker"
        assert_nil token.reload.last_step_up_at
        assert_nil token.last_step_up_scope
        assert_nil token.last_step_up_credential_ref
        assert_predicate token, :currently_usable?
        assert_equal 1, contact_model.effective_binding.where(owner_key => actor.id).count
        assert_nil contact.get_otp
      ensure
        ActionController::Base.allow_forgery_protection = protection
        TurnstileVerifierStub.enabled, TurnstileVerifierStub.response = previous_turnstile
        TurnstileVerifierStub.challenge_enabled, TurnstileVerifierStub.challenge_response = previous_challenge
      end
    end
  end
end
# rubocop:enable Minitest/AssertEqual, Minitest/AssertOperator, Minitest/MultipleAssertions
