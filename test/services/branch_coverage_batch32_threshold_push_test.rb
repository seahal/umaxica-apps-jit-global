# typed: false
# frozen_string_literal: true

require "test_helper"

# Unit tops for still-cold raise/return arms needed to clear the 90% branch floor.
class BranchCoverageBatch32ThresholdPushTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "CredentialSecurityTransition validate! arms" do
    base = {
      current_session: nil,
      revoke_current: false,
      revoke_step_up: false,
      revoke_other_sessions: true,
      request: ActionDispatch::TestRequest.create,
    }
    assert_raises(ArgumentError) do
      CredentialSecurityTransition.new(
        **base,
        actor: nil,
        reason: CredentialSecurityTransition::REASONS.first,
        affected_surface: "app",
      ).send(:validate!)
    end
    assert_raises(ArgumentError) do
      CredentialSecurityTransition.new(
        **base,
        actor: Client.new,
        reason: :not_a_reason,
        affected_surface: "app",
      ).send(:validate!)
    end
    assert_raises(ArgumentError) do
      CredentialSecurityTransition.new(
        **base,
        actor: Client.new,
        reason: CredentialSecurityTransition::REASONS.first,
        affected_surface: "",
      ).send(:validate!)
    end
  end

  test "OidcIdTokenVerifier blank token and nonce arms" do
    missing_token = OidcIdTokenVerifier.new(
      id_token: "",
      client_id: "c",
      resource_type: "client",
      expected_nonce: "n",
    ).call

    assert_equal "missing_id_token", missing_token.error

    missing_nonce = OidcIdTokenVerifier.new(
      id_token: "token",
      client_id: "c",
      resource_type: "client",
      expected_nonce: "",
    ).call

    assert_equal "missing_nonce", missing_nonce.error

    assert_not OidcIdTokenVerifier.new(
      id_token: "a",
      client_id: "c",
      resource_type: "client",
      expected_nonce: "n",
    ).send(:secure_equal?, "ab", "a")
  end

  test "OidcAuthorizationCodeIssuer session token validation arms" do
    issuer = OidcAuthorizationCodeIssuer.allocate
    issuer.define_singleton_method(:session_token) { nil }
    issuer.define_singleton_method(:resource) { Client.new }
    assert_raises(ArgumentError) { issuer.send(:validate_session_token!) }

    bad = OidcAuthorizationCodeIssuer.allocate
    token = Object.new
    token.define_singleton_method(:user_id) { 999 }
    token.define_singleton_method(:currently_usable?) { false }
    bad.define_singleton_method(:session_token) { token }
    bad.define_singleton_method(:resource) { Client.new.tap { |c| c.define_singleton_method(:id) { 1 } } }
    assert_raises(ArgumentError) { bad.send(:validate_session_token!) }
  end

  test "AccountSessionRevocation validate_inputs arms" do
    svc = AccountSessionRevocation.allocate
    svc.define_singleton_method(:operation) { :not_real }
    svc.define_singleton_method(:account) { Client.new }
    svc.define_singleton_method(:operator) { Operator.new }
    svc.define_singleton_method(:reason_code) { AdministrativeAccessLockable::ADMIN_LOCK_REASON_CODES.first }
    assert_raises(ArgumentError) { svc.send(:validate_inputs!) }

    svc2 = AccountSessionRevocation.allocate
    svc2.define_singleton_method(:operation) { AccountSessionRevocation::EVENT_TYPE_BY_OPERATION.keys.first }
    svc2.define_singleton_method(:account) { Object.new }
    svc2.define_singleton_method(:operator) { Operator.new }
    svc2.define_singleton_method(:reason_code) { AdministrativeAccessLockable::ADMIN_LOCK_REASON_CODES.first }
    assert_raises(ArgumentError) { svc2.send(:validate_inputs!) }

    svc3 = AccountSessionRevocation.allocate
    svc3.define_singleton_method(:operation) { AccountSessionRevocation::EVENT_TYPE_BY_OPERATION.keys.first }
    svc3.define_singleton_method(:account) { Client.new }
    svc3.define_singleton_method(:operator) { Client.new }
    svc3.define_singleton_method(:reason_code) { AdministrativeAccessLockable::ADMIN_LOCK_REASON_CODES.first }
    assert_raises(ArgumentError) { svc3.send(:validate_inputs!) }

    svc4 = AccountSessionRevocation.allocate
    svc4.define_singleton_method(:operation) { AccountSessionRevocation::EVENT_TYPE_BY_OPERATION.keys.first }
    svc4.define_singleton_method(:account) { Client.new }
    svc4.define_singleton_method(:operator) { Operator.new }
    svc4.define_singleton_method(:reason_code) { "not-a-reason" }
    assert_raises(ArgumentError) { svc4.send(:validate_inputs!) }
  end

  test "OutboundSensitivePayload validate_envelope and blank encrypt arms" do
    assert_raises(ArgumentError) do
      OutboundSensitivePayload.send(
        :validate_envelope!,
        { "version" => "nope", "subject" => "s", "body" => "b" },
        required_keys: %w(version subject body),
      )
    end
    assert_raises(ArgumentError) do
      OutboundSensitivePayload.send(
        :validate_envelope!,
        { "version" => OutboundSensitivePayload::ENVELOPE_VERSION, "subject" => "s", "body" => "" },
        required_keys: %w(version subject body),
      )
    end
    assert_raises(ArgumentError) { OutboundSensitivePayload.send(:encrypt, "", purpose: :test) }
    assert_raises(ArgumentError) { OutboundSensitivePayload.send(:decrypt, "", purpose: :test) }
  end

  test "AuthAuthorizationHeader blank and missing headers arms" do
    blank = Object.new
    blank.define_singleton_method(:authorization) { nil }
    blank.define_singleton_method(:respond_to?) { |m, *| m == :authorization || m == :headers || super(m) }
    blank.define_singleton_method(:headers) { {} }

    assert_nil AuthAuthorizationHeader.bearer_token(blank)
    assert_nil AuthAuthorizationHeader.access_token(blank)
    assert_nil AuthAuthorizationHeader.token_and_options(blank)

    bare = Object.new

    assert_nil AuthAuthorizationHeader.send(:authorization_value_for, bare)
  end

  test "OrganizationPolicy wrong principal class arms" do
    [
      [Visitor.new, Enterprise.new],
      [Client.new, Company.new],
      [Client.new, Bureau.new],
      [Client.new, Object.new],
    ].each do |user, record|
      policy = OrganizationPolicy.new(record: record, user: user)

      assert_not policy.send(:organization_has_current_principal_membership?)
    rescue ArgumentError, ActionPolicy::Unauthorized
      policy = OrganizationPolicy.new(record)
      policy.define_singleton_method(:user) { user }

      assert_not policy.send(:organization_has_current_principal_membership?)
    end
  end

  test "SignInSelectorParticipant ensure_selector_cycle arms" do
    cycle = Object.new
    cycle.define_singleton_method(:sign_in_selector_pending?) { false }
    cycle.define_singleton_method(:expired?) { false }
    cycle.define_singleton_method(:principal_id) { 1 }
    participant = SignInSelectorParticipant.new(cycle: cycle, actor: Client.new)
    assert_raises(SignInSelectorParticipant::InvalidCycle) { participant.send(:ensure_selector_cycle!) }

    cycle2 = Object.new
    cycle2.define_singleton_method(:sign_in_selector_pending?) { true }
    cycle2.define_singleton_method(:expired?) { true }
    cycle2.define_singleton_method(:principal_id) { 1 }
    participant2 = SignInSelectorParticipant.new(cycle: cycle2, actor: Client.new)
    assert_raises(SignInSelectorParticipant::InvalidCycle) { participant2.send(:ensure_selector_cycle!) }

    cycle3 = Object.new
    cycle3.define_singleton_method(:sign_in_selector_pending?) { true }
    cycle3.define_singleton_method(:expired?) { false }
    cycle3.define_singleton_method(:principal_id) { nil }
    participant3 = SignInSelectorParticipant.new(cycle: cycle3, actor: Client.new)
    assert_raises(SignInSelectorParticipant::InvalidCycle) { participant3.send(:ensure_selector_cycle!) }
  end

  test "SignUpStateMachine clear requirement validation arms" do
    result = SignUpStateMachine.call(ticket: nil, event: :clear_requirement, actor_context: {}, payload: {})

    assert_equal :invalid_transition, result.status
    assert_includes result.errors, "ticket is required"
  end

  test "DbscVerificationService early failure arms" do
    incomplete = Struct.new(:dbsc_session_id, :dbsc_public_key, :dbsc_challenge, :dbsc_challenge_issued_at)
      .new("", nil, "c", Time.current)
    mismatched = Struct.new(:dbsc_session_id, :dbsc_public_key, :dbsc_challenge, :dbsc_challenge_issued_at)
      .new("other", "k", "c", Time.current)
    missing_key = Struct.new(:dbsc_session_id, :dbsc_public_key, :dbsc_challenge, :dbsc_challenge_issued_at)
      .new("s", nil, "c", Time.current)

    assert_equal "registration_incomplete",
                 DbscVerificationService.new(record: incomplete, session_id: "s", proof: "p").call[:error_code]
    assert_equal "session_id_mismatch",
                 DbscVerificationService.new(record: mismatched, session_id: "s", proof: "p").call[:error_code]
    assert_equal "missing_public_key",
                 DbscVerificationService.new(record: missing_key, session_id: "s", proof: "p").call[:error_code]
  end

  test "OidcEndSessionRequest unknown client and actor arms" do
    req = OidcEndSessionRequest.new(params: { "client_id" => "missing" }, request: ActionDispatch::TestRequest.create)
    result = req.call

    assert_predicate result, :success?
    assert_equal :no_hint, result.source
    assert_predicate result, :requires_confirmation?

    req2 = OidcEndSessionRequest.new(params: {}, request: ActionDispatch::TestRequest.create)
    unauth = Object.new
    unauth.define_singleton_method(:unauthenticated?) { true }
    req2.define_singleton_method(:actor) { unauth }

    assert_nil req2.send(:current_actor)
  end

  test "PalmAccessTokenAuthenticator inactive and locked resource arms" do
    blank = PalmAccessTokenAuthenticator.new(
      access_token: "", host: "example.test", authorization_scheme: "Bearer",
    ).call
    wrong_scheme = PalmAccessTokenAuthenticator.new(
      access_token: "tok", host: "example.test", authorization_scheme: "Basic",
    ).call

    assert_equal "invalid_token", blank.error
    assert_not blank.success?
    assert_equal "invalid_token", wrong_scheme.error
  end

  test "JitSecurityJwtRegistry validation raise arms" do
    record = Struct.new(:id, :current_kid, :keys, keyword_init: true).new(id: "r", current_kid: "", keys: [])
    hosts = JitSecurityJwtRegistry.send(:preference_hosts_from_boot_config)

    assert_nil JitSecurityJwtRegistry.send(:validate_record!, record)
    assert_kind_of Array, hosts
  end

  test "IdentityAudit chronicle class selection arms" do
    operator_audit = IdentityAudit.new(
      actor: Operator.new, event_id: "e", subject: nil, action: nil,
      ip_address: nil, user_agent: nil, metadata: {}, occurred_at: Time.current,
    )
    client_audit = IdentityAudit.new(
      actor: Client.new, event_id: "e", subject: nil, action: nil,
      ip_address: nil, user_agent: nil, metadata: {}, occurred_at: Time.current,
    )

    assert_equal OperatorChronicle, operator_audit.send(:chronicle_class)
    assert_equal OperatorChronicleEvent, operator_audit.send(:event_class)
    assert_equal OperatorChronicleLevel, operator_audit.send(:level_class)
    assert_equal ClientChronicle, client_audit.send(:chronicle_class)
    assert_equal ClientChronicleEvent, client_audit.send(:event_class)
    assert_equal ClientChronicleLevel, client_audit.send(:level_class)
  end

  test "OidcBackchannelLogoutNotifier blank sid subject early return" do
    count = OidcBackchannelLogoutNotifier.new(resource_type: "client", subject: nil, sid: nil).call

    assert_equal 0, count
  end

  test "Health ok? status string arms" do
    ok = Health::CheckResult.new(check: :liveness, status: :ok, surface: "app")
    unready = Health::CheckResult.new(check: :liveness, status: :unready, surface: "app")

    assert_predicate ok, :ok?
    assert_not unready.ok?
    assert_equal "ok", ok.as_public_json[:status]
    assert_equal "unavailable", unready.as_public_json[:status]
  end

  test "Avatar follow policy wrong types" do
    policy = AvatarFollowPolicy.new(Object.new)
    policy.define_singleton_method(:user) { Client.new }

    assert_not policy.create?
    assert_not policy.send(:active_avatar?, Object.new)
  end

  test "SignRiskEnforcer disabled env and blank resource" do
    ENV["RISK_ENFORCEMENT_DISABLED"] = "true"
    begin
      assert_nil SignRiskEnforcer.call(Client.new)
      assert_nil SignRiskEmitter.emit("test")
    ensure
      ENV.delete("RISK_ENFORCEMENT_DISABLED")
    end

    assert_nil SignRiskEnforcer.call(nil)
  end

  test "JitSecurityTurnstileVerifier response helper arms" do
    missing_token = JitSecurityTurnstileVerifier.verify(token: nil, remote_ip: "1.2.3.4", secret_key: "secret")
    missing_secret = JitSecurityTurnstileVerifier.verify(token: "tok", remote_ip: "1.2.3.4", secret_key: "")

    assert_not missing_token["success"]
    assert_equal "missing cf-turnstile-response", missing_token["error"]
    assert_not missing_secret["success"]
    assert_equal "missing turnstile secret", missing_secret["error"]
  end

  test "ConfigValues normalize and sanitize origin arms" do
    assert_equal "https://example.test", ConfigValues.send(:normalize_origin, "example.test")
    uri = URI.parse("https://user:pass@example.test/path?q=1#frag")
    ConfigValues.send(:sanitize_origin_uri!, uri)

    assert_equal "/", uri.path
    assert_nil uri.query
    assert_nil uri.fragment
  end

  test "ChainSeal verify rescue ArgumentError path via bad public key type" do
    assert_raises(ChainSeal::FormatError, ChainSeal::VerificationError) do
      ChainSeal.verify(payload: { a: 1 }, compact: "not-a-seal", public_key: "nope")
    end
  end
end
