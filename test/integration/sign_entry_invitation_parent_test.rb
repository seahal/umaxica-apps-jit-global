# typed: false
# frozen_string_literal: true

require "test_helper"

class SignEntryInvitationParentTest < ActionDispatch::IntegrationTest
  NAVIGATION_HEADERS = { "Sec-Fetch-Mode" => "navigate", "Sec-Fetch-Dest" => "document" }.freeze

  self.fixture_table_names = []

  test "invitation binding resolves its authorization parent before attaching on both surfaces" do
    [
      ["app", ENV.fetch("PUBLIC_AUTH_SERVICE_URL"), "core-app-jp", "client_oidc_authorization_transactions"],
      ["org", ENV.fetch("PUBLIC_AUTH_STAFF_URL"), "core-org-jp", "operator_oidc_authorization_transactions"],
    ].each do |surface, host, client_id, parent_table|
      client = OidcClientRegistry.find!(client_id)
      transaction = OidcAuthorizationTransactionCoordinator.issue!(
        surface: surface, intent: "invitation",
        params: {
          response_type: "code",
          client_id: client_id,
          redirect_uri: client.redirect_uris_by_realm.fetch(client.resource_type).first,
          code_challenge: SecureRandom.urlsafe_base64(32),
          code_challenge_method: "S256",
          scope: "openid profile",
          state: SecureRandom.urlsafe_base64(24),
          nonce: SecureRandom.urlsafe_base64(24),
        },
      ).transaction
      issuance = BaseAuthAdmissionCoordinator.issue_handoff!(
        transaction: transaction, base_browser_nonce: SecureRandom.urlsafe_base64(32), base_token: nil,
      )
      feature = FeatureFlags::REGISTRY.fetch(:"sign_in_available_#{surface}").name
      previously_enabled = Flipper.enabled?(feature)
      Flipper.enable(feature)
      host!(host)
      https!
      queries = []
      observer = ->(_name, _start, _finish, _id, payload) { queries << payload[:sql].to_s }

      ActiveSupport::Notifications.subscribed(observer, "sql.active_record") do
        get(
          "/ceremony_bindings", params: { entry_ref: issuance.reference, ri: "jp" },
                                headers: { "Sec-Fetch-Mode" => "navigate", "Sec-Fetch-Dest" => "document" },
        )
      end

      assert_response :see_other
      parent_read = queries.index { |sql| sql.match?(/\ASELECT\b/i) && sql.include?(parent_table) }
      attachment = queries.index { |sql| sql.match?(/\AUPDATE\b/i) && sql.include?("auth_admission_bindings") }

      assert_not_nil parent_read, surface
      assert_not_nil attachment, surface
      assert_operator parent_read, :<, attachment, surface
    ensure
      if feature
        previously_enabled ? Flipper.enable(feature) : Flipper.disable(feature)
      end
    end
  end

  test "a stopped invitation entry does not attach a session on either surface" do
    [
      ["app", ENV.fetch("PUBLIC_AUTH_SERVICE_URL"), "core-app-jp", ClientAuthAdmissionBinding,
       ClientAuthCeremonySession,],
      ["org", ENV.fetch("PUBLIC_AUTH_STAFF_URL"), "core-org-jp", OperatorAuthAdmissionBinding,
       OperatorAuthCeremonySession,],
    ].each do |surface, host, client_id, binding_class, session_class|
      %w(sign_in sign_up).each do |flow|
        client = OidcClientRegistry.find!(client_id)
        transaction = OidcAuthorizationTransactionCoordinator.issue!(
          surface: surface, intent: "invitation",
          params: {
            response_type: "code",
            client_id: client_id,
            redirect_uri: client.redirect_uris_by_realm.fetch(client.resource_type).first,
            code_challenge: SecureRandom.urlsafe_base64(32),
            code_challenge_method: "S256",
            scope: "openid profile",
            state: SecureRandom.urlsafe_base64(24),
            nonce: SecureRandom.urlsafe_base64(24),
            prompt: (flow == "sign_up") ? "create" : "login",
          },
        ).transaction
        issuance = BaseAuthAdmissionCoordinator.issue_handoff!(
          transaction: transaction, base_browser_nonce: SecureRandom.urlsafe_base64(32), base_token: nil,
        )
        binding = binding_class.find_by!(entry_ref: issuance.reference)
        before = binding.attributes
        feature = FeatureFlags::REGISTRY.fetch(:"#{flow}_available_#{surface}").name
        previously_enabled = Flipper.enabled?(feature)
        Flipper.disable(feature)
        host!(host)
        https!

        assert_no_difference -> { session_class.count } do
          get(
            "/ceremony_bindings", params: { entry_ref: issuance.reference, ri: "jp" },
                                  headers: { "Sec-Fetch-Mode" => "navigate", "Sec-Fetch-Dest" => "document" },
          )
        end

        assert_response :service_unavailable
        assert_equal before, binding.reload.attributes
        assert_not_includes response.headers["Set-Cookie"].to_s, "auth_sid="
      ensure
        if feature
          previously_enabled ? Flipper.enable(feature) : Flipper.disable(feature)
        end
      end
    end
  end

  test "a confirmed legacy org invitation does not become a sign-in admission" do
    feature = FeatureFlags::REGISTRY.fetch(:sign_in_available_org).name
    previously_enabled = Flipper.enabled?(feature)
    Flipper.enable(feature)
    host!(ENV.fetch("PUBLIC_AUTH_STAFF_URL"))
    https!
    client_id = "core-org-jp"
    client = OidcClientRegistry.find!(client_id)
    transaction = OidcAuthorizationTransactionCoordinator.issue!(
      surface: "org", intent: "invitation",
      params: {
        response_type: "code",
        client_id: client_id,
        redirect_uri: client.redirect_uris_by_realm.fetch(client.resource_type).first,
        code_challenge: SecureRandom.urlsafe_base64(32),
        code_challenge_method: "S256",
        scope: "openid profile",
        state: SecureRandom.urlsafe_base64(24),
        nonce: SecureRandom.urlsafe_base64(24),
      },
    ).transaction
    issuance = BaseAuthAdmissionCoordinator.issue_handoff!(
      transaction: transaction, base_browser_nonce: SecureRandom.urlsafe_base64(32), base_token: nil,
    )
    get("/sign/in", params: { entry_ref: issuance.reference, ri: "jp" }, headers: NAVIGATION_HEADERS)

    assert_response :see_other
    get(response.location, headers: NAVIGATION_HEADERS)

    assert_response :see_other
    binding = OperatorAuthAdmissionBinding.find_by!(entry_ref: issuance.reference)
    binding.confirm_base!(base_token: nil, browser_digest: binding.base_browser_digest)
    before = binding.reload.attributes
    assert_no_difference -> { OperatorAuthCeremonySession.count } do
      get("/sign/in", params: { entry_ref: issuance.reference, ri: "jp" }, headers: NAVIGATION_HEADERS)
    end

    assert_response :bad_request
    assert_equal before, binding.reload.attributes
    assert_not_includes response.headers["Set-Cookie"].to_s, "auth_sid="
  ensure
    if feature
      previously_enabled ? Flipper.enable(feature) : Flipper.disable(feature)
    end
  end
end
