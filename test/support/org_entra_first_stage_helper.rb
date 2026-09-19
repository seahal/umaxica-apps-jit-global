# typed: false
# frozen_string_literal: true

# Drives the first stage of normal org sign-in -- the Entra ID ceremony -- so a
# test of the second stage starts from the state a real browser would be in.
#
# It runs the real request and callback phases of the strategy rather than
# writing the pending transaction into the session directly. The binding
# between the Entra result and the passkey/secret stage is the security property
# these tests exist to check, so a helper that installed it by hand would be
# asserting against its own fixture instead of against the ceremony.
module OrgEntraFirstStageHelper
  ENTRA_TENANT_ID = "11111111-2222-3333-4444-555555555555"
  ENTRA_CLIENT_ID = "22222222-3333-4444-5555-666666666666"

  # @return [String] the Entra object id the identity was provisioned with
  def complete_org_entra_first_stage!(operator, entra_object_id: SecureRandom.uuid)
    previous_test_mode = OmniAuth.config.test_mode
    OmniAuth.config.test_mode = false
    OrganizationEntraConnectionState.ensure_defaults!
    OperatorEntraIdentityState.ensure_defaults!
    stub_org_entra_registry!

    unless OperatorEntraIdentity.exists?(operator_id: operator.id)
      OperatorEntraIdentity.create!(
        operator_id: operator.id,
        connection_id: nil,
        entra_tenant_id: ENTRA_TENANT_ID,
        entra_object_id: entra_object_id,
        status_id: OperatorEntraIdentityState::ACTIVE,
      )
    end

    post("/social/entra", params: {})
    query = Rack::Utils.parse_nested_query(URI.parse(response.location).query)

    private_key = OpenSSL::PKey::RSA.generate(2048)
    kid = "org-entra-first-stage-#{SecureRandom.hex(4)}"
    jwk = JWT::JWK.new(private_key, { "kid" => kid })
    id_token = org_entra_id_token(
      private_key: private_key, kid: kid, operator: operator,
      entra_object_id: entra_object_id, nonce: query.fetch("nonce"),
    )

    stub_org_entra_access_token(id_token) do
      ExternalSignIn::EntraJwksCache.stub(
        :new, ->(**) {
          loader_double = Object.new
          loader_double.define_singleton_method(:loader) { ->(_opts) { { "keys" => [jwk.export] } } }
          loader_double
        },
      ) do
        get("/social/entra/callback", params: { state: query.fetch("state"), code: "authorization-code" })
      end
    end

    entra_object_id
  ensure
    restore_org_entra_registry!
    OmniAuth.config.test_mode = previous_test_mode
  end

  private

  def org_entra_id_token(private_key:, kid:, operator:, entra_object_id:, nonce:)
    now = Time.now.to_i

    JWT.encode(
      {
        "iss" => "https://login.microsoftonline.com/#{ENTRA_TENANT_ID}/v2.0",
        "aud" => ENTRA_CLIENT_ID,
        "tid" => ENTRA_TENANT_ID,
        "oid" => entra_object_id,
        "sub" => "pairwise-sub-#{operator.id}",
        "acct" => 0,
        "ver" => "2.0",
        "nonce" => nonce,
        "iat" => now,
        "exp" => now + 3600,
      },
      private_key, "RS256", { "kid" => kid },
    )
  end

  # The strategy reads tenant and client from the deployment's credentials and
  # runs inside the request, outside any block a test could wrap, so the values
  # are swapped as singleton methods for the duration of the ceremony.
  def stub_org_entra_registry!
    registry = ExternalAuthentication::ProviderRegistry
    @org_entra_registry_originals =
      %i(tenant_id audience issuer_for).index_with { |name| registry.method(name) }
    tenant = ENTRA_TENANT_ID
    client = ENTRA_CLIENT_ID
    registry.define_singleton_method(:tenant_id) { |_provider| tenant }
    registry.define_singleton_method(:audience) { |_provider| client }
    registry.define_singleton_method(:issuer_for) { |_provider| "https://login.microsoftonline.com/#{tenant}/v2.0" }
  end

  def restore_org_entra_registry!
    @org_entra_registry_originals&.each { |name, method| ExternalAuthentication::ProviderRegistry.define_singleton_method(name, method) }
    @org_entra_registry_originals = nil
  end

  def stub_org_entra_access_token(id_token)
    strategy_class = OmniAuth::Strategies::UmaxicaEntra
    original = strategy_class.instance_method(:access_token)
    strategy_class.define_method(:access_token) do
      verify_id_token!(id_token)
      OpenStruct.new(id_token: id_token)
    end
    yield
  ensure
    strategy_class.define_method(:access_token, original)
  end
end
