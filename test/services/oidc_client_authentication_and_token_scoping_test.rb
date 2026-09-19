# typed: false
# frozen_string_literal: true

require "test_helper"
require "ostruct"

# How a relying party authenticates to the token endpoint, and which surface's
# tables an exchanged token is written into. Both pick per input, and both would
# be wrong in a way nothing else notices: a client that should present a signed
# assertion falling back to a shared secret, or one surface's token usage row
# being written into another surface's table.
class OidcClientAuthenticationAndTokenScopingTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  def token_client(client_id:, client_assertion: nil, client_secret: "shared-secret")
    OidcRpTokenClient.new(
      token_url: "https://id.example.test/oauth/token",
      client_id: client_id,
      client_secret: client_secret,
      client_assertion: client_assertion,
      code: "auth-code",
      redirect_uri: "https://rp.example.test/callback",
      code_verifier: "verifier",
    )
  end

  test "a caller-supplied assertion is presented instead of the shared secret" do
    params = token_client(client_id: "rp-1", client_assertion: "signed.assertion").send(:request_params)

    assert_equal "signed.assertion", params.fetch(:client_assertion)
    assert_equal OidcRpTokenClient::CLIENT_ASSERTION_TYPE, params.fetch(:client_assertion_type)
    assert_not params.key?(:client_secret), "an assertion replaces the secret rather than accompanying it"
  end

  test "a client with no assertion and no private-key registration falls back to the shared secret" do
    params = token_client(client_id: "not-a-registered-client").send(:request_params)

    assert_equal "shared-secret", params.fetch(:client_secret)
    assert_not params.key?(:client_assertion)
    assert_equal "authorization_code", params.fetch(:grant_type)
    assert_equal "verifier", params.fetch(:code_verifier)
  end

  # Each surface keeps its exchanged-token usage in its own table. A root token
  # class the coordinator was not taught raises rather than defaulting into the
  # client tables, which is where an unscoped default would land.
  test "each root token class names its own usage table and an unknown one is refused" do
    coordinator =
      OidcTokenExchangeCoordinator.new(
        grant_type: "authorization_code", code: "code", redirect_uri: "https://rp.example.test/callback",
        client_id: "rp-1", code_verifier: "verifier",
        expected_resource_type: "client",
      )

    {
      ClientToken.new => ClientRpSession,
      OperatorToken.new => OperatorRpSession,
      VisitorToken.new => VisitorRpSession,
    }.each do |root_token, usage_class|
      assert_equal usage_class, coordinator.send(:usage_class_for_root_token, root_token)
    end

    error = assert_raises(ArgumentError) { coordinator.send(:usage_class_for_root_token, ClientEmail.new) }

    assert_match(/unsupported root token class: ClientEmail/, error.message)
  end

  test "a root token of an unknown class never matches the resource being exchanged for" do
    coordinator =
      OidcTokenExchangeCoordinator.new(
        grant_type: "authorization_code", code: "code", redirect_uri: "https://rp.example.test/callback",
        client_id: "rp-1", code_verifier: "verifier",
        expected_resource_type: "client",
      )

    assert_not coordinator.send(:root_token_actor_matches?, ClientEmail.new, Object.new)
    assert_nil coordinator.send(
      :resolve_root_token,
      OpenStruct.new(base_session_ref: nil, resource_type: nil),
    )
  end

  test "each usage class names the foreign key back to its own surface's token" do
    coordinator =
      OidcTokenExchangeCoordinator.new(
        grant_type: "authorization_code", code: "code", redirect_uri: "https://rp.example.test/callback",
        client_id: "rp-1", code_verifier: "verifier",
        expected_resource_type: "client",
      )

    assert_equal :operator_token, coordinator.send(:parent_token_foreign_key_for, OperatorRpSession)
    assert_equal :visitor_token, coordinator.send(:parent_token_foreign_key_for, VisitorRpSession)
    assert_equal :client_token, coordinator.send(:parent_token_foreign_key_for, ClientRpSession)
  end
end
