# frozen_string_literal: true

require "test_helper"

class OidcPkceTest < ActiveSupport::TestCase
  fixtures :clients
  self.fixture_table_names = %w(clients)

  test "challenge generation matches the RFC 7636 S256 example" do
    verifier = "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk"

    assert_equal "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM", OidcPkce.challenge_for(verifier)
    assert OidcPkce.verify(code_verifier: verifier, code_challenge: OidcPkce.challenge_for(verifier))
  end

  test "verification accepts the minimum and maximum valid verifier lengths" do
    ["a" * 43, "a" * 128].each do |verifier|
      assert OidcPkce.verify(code_verifier: verifier, code_challenge: OidcPkce.challenge_for(verifier))
    end
  end

  test "verification refuses missing empty malformed and out-of-range verifier values" do
    invalid_verifiers = [nil, "", "a" * 42, "a" * 129, ("a" * 42) + "%"]

    invalid_verifiers.each do |verifier|
      assert_not OidcPkce.verify(code_verifier: verifier, code_challenge: OidcPkce.challenge_for(verifier))
    end
    assert_not OidcPkce.verify(code_verifier: "a" * 43, code_challenge: "")
    assert_not OidcPkce.verify(
      code_verifier: "a" * 43,
      code_challenge: OidcPkce.challenge_for("a" * 43),
      code_challenge_method: "plain",
    )
  end
end
