# frozen_string_literal: true

require "test_helper"

class OidcResultBrowserBindingTest < ActionDispatch::IntegrationTest
  test "an authenticated OIDC result cannot establish a root in a different Base browser in any realm" do
    protection = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    [
      ["app", "core-app", "client", ENV.fetch("PUBLIC_BASE_SERVICE_URL"),
       ENV.fetch("PUBLIC_AUTH_SERVICE_URL"), Client, ClientToken,],
      ["com", "core-com", "visitor", ENV.fetch("PUBLIC_BASE_CORPORATE_URL"),
       ENV.fetch("PUBLIC_AUTH_CORPORATE_URL"), Visitor, VisitorToken,],
      ["org", "core-org", "operator", ENV.fetch("PUBLIC_BASE_STAFF_URL"),
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
      sync_response_cookie!(
        owner,
        JitSessionCookieConfig.cookie_key(force_secure: JitSessionCookieConfig.force_secure?),
      )
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
      auth.post(
        "/ceremony_bindings", params: { entry_ref: binding.entry_ref, ri: "jp", authenticity_token: csrf },
                              headers: auth_headers,
      )
      confirmation = URI.parse(auth.response.location)
      owner.get(confirmation.request_uri)
      csrf = owner.response.parsed_body.at_css('input[name="authenticity_token"]')["value"]
      owner.post(confirmation.request_uri, params: { authenticity_token: csrf }, headers:)
      entry = URI.parse(owner.response.location)
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

      assert_equal 302, owner.response.status
      assert_predicate parent.reload.base_finalized_at, :present?
      finalized_root = parent.browser_session_ref
      sync_response_cookie!(
        owner,
        JitSessionCookieConfig.cookie_key(force_secure: JitSessionCookieConfig.force_secure?),
      )
      owner.post("/oauth/authorize", params: submission, headers:)

      assert_equal 302, owner.response.status
      assert_equal finalized_root, parent.reload.browser_session_ref
    end
  ensure
    ActionController::Base.allow_forgery_protection = protection
  end
end
