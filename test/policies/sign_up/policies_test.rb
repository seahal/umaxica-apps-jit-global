# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class SignUpPoliciesTest < ActiveSupport::TestCase
  AuthFacts =
    Data.define(:signed_in, :active_sign_sequence_id) do
      def signed_in?
        signed_in
      end
    end

  PendingActor = Data.define(:id)

  test "ticket policy rejects signed-in actors from starting sign-up" do
    context = SignUpPolicyContext.build(
      surface: :app,
      actor_authentication: auth(signed_in: true),
      ticket: nil,
    )

    assert_not_predicate SignUp::TicketPolicy.new(context, user: nil), :start?
  end

  test "ticket policy allows anonymous start" do
    context = SignUpPolicyContext.build(
      surface: :app,
      actor_authentication: auth(signed_in: false),
      ticket: nil,
    )

    assert_predicate SignUp::TicketPolicy.new(context, user: nil), :start?
  end

  test "ticket policy requires sequence binding for existing tickets" do
    ticket = build_ticket(ClientSignUpFlow, entry_method: "email", step: "start")
    bound_context = policy_context(ticket, auth: auth(active_sign_sequence_id: ticket.public_id))
    unbound_context = policy_context(ticket, auth: auth(active_sign_sequence_id: "wrong-sequence"))

    assert_predicate SignUp::TicketPolicy.new(bound_context, user: nil), :submit_contact?
    assert_not_predicate SignUp::TicketPolicy.new(unbound_context, user: nil), :submit_contact?
  end

  test "ticket policy rejects signed-in actor from resuming sign-up" do
    ticket = build_ticket(ClientSignUpFlow, entry_method: "email", step: "start")
    context = policy_context(ticket, auth: auth(signed_in: true, active_sign_sequence_id: ticket.public_id))

    assert_not_predicate SignUp::TicketPolicy.new(context, user: Object.new), :resume?
  end

  test "ticket policy rejects binding to another ticket public id" do
    ticket = build_ticket(ClientSignUpFlow, entry_method: "email", step: "start")
    other_ticket = build_ticket(ClientSignUpFlow, entry_method: "email", step: "start")
    context = policy_context(ticket, auth: auth(active_sign_sequence_id: other_ticket.public_id))

    assert_not_predicate SignUp::TicketPolicy.new(context, user: nil), :show?
    assert_not_predicate SignUp::TicketPolicy.new(context, user: nil), :submit_contact?
  end

  test "ticket policy rejects terminal and expired tickets" do
    completed = build_ticket(
      ClientSignUpFlow,
      status_id: ClientSignUpFlowStatus::COMPLETED,
      step: "completed",
      completed_at: Time.current,
    )
    expired = build_ticket(ClientSignUpFlow, issued_at: 2.minutes.ago, expires_at: 1.minute.ago)

    assert_not_predicate SignUp::TicketPolicy.new(policy_context(completed), user: nil), :show?
    assert_not_predicate SignUp::TicketPolicy.new(policy_context(expired), user: nil), :show?
  end

  test "ticket policy allows cancel only for cancelable or already cancelled tickets" do
    checkpoint = build_ticket(
      ClientSignUpFlow,
      status_id: ClientSignUpFlowStatus::CHECKPOINT_PENDING,
      step: "checkpoint",
    )
    finalizing = build_ticket(
      ClientSignUpFlow,
      status_id: ClientSignUpFlowStatus::FINALIZING,
      step: "finalizing",
    )
    cancelled = build_ticket(
      ClientSignUpFlow,
      status_id: ClientSignUpFlowStatus::CANCELLED,
      step: "cancelled",
    )

    assert_predicate SignUp::TicketPolicy.new(policy_context(checkpoint), user: nil), :cancel?
    assert_not_predicate SignUp::TicketPolicy.new(policy_context(finalizing), user: nil), :cancel?
    assert_predicate SignUp::TicketPolicy.new(policy_context(cancelled), user: nil), :cancel?
  end

  test "ticket policy rejects cross-surface context" do
    ticket = build_ticket(ClientSignUpFlow, entry_method: "email")
    context = SignUpPolicyContext.build(
      surface: :com,
      actor_authentication: auth(active_sign_sequence_id: ticket.public_id),
      ticket: ticket,
    )

    assert_not_predicate SignUp::TicketPolicy.new(context, user: nil), :show?
  end

  test "participant policy requires guardrail before checkpoint" do
    contact_verified = build_ticket(
      ClientSignUpFlow, status_id: ClientSignUpFlowStatus::CONTACT_VERIFIED,
                        step: "contact_verified",
    )
    contact_pending = build_ticket(
      ClientSignUpFlow, status_id: ClientSignUpFlowStatus::CONTACT_PENDING,
                        step: "contact",
    )

    assert_not_predicate SignUp::ParticipantPolicy.new(policy_context(contact_verified), user: nil), :enter_checkpoint?
    assert_not_predicate SignUp::ParticipantPolicy.new(policy_context(contact_pending), user: nil), :enter_checkpoint?
  end

  test "requirement policy allows only ticket-owned checkpoint requirements" do
    ticket = build_ticket(
      ClientSignUpFlow,
      entry_method: "telephone",
      status_id: ClientSignUpFlowStatus::CHECKPOINT_PENDING,
      step: "checkpoint",
      principal_id: 42,
    )
    context = requirement_context(ticket, requirement: :passkey, pending_actor: PendingActor.new(id: 42))

    policy = SignUp::RequirementPolicy.new(context, user: nil)

    assert_predicate policy, :clear_requirement?
    assert_predicate policy, :register_passkey?
    assert_not_predicate policy, :confirm_passcode?
  end

  test "requirement policy rejects stale already-cleared requirement" do
    ticket = build_ticket(
      ClientSignUpFlow,
      entry_method: "email",
      status_id: ClientSignUpFlowStatus::CHECKPOINT_PENDING,
      step: "checkpoint",
      principal_id: 42,
      completed_requirements: { "birthdate" => { "cleared" => true } },
    )
    context = requirement_context(ticket, requirement: :birthdate, pending_actor: PendingActor.new(id: 42))

    assert_not_predicate SignUp::RequirementPolicy.new(context, user: nil), :clear_requirement?
  end

  test "requirement policy allows continuing already-cleared requirement" do
    ticket = build_ticket(
      ClientSignUpFlow,
      entry_method: "email",
      status_id: ClientSignUpFlowStatus::CHECKPOINT_PENDING,
      step: "checkpoint",
      principal_id: 42,
      completed_requirements: { "birthdate" => { "cleared" => true } },
    )
    context = requirement_context(ticket, requirement: :birthdate, pending_actor: PendingActor.new(id: 42))

    policy = SignUp::RequirementPolicy.new(context, user: nil)

    assert_not_predicate policy, :clear_requirement?
    assert_predicate policy, :continue_after_cleared_requirement?
  end

  test "requirement policy rejects wrong pending actor" do
    ticket = build_ticket(
      ClientSignUpFlow,
      entry_method: "telephone",
      status_id: ClientSignUpFlowStatus::CHECKPOINT_PENDING,
      step: "checkpoint",
      principal_id: 42,
    )
    context = requirement_context(ticket, requirement: :passkey, pending_actor: PendingActor.new(id: 99))

    assert_not_predicate SignUp::RequirementPolicy.new(context, user: nil), :clear_requirement?
  end

  test "finalization policy requires all requirements clear" do
    ticket = build_ticket(
      ClientSignUpFlow,
      entry_method: "telephone",
      status_id: ClientSignUpFlowStatus::CHECKPOINT_PENDING,
      step: "checkpoint",
      principal_id: 42,
      completed_requirements: {
        "otp" => { "cleared" => true },
        "birthdate" => { "cleared" => true },
        "passkey" => { "cleared" => true },
        "passcode" => { "cleared" => true },
      },
    )
    context = SignUpFinalizationContext.build(
      surface: :app,
      actor_authentication: auth(active_sign_sequence_id: ticket.public_id),
      ticket: ticket,
      pending_actor: PendingActor.new(id: 42),
    )

    assert_predicate SignUp::FinalizationPolicy.new(context, user: nil), :finalize?
  end

  test "finalization context rejects missing telephone requirements before policy evaluation" do
    ticket = build_ticket(
      ClientSignUpFlow,
      entry_method: "telephone",
      status_id: ClientSignUpFlowStatus::CHECKPOINT_PENDING,
      step: "checkpoint",
      principal_id: 42,
      completed_requirements: {
        "birthdate" => { "cleared" => true },
        "passkey" => { "cleared" => true },
      },
    )

    assert_raises(ArgumentError) do
      SignUpFinalizationContext.build(
        surface: :app,
        actor_authentication: auth(active_sign_sequence_id: ticket.public_id),
        ticket: ticket,
        pending_actor: PendingActor.new(id: 42),
      )
    end
  end

  test "social callback policy is app social only" do
    app_ticket = build_ticket(
      ClientSignUpFlow,
      entry_method: "google",
      status_id: ClientSignUpFlowStatus::STARTED,
      step: "start",
    )
    com_ticket = build_ticket(
      VisitorSignUpFlow,
      entry_method: "email",
      status_id: VisitorSignUpFlowStatus::STARTED,
      step: "start",
    )

    assert_predicate SignUp::SocialCallbackPolicy.new(policy_context(app_ticket), user: nil), :start_social_callback?
    assert_not_predicate SignUp::SocialCallbackPolicy.new(policy_context(com_ticket), user: nil),
                         :start_social_callback?
  end

  test "surface falls back to registry when context lacks surface method" do
    ticket = build_ticket(ClientSignUpFlow, entry_method: "email", step: "start")
    policy = SignUp::TicketPolicy.new(ticket, user: nil)

    assert_not policy.show?
  end

  test "surface_matches? rescues argument error for unsupported ticket class" do
    ticket = OpenStruct.new(step: "start")

    policy = SignUp::TicketPolicy.new(ticket, user: nil)

    assert_not policy.show?
  end

  test "actor_class_matches? verifies user class matches client sign-up flow" do
    ticket = build_ticket(
      ClientSignUpFlow,
      entry_method: "email",
      step: "checkpoint",
      principal_id: clients(:one).id,
    )
    context = policy_context(ticket)

    assert_not_predicate SignUp::TicketPolicy.new(context, user: clients(:one)), :finalize?
  end

  test "actor_class_matches? verifies user class matches visitor sign-up flow" do
    visitor = visitors(:reserved_visitor)
    ticket = build_ticket(
      VisitorSignUpFlow,
      entry_method: "email",
      step: "checkpoint",
      principal_id: visitor.id,
    )
    context = policy_context(ticket)

    assert_not_predicate SignUp::TicketPolicy.new(context, user: visitor), :finalize?
  end

  test "actor_class_matches? returns false for unknown ticket class" do
    context = SignUpPolicyContext.build(
      surface: :app,
      actor_authentication: auth(signed_in: false),
      ticket: OpenStruct.new(step: "checkpoint", public_id: "unknown", principal_id: 1),
    )

    assert_not_predicate SignUp::TicketPolicy.new(context, user: clients(:one)), :finalize?
  end

  test "ticket policy verify_contact requires contact step" do
    ticket = build_ticket(ClientSignUpFlow, step: "contact")

    assert_predicate SignUp::TicketPolicy.new(policy_context(ticket), user: nil), :verify_contact?
  end

  test "ticket policy enter_guardrail requires contact_verified step" do
    ticket = build_ticket(ClientSignUpFlow, step: "contact_verified")

    assert_predicate SignUp::TicketPolicy.new(policy_context(ticket), user: nil), :enter_guardrail?
  end

  test "ticket policy enter_checkpoint requires guardrail or checkpoint step" do
    contact_verified = build_ticket(ClientSignUpFlow, step: "contact_verified")
    guardrail = build_ticket(ClientSignUpFlow, step: "guardrail")
    start = build_ticket(ClientSignUpFlow, step: "start")

    assert_not_predicate SignUp::TicketPolicy.new(policy_context(contact_verified), user: nil), :enter_checkpoint?
    assert_predicate SignUp::TicketPolicy.new(policy_context(guardrail), user: nil), :enter_checkpoint?
    assert_not_predicate SignUp::TicketPolicy.new(policy_context(start), user: nil), :enter_checkpoint?
  end

  test "ticket policy clear_requirement requires checkpoint step and pending actor match" do
    ticket = build_ticket(
      ClientSignUpFlow,
      step: "checkpoint",
      principal_id: 42,
    )
    context = SignUpPolicyContext.build(
      surface: :app,
      actor_authentication: auth(active_sign_sequence_id: ticket.public_id),
      ticket: ticket,
    )

    assert_not_predicate SignUp::TicketPolicy.new(context, user: nil), :clear_requirement?
  end

  test "ticket policy handoff_to_sign_in requires finalized step" do
    ticket = build_ticket(
      ClientSignUpFlow,
      step: "finalized",
      principal_id: 42,
    )

    assert_not_predicate SignUp::TicketPolicy.new(policy_context(ticket), user: nil), :handoff_to_sign_in?
  end

  test "requirement policy clear_birthdate delegates to clear_named_requirement" do
    ticket = build_ticket(
      ClientSignUpFlow,
      entry_method: "telephone",
      status_id: ClientSignUpFlowStatus::CHECKPOINT_PENDING,
      step: "checkpoint",
      principal_id: 42,
    )
    context = requirement_context(ticket, requirement: :birthdate, pending_actor: PendingActor.new(id: 42))

    assert_predicate SignUp::RequirementPolicy.new(context, user: nil), :clear_birthdate?
  end

  test "requirement policy rescues argument error for unsupported entry method" do
    ticket = ClientSignUpFlow.new(
      cycle_attrs(ClientSignUpFlow).merge(
        entry_method: "unsupported",
        status_id: ClientSignUpFlowStatus::CHECKPOINT_PENDING,
        step: "checkpoint",
        principal_id: 42,
        completed_requirements: {},
      ),
    )

    context = SignUpRequirementContext.new(
      surface: :app,
      actor_authentication: auth(active_sign_sequence_id: ticket.public_id),
      ticket: ticket,
      requirement: :otp,
      pending_actor: PendingActor.new(id: 42),
      pending_contact: nil,
    )

    policy = SignUp::RequirementPolicy.new(context, user: nil)

    assert_not_predicate policy, :clear_requirement?
  end

  test "social callback policy requires the matching social step" do
    start_ticket = build_ticket(
      ClientSignUpFlow,
      entry_method: "google",
      status_id: ClientSignUpFlowStatus::STARTED,
      step: "start",
    )
    callback_ticket = build_ticket(
      ClientSignUpFlow,
      entry_method: "google",
      status_id: ClientSignUpFlowStatus::SOCIAL_CALLBACK_PENDING,
      step: "social_callback",
    )

    assert_predicate SignUp::SocialCallbackPolicy.new(policy_context(start_ticket), user: nil), :start_social_callback?
    assert_not_predicate SignUp::SocialCallbackPolicy.new(policy_context(start_ticket), user: nil),
                         :complete_social_callback?
    assert_not_predicate SignUp::SocialCallbackPolicy.new(policy_context(callback_ticket), user: nil),
                         :start_social_callback?
    assert_predicate SignUp::SocialCallbackPolicy.new(policy_context(callback_ticket), user: nil),
                     :complete_social_callback?
  end

  test "requirement policy rescues argument error in still pending check" do
    ticket = build_ticket(
      ClientSignUpFlow,
      entry_method: "email",
      status_id: ClientSignUpFlowStatus::CHECKPOINT_PENDING,
      step: "checkpoint",
      principal_id: 42,
    )
    context = requirement_context(ticket, requirement: :birthdate, pending_actor: PendingActor.new(id: 42))
    policy = SignUp::RequirementPolicy.new(context, user: nil)
    registry = Object.new
    registry.singleton_class.class_eval do
      define_method(:requirement?) { |*| true }
      define_method(:requirement_cleared?) { |*| raise ArgumentError, "unsupported" }
    end

    SignUpRequirementRegistry.stub(:for_ticket, registry) do
      assert_not_predicate policy, :clear_requirement?
      assert_not_predicate policy, :continue_after_cleared_requirement?
    end
  end

  test "finalization policy allows handoff to sign in from finalized step" do
    ticket = build_ticket(
      ClientSignUpFlow,
      entry_method: "email",
      status_id: ClientSignUpFlowStatus::FINALIZED,
      step: "finalized",
      principal_id: 42,
      completed_requirements: {
        "otp" => { "cleared" => true },
        "birthdate" => { "cleared" => true },
      },
    )
    context = SignUpFinalizationContext.build(
      surface: :app,
      actor_authentication: auth(active_sign_sequence_id: ticket.public_id),
      ticket: ticket,
      pending_actor: PendingActor.new(id: 42),
    )

    assert_predicate SignUp::FinalizationPolicy.new(context, user: nil), :handoff_to_sign_in?
  end

  test "finalization policy rescues argument error in requirements check" do
    ticket = build_ticket(
      ClientSignUpFlow,
      entry_method: "email",
      status_id: ClientSignUpFlowStatus::CHECKPOINT_PENDING,
      step: "checkpoint",
      principal_id: 42,
      completed_requirements: {
        "otp" => { "cleared" => true },
        "birthdate" => { "cleared" => true },
      },
    )
    context = SignUpFinalizationContext.build(
      surface: :app,
      actor_authentication: auth(active_sign_sequence_id: ticket.public_id),
      ticket: ticket,
      pending_actor: PendingActor.new(id: 42),
    )
    policy = SignUp::FinalizationPolicy.new(context, user: nil)

    SignUpRequirementRegistry.stub(:for_ticket, ->(*) { raise ArgumentError, "unsupported" }) do
      assert_not_predicate policy, :finalize?
    end
  end

  test "social callback policy rescues argument error for unsupported entry method" do
    unsupported_ticket = ClientSignUpFlow.new(
      cycle_attrs(ClientSignUpFlow).merge(
        entry_method: "unsupported",
        status_id: ClientSignUpFlowStatus::STARTED,
        step: "start",
      ),
    )
    context = SignUpPolicyContext.build(
      surface: :app,
      actor_authentication: auth,
      ticket: unsupported_ticket,
    )

    assert_not_predicate SignUp::SocialCallbackPolicy.new(context, user: nil), :start_social_callback?
  end

  private

  def auth(signed_in: false, active_sign_sequence_id: nil)
    AuthFacts.new(signed_in: signed_in, active_sign_sequence_id: active_sign_sequence_id)
  end

  def policy_context(ticket, auth: auth(active_sign_sequence_id: ticket.public_id))
    SignUpPolicyContext.build(
      surface: SignUpRequirementRegistry.surface_for_ticket(ticket),
      actor_authentication: auth,
      ticket: ticket,
    )
  end

  def requirement_context(ticket, requirement:, pending_actor:)
    SignUpRequirementContext.build(
      surface: SignUpRequirementRegistry.surface_for_ticket(ticket),
      actor_authentication: auth(active_sign_sequence_id: ticket.public_id),
      ticket: ticket,
      requirement: requirement,
      pending_actor: pending_actor,
    )
  end

  def build_ticket(cycle_class, attrs = {})
    ticket = cycle_class.new(cycle_attrs(cycle_class).merge(attrs))

    assert_predicate ticket, :valid?, ticket.errors.full_messages.join(", ")
    ticket
  end

  def cycle_attrs(cycle_class)
    {
      principal_id: nil,
      status_id: cycle_class::STATUS_IDS.first,
      step: cycle_class::STEPS.first,
      nonce_digest: cycle_class.digest_nonce("nonce"),
      issued_at: Time.current,
      expires_at: 15.minutes.from_now,
      entry_method: "email",
    }
  end
end
