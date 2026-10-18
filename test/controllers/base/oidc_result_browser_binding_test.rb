# frozen_string_literal: true

require "test_helper"

class OidcResultBrowserBindingTest < ActionDispatch::IntegrationTest
  test "an authenticated OIDC result cannot establish a root in a different Base browser in any realm" do
    protection = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    [
      ["app", "core-app-jp", "client", ENV.fetch("PUBLIC_BASE_SERVICE_URL"),
       ENV.fetch("PUBLIC_AUTH_SERVICE_URL"), Client, ClientToken,],
      ["com", "core-com-jp", "visitor", ENV.fetch("PUBLIC_BASE_CORPORATE_URL"),
       ENV.fetch("PUBLIC_AUTH_CORPORATE_URL"), Visitor, VisitorToken,],
      ["org", "core-org-jp", "operator", ENV.fetch("PUBLIC_BASE_STAFF_URL"),
       ENV.fetch("PUBLIC_AUTH_STAFF_URL"), Operator, OperatorToken,],
    ].each do |surface, client_id, realm, base_host, auth_host, actor_model, token_model|
      parameters = {
        response_type: "code",
        client_id:,
        redirect_uri: OidcClientRegistry.find!(client_id).redirect_uris_by_realm.fetch(realm).first,
        code_challenge: "a" * 43,
        code_challenge_method: "S256",
        scope: "openid",
        state: SecureRandom.urlsafe_base64(32),
        nonce: SecureRandom.urlsafe_base64(32),
        ri: "jp",
      }
      owner = open_session
      owner.host!(base_host)
      owner.https!
      owner.get("/oauth/authorize", params: parameters)
      form = owner.response.parsed_body.at_css("form")
      csrf = form.at_css('input[name="authenticity_token"]')["value"]
      headers = { "Origin" => "https://#{base_host}", "Sec-Fetch-Site" => "same-origin" }
      owner.post(
        "/oauth/authorize", params: parameters.merge(ceremony_action: "start", authenticity_token: csrf),
                            headers:,
      )
      begin
        fv5006 = owner
        fv5008 = JitSessionCookieConfig.cookie_key(force_secure: JitSessionCookieConfig.force_secure?)
        fv5007 = fv5006.response.cookies[fv5008]
        if fv5007.nil?
          fv5011 = fv5006.response.headers["Set-Cookie"] || fv5006.response.headers["set-cookie"]
          fv5010 =
            if fv5011.is_a?(String) && fv5011.start_with?("[")
              JSON.parse(fv5011)
            else
              Array(fv5011)
            end
          fv5009 =
            fv5010.flat_map { |entry| entry.to_s.split("\n") }.find do |entry|
              entry.split(";", 2).first.to_s.start_with?("#{fv5008}=")
            end
          if fv5009

            _, fv5007 = fv5009.split(";", 2).first.to_s.split("=", 2)
            fv5007 = Rack::Utils.unescape(fv5007.to_s)
          end
        end

        unless fv5007.nil?
          fv5006.cookies.delete(fv5008)
          # Rack::Test's []= uses its default host. The current request may target a
          # different surface, so install the cookie against the browser's active host.
          fv5006.cookies.merge(
            "#{fv5008}=#{Rack::Utils.escape(fv5007)}",
            URI.parse("https://#{fv5006.host}/"),
          )
        end
      end
      parent = OidcAuthorizationTransactionCoordinator.model_for(surface).find_by!(state: parameters.fetch(:state))
      binding = BaseAuthAdmissionCoordinator.admission_binding_model(surface).find_by!(
        authorization_transaction_id: parent.id,
      )
      auth = open_session
      auth.host!(auth_host)
      auth.https!
      auth_headers = { "Origin" => "https://#{auth_host}", "Sec-Fetch-Site" => "same-origin" }
      auth.get("/sign/in", params: { entry_ref: binding.entry_ref, ri: "jp" })
      csrf = auth.response.parsed_body.at_css('input[name="authenticity_token"]')["value"]
      other_auth = open_session
      other_auth.host!(auth_host)
      other_auth.https!
      other_auth.get("/sign/in", params: { entry_ref: binding.entry_ref, ri: "jp" })
      other_csrf = other_auth.response.parsed_body.at_css('input[name="authenticity_token"]')["value"]
      auth.post(
        "/ceremony_bindings", params: { entry_ref: binding.entry_ref, ri: "jp", authenticity_token: csrf },
                              headers: auth_headers,
      )
      attached_session_id = binding.reload.auth_ceremony_session_id
      other_auth.post(
        "/ceremony_bindings",
        params: { entry_ref: binding.entry_ref, ri: "jp", authenticity_token: other_csrf },
        headers: auth_headers,
      )

      assert_equal [400, nil, attached_session_id],
                   [other_auth.response.status, other_auth.response.location,
                    binding.reload.auth_ceremony_session_id,]
      confirmation = URI.parse(auth.response.location)
      other_base = open_session
      other_base.host!(base_host)
      other_base.https!
      other_base.get("/oauth/authorize", params: parameters)
      other_base_csrf = other_base.response.parsed_body.at_css('input[name="authenticity_token"]')["value"]
      other_base.post(confirmation.request_uri, params: { authenticity_token: other_base_csrf }, headers:)

      assert_equal [400, nil, nil],
                   [other_base.response.status, other_base.response.location, binding.reload.base_confirmed_at]
      owner.get(confirmation.request_uri)
      csrf = owner.response.parsed_body.at_css('input[name="authenticity_token"]')["value"]
      owner.post(confirmation.request_uri, params: { authenticity_token: csrf }, headers:)
      entry = URI.parse(owner.response.location)
      other_auth.post(
        "/sign/in",
        params: { entry_ref: binding.entry_ref, ri: "jp", authenticity_token: other_csrf },
        headers: auth_headers,
      )

      assert_equal [400, nil, nil],
                   [other_auth.response.status, other_auth.response.location, binding.reload.redeemed_at]
      auth.get(entry.request_uri)
      csrf = auth.response.parsed_body.at_css('input[name="authenticity_token"]')["value"]
      auth.post(
        "/sign/in", params: { entry_ref: binding.entry_ref, ri: "jp", authenticity_token: csrf },
                    headers: auth_headers,
      )

      assert_predicate binding.reload, :redeemed?

      # Public Auth proof issuance isolates result-receiver browser binding from credential verification.
      actor = actor_model.create!
      result = BaseAuthAdmissionCoordinator.register_result_and_issue!(
        surface:, login_challenge: parent.login_challenge, actor:, session_ref: "ceremony-result",
        auth_method: "passkey", authentication_event_at: parent.class.database_now,
        ceremony_session_ref: binding.admitted_auth_ceremony_session_id.to_s,
      )
      foreign = open_session
      foreign.host!(base_host)
      foreign.https!
      foreign.get("/oauth/authorize", params: parameters)
      csrf = foreign.response.parsed_body.at_css('input[name="authenticity_token"]')["value"]
      foreign.post(
        "/oauth/authorize", params: { result_ref: result.reference,
                                      transaction_ref: parent.transaction_id,
                                      authenticity_token: csrf,
                                      ri: "jp", }, headers:,
      )

      assert_equal [400, nil, nil],
                   [foreign.response.status, foreign.response.location, parent.reload.base_finalized_at]
      assert_equal 0, token_model.where(
        { "app" => :user_id, "com" => :visitor_id, "org" => :staff_id }.fetch(surface) => actor.id,
      ).count
      owner.get(
        "/oauth/authorize",
        params: { result_ref: result.reference, transaction_ref: parent.transaction_id, ri: "jp" },
      )
      csrf = owner.response.parsed_body.at_css('input[name="authenticity_token"]')["value"]
      submission = { result_ref: result.reference,
                     transaction_ref: parent.transaction_id,
                     ri: "jp",
                     authenticity_token: csrf, }
      owner.post("/oauth/authorize", params: submission, headers:)

      assert_equal 303, owner.response.status
      assert_predicate parent.reload.base_finalized_at, :present?
      finalized_root = parent.browser_session_ref
      begin
        fv5000 = owner
        fv5002 = JitSessionCookieConfig.cookie_key(force_secure: JitSessionCookieConfig.force_secure?)
        fv5001 = fv5000.response.cookies[fv5002]
        if fv5001.nil?
          fv5005 = fv5000.response.headers["Set-Cookie"] || fv5000.response.headers["set-cookie"]
          fv5004 =
            if fv5005.is_a?(String) && fv5005.start_with?("[")
              JSON.parse(fv5005)
            else
              Array(fv5005)
            end
          fv5003 =
            fv5004.flat_map { |cookie_entry| cookie_entry.to_s.split("\n") }.find do |cookie_entry|
              cookie_entry.split(";", 2).first.to_s.start_with?("#{fv5002}=")
            end
          if fv5003

            _, fv5001 = fv5003.split(";", 2).first.to_s.split("=", 2)
            fv5001 = Rack::Utils.unescape(fv5001.to_s)
          end
        end

        unless fv5001.nil?
          fv5000.cookies.delete(fv5002)
          # Rack::Test's []= uses its default host. The current request may target a
          # different surface, so install the cookie against the browser's active host.
          fv5000.cookies.merge(
            "#{fv5002}=#{Rack::Utils.escape(fv5001)}",
            URI.parse("https://#{fv5000.host}/"),
          )
        end
      end
      owner.get("/")
      csrf = owner.response.parsed_body.at_css('meta[name="csrf-token"]')["content"]
      owner.post("/oauth/authorize", params: submission.merge(authenticity_token: csrf), headers:)

      assert_equal 303, owner.response.status
      assert_equal finalized_root, parent.reload.browser_session_ref
    end
  ensure
    ActionController::Base.allow_forgery_protection = protection
  end
end
