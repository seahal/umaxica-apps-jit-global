# frozen_string_literal: true

require "test_helper"
require "uri"

class RegionalRpClientMatrixTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "contains exactly the approved twelve regional clients and global edit client" do
    assert_equal AuthBoundaryAuthorityMap.approved_rp_client_ids.sort,
                 RegionalRpClientMatrix.client_ids.sort
    assert_equal 13, RegionalRpClientMatrix.client_ids.length
    namespaces =
      RegionalRpClientMatrix.client_ids.map do |client_id|
        RegionalRpClientMatrix.jwt_namespace_for(client_id)
      end

    assert_equal namespaces.uniq.sort, namespaces.sort
    assert_includes namespaces, "EDIT_ORG"
  end

  test "exposes one expected registry contract for every approved cell without activating it" do
    contract = RegionalRpClientMatrix.expected_registry_contract

    assert_equal RegionalRpClientMatrix.client_ids.sort,
                 contract.map { |entry| entry.fetch(:client_id) }.sort
    assert_equal 13, contract.length
    assert_equal contract.length, contract.map { |entry| entry.fetch(:client_id) }.uniq.length

    contract.each do |entry|
      client_id = entry.fetch(:client_id)
      metadata = AuthBoundaryAuthorityMap.approved_rp_faces.fetch(client_id)

      assert_equal metadata.fetch(:surface), entry.fetch(:surface)
      assert_equal metadata.fetch(:face), entry.fetch(:face)
      expected_region = metadata.fetch(:region)
      if expected_region.nil?
        assert_nil entry.fetch(:region)
      else
        assert_equal expected_region, entry.fetch(:region)
      end

      assert_equal metadata.fetch(:actor), entry.fetch(:actor)
      assert_equal client_id, entry.fetch(:rp_session_client_id)
      assert_equal RegionalRpClientMatrix.jwt_namespace_for(client_id), entry.fetch(:jwt_namespace)
      assert_equal({ client_id:, attribute: :aud }, entry.fetch(:audience_source))
    end

    assert_equal :regional_root_url_registry,
                 contract.find { |entry| entry.fetch(:client_id) == "core-app-us" }
                   .fetch(:canonical_host_source)
    assert_equal "PUBLIC_WARP_APP_US_URL",
                 contract.find { |entry| entry.fetch(:client_id) == "warp-app-us" }
                   .fetch(:canonical_host_source)
    assert_equal :public_edit_staff_url,
                 contract.find { |entry| entry.fetch(:client_id) == "edit-org" }
                   .fetch(:canonical_host_source)
  end

  test "derives Core URIs from the canonical regional root registry" do
    binding = RegionalRpClientMatrix.uri_binding_for("core-app-jp")

    assert_equal "core-app-jp", binding.fetch(:client_id)
    assert_equal "https://jp.umaxica.app/oidc/callback", binding.fetch(:redirect_uri)
    assert_equal "https://jp.umaxica.app/sign/out", binding.fetch(:post_logout_redirect_uri)
    assert_equal "https://jp.umaxica.app/oidc/backchannel/logout", binding.fetch(:backchannel_logout_uri)
    assert_equal "CORE_APP_JP", binding.fetch(:jwt_namespace)
    assert_equal "core-app-jp", binding.fetch(:rp_session_client_id)
  end

  test "accepts only the exact approved surface and region cell" do
    assert RegionalRpClientMatrix.accepts_exact_cell?(
      client_id: "core-app-jp", surface: "core", face: "app", region: "jp",
    )
    assert_not RegionalRpClientMatrix.accepts_exact_cell?(
      client_id: "core-app-jp", surface: "core", face: "app", region: "us",
    )
    assert_not RegionalRpClientMatrix.accepts_exact_cell?(
      client_id: "core-app-jp", surface: "warp", face: "app", region: "jp",
    )
  end

  test "does not invent a Warp regional host when the repository has no canonical source" do
    error =
      assert_raises(RegionalRpClientMatrix::MissingCanonicalHost) do
        RegionalRpClientMatrix.uri_binding_for("warp-app-us")
      end

    assert_match(/warp-app-us/, error.message)
  end

  test "derives the Warp JP binding from the existing canonical host family" do
    binding = RegionalRpClientMatrix.uri_binding_for("warp-app-jp")

    assert_equal "warp-app-jp", binding.fetch(:client_id)
    assert_equal "https://www-jp.umaxica.app/oidc/callback", binding.fetch(:redirect_uri)
    assert_equal "https://www-jp.umaxica.app/sign/out", binding.fetch(:post_logout_redirect_uri)
    assert_equal "https://www-jp.umaxica.app/oidc/backchannel/logout", binding.fetch(:backchannel_logout_uri)
  end

  test "derives the global Edit binding from its existing canonical host" do
    binding = RegionalRpClientMatrix.uri_binding_for("edit-org")

    assert_equal "edit-org", binding.fetch(:client_id)
    assert_equal "EDIT_ORG", binding.fetch(:jwt_namespace)
    assert_equal "edit-org", binding.fetch(:rp_session_client_id)
    configured_host = ENV.fetch("PUBLIC_EDIT_STAFF_URL")
    configured_origin = configured_host.include?("://") ? configured_host : "https://#{configured_host}"

    assert_equal URI.parse(configured_origin).host, URI.parse(binding.fetch(:redirect_uri)).host
    assert_equal "/oidc/callback", URI.parse(binding.fetch(:redirect_uri)).path
  end

  test "does not create a client from an arbitrary host" do
    assert_raises(ArgumentError) do
      RegionalRpClientMatrix.client_id_for(surface: "core", face: "app", region: "attacker")
    end
  end

  test "does not treat the global Edit RP as a regional cell" do
    assert_raises(ArgumentError) do
      RegionalRpClientMatrix.client_id_for(surface: "edit", face: "org", region: "")
    end
  end

  test "rejects an unapproved client for URI binding and JWT namespace" do
    assert_raises(ArgumentError) { RegionalRpClientMatrix.uri_binding_for("attacker-client") }
    assert_raises(ArgumentError) { RegionalRpClientMatrix.jwt_namespace_for("attacker-client") }
  end

  test "an unapproved client is not an exact cell" do
    assert_not RegionalRpClientMatrix.accepts_exact_cell?(
      client_id: "core-app-jp", surface: "core", face: "app", region: "attacker",
    )
  end

  test "rejects canonical host sources that carry a path, a query, or an unsupported scheme" do
    {
      "a path" => "https://edit.example.test/admin",
      "a query" => "https://edit.example.test/?next=1",
      "a fragment" => "https://edit.example.test/#top",
      "an unsupported scheme" => "ftp://edit.example.test",
      "an unparsable value" => "https://exa mple.test",
    }.each do |label, value|
      error =
        assert_raises(RegionalRpClientMatrix::MissingCanonicalHost, label) do
          with_env("PUBLIC_EDIT_STAFF_URL" => value) do
            RegionalRpClientMatrix.uri_binding_for("edit-org")
          end
        end

      assert_equal "invalid canonical host source", error.message, label
    end
  end

  test "has no canonical Edit host when the source is blank" do
    assert_raises(RegionalRpClientMatrix::MissingCanonicalHost) do
      with_env("PUBLIC_EDIT_STAFF_URL" => "") do
        RegionalRpClientMatrix.uri_binding_for("edit-org")
      end
    end
  end

  test "rejects credentials embedded in a canonical host source" do
    error =
      assert_raises(RegionalRpClientMatrix::MissingCanonicalHost) do
        with_env("PUBLIC_EDIT_STAFF_URL" => "https://user:secret@example.test") do
          RegionalRpClientMatrix.uri_binding_for("edit-org")
        end
      end

    assert_equal "invalid canonical host source", error.message
  end

  test "rejects a non-HTTP canonical host source" do
    error =
      assert_raises(RegionalRpClientMatrix::MissingCanonicalHost) do
        with_env("PUBLIC_EDIT_STAFF_URL" => "ftp://edit.example.test") do
          RegionalRpClientMatrix.uri_binding_for("edit-org")
        end
      end

    assert_equal "invalid canonical host source", error.message
  end

  test "does not expose a complete binding until a canonical audience exists" do
    error =
      assert_raises(RegionalRpClientMatrix::MissingCanonicalAudience) do
        RegionalRpClientMatrix.binding_for("core-app-jp")
      end

    assert_match(/core-app-jp/, error.message)
  end

  test "uses the registered audience source without deriving it from the client id" do
    registered_client = registered_client_for(
      client_id: "core-app-jp",
      audience: "core-app-resource",
    )

    binding =
      OidcClientRegistry.stub(
        :find,
        ->(client_id) {
          (client_id == "core-app-jp") ? registered_client : nil
        },
      ) do
        RegionalRpClientMatrix.binding_for("core-app-jp")
      end

    assert_equal "core-app-resource", binding.fetch(:audience)
  end

  test "accepts an exact US binding only with its independent URI and namespace" do
    registered_client = registered_client_for(
      client_id: "core-app-us",
      audience: "core-app-us-resource",
      origin: "https://us.umaxica.app",
      jwt_namespace: "CORE_APP_US",
    )

    binding =
      OidcClientRegistry.stub(
        :find,
        ->(client_id) { (client_id == "core-app-us") ? registered_client : nil },
      ) do
        RegionalRpClientMatrix.binding_for("core-app-us")
      end

    assert_equal "https://us.umaxica.app/oidc/callback", binding.fetch(:redirect_uri)
    assert_equal "https://us.umaxica.app/sign/out", binding.fetch(:post_logout_redirect_uri)
    assert_equal "CORE_APP_US", binding.fetch(:jwt_namespace)
    assert_equal "core-app-us-resource", binding.fetch(:audience)
  end

  test "rejects a JP registration bound to the US redirect and logout family" do
    registered_client = registered_client_for(
      client_id: "core-app-jp",
      audience: "core-app-jp-resource",
      origin: "https://us.umaxica.app",
      jwt_namespace: "CORE_APP_JP",
    )

    error =
      assert_raises(RegionalRpClientMatrix::InvalidCanonicalRegistration) do
        OidcClientRegistry.stub(:find, ->(_client_id) { registered_client }) do
          RegionalRpClientMatrix.binding_for("core-app-jp")
        end
      end

    assert_match(/redirect URI/, error.message)
  end

  test "rejects a regional registration that reuses another cell key namespace" do
    registered_client = registered_client_for(
      client_id: "core-app-jp",
      audience: "core-app-jp-resource",
      jwt_namespace: "CORE_APP_US",
    )

    error =
      assert_raises(RegionalRpClientMatrix::InvalidCanonicalRegistration) do
        OidcClientRegistry.stub(:find, ->(_client_id) { registered_client }) do
          RegionalRpClientMatrix.binding_for("core-app-jp")
        end
      end

    assert_match(/key namespace/, error.message)
  end

  test "rejects a regional registration bound to the wrong actor resource type" do
    registered_client = registered_client_for(
      client_id: "core-app-jp",
      audience: "core-app-jp-resource",
      resource_type: "visitor",
    )

    error =
      assert_raises(RegionalRpClientMatrix::InvalidCanonicalRegistration) do
        OidcClientRegistry.stub(:find, ->(_client_id) { registered_client }) do
          RegionalRpClientMatrix.binding_for("core-app-jp")
        end
      end

    assert_match(/resource type/, error.message)
  end

  test "rejects a registered client whose exact bindings do not match the approved cell" do
    registered_client = registered_client_for(
      client_id: "core-app-jp",
      audience: "core-app-resource",
      redirect_uri: "https://jp.umaxica.app/sign/callback",
    )

    error =
      assert_raises(RegionalRpClientMatrix::InvalidCanonicalRegistration) do
        OidcClientRegistry.stub(:find, ->(_client_id) { registered_client }) do
          RegionalRpClientMatrix.binding_for("core-app-jp")
        end
      end

    assert_match(/redirect URI/, error.message)
  end

  test "rejects a regional registration that is not private_key_jwt" do
    registered_client = registered_client_for(
      client_id: "core-app-jp",
      audience: "core-app-resource",
      private_key_jwt: false,
    )

    error =
      assert_raises(RegionalRpClientMatrix::InvalidCanonicalRegistration) do
        OidcClientRegistry.stub(:find, ->(_client_id) { registered_client }) do
          RegionalRpClientMatrix.binding_for("core-app-jp")
        end
      end

    assert_match(/private_key_jwt/, error.message)
  end

  test "rejects a regional audience shared by another registered cell" do
    jp_client = registered_client_for(
      client_id: "core-app-jp",
      audience: "shared-regional-audience",
    )
    us_client = registered_client_for(
      client_id: "core-app-us",
      audience: "shared-regional-audience",
      redirect_uri: "https://us.umaxica.app/oidc/callback",
    )

    error =
      assert_raises(RegionalRpClientMatrix::InvalidCanonicalRegistration) do
        OidcClientRegistry.stub(
          :find,
          ->(client_id) {
            { "core-app-jp" => jp_client, "core-app-us" => us_client }.fetch(client_id, nil)
          },
        ) do
          RegionalRpClientMatrix.binding_for("core-app-jp")
        end
      end

    assert_match(/audience is shared/, error.message)
  end

  test "does not activate incomplete regional clients in the compatibility registry" do
    AuthBoundaryAuthorityMap::REGIONAL_RP_CLIENT_IDS.each do |client_id|
      assert_nil OidcClientRegistry.find(client_id), client_id
    end
  end

  private

  def registered_client_for(client_id:, audience:, origin: "https://jp.umaxica.app",
                            redirect_uri: "https://jp.umaxica.app/oidc/callback",
                            private_key_jwt: true, resource_type: "client", jwt_namespace: "CORE_APP_JP")
    redirect_uri = "#{origin}/oidc/callback" if origin != "https://jp.umaxica.app"
    Struct.new(
      :aud, :client_id, :resource_type, :redirect_uris_by_realm, :post_logout_redirect_uris,
      :backchannel_logout_uris, :jwt_namespace, :private_key_jwt_client?,
    ).new(
      audience,
      client_id,
      resource_type,
      { "client" => [redirect_uri] },
      ["#{origin}/sign/out"],
      ["#{origin}/oidc/backchannel/logout"],
      jwt_namespace,
      private_key_jwt,
    )
  end

  def with_env(values)
    originals = values.keys.index_with { |key| ENV.fetch(key, nil) }
    values.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
    yield
  ensure
    originals.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
  end
end
