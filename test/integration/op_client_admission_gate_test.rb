# frozen_string_literal: true

require "test_helper"

# R5-WU19: a Base OP role process refuses Code and token issuance to a client that is not admitted
# at the current contract epoch; the shared transitional role does not consult admission.
class OpClientAdmissionGateTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  setup do
    host!(ENV.fetch("PUBLIC_BASE_SERVICE_URL"))
    https!
  end

  test "the OP role refuses the token endpoint for a client that is not admitted" do
    with_runtime_role("op-base-app") { post_token("core-app-jp") }

    assert_response :bad_request
    assert_equal "unauthorized_client", response.parsed_body.fetch("error")
  end

  test "the OP role refuses the authorization endpoint for a client that is not admitted" do
    with_runtime_role("op-base-app") do
      get "/oauth/authorize", params: valid_authorize_params("core-app-jp")
    end

    assert_response :bad_request
    assert_equal "unauthorized_client", response.parsed_body.fetch("error")
  end

  test "an admitted client passes the gate and reaches ordinary token validation" do
    OpClientActivationWriter.call(
      client_id: "core-app-jp", enabled: true, actor_ref: "operator-1", audit_ref: "audit-1",
      source_manifest_digest: "b" * 64,
    )
    with_runtime_role("op-base-app") { post_token("core-app-jp") }

    assert_not_equal "unauthorized_client", response.parsed_body["error"]
  end

  test "the shared transitional role does not consult admission" do
    with_runtime_role(RuntimeRole::SHARED) { post_token("core-app-jp") }

    assert_not_equal "unauthorized_client", response.parsed_body["error"]
  end

  private

  def post_token(client_id)
    post("/oauth/token", params: { grant_type: "authorization_code", client_id:, code: "nope", redirect_uri: "x" })
  end

  # A request that passes ordinary validation, so only admission can refuse it.
  def valid_authorize_params(client_id)
    {
      client_id:,
      response_type: "code",
      scope: "openid",
      state: SecureRandom.hex(16),
      nonce: SecureRandom.hex(16),
      redirect_uri: OidcClientRegistry.find!(client_id).redirect_uris.first,
      code_challenge_method: "S256",
      code_challenge: Base64.urlsafe_encode64(Digest::SHA256.digest("v" * 48), padding: false),
      ri: "jp",
    }
  end

  def with_runtime_role(name)
    previous = ENV["UMAXICA_RUNTIME_ROLE"]
    ENV["UMAXICA_RUNTIME_ROLE"] = name
    yield
  ensure
    ENV["UMAXICA_RUNTIME_ROLE"] = previous
  end
end
