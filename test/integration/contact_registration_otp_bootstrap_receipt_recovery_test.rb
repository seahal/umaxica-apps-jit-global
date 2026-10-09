# frozen_string_literal: true

require "test_helper"

# Boolean comparisons keep OTP, browser bindings and proof out of failure diagnostics.
# rubocop:disable Minitest/MultipleAssertions
class ContactRegistrationOtpBootstrapReceiptRecoveryTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

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
        clear_enqueued_jobs
        browser.post(
          "/identity/emails/registration", params: {
            parameter_scope => fields, "cf-turnstile-response" => "test", :ri => "jp",
          }, headers: headers.merge("X-CSRF-Token" => csrf),
        )

        assert_equal 302, browser.response.status
        contact = contact_model.find_by!(owner_key => actor.id)
        transaction_key =
          (surface == "app") ? :email_registration_transaction_ref :
                   :com_settings_email_registration_transaction_ref
        transaction = flow_model.find_by!(transaction_id: browser.request.session.fetch(transaction_key))
        job = enqueued_jobs.find { |entry| entry.fetch(:job) == OtpNotifierEmailDeliveryJob }

        assert_not_nil job
        delivery = ActiveJob::Arguments.deserialize(job.fetch(:args)).last.fetch(:params).stringify_keys
        code = OutboundSensitivePayload.decrypt_email_otp(delivery.fetch("encrypted_hotp_token"))

        assert_withheld("Delivery must retain the original Email transaction") {
          delivery.fetch("contact_ceremony_transaction_ref") == transaction.transaction_id
        }
        assert_withheld("Delivery must retain the independent Email generation") {
          delivery.fetch("contact_otp_generation") == transaction.otp_generation
        }
        assert_withheld("The keyed proof must bind the original Bootstrap parent before issuance") {
          transaction.bootstrap_ceremony_transaction_ref == parent.transaction_id
        }
        assert_not job.fetch(:args).to_s.include?(code), "Queued delivery must not expose its random code"
        browser.get(URI.parse(browser.response.location).request_uri, params: { ri: "jp" })

        assert_equal 200, browser.response.status
        nonce = browser.request.session.fetch("auth_admission_browser_nonce")
        locator = browser.request.session.fetch("base_step_up_marker_locator")
        marker = BaseStepUpMarkerAdapter.new.read(locator:, transaction_ref: parent.transaction_id)

        assert_not_nil marker
        assert_withheld("Original marker must bind the current Root") { marker.fetch("session_ref") == token.public_id }
        assert_withheld("Email proof must belong to the server-issued original browser and Root") {
          transaction.session_ref == CredentialRegistrationOtpSessionValue.for(
            surface:, channel: :email, transaction_ref: transaction.transaction_id,
            root_ref: token.public_id, browser_nonce: nonce,
          ).dump
        }
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
            next unless sql.start_with?("UPDATE") && sql.include?(failing_table) &&
              sql.match?(/SET.*"status"\s*=/)

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
        assert_nil transaction.reload.otp_verifier
        proof = transaction.attributes.slice(
          "otp_consumed_at", "otp_receipt_verifier", "otp_result_expires_at",
          "otp_generation", "otp_expires_at", "session_ref", "bootstrap_ceremony_transaction_ref",
        )
        source_facts = contact.attributes
        audits = audit_model.where(operation_ref: transaction.transaction_id)

        assert_not_nil proof.fetch("otp_consumed_at")
        assert_not_nil proof.fetch("otp_receipt_verifier")
        assert_equal [proof.fetch("otp_consumed_at") + 60.seconds, transaction.expires_at].min,
                     proof.fetch("otp_result_expires_at")
        assert_operator proof.fetch("otp_result_expires_at"), :>, flow_model.database_now
        verification_changes = %w(
          otp_consumed_at otp_receipt_verifier otp_verifier otp_result_expires_at updated_at lock_version
        )

        assert_withheld("Failed lifecycle receipt must retain every Ticket fact except committed OTP verification") {
          original_ticket.except(*verification_changes) ==
            transaction.reload.attributes.except(*verification_changes)
        }
        assert_equal original_ticket.fetch("lock_version") + 1, transaction.lock_version,
                     "Committed OTP verification must advance the Ticket optimistic lock exactly once"
        verified_ticket = transaction.attributes

        assert_withheld("Failed receipt must retain the original Bootstrap parent") {
          original_parent == parent.reload.attributes
        }
        assert_equal "pending", transaction.status
        assert_equal "pending", parent.status
        assert_equal 1, audits.where(event_name: "finalized", contact_ref: contact.public_id).count
        audit_facts = audits.first.attributes

        assert_includes StepUpConfiguredMethodsQuery.call(actor), :email_otp
        assert_nil token.reload.last_step_up_at
        pending_marker = BaseStepUpMarkerAdapter.new.read(
          locator:, transaction_ref: parent.transaction_id,
        )

        assert_withheld("Persistence failure must retain the original Root/browser marker") { marker == pending_marker }
        wrong_code = ((code.to_i + 1) % 1_000_000).to_s.rjust(6, "0")
        browser.patch(
          "/identity/emails/registration",
          params: submission.merge(parameter_scope => { pass_code: wrong_code }), headers: confirmation_headers,
        )

        assert_equal 422, browser.response.status
        assert_equal "pending", transaction.reload.status
        assert_equal "pending", parent.reload.status
        assert_withheld("Receipt-only authorization must still verify the original submitted code") {
          verified_ticket == transaction.attributes
        }
        assert_equal source_facts.fetch("otp_attempts_count") + 1, contact.reload.otp_attempts_count
        assert_withheld("Wrong-code refusal must not change the Email issuance timestamp") {
          contact.reload.otp_last_sent_at == source_facts.fetch("otp_last_sent_at")
        }
        assert_withheld("Wrong-code refusal updates only the Email failure counter and update timestamp") {
          source_facts.except(
            "otp_attempts_count", "updated_at",
          ) ==
            contact.attributes.except("otp_attempts_count", "updated_at")
        }
        source_facts = contact.attributes
        browser.patch("/identity/emails/registration", params: submission, headers: confirmation_headers)

        assert_equal 302, browser.response.status
        assert_equal "/identity/emails", URI.parse(browser.response.location).path,
                     "Receipt recovery must return to the original target, not ordinary verification"
        assert_withheld("Receipt-only retry must not rewrite committed Source facts") {
          source_facts == contact.reload.attributes
        }
        assert_predicate transaction.reload, :consumed?
        assert_withheld("Retry must retain the exact bounded Email proof") {
          proof == transaction.attributes.slice(*proof.keys)
        }
        assert_equal "consumed", parent.reload.status
        assert_withheld("Original parent must consume the original Contact") {
          parent.verified_credential_ref == contact.public_id
        }
        assert_equal 1, audits.count
        assert_withheld("Retry must not rewrite the original Source audit") { audit_facts == audits.first.attributes }
        assert_withheld("Retry must retain original nonce") {
          nonce == browser.request.session.fetch("auth_admission_browser_nonce")
        }
        assert_withheld("Retry must retain original locator") {
          locator == browser.request.session.fetch("base_step_up_marker_locator")
        }
        completed_marker = BaseStepUpMarkerAdapter.new.read(
          locator:, transaction_ref: parent.transaction_id,
        )

        assert_withheld("Retry must not replace the original Root/browser marker") { marker == completed_marker }
        assert_nil token.reload.last_step_up_at
        assert_nil token.last_step_up_scope
        assert_nil token.last_step_up_credential_ref
        assert_predicate token, :currently_usable?
        assert_equal 1, contact_model.effective_binding.where(owner_key => actor.id).count
        assert_nil transaction.otp_verifier
      ensure
        ActionController::Base.allow_forgery_protection = protection
        TurnstileVerifierStub.enabled, TurnstileVerifierStub.response = previous_turnstile
        TurnstileVerifierStub.challenge_enabled, TurnstileVerifierStub.challenge_response = previous_challenge
      end
    end
  end
end
# rubocop:enable Minitest/MultipleAssertions
