# typed: false
# frozen_string_literal: true

require "test_helper"

# A WebAuthn challenge is bound to a surface, relying party, origin, purpose and
# a single use, and actor-known paths may carry the acting account while discoverable direct
# sign-in leaves that binding nil until credential verification.
# Every binding it fails has to raise its own type, because the caller answers
# differently for a replayed challenge than for one issued for another purpose.
# The jump gateway is the same idea for a token it is asked to forward.
class ChallengeStoreAndJumpGatewayRefusalsTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  ORIGIN = "https://auth.umaxica.app"
  RP_ID = "auth.umaxica.app"

  def store(session = {})
    Webauthn::ChallengeStore.new(session)
  end

  def issue(session, purpose: :registration, actor_global_key: "client:1")
    store(session).issue!(
      challenge: "challenge-bytes", purpose: purpose, surface: :app,
      rp_id: RP_ID, origin: ORIGIN, actor_global_key: actor_global_key,
    )
  end

  def consume(session, id, purpose: :registration)
    store(session).consume_with_actor!(id, purpose: purpose, surface: :app, rp_id: RP_ID, origin: ORIGIN)
  end

  test "a challenge is consumable once and carries the acting account back" do
    session = {}
    id = issue(session)

    consumed = consume(session, id)

    assert_equal "challenge-bytes", consumed.challenge
    assert_equal "client:1", consumed.actor_global_key
    assert_raises(Webauthn::ChallengeStore::ChallengeNotFoundError) { consume(session, id) }
  end

  test "a challenge issued for another purpose is refused as a mismatch, not as missing" do
    session = {}
    id = issue(session, purpose: :registration)

    assert_raises(Webauthn::ChallengeStore::ChallengePurposeMismatchError) do
      consume(session, id, purpose: :step_up)
    end
  end

  test "an expired challenge is refused as expired rather than as missing" do
    session = {}
    id = issue(session)
    session[Webauthn::ChallengeStore::SESSION_KEY][id]["expires_at"] = 1.hour.ago.to_i

    assert_raises(Webauthn::ChallengeStore::ChallengeExpiredError) { consume(session, id) }
  end

  test "a challenge bound to another relying party is refused as a binding mismatch" do
    session = {}
    id = issue(session)

    assert_raises(Webauthn::ChallengeStore::ChallengeBindingMismatchError) do
      store(session).consume_with_actor!(
        id, purpose: :registration, surface: :app, rp_id: "evil.example.com", origin: ORIGIN,
      )
    end
  end

  # The gateway forwards a token it does not read, so the only thing it can check
  # is the shape. Each refusal is a token that could not have been issued here.
  test "a jump token of the wrong shape is refused by the reason it failed" do
    {
      "" => :blank_token,
      "short.token.here" => :token_too_short,
      ("a" * 70) => :malformed_token,
    }.each do |token, reason|
      result = RedirectsJumpGatewayUrl.call(token)

      assert_not result.ok?, token.inspect
      assert_equal reason.to_s, result.failure_reason, token.inspect
    end
  end

  test "a jump token carrying a control character is refused before its shape is read" do
    result = RedirectsJumpGatewayUrl.call("abc\u0000def" + ("a" * 70))

    assert_not result.ok?
    assert_equal "control_char", result.failure_reason
  end

  test "a well-formed jump token is forwarded to the gateway origin as the rt parameter" do
    token = "#{"a" * 30}.#{"b" * 30}.#{"c" * 30}"
    result = RedirectsJumpGatewayUrl.call(token)

    assert_predicate result, :ok?
    assert_includes result.value, "rt=#{token}"
    assert_match(%r{\Ahttps?://}, result.value)
  end
end
