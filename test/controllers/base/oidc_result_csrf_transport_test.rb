# frozen_string_literal: true

require "test_helper"

class OidcResultCsrfTransportTest < ActionDispatch::IntegrationTest
  %w(app com org).each do |surface|
    # One admitted result spans refusals, success and replay to prove refusals never consume it.
    test "#{surface} Visa result requires a browser navigation and legacy POST cannot issue a root" do # rubocop:disable Minitest/MultipleAssertions
      protection = ActionController::Base.allow_forgery_protection
      ActionController::Base.allow_forgery_protection = true
      client_id, realm, visa_host, auth_host, actor_model, token_model, owner_key, active_status =
        case surface
        when "app"
          ["core-app-jp", "client", ENV.fetch("PUBLIC_VISA_SERVICE_URL"), ENV.fetch("PUBLIC_AUTH_SERVICE_URL"), Client,
           ClientToken, :user_id, ClientStatus::ACTIVE,]
        when "com"
          ["core-com-jp", "visitor", ENV.fetch("PUBLIC_VISA_CORPORATE_URL"), ENV.fetch("PUBLIC_AUTH_CORPORATE_URL"),
           Visitor, VisitorToken, :visitor_id, VisitorStatus::ACTIVE,]
        when "org"
          ["core-org-jp", "operator", ENV.fetch("PUBLIC_VISA_STAFF_URL"), ENV.fetch("PUBLIC_AUTH_STAFF_URL"), Operator,
           OperatorToken, :staff_id, OperatorStatus::ACTIVE,]
        end
      navigation = { "Sec-Fetch-Mode" => "navigate", "Sec-Fetch-Dest" => "document", "Sec-Fetch-Site" => "cross-site" }
      parameters = {
        response_type: "code",
        client_id:,
        redirect_uri: OidcClientRegistry.find!(client_id).redirect_uris_by_realm.fetch(realm).first,
        code_challenge: "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM",
        code_challenge_method: "S256",
        scope: "openid",
        state: SecureRandom.urlsafe_base64(32),
        nonce: SecureRandom.urlsafe_base64(32),
        ri: "jp",
      }
      owner = open_session
      owner.host!(visa_host)
      owner.https!
      owner.get("/oauth/authorize", params: parameters, headers: navigation)

      assert_equal 303, owner.response.status
      parent = OidcAuthorizationTransactionCoordinator.model_for(surface).find_by!(state: parameters.fetch(:state))
      binding = BaseAuthAdmissionCoordinator.admission_binding_model(surface).find_by!(
        authorization_transaction_id: parent.id,
      )
      auth = open_session
      auth.host!(auth_host)
      auth.https!
      current_browser = owner
      current_host = visa_host
      confirmation = nil
      jump_host = URI.parse(Rails.configuration.x.boot_config.fetch(:jump).origin.to_s).host
      12.times do
        target = URI.parse(current_browser.response.location.to_s)
        target = URI.parse("https://#{current_host}#{target}") unless target.host
        if target.host == jump_host
          namespace = (current_host == visa_host) ? "VISA_#{surface.upcase}" : "AUTH_#{surface.upcase}"
          issuer = JitSecurityJwtRegistry.surface(namespace)
          payload, = JWT.decode(
            Rack::Utils.parse_query(target.query).fetch("rt"),
            JitSecurityJwtRegistry.public_key_for(issuer.id, issuer.current_kid), true,
            algorithms: ["ES384"], verify_iss: true, iss: "https://#{current_host}",
            verify_aud: true, aud: Rails.configuration.x.boot_config.fetch(:jump).audience,
          )
          target = URI.parse(payload.fetch("url"))
        end

        assert_includes [visa_host, auth_host], target.host
        if target.host == visa_host
          confirmation = target
          break
        end
        auth.get(target.request_uri, headers: navigation)

        assert_equal 303, auth.response.status
        current_browser = auth
        current_host = auth_host
      end

      assert confirmation
      assert_predicate binding.reload, :attached?
      owner.get(confirmation.request_uri, headers: navigation)

      assert_equal 303, owner.response.status
      assert_predicate binding.reload, :confirmed?
      auth.get(URI.parse(owner.response.location).request_uri, headers: navigation)

      assert_equal 303, auth.response.status
      assert_predicate binding.reload, :redeemed?
      auth.get(URI.parse(auth.response.location).request_uri, headers: navigation)

      assert_equal 200, auth.response.status

      # Public Auth proof issuance isolates the OP receiver from credential verification.
      actor = actor_model.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: active_status)
      result = BaseAuthAdmissionCoordinator.register_result_and_issue!(
        surface:, login_challenge: parent.login_challenge, actor:, session_ref: "ceremony-result",
        auth_method: "passkey", authentication_event_at: parent.class.database_now,
        ceremony_session_ref: binding.admitted_auth_ceremony_session_id.to_s,
      )
      submission = { result_ref: result.reference, transaction_ref: parent.transaction_id, ri: "jp" }
      before_parent = parent.reload.attributes
      before_binding = binding.reload.attributes
      tokens_before = token_model.where(owner_key => actor.id).count

      ceremony = binding.class.auth_admission_session_class.find(binding.admitted_auth_ceremony_session_id)
      before_ceremony = ceremony.attributes
      owner.post(
        "/oauth/authorize", params: submission, headers: {
          "Origin" => "https://#{visa_host}", "Sec-Fetch-Site" => nil,
        },
      )

      assert_equal 422, owner.response.status
      parent_unchanged = before_parent == parent.reload.attributes

      assert parent_unchanged, "CSRF refusal changed the parent"
      binding_unchanged = before_binding == binding.reload.attributes

      assert binding_unchanged, "CSRF refusal changed the binding"
      ceremony_unchanged = before_ceremony == ceremony.reload.attributes

      assert ceremony_unchanged, "CSRF refusal changed Auth authority"
      assert_equal tokens_before, token_model.where(owner_key => actor.id).count

      [{}, { "Sec-Fetch-Mode" => "cors", "Sec-Fetch-Dest" => "empty" }].each do |metadata|
        owner.get("/oidc/result", params: submission, headers: metadata)

        assert_equal 400, owner.response.status
        assert_nil owner.response.location
        parent_unchanged = before_parent == parent.reload.attributes

        assert parent_unchanged, "non-navigation GET changed the parent"
        binding_unchanged = before_binding == binding.reload.attributes

        assert binding_unchanged, "non-navigation GET changed the binding"
        assert_equal tokens_before, token_model.where(owner_key => actor.id).count
      end
      owner.head("/oidc/result", params: submission, headers: navigation)

      assert_equal 400, owner.response.status
      assert_empty owner.response.body
      parent_unchanged = before_parent == parent.reload.attributes

      assert parent_unchanged, "HEAD changed the parent"
      assert_equal tokens_before, token_model.where(owner_key => actor.id).count

      owner.get("/oidc/result", params: submission, headers: navigation)

      assert_equal 303, owner.response.status
      assert_includes owner.response.headers.fetch("Cache-Control"), "no-store"
      assert_equal "no-referrer", owner.response.headers.fetch("Referrer-Policy")
      assert_predicate parent.reload.base_finalized_at, :present?
      assert_equal tokens_before + 1, token_model.where(owner_key => actor.id).count
      finalized_root = parent.browser_session_ref
      owner.get("/oidc/result", params: submission, headers: navigation)

      assert_equal 400, owner.response.status
      assert_equal finalized_root, parent.reload.browser_session_ref
      assert_equal tokens_before + 1, token_model.where(owner_key => actor.id).count
    ensure
      ActionController::Base.allow_forgery_protection = protection
    end
  end
end
