# typed: false
# frozen_string_literal: true

require "test_helper"

# Unit tops for still-cold raise/return arms needed to clear the 90% branch floor.
class BranchCoverageBatch32ThresholdPushTest < ActiveSupport::TestCase
  self.fixture_table_names = []

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

  test "ChainSeal verify rescue ArgumentError path via bad public key type" do
    assert_raises(ChainSeal::FormatError, ChainSeal::VerificationError) do
      ChainSeal.verify(payload: { a: 1 }, compact: "not-a-seal", public_key: "nope")
    end
  end
end
