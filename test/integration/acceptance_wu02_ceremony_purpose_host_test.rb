# typed: false
# frozen_string_literal: true

require "test_helper"

class AcceptanceWu02CeremonyPurposeHostTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  test "A02-9: Base refuses Sign-in path bindings before changing their binding, ceremony, or transaction" do
    realms = [
      ["app", "PUBLIC_BASE_SERVICE_URL", "core-app-jp", ClientOidcAuthorizationTransaction,
       ClientAuthAdmissionBinding, ClientAuthCeremonySession],
      ["com", "PUBLIC_BASE_CORPORATE_URL", "core-com-jp", VisitorOidcAuthorizationTransaction,
       VisitorAuthAdmissionBinding, VisitorAuthCeremonySession],
      ["org", "PUBLIC_BASE_STAFF_URL", "core-org-jp", OperatorOidcAuthorizationTransaction,
       OperatorAuthAdmissionBinding, OperatorAuthCeremonySession],
    ]

    realms.each do |surface, base_host_key, client_id, transaction_model, binding_model, session_model|
      client = OidcClientRegistry.find!(client_id)
      transaction = OidcAuthorizationTransactionCoordinator.issue!(
        surface: surface,
        intent: "sign_in",
        params: {
          response_type: "code",
          client_id: client_id,
          redirect_uri: client.redirect_uris_by_realm.fetch(client.resource_type).first,
          code_challenge: SecureRandom.urlsafe_base64(32),
          code_challenge_method: "S256",
          scope: "openid",
          state: SecureRandom.urlsafe_base64(24),
          nonce: SecureRandom.urlsafe_base64(24),
        },
      ).transaction
      issuance = BaseAuthAdmissionCoordinator.issue_handoff!(
        transaction: transaction,
        base_browser_nonce: SecureRandom.urlsafe_base64(32),
        base_token: nil,
      )
      binding = BaseAuthAdmissionCoordinator.find_admission_binding!(surface: surface, reference: issuance.reference)
      continuity, = session_model.issue!
      binding.attach_auth_session!(auth_session: continuity, confirmation_ref: SecureRandom.uuid)
      before = [binding.reload.attributes, continuity.reload.attributes, transaction_model.find(transaction.id).attributes]
      base_browser = open_session
      base_browser.https!
      base_browser.host!(ENV.fetch(base_host_key))
      base_browser.get(
        "/ceremony_bindings/#{binding.confirmation_ref}/confirmation?ri=jp",
        headers: { "Sec-Fetch-Mode" => "navigate", "Sec-Fetch-Dest" => "document" },
      )

      assert_equal [400, nil], [base_browser.response.status, base_browser.response.location], surface
      assert_equal before,
                   [binding.reload.attributes, continuity.reload.attributes,
                    transaction_model.find(transaction.id).attributes,],
                   "Base #{surface} must refuse a Sign-in path binding without changing any parent state"
    end
  end

  test "A02-9: Visa refuses Re-verification bindings before changing their binding, ceremony, or transaction" do
    realms = [
      ["app", "PUBLIC_VISA_SERVICE_URL", Client, ClientToken, ClientAuthAdmissionBinding,
       ClientAuthCeremonySession, "client", ClientStepUpCeremonyTransaction],
      ["com", "PUBLIC_VISA_CORPORATE_URL", Visitor, VisitorToken, VisitorAuthAdmissionBinding,
       VisitorAuthCeremonySession, "visitor", VisitorStepUpCeremonyTransaction],
      ["org", "PUBLIC_VISA_STAFF_URL", Operator, OperatorToken, OperatorAuthAdmissionBinding,
       OperatorAuthCeremonySession, "operator", OperatorStepUpCeremonyTransaction],
    ]

    realms.each do |surface, visa_host_key, actor_class, token_class, binding_class, session_class,
                   resource_type, transaction_class|
      actor_attributes = { security_mode_id: SecurityModeTestDefault.id_for(actor_class) }
      actor_attributes[:status_id] =
        case surface
        when "app" then ClientStatus::ACTIVE
        when "com" then VisitorStatus::ACTIVE
        when "org" then OperatorStatus::ACTIVE
        else raise ArgumentError, "unsupported surface: #{surface.inspect}"
        end if surface != "org"
      actor = actor_class.create!(actor_attributes)
      token =
        case surface
        when "app" then token_class.create!(authentication_epoch: 0, user: actor)
        when "com" then token_class.create!(authentication_epoch: 0, visitor: actor)
        when "org" then token_class.create!(authentication_epoch: 0, staff: actor)
        else raise ArgumentError, "unsupported surface: #{surface.inspect}"
        end
      requirement = StepUpRequirement.new(
        scope: "settings_passkey",
        purpose: "reauthentication",
        step_up_required: true,
        allowed_methods: [:passkey],
        phishing_resistant_required: true,
        user_verification_required: true,
        full_reauthentication_required: true,
        audience: "step_up:#{surface}",
        session_binding: token.public_id,
        token_binding: token.public_id,
        require_session_binding: true,
        ttl: 15.minutes,
        actor_ref: actor.public_id,
        resource_ref: nil,
        tenant_ref: nil,
      )
      issuance = BaseStepUpAdmissionIssuer.call!(
        actor: actor,
        token: token,
        requirement: requirement,
        return_to: "/identity/passkeys",
        base_browser_nonce: SecureRandom.urlsafe_base64(32),
        base_token: token,
      )
      binding = binding_class.find_by!(entry_ref: issuance.reference)
      continuity, = session_class.issue!
      binding.attach_auth_session!(auth_session: continuity, confirmation_ref: SecureRandom.uuid)
      before = [binding.reload.attributes, continuity.reload.attributes, transaction_class.find(issuance.transaction.id).attributes]
      visa_browser = open_session
      visa_browser.https!
      visa_browser.host!(ENV.fetch(visa_host_key))
      visa_browser.get(
        "/ceremony_bindings/#{binding.confirmation_ref}/confirmation?ri=jp",
        headers: { "Sec-Fetch-Mode" => "navigate", "Sec-Fetch-Dest" => "document" },
      )

      assert_equal [400, nil], [visa_browser.response.status, visa_browser.response.location], resource_type
      assert_equal before,
                   [binding.reload.attributes, continuity.reload.attributes,
                    transaction_class.find(issuance.transaction.id).attributes,],
                   "Visa #{surface} must refuse a Re-verification binding without changing any parent state"
    end
  end
end
