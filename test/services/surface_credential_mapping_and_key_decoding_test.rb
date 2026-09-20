# typed: false
# frozen_string_literal: true

require "test_helper"
require "jit_security_jwt_keyring"

# Small per-surface mappings and decoders that answer for the wrong surface, or
# answer at all when they should refuse, rather than raising. Each is a single
# line, which is exactly why a wrong copy reads as plausible.
class SurfaceCredentialMappingAndKeyDecodingTest < ActiveSupport::TestCase
  fixtures :operators, :operator_statuses

  # The risk score is read from the occurrence table of the actor's own surface;
  # scoring a staff sign-in against the client table would report someone else's
  # recent failures as theirs.
  test "the risk score is read from the occurrence table of the actor's own surface" do
    assert_equal 0, SignRiskEngine.score
    assert_equal 0, SignRiskEngine.score(staff_id: operators(:one).id)
    assert_equal 0, SignRiskEngine.score(visitor_id: 1)
    assert_equal 0, SignRiskEngine.score(user_id: 1)
  end

  # Deleting a cookie must not carry an expiry or the httponly flag, because the
  # deletion has to match the cookie's own path and same-site attributes only.
  test "cookie deletion options drop the attributes that would stop the deletion matching" do
    %i(access_cookie_deletion_options refresh_cookie_deletion_options).each do |name|
      options = CoreBrowserCredentialContract.public_send(name)

      assert_not options.key?(:expires), name
      assert_not options.key?(:httponly), name
    end

    oidc = CoreBrowserCredentialContract.oidc_cookie_deletion_options

    assert_equal :lax, oidc.fetch(:same_site)
    assert_equal CoreBrowserCredentialContract::OIDC_PATH, oidc.fetch(:path)
    assert_not oidc.key?(:expires)
  end

  # A key that cannot be decoded answers nil rather than raising, so a single bad
  # entry in a keyset does not take the whole issuer down at boot.
  test "an undecodable key answers nothing rather than raising" do
    assert_nil JitSecurityJwtKeyring.decode_key(nil)
    assert_nil JitSecurityJwtKeyring.decode_key("")
    assert_nil JitSecurityJwtKeyring.decode_key(Base64.encode64("not a DER key"))
  end

  test "a well-formed key decodes back to the same public point" do
    key = OpenSSL::PKey::EC.generate("secp384r1")
    encoded = Base64.encode64(key.to_der)

    assert_equal key.public_to_der, JitSecurityJwtKeyring.decode_key(encoded).public_to_der
  end

  test "a keyset that is blank or unparsable answers an empty set rather than raising" do
    assert_empty JitSecurityJwtKeyring.parse_keyset(nil)
    assert_empty JitSecurityJwtKeyring.parse_keyset("")
    assert_empty JitSecurityJwtKeyring.parse_keyset("{not json")
    assert_empty JitSecurityJwtKeyring.parse_keyset("[1, 2]")
    assert_equal({ "kid" => "value" }, JitSecurityJwtKeyring.parse_keyset(%({"kid":"value"})))
  end

  test "the active public key is resolved without naming a kid" do
    assert_equal JitSecurityJwtKeyring.public_key_for(JitSecurityJwtKeyring.active_kid("auth"), issuer_id: "auth"),
                 JitSecurityJwtKeyring.public_key_for_active("auth")
  end
end
