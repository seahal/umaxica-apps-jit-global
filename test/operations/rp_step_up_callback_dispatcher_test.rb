# frozen_string_literal: true

require "test_helper"

class RpStepUpCallbackDispatcherTest < ActiveSupport::TestCase
  fixtures :clients, :operators
  # Avoid loading unrelated Chronicle fixtures through the suite's inherited `fixtures :all`.
  self.fixture_table_names = %w(clients operators)

  test "known browser and issuer refusals are audited once without changing state" do
    attempt_outboxes = RpStepUpAuditOutbox.where(
      context_ref: @state.public_id, event_type: "step_up.attempt_rejected",
    )

    OidcOpTokenClient.stub(:authorization_code, ->(**) { flunk("invalid correlation must not dispatch") }) do
      foreign = dispatch(browser_binding: "x" * 43)
      repeated_foreign = dispatch(browser_binding: "x" * 43)
      wrong_issuer = dispatch(issuer: "https://other.example")

      assert_equal :invalid, foreign.outcome
      assert_equal "foreign_browser", foreign.reason_code
      assert_equal foreign.outcome, repeated_foreign.outcome
      assert_equal :invalid, wrong_issuer.outcome
      assert_equal "state_mismatch", wrong_issuer.reason_code
    end
    assert_equal RpStepUpStateStatus::PENDING, @state.reload.state_id
    assert_empty @state.transitions
    assert_equal %w(foreign_browser state_mismatch), attempt_outboxes.reload.order(:reason_code).pluck(:reason_code)
    assert_equal 2, attempt_outboxes.count
    assert_nil @session.reload.current_access_jti_digest
    assert_equal 0, @session.installed_generation
  end

  test "another same-client session or grant cannot consume the pending request" do
    other_sid = SecureRandom.alphanumeric(21)
    other_session = RpCallbackCommitter.call(
      cell: @cell,
      issuer: @issuer,
      subject: @subject,
      sid: other_sid,
      absolute_expires_at: 1.hour.from_now,
    ).session
    other_access_state = BrowserRpAuthentication::AccessState.new(
      status: :valid,
      resource: @principal,
      rp_session: other_session,
      payload: @access_state.payload.merge("sid" => other_sid),
      security_context: nil,
    )
    wrong_grant_state = BrowserRpAuthentication::AccessState.new(
      status: :valid,
      resource: @principal,
      rp_session: @session,
      payload: @access_state.payload.merge("sid" => other_sid),
      security_context: nil,
    )
    attempt_outboxes = RpStepUpAuditOutbox.where(
      context_ref: @state.public_id, event_type: "step_up.attempt_rejected",
    )

    OidcOpTokenClient.stub(:authorization_code, ->(**) { flunk("invalid grant must not dispatch") }) do
      wrong_session = dispatch(access_state: other_access_state)
      wrong_grant = dispatch(access_state: wrong_grant_state)

      assert_equal :invalid, wrong_session.outcome
      assert_equal :invalid, wrong_grant.outcome
    end

    assert_equal RpStepUpStateStatus::PENDING, @state.reload.state_id
    assert_empty @state.transitions
    assert_equal ["state_mismatch"], attempt_outboxes.reload.pluck(:reason_code).uniq
    assert_equal 1, attempt_outboxes.count
    assert_equal 0, @session.reload.installed_generation
    assert_nil @session.current_access_jti_digest
  end

  test "a duplicate error response after dispatch conflicts without another token request" do
    calls = 0
    refusal = OidcOpTokenClient::Result.new(outcome: :refused, token_response: nil, error: "invalid_grant")
    OidcOpTokenClient.stub(
      :authorization_code, ->(**) {
                             calls += 1
                             refusal
                           },
    ) do
      first = dispatch
      second = dispatch(code: nil, error: "access_denied")
      repeated_second = dispatch(code: nil, error: "access_denied")

      assert_equal :refused, first.outcome
      assert_equal "op_error", first.reason_code
      assert_equal :conflict, second.outcome
      assert_equal "duplicate_callback", second.reason_code
      assert_equal second.outcome, repeated_second.outcome
    end

    assert_equal 1, calls
    assert_equal RpStepUpStateStatus::REFUSED, @state.reload.state_id
    assert_equal %w(dispatch_started op_error), @state.transitions.order(:id).pluck(:reason_code)
    assert_equal 1, RpStepUpAuditOutbox.where(context_ref: @state.public_id, event_type: "step_up.refused").count
    duplicate_audits = RpStepUpAuditOutbox.where(
      context_ref: @state.public_id, event_type: "step_up.attempt_rejected", reason_code: "duplicate_callback",
    )

    assert_equal 1, duplicate_audits.count
    assert_equal(
      { "context_ref" => @state.public_id, "rejection_code" => "duplicate_callback" },
      duplicate_audits.sole.payload,
    )
    assert_equal 0, @session.reload.installed_generation
  end

  test "unknown, expired, and logged-out flows do not create refusal audit rows" do
    attempt_outboxes = RpStepUpAuditOutbox.where(
      context_ref: @state.public_id, event_type: "step_up.attempt_rejected",
    )

    unknown = dispatch(state_token: SecureRandom.urlsafe_base64(32))
    @state.update!(expires_at: RpBaseAppRecord.database_now - 1.second)
    expired = dispatch(browser_binding: "x" * 43)

    @state.update!(expires_at: RpBaseAppRecord.database_now + 10.minutes)
    binding = RpBaseAppOpSessionBinding.find(@session.op_session_binding_id)
    binding.revoke!
    logged_out = dispatch(browser_binding: "x" * 43)

    assert_equal :invalid, unknown.outcome
    assert_equal "invalid_state", unknown.reason_code
    assert_equal :invalid, expired.outcome
    assert_equal "invalid_state", expired.reason_code
    assert_equal :invalid, logged_out.outcome
    assert_empty attempt_outboxes
    assert_equal RpStepUpStateStatus::PENDING, @state.reload.state_id
    assert_empty @state.transitions
  end

  test "ORG callback refusals use the separate ORG RP audit outbox" do
    @actor = operators(:one)
    @cell = RpCellBinding.fetch("rp_base_org")
    @issuer = OidcIssuer.for_resource_type("operator")
    @subject = OidcSubject.for(@actor, resource_type: "operator")
    @sid = SecureRandom.alphanumeric(21)
    @browser_binding = SecureRandom.urlsafe_base64(32)
    @session = RpCallbackCommitter.call(
      cell: @cell, issuer: @issuer, subject: @subject, sid: @sid, absolute_expires_at: 1.hour.from_now,
    ).session
    binding = RpBaseOrgOpSessionBinding.includes(identity_binding: :principal).find(@session.op_session_binding_id)
    @principal = binding.identity_binding.principal
    @access_state = BrowserRpAuthentication::AccessState.new(
      status: :valid,
      resource: @principal,
      rp_session: @session,
      payload: {
        "iss" => @issuer,
        "aud" => [@cell.client_id],
        "sid" => @sid,
        "sub" => @subject,
        "client_id" => @cell.client_id,
        "authn_ctx" => AuthenticationContextValue::NORMAL_KEY,
      },
      security_context: nil,
    )
    started = RpStepUpStartIssuer.call(
      cell: @cell,
      access_state: @access_state,
      actor: @actor,
      browser_binding: @browser_binding,
      return_target: "/settings/security",
    )
    @state = RpBaseOrgStepUpState.find_by!(public_id: started.state_ref)
    @state_token = Rack::Utils.parse_nested_query(URI.parse(started.authorization_url).query).fetch("state")

    result = dispatch(browser_binding: "x" * 43)
    outbox = RpBaseOrgStepUpAuditOutbox.find_by!(
      context_ref: @state.public_id, event_type: "step_up.attempt_rejected",
    )

    assert_equal :invalid, result.outcome
    assert_equal "foreign_browser", result.reason_code
    assert_equal "ORG", outbox.realm
    assert_equal "foreign_browser", outbox.reason_code
    assert_equal({ "context_ref" => @state.public_id, "rejection_code" => "foreign_browser" }, outbox.payload)
    assert_empty RpStepUpAuditOutbox.where(context_ref: @state.public_id, event_type: "step_up.attempt_rejected")
    assert_equal RpBaseOrgStepUpStateStatus::PENDING, @state.reload.state_id
    assert_empty @state.transitions
  end

  test "a valid response installs once in the initiating RP session and preserves its identifier" do
    expectation = nil
    dispatches = 0
    token_response = signed_step_up_response
    success = OidcOpTokenClient::Result.new(outcome: :success, token_response:, error: nil)
    OidcOpTokenClient.stub(
      :authorization_code, lambda { |**arguments|
                             dispatches += 1
                             expectation = arguments.fetch(:step_up_expectation)
                             success
                           },
    ) do
      OidcOpJwksClient.stub(:for_resource_type, jwks_client) do
        result = dispatch

        assert_equal :installed, result.outcome
        assert_equal token_response, result.token_response
      end
    end

    assert_equal 1, dispatches
    assert_equal @sid, expectation.grant
    assert_equal @subject, expectation.subject
    assert_equal RpStepUpStateStatus::INSTALLED, @state.reload.state_id
    assert_equal 1, @session.reload.installed_generation
    assert_equal Digest::SHA256.hexdigest("step-up-access-jti"), @session.current_access_jti_digest
    assert_equal @session_public_id, @session.public_id
    assert_equal "step_up.installed",
                 RpStepUpAuditOutbox.find_by!(context_ref: @state.public_id, event_type: "step_up.installed").event_type
    assert_equal 2, @state.transitions.count
  end

  test "a late successful token response after the dispatch deadline is not installed" do
    token_response = signed_step_up_response
    success = OidcOpTokenClient::Result.new(outcome: :success, token_response:, error: nil)
    calls = 0
    OidcOpTokenClient.stub(
      :authorization_code, lambda { |**|
                             calls += 1
                             dispatch_transition = @state.transitions.find_by!(to_state_id: RpStepUpStateStatus::DISPATCHING)
                             dispatch_transition.update!(occurred_at: RpBaseAppRecord.database_now - 61.seconds)
                             success
                           },
    ) do
      OidcOpJwksClient.stub(:for_resource_type, jwks_client) do
        result = dispatch

        assert_equal :indeterminate, result.outcome
        assert_nil result.token_response
      end
    end

    assert_equal 1, calls
    assert_equal RpStepUpStateStatus::INDETERMINATE, @state.reload.state_id
    assert_equal 0, @session.reload.installed_generation
    assert_nil @session.current_access_jti_digest
    assert_equal "dispatch_deadline_passed",
                 RpStepUpAuditOutbox.find_by!(context_ref: @state.public_id, event_type: "step_up.indeterminate")
                   .reason_code
  end

  private

  def setup
    @actor = clients(:one)
    @cell = RpCellBinding.fetch("rp_base_app")
    @issuer = OidcIssuer.for_resource_type("client")
    @subject = OidcSubject.for(@actor, resource_type: "client")
    @sid = SecureRandom.alphanumeric(21)
    @browser_binding = SecureRandom.urlsafe_base64(32)
    @session = RpCallbackCommitter.call(
      cell: @cell, issuer: @issuer, subject: @subject, sid: @sid, absolute_expires_at: 1.hour.from_now,
    ).session
    @session_public_id = @session.public_id
    binding = RpBaseAppOpSessionBinding.includes(identity_binding: :principal).find(@session.op_session_binding_id)
    @principal = binding.identity_binding.principal
    @access_state = BrowserRpAuthentication::AccessState.new(
      status: :valid,
      resource: @principal,
      rp_session: @session,
      payload: {
        "iss" => @issuer,
        "aud" => [@cell.client_id],
        "sid" => @sid,
        "sub" => @subject,
        "client_id" => @cell.client_id,
        "authn_ctx" => AuthenticationContextValue::NORMAL_KEY,
      },
      security_context: nil,
    )
    started = RpStepUpStartIssuer.call(
      cell: @cell,
      access_state: @access_state,
      actor: @actor,
      browser_binding: @browser_binding,
      return_target: "/settings/security",
    )
    @state = RpStepUpState.find_by!(public_id: started.state_ref)
    query = Rack::Utils.parse_nested_query(URI.parse(started.authorization_url).query)
    @state_token = query.fetch("state")
    @nonce = query.fetch("nonce")
  end

  def dispatch(
    access_state: @access_state,
    browser_binding: @browser_binding,
    issuer: @issuer,
    state_token: @state_token,
    code: "single-use-code",
    error: nil
  )
    RpStepUpCallbackDispatcher.call(
      cell: @cell,
      access_state:,
      actor: @actor,
      browser_binding:,
      state_token:,
      issuer:,
      code:,
      error:,
    )
  end

  def signed_step_up_response
    key = OpenSSL::PKey::EC.generate("secp384r1")
    now = Time.current.to_i
    evidence = evidence_claims(now)
    access_token = encode_token(
      access_token_payload(now:, evidence:), key:, kid: "step-up-test", typ: OidcOpAccessTokenVerifier::TOKEN_TYPE,
    )
    id_token = encode_token(
      id_token_payload(now:, evidence:), key:, kid: "step-up-test", typ: OidcOpIdTokenVerifier::TOKEN_TYPE,
    )
    jwk = JitSecurityJwtJwk.export_public(key, kid: "step-up-test")
    @jwks_document = { "keys" => [jwk] }
    {
      access_token:,
      id_token:,
      refresh_token: "step-up-refresh-token",
      expires_in: 300,
      refresh_token_expires_in: 3600,
    }.with_indifferent_access
  end

  def evidence_claims(now)
    {
      "acr" => RpStepUpStartIssuer::STEP_UP_ACR,
      "amr" => ["passkey"],
      "auth_time" => now - 1,
    }
  end

  def access_token_payload(now:, evidence:)
    {
      "iss" => @issuer,
      "aud" => [@cell.client_id],
      "exp" => now + 300,
      "nbf" => now - 5,
      "iat" => now - 1,
      "sub" => @subject,
      "sid" => @sid,
      "client_id" => @cell.client_id,
      "jti" => "step-up-access-jti",
      "scope" => "openid domain:client read:self",
      "authn_ctx" => "normal",
    }.merge(evidence)
  end

  def id_token_payload(now:, evidence:)
    {
      "iss" => @issuer,
      "aud" => [@cell.client_id],
      "exp" => now + 300,
      "nbf" => now - 5,
      "iat" => now - 1,
      "sub" => @subject,
      "nonce" => @nonce,
      "jti" => "step-up-id-jti",
      "sid" => @sid,
      "typ" => OidcOpIdTokenVerifier::TOKEN_TYPE,
      "act" => "client",
    }.merge(evidence)
  end

  def encode_token(payload, key:, kid:, typ:)
    JWT.encode(payload, key, "ES384", { "kid" => kid, "typ" => typ })
  end

  def jwks_client
    OidcOpJwksClient.new(
      jwks_uri: "#{@issuer}/.well-known/jwks.json",
      fetcher: -> { @jwks_document },
      limiter: OidcJwksRefetchLimiter.new(connection: UnavailableValkey.new),
    )
  end

  class UnavailableValkey
    def key(suffix) = "test:#{suffix}"

    def call(*) = raise(Umaxica::Valkey::Unavailable, "unavailable")
  end
end
