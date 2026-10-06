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

  test "sign-in cycles accept expected protocol boundary states" do
    SIGN_IN_CLASSES.each do |cycle_class|
      states = cycle_class::STATE_MODEL.where(id: cycle_class::STATE_IDS).index_by(&:id)

      cycle_class::STATES.values.each do |state_id|
        cycle = build_cycle(
          cycle_class,
          state: states.fetch(state_id),
        )
        cycle.completed_at = Time.current if state_id == cycle_class.completed_state_id

        assert_predicate cycle, :valid?, "#{cycle_class.name} #{state_id}"
      end

      assert_equal "DASHBOARD_PENDING", cycle_class.state_name_for(cycle_class::STATE_MODEL::DASHBOARD_PENDING)
      assert_equal "RETURN_PENDING", cycle_class.state_name_for(cycle_class::STATE_MODEL::RETURN_PENDING)
    end
  end

  test "sign-in cycle statuses expose explicit participant states" do
    SIGN_IN_CLASSES.each do |cycle_class|
      assert_equal(
        %w(
          PRIMARY_PENDING
          MFA_PENDING
          GUARDRAIL_PENDING
          SESSION_ISSUANCE_PENDING
          CHECKPOINT_PENDING
          SELECTOR_PENDING
          COMPLETED
          FAILED
          EXPIRED
          CANCELLED
          HALTED
        ),
        cycle_class::STATES.keys,
        cycle_class.name,
      )

      assert_not_includes cycle_class::STATES, "POST_LOGIN_PENDING", cycle_class.name
      assert_equal cycle_class::STATE_MODEL::SESSION_LIMIT_PENDING,
                   cycle_class::HISTORICAL_STATES.fetch("SESSION_LIMIT_PENDING"), cycle_class.name
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
    assert_not_includes VisitorSignUpFlow::STATUS_MODEL::DEFAULTS, 36
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
      cycle = build_cycle(cycle_class, cleanup_status_id: cycle_class.cleanup_status_id_for(:pending))

      assert_predicate cycle, :cleanup_pending?, cycle_class.name
      assert_not cycle.cleanup_idle?
      assert_not cycle.cleanup_completed?
      assert_not cycle.cleanup_failed?
    end
  end

  test "cycles require completed_at when state is completed" do
    SIGN_IN_CLASSES.each do |cycle_class|
      cycle = build_cycle(cycle_class, state_id: cycle_class.completed_state_id)

      assert_not cycle.valid?, cycle_class.name
      assert_not_empty cycle.errors[:completed_at]
    end

    SIGN_UP_CLASSES.each do |cycle_class|
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

  test "named sign-in transitions allow forward edges and reject reverse edges" do
    cycle = ClientSignInFlow.create!(cycle_attrs(ClientSignInFlow))

    cycle.advance_sign_in_to_mfa!

    assert_equal ClientSignInFlowState::MFA_PENDING, cycle.state_id

    error =
      assert_raises(FlowInvalidTransition) do
        cycle.advance_sign_in_to_mfa!
      end
    assert_match(/invalid transition/, error.message)
  end

  test "sign-in flows use only the durable state foreign key" do
    assert_includes ClientSignInFlow.column_names, "state_id"
    assert_not_includes ClientSignInFlow.column_names, "status_id"
    assert_not_includes ClientSignInFlow.column_names, "state"
    assert_not_includes ClientSignInFlow.column_names, "step"
  end

  test "sign-in state foreign keys reject unknown values and protect referenced rows" do
    SIGN_IN_CLASSES.each do |cycle_class|
      flow = cycle_class.create!(cycle_attrs(cycle_class))
      state_class = cycle_class::STATE_MODEL
      state_id = cycle_class::STATE_IDS.first

      assert_raises(ActiveRecord::InvalidForeignKey, cycle_class.name) do
        cycle_class.transaction(requires_new: true) do
          # Bypass model inclusion validation to exercise the database FK itself.
          flow.update_columns(state_id: 999)
        end
      end

      assert_raises(ActiveRecord::InvalidForeignKey, cycle_class.name) do
        state_class.transaction(requires_new: true) do
          state_class.where(id: state_id).delete_all
        end
      end
    end
  end

  test "named sign-in transition owns the canonical step" do
    cycle = ClientSignInFlow.create!(cycle_attrs(ClientSignInFlow))

    cycle.advance_sign_in_to_mfa!

    assert_equal ClientSignInFlowState::MFA_PENDING, cycle.state_id
  end

  test "arbitrary transition entry points are not public" do
    cycle = ClientSignInFlow.create!(cycle_attrs(ClientSignInFlow))

    assert_not_respond_to cycle, :transition_to!
    assert_not_respond_to cycle, :transition_cycle_to!
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
      assert_equal ClientSignInFlowState::MFA_PENDING, cycle.state_id

      cycle.advance_sign_in_to_guardrail!

      assert_predicate cycle, :sign_in_guardrail_pending?, cycle_class.name
      assert_equal ClientSignInFlowState::GUARDRAIL_PENDING, cycle.state_id

      cycle.advance_sign_in_to_checkpoint!

      assert_predicate cycle, :sign_in_checkpoint_pending?, cycle_class.name
      assert_equal ClientSignInFlowState::CHECKPOINT_PENDING, cycle.state_id

      cycle.advance_sign_in_to_selector!

      assert_predicate cycle, :sign_in_selector_pending?, cycle_class.name
      assert_equal ClientSignInFlowState::SELECTOR_PENDING, cycle.state_id

      cycle.advance_sign_in_to_session_issuance!

      assert_predicate cycle, :sign_in_session_issuance_pending?, cycle_class.name
      assert_equal ClientSignInFlowState::SESSION_ISSUANCE_PENDING, cycle.state_id

      cycle.complete_sign_in!

      assert_predicate cycle, :sign_in_completed?, cycle_class.name
      assert_equal ClientSignInFlowState::COMPLETED, cycle.state_id
    end
  end

  test "sign-in cycles keep session-limit resolution outside the main graph" do
    SIGN_IN_CLASSES.each do |cycle_class|
      cycle = cycle_class.create!(cycle_attrs(cycle_class))
      cycle.advance_sign_in_to_mfa!

      assert_not cycle.can_transition_to?(cycle_class::STATE_MODEL::SESSION_LIMIT_PENDING)

      cycle.advance_sign_in_to_guardrail!
      cycle.advance_sign_in_to_checkpoint!
      cycle.advance_sign_in_to_selector!
      cycle.advance_sign_in_to_session_issuance!

      assert_predicate cycle, :sign_in_session_issuance_pending?, cycle_class.name
      assert_not cycle.can_transition_to?(cycle_class::STATE_MODEL::SESSION_LIMIT_PENDING)
    end
  end

  test "sign-in cycle methods reject reverse transitions through FlowBase" do
    cycle = ClientSignInFlow.create!(cycle_attrs(ClientSignInFlow))
    cycle.advance_sign_in_to_mfa!

    error =
      assert_raises(FlowInvalidTransition) do
        cycle.advance_sign_in_to_mfa!
      end

    assert_match(/invalid transition/, error.message)
    assert_equal ClientSignInFlowState::MFA_PENDING, cycle.reload.state_id
  end

  test "sign-in cycle completion stamps completed_at while the current schema requires it" do
    now = ClientSignInFlow.database_now
    cycle = ClientSignInFlow.create!(
      cycle_attrs(ClientSignInFlow).merge(issued_at: now - 1.minute, expires_at: now + 1.hour),
    )
    cycle.advance_sign_in_to_guardrail!
    cycle.advance_sign_in_to_checkpoint!
    cycle.advance_sign_in_to_selector!
    cycle.advance_sign_in_to_session_issuance!

    travel_to now do
      cycle.complete_sign_in!
    end

    cycle.reload

    assert_predicate cycle, :sign_in_completed?
    assert_equal ClientSignInFlowState::COMPLETED, cycle.state_id
    assert_operator cycle.completed_at, :>=, now
  end

  test "sign-in cycle can be cancelled from every non-terminal state" do
    non_terminal_states = ClientSignInFlow::STATES.except("COMPLETED", "FAILED", "EXPIRED", "CANCELLED", "HALTED")

    prosopite_pause do
      non_terminal_states.each do |state_name, state_id|
        cycle = ClientSignInFlow.create!(
          cycle_attrs(ClientSignInFlow).merge(state_id: state_id),
        )

        cycle.cancel_sign_in!

        assert_predicate cycle, :sign_in_cancelled?, state_name
        assert_equal ClientSignInFlowState::CANCELLED, cycle.state_id
      end
    end
  end

  test "terminal sign-in cycles do not transition again" do
    completed = ClientSignInFlow.create!(
      cycle_attrs(ClientSignInFlow).merge(
        state_id: ClientSignInFlowState::COMPLETED,
        completed_at: Time.current,
      ),
    )

    assert_raises(FlowInvalidTransition) { completed.cancel_sign_in! }

    failed = ClientSignInFlow.create!(
      cycle_attrs(ClientSignInFlow).merge(state_id: ClientSignInFlowState::FAILED),
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

    assert_equal ClientSignInFlowState::EXPIRED, cycle.reload.state_id
  end

  test "named sign-in transitions reject expired cycles after terminalizing them" do
    now = Time.zone.local(2026, 5, 19, 11, 0, 0)
    cycle = ClientSignInFlow.create!(
      cycle_attrs(ClientSignInFlow).merge(issued_at: now - 1.minute, expires_at: now),
    )

    travel_to now do
      assert_raises(FlowInvalidTransition) { cycle.advance_sign_in_to_mfa! }
    end

    assert_equal ClientSignInFlowState::EXPIRED, cycle.reload.state_id
  end

  test "sign-up cycles cannot complete before sign-in handoff" do
    cycle = ClientSignUpFlow.create!(cycle_attrs(ClientSignUpFlow))

    cycle.advance_sign_up_to_contact!
    cycle.verify_sign_up_contact!
    cycle.advance_sign_up_to_guardrail!
    cycle.advance_sign_up_to_checkpoint!

    assert_not_respond_to cycle, :transition_to!
    assert_raises(FlowInvalidTransition) { cycle.complete_sign_up! }
  end

  test "named sign-up transitions stamp completed_at after durable finalization" do
    now = Time.zone.local(2026, 5, 18, 9, 0, 0)
    cycle = ClientSignUpFlow.create!(cycle_attrs(ClientSignUpFlow))

    travel_to now do
      cycle.advance_sign_up_to_contact!
      cycle.verify_sign_up_contact!
      cycle.advance_sign_up_to_guardrail!
      cycle.advance_sign_up_to_checkpoint!
      cycle.begin_sign_up_finalization!
      cycle.complete_sign_up!
    end

    assert_equal ClientSignUpFlowStatus::COMPLETED, cycle.status_id
    assert_equal "COMPLETED", cycle.state
    assert_operator cycle.completed_at, :>=, now
  end

  test "expired reflects expires_at and discard_at boundaries" do
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

  test "named sign-in transitions derive the step from the status" do
    cycle = ClientSignInFlow.create!(cycle_attrs(ClientSignInFlow))

    cycle.advance_sign_in_to_mfa!

    assert_equal ClientSignInFlow.state_id_for("MFA_PENDING"), cycle.state_id
  end

  private

  def build_cycle(cycle_class, nonce: "nonce", **overrides)
    cycle_class.new(cycle_attrs(cycle_class, nonce: nonce).merge(overrides))
  end

  def cycle_attrs(cycle_class, nonce: "nonce")
    attrs =
      if cycle_class < SignInFlow
        {
          principal_id: 123,
          state_id: cycle_class::STATE_IDS.first,
          return_to: "/dashboard",
          nonce_digest: cycle_class.digest_nonce(nonce),
          issued_at: Time.current,
          expires_at: 15.minutes.from_now,
        }
      else
        {
          principal_id: 123,
          status_id: cycle_class::STATUS_IDS.first,
          step: cycle_class::STEPS.first,
          return_to: "/dashboard",
          nonce_digest: cycle_class.digest_nonce(nonce),
          issued_at: Time.current,
          expires_at: 15.minutes.from_now,
        }
      end
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
      "COMPLETED" => "completed",
      "FAILED" => "failed",
      "EXPIRED" => "expired",
      "CANCELLED" => "cancelled",
      "HALTED" => "halted",
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
