# typed: false
# frozen_string_literal: true

require "test_helper"

class BranchCoverageBatch33PreciseArmsTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  def credential_transition(**overrides)
    CredentialSecurityTransition.new(
      **{
        actor: Client.new,
        current_session: nil,
        reason: CredentialSecurityTransition::REASONS.first,
        affected_surface: "app",
        revoke_current: false,
        revoke_step_up: false,
        revoke_other_sessions: true,
        request: ActionDispatch::TestRequest.create,
      }.merge(overrides),
    )
  end

  test "CredentialSecurityTransition validate! blank actor and surface" do
    assert_raises(ArgumentError) { credential_transition(actor: nil).send(:validate!) }
    assert_raises(ArgumentError) { credential_transition(affected_surface: nil).send(:validate!) }
    assert_raises(ArgumentError) { credential_transition(affected_surface: "").send(:validate!) }
    assert_raises(ArgumentError) { credential_transition(reason: :nope).send(:validate!) }
  end

  test "CredentialSecurityTransition chronicle event for operator" do
    operator_svc = credential_transition(actor: Operator.new)
    client_svc = credential_transition(actor: Client.new)

    assert_equal OperatorChronicleEvent::CREDENTIAL_SECURITY_TRANSITION, operator_svc.send(:audit_event_id)
    assert_equal ClientChronicleEvent::CREDENTIAL_SECURITY_TRANSITION, client_svc.send(:audit_event_id)
  end

  test "OrganizationPolicy early returns for mismatched principals" do
    enterprise = Enterprise.new
    company = Company.new
    bureau = Bureau.new

    p1 = OrganizationPolicy.new(enterprise)
    p1.define_singleton_method(:user) { Visitor.new }

    assert_not p1.send(:organization_has_current_principal_membership?)

    p2 = OrganizationPolicy.new(company)
    p2.define_singleton_method(:user) { Client.new }

    assert_not p2.send(:organization_has_current_principal_membership?)

    p3 = OrganizationPolicy.new(bureau)
    p3.define_singleton_method(:user) { Client.new }

    assert_not p3.send(:organization_has_current_principal_membership?)
  end

  test "ConfigValues scheme and ipv6 host validation arms" do
    # L44: unless uri.is_a?(URI::HTTP) - ftp is URI::Generic
    assert_raises(ArgumentError) {
      ConfigValues.send(:validate_origin_uri!, URI.parse("ftp://x"), allow_localhost: false)
    }
    # non-http scheme already covered; force scheme check with custom object
    weird = URI.parse("https://example.test")
    weird.define_singleton_method(:scheme) { "ftp" }
    assert_raises(ArgumentError) { ConfigValues.send(:validate_origin_uri!, weird, allow_localhost: false) }

    # L50: host includes ":" and port blank - rare; simulate
    ipv6 = URI.parse("http://[::1]")
    ipv6.define_singleton_method(:port) { nil }
    ipv6.define_singleton_method(:host) { "::1" }
    assert_raises(ArgumentError) { ConfigValues.send(:validate_origin_uri!, ipv6, allow_localhost: true) }
  end

  test "OidcIdTokenVerifier audience mismatch raise arm" do
    verifier = OidcIdTokenVerifier.new(
      id_token: "x",
      client_id: "expected",
      resource_type: "client",
      expected_nonce: "n",
    )
    assert_raises(ArgumentError) { verifier.send(:validate_audience!, { "aud" => ["other"] }) }
    assert_raises(ArgumentError) { verifier.send(:validate_audience!, { "aud" => "not-array" }) }
    assert_raises(ArgumentError) { verifier.send(:validate_audience!, { "aud" => %w(a b) }) }
  end

  test "SignInSelectorParticipant auto_commit requires single candidate" do
    cycle = Object.new
    cycle.define_singleton_method(:class) { ClientSignInFlow }
    cycle.define_singleton_method(:lock!) { true }
    cycle.define_singleton_method(:sign_in_selector_pending?) { true }
    cycle.define_singleton_method(:expired?) { false }
    cycle.define_singleton_method(:principal_id) { 1 }
    cycle.define_singleton_method(:transaction) { |&block| block.call }

    resolver = Object.new
    resolver.define_singleton_method(:candidates) { [] }

    actor = Client.new
    actor.define_singleton_method(:id) { 1 }
    participant = SignInSelectorParticipant.new(cycle: cycle, actor: actor, resolver: resolver)
    participant.define_singleton_method(:ensure_selector_cycle!) { true }
    participant.define_singleton_method(:resolved_actor) { actor }

    # Stub transaction on the cycle class path used inside auto_commit_single!
    ClientSignInFlow.stub(:transaction, ->(&b) { b.call }) do
      cycle.define_singleton_method(:lock!) { true }
      assert_raises(SignInSelectorParticipant::InvalidCycle) { participant.auto_commit_single! }
    end
  end

  test "many service blank-input failure arms" do
    assert_equal "missing_id_token",
                 OidcIdTokenVerifier.new(
                   id_token: nil, client_id: "c", resource_type: "client",
                   expected_nonce: "n",
                 ).call.error
    assert_equal "missing_nonce",
                 OidcIdTokenVerifier.new(
                   id_token: "t", client_id: "c", resource_type: "client",
                   expected_nonce: nil,
                 ).call.error

    assert_raises(ArgumentError) { OutboundSensitivePayload.send(:encrypt, nil, purpose: :x) }
    assert_raises(ArgumentError) { OutboundSensitivePayload.send(:decrypt, nil, purpose: :x) }

    # Auth header scheme helpers
    req = ActionDispatch::TestRequest.create
    req.headers["Authorization"] = "Bearer abc"

    assert_equal "abc", AuthAuthorizationHeader.bearer_token(req)
    assert_equal "Bearer", AuthAuthorizationHeader.scheme(req)
    assert AuthAuthorizationHeader.scheme?(req, "bearer")
  end

  test "OidcAuthorizationCodeIssuer validate_session_token precise" do
    issuer = OidcAuthorizationCodeIssuer.allocate
    issuer.instance_variable_set(:@session_token, nil)
    issuer.instance_variable_set(:@resource, Client.new)
    assert_raises(ArgumentError) { issuer.send(:validate_session_token!) }

    token = Object.new
    token.define_singleton_method(:user_id) { 1 }
    token.define_singleton_method(:currently_usable?) { false }
    client = Client.new
    client.define_singleton_method(:id) { 1 }
    issuer.instance_variable_set(:@session_token, token)
    issuer.instance_variable_set(:@resource, client)
    assert_raises(ArgumentError) { issuer.send(:validate_session_token!) }
  end

  test "ChainSeal pad_base64 and raw signature length arms" do
    assert_raises(ChainSeal::FormatError) do
      ChainSeal.send(:asn1_to_raw_signature, OpenSSL::ASN1::Sequence([]).to_der)
    end
    assert_raises(ChainSeal::FormatError) { ChainSeal.send(:raw_to_asn1_signature, "short") }
  end

  test "Publishing create entry operation easy guard" do
    error = assert_raises(ArgumentError) { Publishing::CreateEntryOperation.new }

    assert_match(/missing keyword/, error.message)
  end

  test "Identity ceremony final committer blank audit early returns" do
    email = IdentityEmailCeremonyFinalCommitter.allocate
    email.define_singleton_method(:config) { { audit_event_id: "" } }
    telephone = IdentityTelephoneCeremonyFinalCommitter.allocate
    telephone.define_singleton_method(:config) { { audit_event_id: nil } }

    assert_nil email.send(:record_audit!, Object.new)
    assert_nil telephone.send(:record_audit!, Object.new)
  end

  test "Oidc refresh token issuer failure helpers" do
    issuer = OidcRefreshTokenIssuer.allocate
    invalid_format = issuer.send(:failure, :invalid_format)
    token_not_found = issuer.send(:failure, :token_not_found)
    inactive = issuer.send(:failure, :inactive_token, token: nil)

    assert_equal :invalid_format, invalid_format.reason
    assert_not invalid_format.success?
    assert_equal :token_not_found, token_not_found.reason
    assert_equal :inactive_token, inactive.reason
    assert_nil inactive.token
  end

  test "Sign secret verify discarded and kind arms" do
    blank = SignSecretVerify.call(secret_credential: nil, raw_secret_credential: "secret")
    inst = SignSecretVerify.allocate
    inst.instance_variable_set(:@now, Time.current)
    infinite = Object.new
    infinite.define_singleton_method(:infinite?) { true }
    infinite.define_singleton_method(:blank?) { false }
    inst.instance_variable_set(:@secret_credential, Struct.new(:discarded_at).new(infinite))

    assert_equal :secret_credential_mismatch, blank.reason
    assert_not inst.send(:lapsed?)
  end

  test "Health and JitSecurityJwtAnomalyReporter host classification" do
    ok = Health::CheckResult.new(check: :liveness, status: :ok, surface: "app")

    assert_equal "COM_PREFERENCE", JitSecurityJwtAnomalyReporter.send(:preference_context, "www.com.example")
    assert_equal "ORG_PREFERENCE", JitSecurityJwtAnomalyReporter.send(:preference_context, "org.example")
    assert_nil JitSecurityJwtAnomalyReporter.send(:preference_context, "example.test")
    assert_predicate ok, :ok?
  end
end
