# frozen_string_literal: true

require "test_helper"

class EffectiveEntryIntentTest < ActionDispatch::IntegrationTest
  %w(app com).each do |surface|
    [nil, "create"].each do |prompt|
      %i(continuation redemption).each do |phase|
        test "#{surface} #{prompt || "ordinary"} admission refuses the other intent at #{phase} without consumption" do
          protection = ActionController::Base.allow_forgery_protection
          ActionController::Base.allow_forgery_protection = true
          host, client_id, resource_type =
            case surface
            when "app" then [ENV.fetch("PUBLIC_AUTH_SERVICE_URL"), "core-app-jp", "client"]
            when "com" then [ENV.fetch("PUBLIC_AUTH_CORPORATE_URL"), "core-com-jp", "visitor"]
            end
          transaction = OidcAuthorizationTransactionCoordinator.issue!(
            surface: surface, intent: "authentication",
            params: {
              client_id: client_id,
              response_type: "code",
              scope: "openid profile",
              redirect_uri: OidcClientRegistry.find!(client_id).redirect_uris_by_realm.fetch(resource_type).first,
              state: SecureRandom.hex(16),
              nonce: SecureRandom.hex(16),
              prompt: prompt,
              code_challenge: "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM",
              code_challenge_method: "S256",
            },
          ).transaction
          issuance = BaseAuthAdmissionCoordinator.issue_handoff!(
            transaction: transaction, base_browser_nonce: SecureRandom.urlsafe_base64(32), base_token: nil,
          )
          binding = BaseAuthAdmissionCoordinator.find_admission_binding!(
            surface: surface,
            reference: issuance.reference,
          )
          valid_path = (prompt == "create") ? "/sign/up" : "/sign/in"
          wrong_path = (prompt == "create") ? "/sign/in" : "/sign/up"
          browser = open_session
          browser.host!(host)
          browser.https!
          headers = { "Origin" => "https://#{host}", "Sec-Fetch-Site" => "same-origin" }
          fields = { entry_ref: issuance.reference, ri: "jp" }

          if phase == :continuation
            before = binding.attributes
            browser.get(wrong_path, params: fields)

            assert_equal 400, browser.response.status
            assert_equal before, binding.reload.attributes
          end

          browser.get(valid_path, params: fields)

          assert_equal 200, browser.response.status
          csrf = browser.response.parsed_body.at_css('input[name="authenticity_token"]')["value"]
          fields[:authenticity_token] = csrf
          browser.post("/ceremony_bindings", params: fields, headers: headers)

          assert_equal 303, browser.response.status
          binding.reload.confirm_base!(base_token: nil, browser_digest: binding.base_browser_digest)

          if phase == :redemption
            before = binding.reload.attributes
            browser.post(wrong_path, params: fields, headers: headers)

            assert_equal 400, browser.response.status
            assert_equal before, binding.reload.attributes
            assert_not_predicate binding, :redeemed?
          end

          browser.post(valid_path, params: fields, headers: headers)

          assert_equal 303, browser.response.status
          assert_predicate binding.reload, :redeemed?

          # Once admitted, a page name or query parameter cannot reinterpret the same ceremony.
          browser.get(wrong_path, params: { ri: "jp", prompt: (prompt == "create") ? "login" : "create" })

          assert_equal 400, browser.response.status
          assert_equal "pending", transaction.reload.status
        ensure
          ActionController::Base.allow_forgery_protection = protection
        end
      end
    end
  end
end
