# typed: false
# frozen_string_literal: true

require "test_helper"

class OidcAccessJwtChildRevokeIndependenceTest < ActiveSupport::TestCase
  test "Access JWT TTL is five minutes with thirty-second leeway" do
    assert_equal 5.minutes, SecurityTokenLifetimes::OIDC_ACCESS_JWT_TTL
    assert_equal 30, SecurityTokenLifetimes::OIDC_ACCESS_JWT_CLOCK_LEEWAY_SECONDS
    assert_equal 30, SecurityJwtRfc9068AccessTokenProfile::CLOCK_SKEW_LEEWAY_SECONDS
    assert_equal(
      SecurityJwtRfc9068AccessTokenProfile::CLOCK_SKEW_LEEWAY_SECONDS,
      AuthenticationJwtConfiguration.leeway_seconds,
    )
  end

  test "child RP Session revoke does not appear in Access JWT authenticator source" do
    source = Rails.root.join("app/services/oidc_access_token_authenticator.rb").read

    assert_no_match(/ClientRpSession|VisitorRpSession|OperatorRpSession/, source)
    assert_match(/must not query the RP Session row/, source)
  end

  test "revoked RP Session remains inactive while parent Base Browser Session stays usable" do
    root = ClientToken.create!(user: Client.create!)
    session = ClientRpSession.create!(
      client_token: root,
      oidc_client_id: "core-app-rp",
      oidc_scope: "openid profile",
      refresh_token_expires_at: 1.hour.from_now,
    )

    RpSessionRevoker.call(scope: :rp_session, record: session)

    assert_predicate session.reload, :revoked?
    assert_not session.active?
    assert_predicate root.reload, :currently_usable?
  end
end
