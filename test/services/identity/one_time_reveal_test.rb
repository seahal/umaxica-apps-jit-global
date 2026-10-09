# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class IdentityOneTimeRevealTest < ActiveSupport::TestCase
  fixtures :clients

  test "reveals value once for matching actor session and purpose" do
    actor = clients(:one)
    issued = IdentityOneTimeReveal.issue!(
      actor: actor,
      session_nonce: "session-1",
      value: "secret_credential-value",
      purpose: "test.reveal",
      metadata: { source: "test" },
    )

    reveal = IdentityOneTimeReveal.consume!(
      actor: actor,
      session_nonce: "session-1",
      token: issued.token,
      purpose: "test.reveal",
    )

    assert_equal "secret_credential-value", reveal.value
    assert_equal "test", reveal.metadata["source"]

    second_reveal = IdentityOneTimeReveal.consume!(
      actor: actor,
      session_nonce: "session-1",
      token: issued.token,
      purpose: "test.reveal",
    )

    assert_nil second_reveal
  end

  test "rejects mismatched session" do
    actor = clients(:one)
    issued = IdentityOneTimeReveal.issue!(
      actor: actor,
      session_nonce: "session-1",
      value: "secret_credential-value",
      purpose: "test.reveal",
    )

    reveal = IdentityOneTimeReveal.consume!(
      actor: actor,
      session_nonce: "session-2",
      token: issued.token,
      purpose: "test.reveal",
    )

    assert_nil reveal
  end

  test "issue! refuses a missing actor session value or purpose" do
    actor = clients(:one)

    error =
      assert_raises(ArgumentError) do
        IdentityOneTimeReveal.issue!(
          actor: nil, session_nonce: "session-1", value: "secret", purpose: "test.reveal",
        )
      end
    assert_includes error.message, "actor is required"

    error =
      assert_raises(ArgumentError) do
        IdentityOneTimeReveal.issue!(
          actor: actor, session_nonce: "", value: "secret", purpose: "test.reveal",
        )
      end
    assert_includes error.message, "session_nonce is required"

    error =
      assert_raises(ArgumentError) do
        IdentityOneTimeReveal.issue!(
          actor: actor, session_nonce: "session-1", value: "", purpose: "test.reveal",
        )
      end
    assert_includes error.message, "value is required"

    error =
      assert_raises(ArgumentError) do
        IdentityOneTimeReveal.issue!(
          actor: actor, session_nonce: "session-1", value: "secret", purpose: "",
        )
      end
    assert_includes error.message, "purpose is required"
  end

  test "returns nil for malformed/invalid token signature" do
    actor = clients(:one)
    reveal = IdentityOneTimeReveal.consume!(
      actor: actor,
      session_nonce: "session-1",
      token: "completely-malformed-token-or-signature",
      purpose: "test.reveal",
    )

    assert_nil reveal
  end

  test "expired reveal remains unavailable even when its PostgreSQL row exists" do
    actor = clients(:one)
    issued = IdentityOneTimeReveal.issue!(
      actor: actor,
      session_nonce: "session-1",
      value: "secret_credential-value",
      purpose: "test.reveal",
      expires_in: 1.second,
    )

    travel 2.seconds do
      assert_nil IdentityOneTimeReveal.consume!(
        actor: actor,
        session_nonce: "session-1",
        token: issued.token,
        purpose: "test.reveal",
      )
    end
  end
  test "operation retry preserves one delivery and refuses foreign bindings and consumed evidence" do
    actor = clients(:one)
    operation = SecureRandom.uuid
    issued = IdentityOneTimeReveal.issue!(
      actor: actor, session_nonce: "original-browser", value: ["first", "second"], purpose: "test.operation",
      metadata: { delivery_operation_ref: operation, source: "signup" },
    )
    record = SecurityOneTimeReveal.where(actor_id: actor.id, purpose: "test.operation").sole
    facts = record.attributes
    resume_arguments = {
      actor: actor, session_nonce: "original-browser", purpose: "test.operation", operation_ref: operation,
    }
    resumed = IdentityOneTimeReveal.resume_for_operation!(**resume_arguments)

    assert_equal issued.token, resumed.token
    assert_equal record.expires_at, resumed.expires_at
    assert_equal facts, record.reload.attributes
    [{ actor: clients(:two) }, { session_nonce: "other-browser" }, { purpose: "other-purpose" },
     { operation_ref: SecureRandom.uuid },].each do |replacement|
      assert_nil IdentityOneTimeReveal.resume_for_operation!(**resume_arguments.merge(replacement))
    end
    [nil, ""].each do |missing|
      assert_raises(ArgumentError) do
        IdentityOneTimeReveal.resume_for_operation!(**resume_arguments.merge(operation_ref: missing))
      end
    end
    assert_equal facts, record.reload.attributes
    revealed = IdentityOneTimeReveal.consume!(
      actor: actor, session_nonce: "original-browser", token: resumed.token, purpose: "test.operation",
    )

    assert_equal ["first", "second"], revealed.value
    assert_equal({ "source" => "signup" }, revealed.metadata)
    assert_nil IdentityOneTimeReveal.resume_for_operation!(**resume_arguments)
    assert_equal 1, SecurityOneTimeReveal.where(actor_id: actor.id, purpose: "test.operation").count
  end

  test "operation retry respects the persisted deadline immediately below at and above expiry" do
    actor = clients(:one)
    operation = SecureRandom.uuid
    issued = IdentityOneTimeReveal.issue!(
      actor: actor, session_nonce: "browser", value: "value", purpose: "test.operation.expiry",
      metadata: { delivery_operation_ref: operation },
    )
    record = SecurityOneTimeReveal.where(actor_id: actor.id, purpose: "test.operation.expiry").sole
    facts = record.attributes
    [-1, 0, 1].each do |microseconds|
      now = record.expires_at + Rational(microseconds, 1_000_000)
      resumed =
        SecurityOneTimeReveal.stub(:database_now, now) do
          IdentityOneTimeReveal.resume_for_operation!(
            actor: actor, session_nonce: "browser", purpose: "test.operation.expiry", operation_ref: operation,
          )
        end
      if microseconds.negative?
        assert_equal issued.token, resumed.token
      else
        assert_nil resumed
      end

      assert_equal facts, record.reload.attributes
    end
  end
end
