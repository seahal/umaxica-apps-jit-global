# frozen_string_literal: true

require "test_helper"

# Boolean snapshots keep retained proof and cookie material out of assertion output.
class OidcResultCsrfTransportTest < ActionDispatch::IntegrationTest
  %w(app com org).each do |surface|
    test "#{surface} genuine OIDC result requires missing-header CSRF fallback and finalizes one root" do
      previous_protection = ActionController::Base.allow_forgery_protection
      ActionController::Base.allow_forgery_protection = true
      base_host, auth_host, client_id, realm, actor_model, token_model, owner_key =
        case surface
        when "app"
          [ENV.fetch("PUBLIC_BASE_SERVICE_URL"), ENV.fetch("PUBLIC_AUTH_SERVICE_URL"),
           "core-app", "client", Client, ClientToken, :user_id,]
        when "com"
          [ENV.fetch("PUBLIC_BASE_CORPORATE_URL"), ENV.fetch("PUBLIC_AUTH_CORPORATE_URL"),
           "core-com", "visitor", Visitor, VisitorToken, :visitor_id,]
        when "org"
          [ENV.fetch("PUBLIC_BASE_STAFF_URL"), ENV.fetch("PUBLIC_AUTH_STAFF_URL"),
           "core-org", "operator", Operator, OperatorToken, :staff_id,]
        end
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
      base_headers = { "Origin" => "https://#{base_host}", "Sec-Fetch-Site" => "same-origin" }
      owner.get("/oauth/authorize", params: parameters)
      csrf = owner.response.parsed_body.at_css('input[name="authenticity_token"]')["value"]
      owner.post(
        "/oauth/authorize", params: parameters.merge(ceremony_action: "start", authenticity_token: csrf),
                            headers: base_headers,
      )

      assert_equal 303, owner.response.status
      # Normalize Rack::Test's encoded multi-value Set-Cookie representation using
      # public response/CookieJar APIs, without synthesizing a browser session.
      cookie_name = JitSessionCookieConfig.cookie_key(force_secure: JitSessionCookieConfig.force_secure?)
      cookie_value = owner.response.cookies[cookie_name]
      if cookie_value.nil?
        raw = owner.response.headers["Set-Cookie"] || owner.response.headers["set-cookie"]
        lines = (raw.is_a?(String) && raw.start_with?("[")) ? JSON.parse(raw) : Array(raw)
        line =
          lines.flat_map { |entry| entry.to_s.split("\n") }.find do |entry|
            entry.split(";", 2).first.start_with?("#{cookie_name}=")
          end

        assert_withheld("expected the actual Base session Set-Cookie") { line.present? }
        cookie_value = Rack::Utils.unescape(line.split(";", 2).first.split("=", 2).last)
      end
      owner.cookies.delete(cookie_name)
      _received_cookie = owner.cookies.merge(
        "#{cookie_name}=#{Rack::Utils.escape(cookie_value)}", URI.parse("https://#{base_host}/"),
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

      assert_equal 303, auth.response.status
      confirmation = URI.parse(auth.response.location)
      owner.get(confirmation.request_uri)
      csrf = owner.response.parsed_body.at_css('input[name="authenticity_token"]')["value"]
      owner.post(confirmation.request_uri, params: { authenticity_token: csrf }, headers: base_headers)

      assert_equal 303, owner.response.status
      auth.get(URI.parse(owner.response.location).request_uri)
      csrf = auth.response.parsed_body.at_css('input[name="authenticity_token"]')["value"]
      auth.post(
        "/sign/in", params: { entry_ref: binding.entry_ref, ri: "jp", authenticity_token: csrf },
                    headers: auth_headers,
      )

      assert_equal 303, auth.response.status
      assert_withheld { binding.reload.redeemed? }
      # Real public proof issuance isolates receiver CSRF from credential verification;
      # neither admission nor opaque result verification/finalization is mocked.
      actor = actor_model.create!(id: SecureRandom.random_number(1 << 60))
      result = BaseAuthAdmissionCoordinator.register_result_and_issue!(
        surface:, login_challenge: parent.login_challenge, actor:, session_ref: "ceremony-result",
        auth_method: "passkey", authentication_event_at: parent.class.database_now,
        ceremony_session_ref: binding.admitted_auth_ceremony_session_id.to_s,
      )
      ceremony = binding.class.auth_admission_session_class.find(binding.admitted_auth_ceremony_session_id)
      before_parent = parent.reload.attributes
      before_binding = binding.reload.attributes
      before_ceremony = ceremony.reload.attributes
      submission = { result_ref: result.reference, transaction_ref: parent.transaction_id, ri: "jp" }
      # Explicit nil opts out of the repository's automatic same-origin metadata.
      owner.post(
        "/oauth/authorize", params: submission, headers: {
          "Origin" => "https://#{base_host}", "Sec-Fetch-Site" => nil,
        },
      )

      # The pinned Rails header_or_legacy_token strategy uses a token when Fetch
      # Metadata is absent; a genuine result is not a replacement for that token.
      assert_nil owner.request.headers["Sec-Fetch-Site"]
      assert_equal "https://#{base_host}", owner.request.headers["Origin"]
      assert_equal 422, owner.response.status
      assert_nil owner.response.location
      assert_withheld("CSRF refusal must leave the parent unchanged") { before_parent == parent.reload.attributes }
      assert_withheld("CSRF refusal must leave the binding unchanged") { before_binding == binding.reload.attributes }
      assert_withheld("CSRF refusal must leave Auth authority unchanged") {
        before_ceremony == ceremony.reload.attributes
      }
      assert_equal 0, token_model.where(owner_key => actor.id).count
      root_reference = nil
      2.times do |attempt|
        owner.get("/oauth/authorize", params: submission)

        assert_equal 200, owner.response.status
        csrf = owner.response.parsed_body.at_css('input[name="authenticity_token"]')["value"]
        # Deliberately omit both Origin and Fetch Metadata, including on the retry.
        # Obtain a fresh owner-local token after the successful session rotation.
        owner.post(
          "/oauth/authorize", params: submission.merge(authenticity_token: csrf), headers: {
            "Origin" => nil, "Sec-Fetch-Site" => nil,
          },
        )

        assert_nil owner.request.headers["Sec-Fetch-Site"]
        assert_nil owner.request.headers["Origin"]
        assert_equal 303, owner.response.status
        assert_withheld { parent.reload.base_finalized_at.present? }
        root_reference ||= parent.browser_session_ref

        assert_equal root_reference, parent.browser_session_ref
        assert_equal 1, token_model.where(owner_key => actor.id).count
        # Only the first success rotates the browser session. No new Set-Cookie
        # is required on the exact replay, and no request follows that replay.
        next unless attempt.zero?

        cookie_value = owner.response.cookies[cookie_name]
        if cookie_value.nil?
          raw = owner.response.headers["Set-Cookie"] || owner.response.headers["set-cookie"]
          lines = (raw.is_a?(String) && raw.start_with?("[")) ? JSON.parse(raw) : Array(raw)
          line =
            lines.flat_map { |entry| entry.to_s.split("\n") }.find do |entry|
              entry.split(";", 2).first.start_with?("#{cookie_name}=")
            end

          assert_withheld("expected the actual finalized Base session Set-Cookie") { line.present? }
          cookie_value = Rack::Utils.unescape(line.split(";", 2).first.split("=", 2).last)
        end
        owner.cookies.delete(cookie_name)
        _received_cookie = owner.cookies.merge(
          "#{cookie_name}=#{Rack::Utils.escape(cookie_value)}", URI.parse("https://#{base_host}/"),
        )
      end
    ensure
      ActionController::Base.allow_forgery_protection = previous_protection
    end
  end
end
