# typed: false
# frozen_string_literal: true

require "test_helper"

class OidcAccessTokenAuthenticatorNoRpSessionLookupTest < ActiveSupport::TestCase
  test "find_token resolves Base Browser Session without querying RP Session" do
    authenticator = OidcAccessTokenAuthenticator.new(
      access_token: "unused",
      resource_type: "client",
      host: "base.app.localhost",
    )

    assert_not authenticator.respond_to?(:usage_class_for_resource_type, true)

    source = Rails.root.join("app/services/oidc_access_token_authenticator.rb").read

    assert_no_match(/ClientRpSession|VisitorRpSession|OperatorRpSession/, source)
    assert_match(/must not query the RP Session row/, source)
  end
end
