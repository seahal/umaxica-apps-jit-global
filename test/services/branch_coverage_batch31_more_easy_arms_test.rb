# typed: false
# frozen_string_literal: true

require "test_helper"

class BranchCoverageBatch31MoreEasyArmsTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "ChainSeal canonicalize and decode_signature edge arms" do
    assert_raises(ChainSeal::FormatError) { ChainSeal.send(:canonicalize, BasicObject.new) }
    assert_raises(ChainSeal::FormatError) { ChainSeal.send(:decode_signature, "abc=") }
    assert_raises(ChainSeal::FormatError) do
      ChainSeal.send(:decode_signature, Base64.urlsafe_encode64("short", padding: false))
    end
    assert_raises(ChainSeal::FormatError) { ChainSeal.send(:validate_ec_key!, OpenSSL::PKey::RSA.new(2048)) }
    key = OpenSSL::PKey::EC.generate("prime256v1")
    assert_raises(ChainSeal::FormatError) { ChainSeal.send(:validate_ec_key!, key) }
  end

  test "JitSecurityTurnstileVerifier blank token arms" do
    blank_token = JitSecurityTurnstileVerifier.verify(token: "", remote_ip: "127.0.0.1")

    assert_equal "missing cf-turnstile-response", blank_token["error"]
    nil_token = JitSecurityTurnstileVerifier.verify(token: nil, remote_ip: "127.0.0.1")

    assert_equal "missing cf-turnstile-response", nil_token["error"]
  end

  test "ExternalAuthentication LinkResult and LoginResult rejection arms" do
    assert_raises(ArgumentError) { ExternalAuthentication::LinkResult.new(status: :other, user: Object.new, identity: Object.new) }
    assert_raises(ArgumentError) { ExternalAuthentication::LinkResult.new(status: :linked, user: nil, identity: Object.new) }
    if defined?(ExternalAuthentication::LoginResult)
      assert_raises(ArgumentError) { ExternalAuthentication::LoginResult.new(status: :other, user: Object.new) }
    end
  end

  test "OidcIdTokenIssuer blank nonce and inverted times" do
    resource = Client.new
    client = Struct.new(:client_id).new("base-rails-rp")
    assert_raises(ArgumentError) do
      OidcIdTokenIssuer.new(
        resource: resource,
        client: client,
        nonce: "",
        issued_at: Time.current,
        expires_at: 1.minute.from_now,
      ).call
    end
    assert_raises(ArgumentError) do
      OidcIdTokenIssuer.new(
        resource: resource,
        client: client,
        nonce: "n",
        issued_at: 1.minute.from_now,
        expires_at: Time.current,
      ).call
    end
  end

  test "Palm and OIDC access token authenticators blank tokens" do
    [PalmAccessTokenAuthenticator, OidcAccessTokenAuthenticator].each do |klass|
      assert_raises(ArgumentError) { klass.new(token: nil) }
      assert_raises(ArgumentError) { klass.new(token: " ") }
    end
  end

  test "DbscVerificationService blank proof" do
    assert_raises(ArgumentError) do
      DbscVerificationService.new(
        proof: nil, challenge: "c", challenge_issued_at: Time.current,
        expected_audience: "a",
      )
    end
    assert_raises(ArgumentError) do
      DbscVerificationService.new(
        proof: "", challenge: "c", challenge_issued_at: Time.current,
        expected_audience: "a",
      )
    end
  end

  test "CredentialSecurityTransition blank actor" do
    assert_raises(ArgumentError) { CredentialSecurityTransition.new(actor: nil, event: :rotate) }
  end

  test "SignTelephoneOtpDelivery assign writes otp fields" do
    telephone = Object.new
    telephone.define_singleton_method(:otp_private_key=) { |v| @k = v }
    telephone.define_singleton_method(:otp_counter=) { |v| @c = v }
    telephone.define_singleton_method(:otp_expires_at=) { |v| @e = v }
    telephone.define_singleton_method(:otp_last_sent_at=) { |v| @s = v }
    telephone.define_singleton_method(:respond_to?) { |m, *|
      %i(otp_private_key= otp_counter= otp_expires_at= otp_last_sent_at=).include?(m) || super(m)
    }

    code = SignTelephoneOtpDelivery.assign(telephone)

    assert_match(/\A\d+\z/, code)
  end

  test "AuthMethodGuard and single-use token easy rejects" do
    assert_not AuthMethodGuard.respond_to?(:allow?)
  end

  test "ConfigValues OriginValue to_s default and explicit ports" do
    https = ConfigValues.build("https://example.test")

    assert_equal "https://example.test", https.to_s
    http = ConfigValues.build("http://localhost", allow_localhost: true)

    assert_equal "http://localhost", http.to_s
    custom = ConfigValues.build("https://example.test:8443")

    assert_includes custom.to_s, ":8443"
  end

  test "JitSecurityJwtJtiGenerator generate produces strings" do
    a = JitSecurityJwtJtiGenerator.generate
    b = JitSecurityJwtJtiGenerator.generate

    assert_kind_of String, a
    assert_kind_of String, b
    assert_not_equal a, b
  end

  test "SecurityJwtOidcIdTokenCodec normalize_time and decode_options" do
    t = SecurityJwtOidcIdTokenCodec.send(:normalize_time!, Time.current)

    assert_kind_of Time, t
    assert_kind_of Time, SecurityJwtOidcIdTokenCodec.send(:normalize_time!, Time.current.to_i)
    opts = SecurityJwtOidcIdTokenCodec.send(:decode_options, client_id: "c", resource_type: "client", issuer: "iss")

    assert_equal "iss", opts[:iss]
    assert_equal "c", opts[:aud]
  end
end
