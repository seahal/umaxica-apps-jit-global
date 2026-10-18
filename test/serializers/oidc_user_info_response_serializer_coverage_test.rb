# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class OidcUserInfoResponseSerializerCoverageTest < ActiveSupport::TestCase
  test "build returns profile claims when the resource exposes them" do
    resource = Struct.new(:public_id, :name, :email).new("user-1", "Ada Lovelace", "ada@example.test")

    claims = OidcUserInfoResponseSerializer.build(
      resource: resource,
      payload: { "scope" => "openid profile email domain:client" },
    )

    assert_equal "Ada Lovelace", claims[:name]
    assert_equal "ada@example.test", claims[:email]
    assert claims[:email_verified]
    assert_equal OidcSubject.for(resource, resource_type: "client"), claims[:sub]
  end

  test "build omits profile claims when the resource does not expose them" do
    resource = Struct.new(:public_id).new("visitor-1")

    claims = OidcUserInfoResponseSerializer.build(
      resource: resource,
      payload: { "acr" => "acr", "scope" => "openid domain:visitor" },
    )

    assert_equal "acr", claims[:acr]
    assert_equal OidcSubject.for(resource, resource_type: "visitor"), claims[:sub]
    assert_not claims.key?(:name)
    assert_not claims.key?(:email)
    assert_not claims.key?(:email_verified)
  end

  test "build scopes profile and email claims independently" do
    resource = Struct.new(:public_id, :name, :email).new("user-2", "Grace Hopper", "grace@example.test")

    profile_claims = OidcUserInfoResponseSerializer.build(
      resource: resource,
      payload: {
        "scope" => "openid profile domain:client",
      },
    )
    email_claims = OidcUserInfoResponseSerializer.build(
      resource: resource,
      payload: {
        "scope" => "openid email domain:client",
      },
    )

    assert_equal "Grace Hopper", profile_claims[:name]
    assert_not profile_claims.key?(:email)
    assert_not profile_claims.key?(:email_verified)

    assert_equal "grace@example.test", email_claims[:email]
    assert email_claims[:email_verified]
    assert_not email_claims.key?(:name)
  end
end
