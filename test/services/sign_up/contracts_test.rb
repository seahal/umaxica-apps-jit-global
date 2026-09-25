# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class SignUpContractsTest < ActiveSupport::TestCase
  test "result normalizes allowed statuses and rejects unknown statuses" do
    result = SignUpResult.build(status: "advanced", errors: "next step")

    assert_equal :advanced, result.status
    assert_predicate result, :success?
    assert_equal ["next step"], result.errors
    assert_not result.cleanup_required?

    assert_raises(ArgumentError) { SignUpResult.build(status: :unknown) }
  end

  test "requirement registry exposes app entry requirements" do
    assert_equal %i(otp birthdate),
                 SignUpRequirementRegistry.for_entry(surface: :app, entry_method: "email").requirements
    assert_equal(
      %i(otp passkey birthdate),
      SignUpRequirementRegistry.for_entry(surface: :app, entry_method: "telephone").requirements,
    )
    assert_not SignUpRequirementRegistry.for_entry(surface: :app, entry_method: "telephone").requirement?(:passcode)
    assert_equal %i(confirmation birthdate),
                 SignUpRequirementRegistry.for_entry(surface: :app, entry_method: "google").requirements
    assert_equal %i(confirmation birthdate),
                 SignUpRequirementRegistry.for_entry(surface: :app, entry_method: "apple").requirements
    assert_predicate SignUpRequirementRegistry.for_entry(surface: :app, entry_method: "google"), :social?
    assert_predicate SignUpRequirementRegistry.for_entry(surface: :app, entry_method: "apple"), :social?
  end

  test "requirement registry rejects com social entry methods" do
    assert_equal %i(otp birthdate),
                 SignUpRequirementRegistry.for_entry(surface: :com, entry_method: "email").requirements
    assert_equal(
      %i(otp passkey birthdate),
      SignUpRequirementRegistry.for_entry(surface: :com, entry_method: "telephone").requirements,
    )
    assert_not SignUpRequirementRegistry.for_entry(surface: :com, entry_method: "telephone").requirement?(:passcode)

    assert_raises(ArgumentError) { SignUpRequirementRegistry.for_entry(surface: :com, entry_method: "google") }
    assert_raises(ArgumentError) { SignUpRequirementRegistry.for_entry(surface: :com, entry_method: "apple") }
  end

  test "requirement registry rejects unknown surfaces" do
    assert_raises(ArgumentError) { SignUpRequirementRegistry.for_entry(surface: :org, entry_method: "email") }
  end

  test "requirement registry derives surface from ticket class" do
    app_ticket = build_cycle(ClientSignUpFlow, entry_method: "google")
    com_ticket = build_cycle(VisitorSignUpFlow, entry_method: "telephone")

    assert_equal :app, SignUpRequirementRegistry.for_ticket(app_ticket).surface
    assert_equal :com, SignUpRequirementRegistry.for_ticket(com_ticket).surface
  end

  test "policy context copies step and entry method from ticket" do
    ticket = build_cycle(ClientSignUpFlow, entry_method: "email", step: "checkpoint")
    context = SignUpPolicyContext.build(surface: :app, actor_authentication: nil, ticket: ticket)

    assert_equal :app, context.surface
    assert_equal "checkpoint", context.step
    assert_equal "email", context.entry_method
  end

  test "requirement context accepts only requirements for the ticket entry method" do
    ticket = build_cycle(ClientSignUpFlow, entry_method: "email")

    context = SignUpRequirementContext.build(
      surface: :app,
      actor_authentication: nil,
      ticket: ticket,
      requirement: :birthdate,
    )

    assert_equal :birthdate, context.requirement
    assert_raises(ArgumentError) do
      SignUpRequirementContext.build(
        surface: :app,
        actor_authentication: nil,
        ticket: ticket,
        requirement: :passkey,
      )
    end
  end

  test "finalization context requires all entry requirements to be clear" do
    ticket = build_cycle(
      ClientSignUpFlow,
      entry_method: "telephone",
      completed_requirements: {
        "otp" => { "cleared" => true },
        "birthdate" => { "cleared" => true },
        "passkey" => { "cleared" => true },
      },
    )

    context = SignUpFinalizationContext.build(
      surface: :app,
      actor_authentication: nil,
      ticket: ticket,
      pending_actor: Object.new,
    )

    assert_equal :app, context.surface

    ticket.completed_requirements.delete("birthdate")
    assert_raises(ArgumentError) do
      SignUpFinalizationContext.build(
        surface: :app,
        actor_authentication: nil,
        ticket: ticket,
        pending_actor: Object.new,
      )
    end
  end

  test "requirement registry rejects unsupported ticket class" do
    assert_raises(ArgumentError, match: /unsupported sign-up ticket class/) do
      SignUpRequirementRegistry.surface_for_ticket(Object.new)
    end
  end

  test "state machine protocol rejects unknown events before core wiring" do
    ticket = build_cycle(ClientSignUpFlow, entry_method: "email")

    result = SignUpStateMachine.call(ticket: ticket, event: :bogus, actor_context: nil)

    assert_equal :invalid_transition, result.status
    assert_predicate result, :failure?
    assert_equal ticket, result.ticket
  end

  test "state machine protocol returns a typed result for known events" do
    ticket = create_cycle(ClientSignUpFlow, entry_method: "email")

    result = SignUpStateMachine.call(ticket: ticket, event: :submit_contact, actor_context: nil)

    assert_equal :advanced, result.status
    assert_equal :verify_contact, result.next_event
    assert_equal ticket, result.ticket
  end

  private

  def create_cycle(cycle_class, attrs = {})
    cycle_class.create!(cycle_attrs(cycle_class).merge(attrs))
  end

  def build_cycle(cycle_class, attrs = {})
    cycle_class.new(cycle_attrs(cycle_class).merge(attrs))
  end

  def cycle_attrs(cycle_class)
    {
      principal_id: 123,
      status_id: cycle_class::STATUS_IDS.first,
      step: cycle_class::STEPS.first,
      nonce_digest: cycle_class.digest_nonce("nonce"),
      issued_at: Time.current,
      expires_at: 15.minutes.from_now,
      entry_method: default_entry_method(cycle_class),
    }
  end

  def default_entry_method(_cycle_class)
    "email"
  end
end
