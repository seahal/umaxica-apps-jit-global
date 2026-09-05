# typed: false
# frozen_string_literal: true

require "test_helper"

# Whether a redirect host counts as public decides if a registered OIDC client may
# send a browser there. Loopback, private and link-local addresses are not public;
# a name that is not an IP is, unless it is localhost. The logout-URI classifier
# picks the surface a post-logout redirect belongs to.
class OidcClientRegistryHostHelpersTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "public_host? rejects loopback, private and link-local addresses" do
    assert_not OidcClientRegistry.send(:public_host?, "127.0.0.1")
    assert_not OidcClientRegistry.send(:public_host?, "10.0.0.5")
    assert_not OidcClientRegistry.send(:public_host?, "192.168.1.20")
    assert_not OidcClientRegistry.send(:public_host?, "169.254.10.1")
    assert_not OidcClientRegistry.send(:public_host?, "::1")
  end

  test "public_host? accepts a routable address and a real hostname but not localhost" do
    assert OidcClientRegistry.send(:public_host?, "203.0.113.7")
    assert OidcClientRegistry.send(:public_host?, "www.umaxica.com")
    assert OidcClientRegistry.send(:public_host?, "https://www.umaxica.com/callback")
    assert_not OidcClientRegistry.send(:public_host?, "localhost")
    assert_not OidcClientRegistry.send(:public_host?, "")
  end

  test "normalize_host reads the host out of a URL, a bare name and a malformed value" do
    assert_equal "www.umaxica.com", OidcClientRegistry.send(:normalize_host, "https://www.umaxica.com/x")
    assert_equal "www.umaxica.com", OidcClientRegistry.send(:normalize_host, "www.umaxica.com")
    assert_equal "not a host", OidcClientRegistry.send(:normalize_host, "not a host")
  end

  # A value `normalize_host` hands back unchanged but `URI` refuses to parse. It reaches the
  # second rescue rather than the IPAddr one, and has to answer "not public" -- treating an
  # unparsable host as public would let a client register a redirect target nobody can verify.
  test "public_host? answers false for a host uri cannot parse at all" do
    assert_not OidcClientRegistry.send(:public_host?, "not a host")
  end

  # The default arm of the surface host list. `logout_uri_resource_type` only ever asks for the
  # operator and visitor lists before falling back to "client", so the client list itself is only
  # reachable by asking for it, and it is what decides which hosts a client post-logout redirect
  # may name.
  test "logout_hosts_for falls back to the service hosts for the client surface" do
    hosts = Rails.configuration.x.boot_config.fetch(:hosts)

    %w(client unrecognised).each do |resource_type|
      result = OidcClientRegistry.send(:logout_hosts_for, resource_type)

      assert_includes result, OidcClientRegistry.send(:normalize_host, hosts.sign_service)
      assert_includes result, OidcClientRegistry.send(:normalize_host, hosts.auth_service)
      assert_equal result, result.uniq
      assert_not_includes result, OidcClientRegistry.send(:normalize_host, hosts.sign_staff)
    end
  end

  test "logout_uri_resource_type names the surface and answers nil for an unparsable uri" do
    assert_equal "client", OidcClientRegistry.send(:logout_uri_resource_type, "https://example.test/logout")
    assert_nil OidcClientRegistry.send(:logout_uri_resource_type, "http://[bad")
  end
end
