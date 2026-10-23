# frozen_string_literal: true

# A ceremony admission under an OIDC authorization transaction, the only surviving entry after the
# Local Sign-in Flow was removed (D-60, WU-01). Tests that need an admitted Auth ceremony start here
# instead of the retired `issue_local_entry!`. It returns the admission issuance (`reference`,
# `code`, `transaction` = the OIDC authorization transaction).
module OidcTestEntry
  module_function

  CLIENTS = {
    "app" => ["core-app-jp", "client"],
    "com" => ["core-com-jp", "visitor"],
    "org" => ["core-org-jp", "operator"],
  }.freeze
  CODE_CHALLENGE = "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM"

  def issue!(surface:, intent:, base_browser_nonce:, base_token:)
    client_id, realm = CLIENTS.fetch(surface.to_s)
    params = {
      client_id:,
      response_type: "code",
      scope: "openid profile",
      redirect_uri: OidcClientRegistry.find!(client_id).redirect_uris_by_realm.fetch(realm).first,
      state: SecureRandom.hex(8),
      nonce: SecureRandom.hex(8),
      code_challenge: CODE_CHALLENGE,
      code_challenge_method: "S256",
      prompt: (intent.to_s == "sign_up") ? "create" : nil,
    }
    oidc_intent = (intent.to_s == "sign_up") ? "sign_up" : "sign_in"
    transaction = OidcAuthorizationTransactionCoordinator.issue!(surface:, intent: oidc_intent, params:).transaction
    BaseAuthAdmissionCoordinator.issue_handoff!(transaction:, base_browser_nonce:, base_token:)
  end
end
