# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class SignInSequenceCarrierTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  ClientStub = Struct.new(:id)

  test "stores sequence state in a surface-local session key" do
    session = {}
    actor = ClientStub.new(42)

    sequence = SignInSequenceCarrier.new(session, surface: :app).start!(
      surface: :app,
      actor: actor,
      method: :email_otp,
      state: "CHECKPOINT_PENDING",
      participant: :checkpoint,
      pt: "/settings",
    )

    assert_equal sequence.id, session.fetch(:app_sign_in_sequence).fetch("id")
    assert_nil session[:com_sign_in_sequence]
    assert_nil session[SignInSequenceCarrier::KEY]
  end

  test "does not expose another surface sequence as current" do
    session = {}
    actor = ClientStub.new(42)

    SignInSequenceCarrier.new(session, surface: :app).start!(
      surface: :app,
      actor: actor,
      method: :email_otp,
      state: "CHECKPOINT_PENDING",
      participant: :checkpoint,
      pt: nil,
    )

    assert_predicate SignInSequenceCarrier.new(session, surface: :app).current, :present?
    assert_not SignInSequenceCarrier.new(session, surface: :com).current.present?
  end

  test "terminal sequence is not valid for a participant" do
    session = {}
    actor = ClientStub.new(42)
    carrier = SignInSequenceCarrier.new(session, surface: :app)

    carrier.start!(
      surface: :app,
      actor: actor,
      method: :email_otp,
      state: "CHECKPOINT_PENDING",
      participant: :checkpoint,
      pt: nil,
    )
    sequence = carrier.halt!

    assert_predicate sequence, :terminal?
    assert_not sequence.valid_for?(surface: :app, actor: actor, participant: :checkpoint)
  end

  test "legacy key is migrated only for matching surface" do
    session = {
      SignInSequenceCarrier::KEY => {
        "id" => SecureRandom.uuid,
        "surface" => "app",
        "actor_type" => ClientStub.name,
        "actor_id" => 42,
        "state" => "CHECKPOINT_PENDING",
        "participant" => "checkpoint",
        "expires_at" => 10.minutes.from_now.iso8601,
      },
    }

    assert_not SignInSequenceCarrier.new(session, surface: :com).current.present?
    assert_predicate SignInSequenceCarrier.new(session, surface: :app).current, :present?
    assert_nil session[SignInSequenceCarrier::KEY]
  end

  test "unsupported surface does not fall back to app" do
    session = {}
    actor = ClientStub.new(42)

    assert_raises(ArgumentError) do
      SignInSequenceCarrier.new(session, surface: :net).start!(
        surface: :net,
        actor: actor,
        method: :email_otp,
        state: "CHECKPOINT_PENDING",
        participant: :checkpoint,
        pt: nil,
      )
    end

    assert_not SignInSequenceCarrier.new(session, surface: :net).current.present?
    assert_nil session[:app_sign_in_sequence]
  end

  test "unsupported state and participant are rejected" do
    session = {}
    actor = ClientStub.new(42)
    carrier = SignInSequenceCarrier.new(session, surface: :app)

    assert_raises(ArgumentError) do
      carrier.start!(
        surface: :app,
        actor: actor,
        method: :email_otp,
        state: "BOGUS",
        participant: :checkpoint,
        pt: nil,
      )
    end

    assert_raises(ArgumentError) do
      carrier.start!(
        surface: :app,
        actor: actor,
        method: :email_otp,
        state: "CHECKPOINT_PENDING",
        participant: :unknown,
        pt: nil,
      )
    end
  end

  test "advances a live sequence and preserves reference values" do
    session = {}
    actor = ClientStub.new(42)
    carrier = SignInSequenceCarrier.new(session, surface: :app)
    carrier.start!(
      surface: :app,
      actor: actor,
      method: :email_otp,
      state: "CHECKPOINT_PENDING",
      participant: :checkpoint,
      pt: nil,
    )

    sequence = carrier.advance!(
      state: "MFA_PENDING",
      participant: :guardrail,
      mfa_challenge_id: "challenge-1",
    )

    assert_equal "MFA_PENDING", sequence.state
    assert_equal "guardrail", sequence.participant
    assert_equal "challenge-1", sequence.payload["mfa_challenge_id"]
    assert_equal sequence.payload, session.fetch(:app_sign_in_sequence)
  end

  test "advance rejects unsupported values and leaves terminal sequences unchanged" do
    session = {}
    actor = ClientStub.new(42)
    carrier = SignInSequenceCarrier.new(session, surface: :app)

    assert_predicate carrier.advance!(state: "MFA_PENDING", participant: :guardrail), :blank?

    carrier.start!(
      surface: :app,
      actor: actor,
      method: :email_otp,
      state: "CHECKPOINT_PENDING",
      participant: :checkpoint,
      pt: nil,
    )
    terminal = carrier.complete!

    assert_equal terminal.payload, carrier.advance!(state: "MFA_PENDING", participant: :guardrail).payload

    carrier.start!(
      surface: :app,
      actor: actor,
      method: :email_otp,
      state: "CHECKPOINT_PENDING",
      participant: :checkpoint,
      pt: nil,
    )
    assert_raises(ArgumentError) { carrier.advance!(state: "BOGUS", participant: :guardrail) }
    assert_raises(ArgumentError) { carrier.advance!(state: "MFA_PENDING", participant: :unknown) }
  end

  test "expire and clear remove every compatible session key" do
    session = {}
    actor = ClientStub.new(42)
    carrier = SignInSequenceCarrier.new(session, surface: :app)
    carrier.start!(
      surface: :app,
      actor: actor,
      method: :email_otp,
      state: "CHECKPOINT_PENDING",
      participant: :checkpoint,
      pt: nil,
    )

    expired = carrier.expire!

    assert_equal "EXPIRED", expired.terminal_state

    session[SignInSequenceCarrier::KEY] = { "surface" => "app" }
    carrier.clear!

    assert_nil session[:app_sign_in_sequence]
    assert_nil session[SignInSequenceCarrier::KEY]
  end
end
