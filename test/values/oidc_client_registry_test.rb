# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class OidcClientRegistryTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "find returns client config as visitor account" do
    client = OidcClientRegistry.find("base-rails-rp")

    assert_not_nil client
    assert_equal "base-rails-rp", client.client_id
    assert_equal "base-rails-rp", client.aud
    assert client.redirect_uris.any? { |uri| uri.end_with?("/oidc/callback") }
  end

  # test_helper collapses PUBLIC_* and PRIVATE_* auth hosts onto the same auth.*.localhost value,
  # which is why the deployed split (auth.umaxica.org vs auth.org.localhost) went uncovered. These
  # tests set the two apart explicitly so both variants must stay registered.
  test "sign-rp registers a redirect URI for the public and private host of every realm" do
    with_split_auth_hosts do |public_hosts, private_hosts|
      redirect_hosts = sign_rp_redirect_hosts

      (public_hosts + private_hosts).each do |expected_host|
        assert_includes redirect_hosts, expected_host,
                        "#{expected_host} has no registered sign-rp redirect URI, so " \
                        "OidcSsoInitiator#oidc_callback_url raises BadRequest on that host"
      end
    end
  end

  test "sign-rp registers a post logout redirect URI for the public and private host of every realm" do
    with_split_auth_hosts do |public_hosts, private_hosts|
      logout_hosts =
        OidcClientRegistry.find!("sign-rp").post_logout_redirect_uris.filter_map { |uri| URI.parse(uri).host }

      (public_hosts + private_hosts).each do |expected_host|
        assert_includes logout_hosts, expected_host,
                        "#{expected_host} has no registered sign-rp post logout redirect URI"
      end
    end
  end

  test "find returns nil for unknown client" do
    client = OidcClientRegistry.find("unknown-client")

    assert_nil client
  end

  test "find! raises for unknown client" do
    assert_raises(OidcClientRegistry::ClientNotFound) do
      OidcClientRegistry.find!("unknown-client")
    end
  end

  private

  def sign_rp_redirect_hosts
    OidcClientRegistry.find!("sign-rp").redirect_uris.filter_map { |uri| URI.parse(uri).host }
  end

  # Mirrors the deployed topology: a browser-visible public host per realm, distinct from the
  # pod-internal private host. Yields [public_hosts, private_hosts].
  def with_split_auth_hosts
    public_hosts = %w(auth.split.test auth-staff.split.test auth-corporate.split.test)
    private_hosts = %w(auth.split.localhost auth-staff.split.localhost auth-corporate.split.localhost)
    overrides = {
      "PUBLIC_AUTH_SERVICE_URL" => public_hosts[0],
      "PUBLIC_AUTH_STAFF_URL" => public_hosts[1],
      "PUBLIC_AUTH_CORPORATE_URL" => public_hosts[2],
      "PRIVATE_AUTH_SERVICE_URL" => private_hosts[0],
      "PRIVATE_AUTH_STAFF_URL" => private_hosts[1],
      "PRIVATE_AUTH_CORPORATE_URL" => private_hosts[2],
    }
    originals = overrides.keys.index_with { |key| ENV[key] }
    overrides.each { |key, value| ENV[key] = value }
    yield(public_hosts, private_hosts)
  ensure
    originals.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
  end
end
