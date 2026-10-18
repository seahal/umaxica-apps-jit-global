# typed: false
# frozen_string_literal: true

require "test_helper"

class BranchCoverageBatch30LibEasyArmsTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "JitSecurityJwtJwk normalize_public and validate_public arms" do
    assert_raises(JitSecurityJwtJwk::Error) { JitSecurityJwtJwk.normalize_public([]) }
    assert_raises(JitSecurityJwtJwk::Error) do
      JitSecurityJwtJwk.normalize_public(
        "alg" => JitSecurityJwtJwk::ALGORITHM,
        "use" => "sig",
        "kty" => "EC",
        "crv" => JitSecurityJwtJwk::CURVE,
        "x" => "x",
        "y" => "y",
        "kid" => "k",
        "d" => "private",
      )
    end
    assert_raises(JitSecurityJwtJwk::Error) do
      JitSecurityJwtJwk.validate_public!(
        "alg" => JitSecurityJwtJwk::ALGORITHM,
        "use" => "sig",
        "kty" => "RSA",
        "crv" => JitSecurityJwtJwk::CURVE,
        "x" => "x",
        "y" => "y",
        "kid" => "k",
      )
    end
    assert_raises(JitSecurityJwtJwk::Error) do
      JitSecurityJwtJwk.validate_public!(
        "alg" => JitSecurityJwtJwk::ALGORITHM,
        "use" => "sig",
        "kty" => "EC",
        "crv" => "P-256",
        "x" => "x",
        "y" => "y",
        "kid" => "k",
      )
    end
    assert_raises(JitSecurityJwtJwk::Error) do
      JitSecurityJwtJwk.validate_public!(
        "alg" => "ES256",
        "use" => "sig",
        "kty" => "EC",
        "crv" => JitSecurityJwtJwk::CURVE,
        "x" => "x",
        "y" => "y",
        "kid" => "k",
      )
    end
    assert_raises(JitSecurityJwtJwk::Error) do
      JitSecurityJwtJwk.validate_public!(
        "alg" => JitSecurityJwtJwk::ALGORITHM,
        "use" => "enc",
        "kty" => "EC",
        "crv" => JitSecurityJwtJwk::CURVE,
        "x" => "x",
        "y" => "y",
        "kid" => "k",
      )
    end
  end

  test "SecurityJwtOidcIdTokenCodec build_payload time ordering and claim arms" do
    now = Time.current
    client = Struct.new(:client_id, :resource_type).new("cid", "client")
    assert_raises(ArgumentError) do
      SecurityJwtOidcIdTokenCodec.build_payload(
        resource: Client.new,
        client: client,
        nonce: "n",
        issued_at: now + 1.hour,
        expires_at: now,
        acr: nil,
        amr: nil,
        issuer: "iss",
        subject: "sub",
        sid: "sid",
        auth_time: nil,
        step_up_until: nil,
      )
    end

    payload = SecurityJwtOidcIdTokenCodec.build_payload(
      resource: Client.new,
      client: client,
      nonce: "n",
      issued_at: now,
      expires_at: now + 60,
      acr: nil,
      amr: ["pwd"],
      issuer: "iss",
      subject: "sub",
      sid: "sid",
      auth_time: now,
      step_up_until: now + 30,
    )

    assert_equal ["pwd"], payload["amr"]
    assert payload.key?("auth_time")
    assert payload.key?("step_up_until")
    assert_equal "client", SecurityJwtOidcIdTokenCodec.resource_type_for_client(client)
    assert_equal "operator",
                 SecurityJwtOidcIdTokenCodec.resource_type_for_client(Struct.new(:resource_type).new("staff"))
    assert_equal "visitor",
                 SecurityJwtOidcIdTokenCodec.resource_type_for_client(Struct.new(:resource_type).new("customer"))
    assert_equal "operator", SecurityJwtOidcIdTokenCodec.resource_type_for_resource(Operator.new)
    assert_equal "visitor", SecurityJwtOidcIdTokenCodec.resource_type_for_resource(Visitor.new)
  end

  test "SignInSequence expired blank expires_at is expired" do
    seq = SignInSequence.new(id: "1", expires_at: nil)

    assert_predicate seq, :expired?
  end
end
