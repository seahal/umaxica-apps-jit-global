# typed: false
# frozen_string_literal: true

require "test_helper"

# Per-actor mappings and required-input guards on the retention and Apple
# credential paths. Both refuse an input they were not built for, because
# purging against the wrong surface's enforcement table, or minting a client
# secret from a partially configured key, fails in a way nothing else catches.
class RetentionAndCredentialProviderRefusalsTest < ActiveSupport::TestCase
  fixtures :clients, :client_statuses, :client_visibilities, :operators, :operator_statuses

  # The Apple client secret is a signed assertion; every input it is signed with
  # has to be present, or the assertion is minted against a partial identity.
  test "each missing Apple credential input is refused by name" do
    key = OpenSSL::PKey::EC.generate("prime256v1").to_pem
    complete = { client_id: "com.example.app", team_id: "TEAM", key_id: "KEY", private_key_pem: key }

    assert ExternalAuthentication::AppleClientSecretProvider.new(**complete)

    %i(client_id team_id key_id private_key_pem).each do |missing|
      error =
        assert_raises(ArgumentError) do
          ExternalAuthentication::AppleClientSecretProvider.new(**complete.merge(missing => ""))
        end

      assert_match(/#{missing} is required/, error.message)
    end
  end

  test "an Apple client secret ttl must be positive and within the maximum Apple accepts" do
    key = OpenSSL::PKey::EC.generate("prime256v1").to_pem
    complete = { client_id: "com.example.app", team_id: "TEAM", key_id: "KEY", private_key_pem: key }

    assert_raises(ArgumentError) do
      ExternalAuthentication::AppleClientSecretProvider.new(**complete, ttl: 0)
    end
    assert_raises(ArgumentError) do
      ExternalAuthentication::AppleClientSecretProvider.new(
        **complete, ttl: ExternalAuthentication::AppleClientSecretProvider::MAXIMUM_TTL + 1.second,
      )
    end
  end
end
