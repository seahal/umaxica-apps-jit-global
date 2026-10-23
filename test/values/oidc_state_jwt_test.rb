# typed: false
# frozen_string_literal: true

require "test_helper"

# D-149 / D-150: the RP `state` JWS.
class OidcStateJwtTest < ActiveSupport::TestCase
  CLIENT_ID = "core-app-jp"

  test "a state issued by the RP verifies for that RP and carries its jti and target" do
    state, jti = OidcStateJwt.issue(client_id: CLIENT_ID, target_link_uri: "/dashboard")
    result = OidcStateJwt.verify(client_id: CLIENT_ID, token: state)

    assert_predicate result, :valid?
    assert_equal [jti, "/dashboard"], [result.jti, result.target_link_uri]
  end

  test "another RP, a tampered payload or signature, and other algorithms are refused" do
    state, = OidcStateJwt.issue(client_id: CLIENT_ID, target_link_uri: "/a")
    header, payload, signature = state.split(".")
    tampered_payload = Base64.urlsafe_encode64(
      JSON.generate(JSON.parse(Base64.urlsafe_decode64(payload)).merge("target_link_uri" => "/b")), padding: false,
    )
    hs256 = JWT.encode({ "iss" => CLIENT_ID }, "secret", "HS256", { "typ" => OidcStateJwt::TOKEN_TYPE, "kid" => "k" })
    none = JWT.encode({ "iss" => CLIENT_ID }, nil, "none", { "typ" => OidcStateJwt::TOKEN_TYPE })

    [
      OidcStateJwt.verify(client_id: "core-com-jp", token: state),
      OidcStateJwt.verify(client_id: CLIENT_ID, token: [header, tampered_payload, signature].join(".")),
      OidcStateJwt.verify(client_id: CLIENT_ID, token: "#{state[0..-3]}xx"),
      OidcStateJwt.verify(client_id: CLIENT_ID, token: hs256),
      OidcStateJwt.verify(client_id: CLIENT_ID, token: none),
      OidcStateJwt.verify(client_id: CLIENT_ID, token: ""),
    ].each_with_index { |result, index| assert_not_predicate result, :valid?, index.to_s }
  end

  test "a client assertion is not accepted as a state" do
    assertion = OidcClientAssertionJwt.issue(client_id: CLIENT_ID, token_url: OidcIssuer.token_endpoint("client"))

    assert_not_predicate OidcStateJwt.verify(client_id: CLIENT_ID, token: assertion), :valid?
  end

  test "the state is valid before 30 minutes and refused at and after 30 minutes" do
    issued_at = Time.current.change(usec: 0)
    state, = OidcStateJwt.issue(client_id: CLIENT_ID, target_link_uri: nil, now: issued_at)

    { 1799 => true, 1800 => false, 1801 => false }.each do |seconds, valid|
      travel_to(issued_at + seconds) do
        assert_equal valid, OidcStateJwt.verify(client_id: CLIENT_ID, token: state).valid?, "#{seconds}s"
      end
    end
  end

  test "an iat beyond the clock leeway in the future is refused" do
    state, = OidcStateJwt.issue(client_id: CLIENT_ID, target_link_uri: nil, now: 2.minutes.from_now)

    assert_not_predicate OidcStateJwt.verify(client_id: CLIENT_ID, token: state), :valid?
  end
end
