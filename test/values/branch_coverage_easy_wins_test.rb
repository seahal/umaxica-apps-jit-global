# typed: false
# frozen_string_literal: true

require "test_helper"

class BranchCoverageEasyWinsTest < ActiveSupport::TestCase
  test "CoreCookieDomain covers configured match, host-only, and localhost edges" do
    creds = Object.new
    creds.define_singleton_method(:option) { |_key| ".umaxica.app" }

    Rails.app.stub(:creds, creds) do
      assert_equal ".umaxica.app", CoreCookieDomain.for(surface: :app, request_host: "www.umaxica.app")
    end

    host_only = Object.new
    host_only.define_singleton_method(:option) { |_key| "HOST_ONLY" }

    Rails.app.stub(:creds, host_only) do
      assert_nil CoreCookieDomain.for(surface: :app, request_host: "www.umaxica.app")
    end

    mismatched = Object.new
    mismatched.define_singleton_method(:option) { |_key| ".other.example" }

    Rails.app.stub(:creds, mismatched) do
      assert_equal ".umaxica.app", CoreCookieDomain.for(surface: :com, request_host: "www.umaxica.app")
    end

    assert_equal ".app.localhost", CoreCookieDomain.for(surface: :app, request_host: "www.app.localhost")
  end

  test "ExternalAuthentication::LinkResult rejects unsupported status and missing peers" do
    assert_raises(ArgumentError) { ExternalAuthentication::LinkResult.new(status: :other, user: Object.new, identity: Object.new) }
    assert_raises(ArgumentError) { ExternalAuthentication::LinkResult.new(status: :linked, user: nil, identity: Object.new) }
    assert_raises(ArgumentError) { ExternalAuthentication::LinkResult.new(status: :linked, user: Object.new, identity: nil) }
    result = ExternalAuthentication::LinkResult.new(status: :linked, user: :u, identity: :i)

    assert_equal :linked, result.status
  end

  test "OidcIdTokenIssuer rejects blank nonce and inverted time ordering" do
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

  test "identity ceremony results reject future verified_at timestamps" do
    now = Time.zone.parse("2026-06-24 12:00:00 UTC")
    future = now + IdentitySocialCeremonyContract::LEEWAY + 60
    payload = {
      "typ" => IdentitySocialCeremonyResult::TOKEN_TYPE,
      "iss" => IdentitySocialCeremonyContract.sign_issuer("app"),
      "aud" => IdentitySocialCeremonyContract.acme_audience("app"),
      "purpose" => IdentitySocialCeremonyResult::PURPOSE,
      "surface" => "app",
      "actor_ref" => "a",
      "session_ref" => "s",
      "transaction_id" => "t",
      "grant_jti" => "g",
      "result_jti" => "r",
      "operation" => "signup",
      "provider" => "google",
      "proof_method" => IdentitySocialCeremonyResult::PROOF_METHOD,
      "provider_subject_ref" => "subj",
      "provider_subject_digest" => "digest",
      "verified_at" => future.to_i,
      "challenge_id" => "c",
      "expires_at" => (now + 5.minutes).to_i,
      "iat" => now.to_i,
      "exp" => (now + 5.minutes).to_i,
    }
    assert_raises(IdentitySocialCeremonyContract::Error) do
      IdentitySocialCeremonyResult.new(payload, now: now)
    end
  end

  test "Webauthn::UvPolicy.for accepts an already constructed policy" do
    policy = Webauthn::UvPolicy::REGISTRY.fetch(:registration)

    assert_same policy, Webauthn::UvPolicy.for(policy)
  end

  test "OidcClientAssertionJwt covers refresh and consume_jti failure arms" do
    assert_not OidcClientAssertionJwt.send(
      :refresh_local_key_material!,
      client_id: "missing_client",
    )

    Rails.env.stub(:local?, false) do
      assert_not OidcClientAssertionJwt.send(:refresh_local_key_material!, client_id: "base-rails-rp")
    end

    OidcClientRegistry.stub(:jwt_namespace_for, nil) do
      Rails.env.stub(:local?, true) do
        assert_not OidcClientAssertionJwt.send(:refresh_local_key_material!, client_id: "base-rails-rp")
      end
    end

    assert_not OidcClientAssertionJwt.send(
      :consume_jti?,
      client_id: "core-next-rp",
      jti: "",
      exp: 1.hour.from_now.to_i,
      now: Time.current,
    )
    assert_not OidcClientAssertionJwt.send(
      :consume_jti?,
      client_id: "core-next-rp",
      jti: "jti-1",
      exp: 1.hour.ago.to_i,
      now: Time.current,
    )

    OidcClientAssertionJwt.stub(:refresh_local_key_material!, false) do
      OidcClientAssertionJwt.stub(
        :issue_with_configured_key,
        ->(**) { raise JitSecurityJwtRegistry::ConfigurationError },
      ) do
        assert_nil OidcClientAssertionJwt.issue(client_id: "base-rails-rp", token_url: "https://id.example/token")
      end
    end

    header = { "alg" => JitSecurityJwtRegistry::ALGORITHM, "typ" => "wrong", "kid" => "k" }

    JitSecurityJwtKeyring.stub(:parse_header, header) do
      assert_not OidcClientAssertionJwt.valid?(
        client_id: "core-next-rp",
        assertion: "x.y.z",
        token_url: "https://id.example/token",
      )
    end

    header_ok = { "alg" => JitSecurityJwtRegistry::ALGORITHM, "typ" => OidcClientAssertionJwt::TOKEN_TYPE, "kid" => "k" }
    JitSecurityJwtKeyring.stub(:parse_header, header_ok) do
      JitSecurityJwtRegistry.stub(:public_key_for, nil) do
        assert_not OidcClientAssertionJwt.valid?(
          client_id: "core-next-rp",
          assertion: "x.y.z",
          token_url: "https://id.example/token",
        )
      end
    end
  end

  test "Oidc::AcmeServiceOrigin rejected decision covers nil-target safe navigation" do
    origin = Oidc::AcmeServiceOrigin.send(:new, scheme: "https", host: "www.umaxica.app", port: nil)
    request = ActionDispatch::TestRequest.create
    request.host = "log.umaxica.app"
    request.set_header("HTTPS", "on")

    decision = origin.send(:reject_decision, :invalid_target, request: request, target: nil)

    assert_equal :rejected, decision.kind
    assert_nil decision.target_scheme
    assert_nil decision.target_host
    assert_nil decision.target_port
    assert_nil decision.target_path

    target = URI.parse("https://evil.example:8443/callback")
    decision2 = origin.send(:reject_decision, :invalid_target, request: request, target: target)

    assert_equal "https", decision2.target_scheme
    assert_equal "evil.example", decision2.target_host
    assert_equal 8443, decision2.target_port
    assert_equal "/callback", decision2.target_path

    assert_nil origin.send(:parse_target_url, "relative-without-slash")
    fake = Struct.new(:scheme, :host, :path).new(nil, "ex.com", "noslash")

    URI.stub(:parse, fake) { assert_nil origin.send(:parse_target_url, "ignored") }

    http_uri = URI.parse("https://example.com")
    http_uri.define_singleton_method(:scheme) { "ftp" }

    URI.stub(:parse, ->(*) { http_uri }) do
      assert_raises(ArgumentError) do
        Oidc::AcmeServiceOrigin.send(:parse_origin, "https://example.com", default_scheme: "https")
      end
    end
  end

  test "DbscProofVerifier covers missing proof challenge and claim failure arms" do
    assert_equal "missing_proof",
                 DbscProofVerifier.call(proof: "", challenge: "c", challenge_issued_at: Time.current).error_code
    assert_equal "missing_challenge",
                 DbscProofVerifier.call(proof: "x.y.z", challenge: "", challenge_issued_at: Time.current).error_code
    assert_equal "challenge_expired",
                 DbscProofVerifier.call(proof: "x.y.z", challenge: "c", challenge_issued_at: 1.hour.ago).error_code

    key = OpenSSL::PKey::EC.generate("prime256v1")
    public_jwk = JWT::JWK.new(key).export
    now = Time.current
    proof = JWT.encode(
      { "jti" => "c", "aud" => "https://test.host/x", "iat" => now.to_i },
      key,
      "ES256",
      { typ: "wrong", jwk: public_jwk },
    )

    assert_equal "invalid_type",
                 DbscProofVerifier.call(proof: proof, challenge: "c", challenge_issued_at: now).error_code

    proof = JWT.encode(
      { "jti" => "c", "aud" => "", "iat" => now.to_i },
      key,
      "ES256",
      { typ: "dbsc+jwt", jwk: public_jwk },
    )

    assert_equal "missing_audience",
                 DbscProofVerifier.call(proof: proof, challenge: "c", challenge_issued_at: now).error_code

    proof = JWT.encode(
      { "jti" => "c", "aud" => "https://test.host/x", "iat" => now.to_i },
      key,
      "ES256",
      { typ: "dbsc+jwt", jwk: public_jwk },
    )

    assert_equal "audience_mismatch",
                 DbscProofVerifier.call(
                   proof: proof,
                   challenge: "c",
                   challenge_issued_at: now,
                   expected_audience: "https://other.host/x",
                 ).error_code

    proof = JWT.encode(
      { "jti" => "other", "aud" => "https://test.host/x", "iat" => now.to_i },
      key,
      "ES256",
      { typ: "dbsc+jwt", jwk: public_jwk },
    )

    assert_equal "challenge_mismatch",
                 DbscProofVerifier.call(proof: proof, challenge: "c", challenge_issued_at: now).error_code
  end
end
