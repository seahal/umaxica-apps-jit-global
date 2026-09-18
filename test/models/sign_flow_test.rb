# typed: false
# frozen_string_literal: true

require "test_helper"

class SignFlowTest < ActiveSupport::TestCase
  SIGN_IN_CLASSES = [
    ClientSignInFlow,
    VisitorSignInFlow,
    OperatorSignInFlow,
  ].freeze

  SIGN_UP_CLASSES = [
    ClientSignUpFlow,
    VisitorSignUpFlow,
    OperatorSignUpFlow,
  ].freeze

  test "sign-in cycles inherit from their surface cycle records" do
    assert_operator ClientSignInFlow, :<, AppTicketRecord
    assert_operator VisitorSignInFlow, :<, ComTicketRecord
    assert_operator OperatorSignInFlow, :<, OrgTicketRecord
  end

  test "sign-up cycles inherit from their surface cycle records" do
    assert_operator ClientSignUpFlow, :<, AppTicketRecord
    assert_operator VisitorSignUpFlow, :<, ComTicketRecord
    assert_operator OperatorSignUpFlow, :<, OrgTicketRecord
  end

  test "sign-in cycles accept expected protocol boundary statuses" do
    SIGN_IN_CLASSES.each do |cycle_class|
      cycle_class::STATUS_MODEL.ensure_defaults!
      statuses = cycle_class::STATUS_MODEL.where(id: cycle_class::STATUS_IDS).index_by(&:id)

      cycle_class::STATUS_IDS.each do |status_id|
        cycle = build_cycle(
          cycle_class,
          status: statuses.fetch(status_id),
          step: step_for_status(cycle_class.status_name_for(status_id)),
        )
        cycle.completed_at = Time.current if status_id == cycle_class.completed_status_id

        assert_predicate cycle, :valid?, "#{cycle_class.name} #{status_id}"
      end
    end
  end

  test "sign-in cycle statuses expose explicit participant states" do
    SIGN_IN_CLASSES.each do |cycle_class|
      assert_equal(
        %w(
          PRIMARY_PENDING
          MFA_PENDING
          SESSION_LIMIT_PENDING
          GUARDRAIL_PENDING
          SESSION_ISSUANCE_PENDING
          CHECKPOINT_PENDING
          SELECTOR_PENDING
          DASHBOARD_PENDING
          RETURN_PENDING
          COMPLETED
          FAILED
        ),
        cycle_class::STATUSES.keys,
        cycle_class.name,
      )

      assert_not_includes cycle_class::STATUSES, "POST_LOGIN_PENDING", cycle_class.name
    end
  end

  test "sign-in cycle defaults expose the configured ttl and expiry window" do
    assert_equal 15.minutes, ClientSignInFlow.default_ttl

    flow = ClientSignInFlow.new(cycle_attrs(ClientSignInFlow))

    assert_in_delta 15.minutes, flow.default_expires_at - Time.current, 2.seconds
  end

  test "sign-up cycles reject unknown statuses" do
    SIGN_UP_CLASSES.each do |cycle_class|
      cycle = build_cycle(cycle_class, status_id: 999)

      assert_not cycle.valid?, cycle_class.name
      assert_not_empty cycle.errors[:status_id]
    end
  end

  test "app sign-up cycles accept app entry methods" do
    ClientSignUpFlow::ENTRY_METHODS.each do |entry_method|
      cycle = build_cycle(ClientSignUpFlow, entry_method: entry_method)

      assert_predicate cycle, :valid?, entry_method
    end
  end

  test "com sign-up cycles accept only email and telephone entry methods" do
    %w(email telephone).each do |entry_method|
      cycle = build_cycle(VisitorSignUpFlow, entry_method: entry_method)

      assert_predicate cycle, :valid?, entry_method
    end

    %w(google apple).each do |entry_method|
      cycle = build_cycle(VisitorSignUpFlow, entry_method: entry_method)

      assert_not cycle.valid?, entry_method
      assert_not_empty cycle.errors[:entry_method]
    end
  end

  test "com sign-up cycles reject social provider state" do
    cycle = build_cycle(VisitorSignUpFlow, entry_method: "email", social_provider: "google")

    assert_not cycle.valid?
    assert_not_empty cycle.errors[:social_provider]
  end

  test "com sign-up cycles do not expose social callback state" do
    assert_not_includes VisitorSignUpFlow::STATUSES, "SOCIAL_CALLBACK_PENDING"
    assert_not_includes VisitorSignUpFlow::STEPS, "social_callback"
    assert_not_includes VisitorSignUpFlowStatus::DEFAULTS, 36
  end

  test "sign-up cycles reject unsafe return paths" do
    ["https://example.test/dashboard", "//example.test/dashboard", "dashboard"].each do |return_to|
      cycle = build_cycle(ClientSignUpFlow, return_to: return_to)

      assert_not cycle.valid?, return_to
      assert_not_empty cycle.errors[:return_to]
    end

    assert_predicate build_cycle(ClientSignUpFlow, return_to: "/dashboard?tab=home"), :valid?
  end

  test "sign-up cycles expose checkpoint requirement clearance" do
    cycle = build_cycle(
      ClientSignUpFlow,
      completed_requirements: {
        "birthdate" => { "cleared" => true, "cleared_at" => Time.current.iso8601 },
        "passkey" => { "cleared" => false },
      },
    )

    assert cycle.requirement_cleared?("birthdate")
    assert_not cycle.requirement_cleared?("passkey")
    assert_not cycle.requirement_cleared?("passcode")
  end

  test "sign-up cycle lifecycle predicates classify cancelable and terminal states" do
    cancelable = ClientSignUpFlow.create!(
      cycle_attrs(ClientSignUpFlow).merge(
        status_id: ClientSignUpFlowStatus::CHECKPOINT_PENDING,
        step: "checkpoint",
      ),
    )
    finalizing = ClientSignUpFlow.create!(
      cycle_attrs(ClientSignUpFlow).merge(
        status_id: ClientSignUpFlowStatus::FINALIZING,
        step: "finalizing",
      ),
    )
    cancelled = ClientSignUpFlow.create!(
      cycle_attrs(ClientSignUpFlow).merge(
        status_id: ClientSignUpFlowStatus::CANCELLED,
        step: "cancelled",
      ),
    )

    assert_predicate cancelable, :sign_up_in_progress?
    assert_predicate cancelable, :sign_up_cancelable?
    assert_predicate finalizing, :sign_up_in_progress?
    assert_not finalizing.sign_up_cancelable?
    assert_predicate cancelled, :sign_up_terminal?
    assert_not cancelled.sign_up_in_progress?
  end

  test "sign-up cycles reject secret_credential material in requirement state" do
    cycle = build_cycle(
      ClientSignUpFlow,
      completed_requirements: {
        "birthdate" => { "cleared" => true },
        "passcode" => { "access_token" => "secret_credential-value" },
      },
    )

    assert_not cycle.valid?
    assert_not_empty cycle.errors[:completed_requirements]
  end

  test "sign-up cycles accept the social ceremony evidence blob" do
    cycle = build_cycle(
      ClientSignUpFlow,
      entry_method: "google",
      social_provider: "google",
      completed_requirements: {
        "confirmation" => { "cleared" => true },
        "social_signup" => {
          "candidate_ref" => SecureRandom.uuid,
          "candidate_digest" => SecureRandom.hex(32),
          "provider" => "google",
          "uid_digest" => SecureRandom.hex(32),
          "grant_transaction_id" => SecureRandom.uuid,
          "stored_at" => Time.current.iso8601,
        },
      },
    )

    assert_predicate cycle, :valid?
  end

  test "sign-up cycles reject social ceremony evidence renamed to secret-looking keys" do
    cycle = build_cycle(
      ClientSignUpFlow,
      entry_method: "google",
      social_provider: "google",
      completed_requirements: {
        "social_signup" => { "grant_token" => SecureRandom.uuid },
      },
    )

    assert_not cycle.valid?
    assert_not_empty cycle.errors[:completed_requirements]
  end

  test "social ceremony evidence does not satisfy or block any requirement" do
    registry = SignUpRequirementRegistry.for_entry(surface: :app, entry_method: "google")
    requirements = {
      "social_signup" => { "candidate_ref" => SecureRandom.uuid },
    }

    assert_equal %i(confirmation birthdate), registry.missing_requirements(requirements)
    assert_not registry.requirement?(:social_signup)
  end

  test "sign-up cycles require requirement state to be an object" do
    cycle = build_cycle(ClientSignUpFlow, completed_requirements: ["birthdate"])

    assert_not cycle.valid?
    assert_not_empty cycle.errors[:completed_requirements]
  end

  test "sign-up cycle cleanup predicates track the configured cleanup status" do
    [ClientSignUpFlow, VisitorSignUpFlow].each do |cycle_class|
      cycle_class.cleanup_status_class.ensure_defaults!
      cycle = build_cycle(cycle_class, cleanup_status_id: cycle_class.cleanup_status_id_for(:pending))

      assert_predicate cycle, :cleanup_pending?, cycle_class.name
      assert_not cycle.cleanup_idle?
      assert_not cycle.cleanup_completed?
      assert_not cycle.cleanup_failed?
    end
  end

  test "cycles require completed_at when state is completed" do
    (SIGN_IN_CLASSES + SIGN_UP_CLASSES).each do |cycle_class|
      cycle = build_cycle(
        cycle_class, status_id: cycle_class.completed_status_id,
                     step: completion_step_for(cycle_class),
      )

      assert_not cycle.valid?, cycle_class.name
      assert_not_empty cycle.errors[:completed_at]
    end
  end

  test "nonce comparison uses the stored digest" do
    cycle = build_cycle(ClientSignInFlow, nonce: "nonce-one")

    assert cycle.nonce_matches?("nonce-one")
    assert_not cycle.nonce_matches?("nonce-two")
    assert_not cycle.nonce_matches?(nil)
  end

  test "transition_to allows forward sign-in transitions and rejects reverse transitions" do
    cycle = ClientSignInFlow.create!(cycle_attrs(ClientSignInFlow))

    cycle.transition_to!("MFA_PENDING", step: "mfa")

    assert_equal ClientSignInFlowStatus::MFA_PENDING, cycle.status_id
    assert_equal "MFA_PENDING", cycle.state
    assert_equal "mfa", cycle.step

    error =
      assert_raises(ArgumentError) do
        cycle.transition_to!("PRIMARY_PENDING", step: "primary")
      end
    assert_match(/invalid transition/, error.message)
  end

  test "sign-in cycles reject legacy state that disagrees with status" do
    cycle = build_cycle(
      ClientSignInFlow,
      status_id: ClientSignInFlowStatus::MFA_PENDING,
      state: "PRIMARY_PENDING",
      step: "mfa",
    )

    assert_not cycle.valid?
    assert_not_empty cycle.errors[:state]
  end

  test "sign-in cycles reject step that disagrees with status" do
    cycle = build_cycle(
      ClientSignInFlow,
      status_id: ClientSignInFlowStatus::MFA_PENDING,
      state: "MFA_PENDING",
      step: "primary",
    )

    assert_not cycle.valid?
    assert_not_empty cycle.errors[:step]
  end

  test "sign-in transition_to ignores mismatched step input and keeps canonical step" do
    cycle = ClientSignInFlow.create!(cycle_attrs(ClientSignInFlow))

    cycle.transition_to!("MFA_PENDING", step: "checkpoint")

    assert_equal ClientSignInFlowStatus::MFA_PENDING, cycle.status_id
    assert_equal "mfa", cycle.step
  end

  test "sign-in transition_to always uses the row lock path" do
    cycle = ClientSignInFlow.create!(cycle_attrs(ClientSignInFlow))
    called = false

    cycle.define_singleton_method(:with_cycle_lock) do |&block|
      called = true
      block.call
    end

    cycle.transition_to!("MFA_PENDING", step: "mfa")

    assert called
    assert_equal ClientSignInFlowStatus::MFA_PENDING, cycle.status_id
  end

  test "sign-in cycles reject zero-length lifetimes" do
    cycle = build_cycle(
      ClientSignInFlow,
      issued_at: Time.zone.local(2026, 6, 19, 12, 0, 0),
      expires_at: Time.zone.local(2026, 6, 19, 12, 0, 0),
    )

    assert_not cycle.valid?
    assert_includes cycle.errors[:expires_at], "must be after issued_at"
  end

  test "sign-in cycle methods advance through named transitions" do
    SIGN_IN_CLASSES.each do |cycle_class|
      cycle = cycle_class.create!(cycle_attrs(cycle_class))

      cycle.advance_sign_in_to_mfa!

      assert_predicate cycle, :sign_in_mfa_pending?, cycle_class.name
      assert_equal "mfa", cycle.step

      cycle.advance_sign_in_to_session_limit!

      assert_predicate cycle, :sign_in_session_limit_pending?, cycle_class.name
      assert_equal "session_limit", cycle.step

      cycle.advance_sign_in_to_guardrail!

      assert_predicate cycle, :sign_in_guardrail_pending?, cycle_class.name
      assert_equal "guardrail", cycle.step

      cycle.advance_sign_in_to_checkpoint!

      assert_predicate cycle, :sign_in_checkpoint_pending?, cycle_class.name
      assert_equal "checkpoint", cycle.step

      cycle.advance_sign_in_to_selector!

      assert_predicate cycle, :sign_in_selector_pending?, cycle_class.name
      assert_equal "selector", cycle.step

      cycle.advance_sign_in_to_session_issuance!

      assert_predicate cycle, :sign_in_session_issuance_pending?, cycle_class.name
      assert_equal "session_issuance", cycle.step

      cycle.complete_sign_in!

      assert_predicate cycle, :sign_in_completed?, cycle_class.name
      assert_equal "completed", cycle.step
    end
  end

  test "sign-in cycle methods reject reverse transitions through FlowBase" do
    cycle = ClientSignInFlow.create!(cycle_attrs(ClientSignInFlow))
    cycle.advance_sign_in_to_mfa!

    error =
      assert_raises(FlowInvalidTransition) do
        cycle.transition_cycle_to!(
          ClientSignInFlowStatus::PRIMARY_PENDING,
          allowed_from: [ClientSignInFlowStatus::PRIMARY_PENDING],
        )
      end

    assert_match(/invalid transition/, error.message)
    assert_equal ClientSignInFlowStatus::MFA_PENDING, cycle.reload.status_id
  end

  test "sign-in cycle completion stamps completed_at while the current schema requires it" do
    now = Time.zone.local(2026, 5, 19, 11, 0, 0)
    cycle = ClientSignInFlow.create!(
      cycle_attrs(ClientSignInFlow).merge(issued_at: now - 1.minute, expires_at: now + 1.hour),
    )
    cycle.advance_sign_in_to_guardrail!(now: now - 50.seconds)
    cycle.advance_sign_in_to_checkpoint!(now: now - 40.seconds)
    cycle.advance_sign_in_to_selector!(now: now - 30.seconds)
    cycle.advance_sign_in_to_session_issuance!(now: now - 20.seconds)

    travel_to now do
      cycle.complete_sign_in!
    end

    cycle.reload

    assert_predicate cycle, :sign_in_completed?
    assert_equal "completed", cycle.step
    assert_equal now, cycle.completed_at
  end

  test "sign-in cycle can fail from every non-terminal state" do
    non_terminal_statuses = ClientSignInFlow::STATUSES.except("COMPLETED", "FAILED")

    prosopite_pause do
      non_terminal_statuses.each do |status_name, status_id|
        cycle = ClientSignInFlow.create!(
          cycle_attrs(ClientSignInFlow).merge(status_id: status_id, step: step_for_status(status_name)),
        )

        cycle.fail_sign_in!

        assert_predicate cycle, :sign_in_failed?, status_name
        assert_equal "failed", cycle.step
      end
    end
  end

  test "terminal sign-in cycles do not transition again" do
    completed = ClientSignInFlow.create!(
      cycle_attrs(ClientSignInFlow).merge(
        status_id: ClientSignInFlowStatus::COMPLETED,
        step: "completed",
        completed_at: Time.current,
      ),
    )

    assert_raises(FlowInvalidTransition) { completed.fail_sign_in! }

    failed = ClientSignInFlow.create!(
      cycle_attrs(ClientSignInFlow).merge(status_id: ClientSignInFlowStatus::FAILED, step: "failed"),
    )

    assert_raises(FlowInvalidTransition) { failed.advance_sign_in_to_guardrail! }
  end

  test "sign-in cycle methods reject expired cycles" do
    now = Time.zone.local(2026, 5, 19, 11, 0, 0)
    cycle = ClientSignInFlow.create!(
      cycle_attrs(ClientSignInFlow).merge(issued_at: now - 1.minute, expires_at: now),
    )

    travel_to now do
      assert_raises(FlowInvalidTransition) { cycle.advance_sign_in_to_mfa! }
    end

    assert_equal ClientSignInFlowStatus::PRIMARY_PENDING, cycle.reload.status_id
  end

  test "sign-in transition_to rejects expired cycles" do
    now = Time.zone.local(2026, 5, 19, 11, 0, 0)
    cycle = ClientSignInFlow.create!(
      cycle_attrs(ClientSignInFlow).merge(issued_at: now - 1.minute, expires_at: now),
    )

    travel_to now do
      assert_raises(FlowInvalidTransition) { cycle.transition_to!("MFA_PENDING") }
    end

    assert_equal ClientSignInFlowStatus::PRIMARY_PENDING, cycle.reload.status_id
  end

  test "sign-up cycles cannot complete before sign-in handoff" do
    cycle = ClientSignUpFlow.create!(cycle_attrs(ClientSignUpFlow))

    cycle.transition_to!("CONTACT_PENDING", step: "contact")
    cycle.transition_to!("CONTACT_VERIFIED", step: "contact_verified")
    cycle.transition_to!("GUARDRAIL_PENDING", step: "guardrail")
    cycle.transition_to!("CHECKPOINT_PENDING", step: "checkpoint")

    assert_raises(ArgumentError) { cycle.transition_to!("COMPLETED", step: "completed") }
    assert_raises(FlowInvalidTransition) { cycle.complete_sign_up! }
  end

  test "transition_to stamps completed_at for post-handoff completed transitions" do
    now = Time.zone.local(2026, 5, 18, 9, 0, 0)
    cycle = ClientSignUpFlow.create!(cycle_attrs(ClientSignUpFlow))

    travel_to now do
      cycle.transition_to!("CONTACT_PENDING", step: "contact")
      cycle.transition_to!("CONTACT_VERIFIED", step: "contact_verified")
      cycle.transition_to!("GUARDRAIL_PENDING", step: "guardrail")
      cycle.transition_to!("CHECKPOINT_PENDING", step: "checkpoint")
      cycle.transition_to!("FINALIZING", step: "finalizing")
      cycle.transition_to!("FINALIZED", step: "finalized")
      cycle.transition_to!("SIGN_IN_HANDOFF_PENDING", step: "sign_in_handoff")
      cycle.complete_sign_up!
    end

    assert_equal ClientSignUpFlowStatus::COMPLETED, cycle.status_id
    assert_equal "COMPLETED", cycle.state
    assert_equal now, cycle.completed_at
  end

  test "expired reflects expires_at and discarded_at boundaries" do
    cycle = build_cycle(ClientSignInFlow, expires_at: 1.second.from_now)

    assert_not cycle.expired?

    expired = build_cycle(ClientSignInFlow, expires_at: Time.current)

    assert_predicate expired, :expired?

    discarded = ClientSignInFlow.create!(cycle_attrs(ClientSignInFlow))
    discarded.discard!(now: Time.current)

    assert_predicate discarded, :lapsed?
    assert_not discarded.expired?
  end

  test "client sign-in cycle can belong to a client token" do
    user = Client.create!(public_id: "seq_#{SecureRandom.hex(8)}", status_id: ClientStatus::ACTIVE)
    token = ClientToken.create!(user: user)

    cycle = ClientSignInFlow.create!(
      cycle_attrs(ClientSignInFlow).merge(principal_id: user.id, token: token),
    )

    assert_equal token, cycle.token
    assert_equal user.id, cycle.principal_id
  end

  test "transition_to! derives the step from STEP_BY_STATUS_ID for sign-in flows" do
    cycle = ClientSignInFlow.create!(cycle_attrs(ClientSignInFlow))

    cycle.transition_to!("MFA_PENDING")

    assert_equal ClientSignInFlow.status_id_for("MFA_PENDING"), cycle.status_id
    assert_equal "mfa", cycle.step
  end

  test "canonical_step_for_status returns the mapped step for sign-in flows" do
    cycle = ClientSignInFlow.create!(cycle_attrs(ClientSignInFlow))
    mfa_id = ClientSignInFlow.status_id_for("MFA_PENDING")

    assert_equal "mfa", cycle.send(:canonical_step_for_status, mfa_id)
  end

  test "canonical_step_for_status returns nil when STEP_BY_STATUS_ID is absent" do
    cycle = ClientSignUpFlow.create!(cycle_attrs(ClientSignUpFlow))

    assert_nil cycle.send(:canonical_step_for_status, cycle.status_id)
  end

  private

  def build_cycle(cycle_class, nonce: "nonce", **overrides)
    cycle_class.new(cycle_attrs(cycle_class, nonce: nonce).merge(overrides))
  end

  def cycle_attrs(cycle_class, nonce: "nonce")
    if cycle_class < SignUpFlowTicket && cycle_class.respond_to?(:cleanup_status_class)
      cycle_class.cleanup_status_class.ensure_defaults!
    end

    attrs = {
      principal_id: 123,
      status_id: cycle_class::STATUS_IDS.first,
      step: cycle_class::STEPS.first,
      return_to: "/dashboard",
      nonce_digest: cycle_class.digest_nonce(nonce),
      issued_at: Time.current,
      expires_at: 15.minutes.from_now,
    }
    attrs[:entry_method] = default_sign_up_entry_method(cycle_class) if cycle_class < SignUpFlowTicket
    attrs
  end

  def completion_step_for(cycle_class)
    cycle_class::STEPS.include?("completed") ? "completed" : "return_to"
  end

  def step_for_status(status_name)
    {
      "PRIMARY_PENDING" => "primary",
      "MFA_PENDING" => "mfa",
      "SESSION_LIMIT_PENDING" => "session_limit",
      "GUARDRAIL_PENDING" => "guardrail",
      "CHECKPOINT_PENDING" => "checkpoint",
      "SELECTOR_PENDING" => "selector",
      "SESSION_ISSUANCE_PENDING" => "session_issuance",
      "DASHBOARD_PENDING" => "dashboard",
      "RETURN_PENDING" => "return_to",
      "COMPLETED" => "completed",
      "FAILED" => "failed",
    }.fetch(status_name)
  end

  def default_sign_up_entry_method(_cycle_class)
    "email"
  end

  def prosopite_pause(&)
    if defined?(Prosopite)
      Prosopite.pause(&)
    else
      yield
    end
  end
end
