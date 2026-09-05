# typed: false
# frozen_string_literal: true

require "test_helper"

# The sign-up state machine is the only thing that moves a ticket between states,
# so every arm that answers without transitioning matters: an event it does not
# know, a ticket it cannot lock, and a hand-off result it does not recognise all
# have to answer rather than transition, because a wrong transition leaves a
# ticket in a state no later step accepts.
class SignUpStateMachineDispatchTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  setup { ClientSignUpFlowStatus.ensure_defaults! }

  def ticket(status_name = "STARTED", step: "start")
    ClientSignUpFlow.new(
      step: step,
      entry_method: "email",
      status_id: ClientSignUpFlow::STATUS_NAMES.key(status_name),
      issued_at: Time.current,
      expires_at: 1.hour.from_now,
    )
  end

  # `google` is what makes the registry call this ticket social; the app surface is the only one
  # that defines a social entry method at all.
  def social_ticket
    ticket = ticket("SOCIAL_CALLBACK_PENDING", step: "social_callback")
    ticket.entry_method = "google"
    ticket
  end

  test "an event the machine does not know is refused before any ticket is touched" do
    result = SignUpStateMachine.call(ticket: ticket, event: :teleport, actor_context: nil)

    assert_equal :invalid_transition, result.status
    assert_includes result.errors, "unknown event"
  end

  test "a call with no ticket is refused rather than attempted" do
    result = SignUpStateMachine.call(ticket: nil, event: :start, actor_context: nil)

    assert_equal :invalid_transition, result.status
  end

  # An unpersisted ticket has no row to lock, so the decision is evaluated
  # directly. The lock exists to serialise concurrent writers, not to gate the
  # first transition of a ticket that does not exist yet.
  test "an unpersisted ticket is evaluated without taking a row lock" do
    result = SignUpStateMachine.call(ticket: ticket, event: :start, actor_context: nil)

    assert_equal :ok, result.status
    assert_equal :submit_contact, result.next_event
  end

  # Anything that raises inside the evaluation is answered as an invalid
  # transition carrying the reason, rather than propagating out of the machine.
  test "a transition the ticket refuses is answered as invalid rather than raised" do
    result = SignUpStateMachine.call(ticket: ticket("COMPLETED"), event: :submit_contact, actor_context: nil)

    assert_equal :invalid_transition, result.status
    assert_predicate result.errors, :present?
  end

  test "a terminal state is recognised through the ticket's own predicate and by status otherwise" do
    machine = SignUpStateMachine.new(ticket: ticket("COMPLETED"), event: :complete, actor_context: nil)

    assert machine.send(:terminal?)

    without_predicate = SignUpStateMachine.new(ticket: ticket("STARTED"), event: :complete, actor_context: nil)

    assert_not without_predicate.send(:terminal?)
  end

  # A social callback that already carries a sign-in hand-off is handed straight to the hand-off
  # step. Transitioning it to the checkpoint first would ask a signed-in social account for a
  # confirmation it has already given.
  test "a social callback carrying a hand-off skips the checkpoint and goes to the hand-off step" do
    result = SignUpStateMachine.call(
      ticket: social_ticket,
      event: :complete_social_callback,
      actor_context: nil,
      payload: { sign_in_handoff: { "session" => "handed-off" } },
    )

    assert_equal :sign_in_handoff_accepted, result.status
    assert_equal :handoff_to_sign_in, result.next_event
    assert_equal({ "session" => "handed-off" }, result.sign_in_handoff)
  end

  # The hand-off arms that do not transition. `stopped` is a hand-off the sign-in side declined,
  # and an unrecognised status must be refused rather than treated as one of the arms above -
  # either would otherwise leave the ticket in a state no later step accepts.
  test "a stopped hand-off is reported without transitioning the ticket" do
    ticket = ticket("FINALIZED", step: "finalized")

    result = SignUpStateMachine.call(
      ticket: ticket,
      event: :handoff_to_sign_in,
      actor_context: nil,
      payload: { sign_in_handoff_status: :stopped, sign_in_handoff: { "reason" => "limit" } },
    )

    assert_equal :sign_in_handoff_stopped, result.status
    assert_equal({ "reason" => "limit" }, result.sign_in_handoff)
    assert_equal "FINALIZED", ClientSignUpFlow::STATUS_NAMES.fetch(ticket.status_id)
  end

  test "a hand-off status the machine does not recognise is refused" do
    result = SignUpStateMachine.call(
      ticket: ticket("FINALIZED", step: "finalized"),
      event: :handoff_to_sign_in,
      actor_context: nil,
      payload: { sign_in_handoff_status: :teleported, sign_in_handoff: {} },
    )

    assert_equal :invalid_transition, result.status
    assert_includes result.errors, "unknown sign-in handoff status"
  end

  test "a payload that is not a hash is normalised to one rather than carried through" do
    machine = SignUpStateMachine.new(ticket: ticket, event: :start, actor_context: nil, payload: nil)

    assert_empty machine.payload
  end
end
