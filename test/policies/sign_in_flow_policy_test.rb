# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class SignInFlowPolicyTest < ActiveSupport::TestCase
  setup do
    @client = Client.create!(public_id: "c#{SecureRandom.hex(10)}", status_id: ClientStatus::ACTIVE)
    @token = ClientToken.create!(user: @client)
  end

  teardown do
    Actor.install_context!(authn: Actor::Authentication::NULL)
  end

  test "allows primary actions before actor binding" do
    cycle = create_cycle("PRIMARY_PENDING")
    policy = ClientSignInFlowPolicy.new(cycle, user: nil)

    assert_predicate policy, :show_primary?
    assert_predicate policy, :verify_primary?
    assert_not_predicate policy, :show_mfa?
  end

  test "primary actions require matching actor when cycle is already actor-bound" do
    cycle = create_cycle("PRIMARY_PENDING", principal_id: @client.id)

    assert_not_predicate ClientSignInFlowPolicy.new(cycle, user: nil), :show_primary?
    assert_not_predicate ClientSignInFlowPolicy.new(cycle, user: create_client), :verify_primary?
    assert_predicate ClientSignInFlowPolicy.new(cycle, user: @client), :show_primary?
  end

  test "allows mfa only for matching actor-bound cycle" do
    cycle = create_cycle("MFA_PENDING", principal_id: @client.id)

    assert_predicate ClientSignInFlowPolicy.new(cycle, user: @client), :show_mfa?
    assert_predicate ClientSignInFlowPolicy.new(cycle, user: @client), :verify_mfa?
    assert_not_predicate ClientSignInFlowPolicy.new(cycle, user: nil), :show_mfa?
    assert_not_predicate ClientSignInFlowPolicy.new(cycle, user: create_client), :show_mfa?
  end

  test "allows each participant only in matching state" do
    expectations = {
      "SESSION_LIMIT_PENDING" => :manage_session_limit?,
      "GUARDRAIL_PENDING" => :run_guardrail?,
      "SESSION_ISSUANCE_PENDING" => :issue_session?,
      "CHECKPOINT_PENDING" => :show_checkpoint?,
      "SELECTOR_PENDING" => :show_selector?,
      "DASHBOARD_PENDING" => :show_dashboard?,
      "RETURN_PENDING" => :consume_return?,
    }

    expectations.each do |status_name, allowed_method|
      # One flow binds at most one session (unique token_id), so each state gets its own session.
      token = ClientToken.create!(user: @client, user_token_status_id: ClientTokenStatus::ACTIVE)
      cycle = create_cycle(status_name, principal_id: @client.id, token: token)
      Actor.install_context!(authn: Actor::Authentication.new(login_public_id: token.public_id))
      policy = ClientSignInFlowPolicy.new(cycle, user: @client)

      expectations.values.each do |method_name|
        if method_name == allowed_method
          assert_predicate policy, method_name, "#{status_name} #{method_name}"
        else
          assert_not_predicate policy, method_name, "#{status_name} #{method_name}"
        end
      end
      # Keep the account under its session ceiling for the next state.
      token.revoke!
    end
  end

  test "checkpoint and selector participants are allowed by pending cycle state before token issuance" do
    checkpoint = create_cycle("CHECKPOINT_PENDING", principal_id: @client.id)
    selector = create_cycle("SELECTOR_PENDING", principal_id: @client.id)

    assert_predicate ClientSignInFlowPolicy.new(checkpoint, user: nil), :show_checkpoint?
    assert_predicate ClientSignInFlowPolicy.new(selector, user: nil), :show_selector?
  end

  test "token-bound post-completion participants require matching Actor authentication token" do
    cycle = create_cycle("DASHBOARD_PENDING", principal_id: @client.id, token: @token)
    policy = ClientSignInFlowPolicy.new(cycle, user: @client)

    Actor.install_context!(authn: Actor::Authentication::NULL)

    assert_not_predicate policy, :show_dashboard?

    Actor.install_context!(authn: Actor::Authentication.new(login_public_id: "wrong-token"))

    assert_not_predicate policy, :show_dashboard?

    Actor.install_context!(authn: Actor::Authentication.new(login_public_id: @token.public_id))

    assert_predicate policy, :show_dashboard?
  end

  test "token-bound post-issuance participants accept matching device session id" do
    cycle = create_cycle("DASHBOARD_PENDING", principal_id: @client.id, token: @token)

    Actor.install_context!(authn: Actor::Authentication.new(login_public_id: @token.device_session.public_id))

    assert_predicate ClientSignInFlowPolicy.new(cycle, user: @client), :show_dashboard?
  end

  test "session limit is allowed by pending cycle state before token issuance" do
    cycle = create_cycle("SESSION_LIMIT_PENDING", principal_id: @client.id)

    assert_predicate ClientSignInFlowPolicy.new(cycle, user: nil), :manage_session_limit?
  end

  test "guardrail requires matching actor" do
    cycle = create_cycle("GUARDRAIL_PENDING", principal_id: @client.id)

    assert_not_predicate ClientSignInFlowPolicy.new(cycle, user: nil), :run_guardrail?
    assert_not_predicate ClientSignInFlowPolicy.new(cycle, user: create_client), :run_guardrail?
    assert_predicate ClientSignInFlowPolicy.new(cycle, user: @client), :run_guardrail?
  end

  test "terminal cycles deny participant actions and cannot fail again" do
    completed = create_cycle(
      "COMPLETED",
      principal_id: @client.id,
      token: @token,
      step: "completed",
      completed_at: Time.current,
    )
    failed = create_cycle("FAILED", principal_id: @client.id, step: "failed")

    Actor.install_context!(authn: Actor::Authentication.new(login_public_id: @token.public_id))

    assert_not_predicate ClientSignInFlowPolicy.new(completed, user: @client), :show_dashboard?
    assert_not_predicate ClientSignInFlowPolicy.new(completed, user: @client), :fail?
    assert_not_predicate ClientSignInFlowPolicy.new(failed, user: @client), :fail?
  end

  test "fail is allowed only for non-terminal sign-in cycles" do
    cycle = create_cycle("GUARDRAIL_PENDING", principal_id: @client.id)

    assert_predicate ClientSignInFlowPolicy.new(cycle, user: @client), :fail?
  end

  test "fail requires matching actor and token when cycle is bound" do
    cycle = create_cycle("CHECKPOINT_PENDING", principal_id: @client.id, token: @token)

    Actor.install_context!(authn: Actor::Authentication::NULL)

    assert_not_predicate ClientSignInFlowPolicy.new(cycle, user: @client), :fail?

    Actor.install_context!(authn: Actor::Authentication.new(login_public_id: @token.public_id))

    assert_not_predicate ClientSignInFlowPolicy.new(cycle, user: create_client), :fail?
    assert_predicate ClientSignInFlowPolicy.new(cycle, user: @client), :fail?
  end

  test "surface actor class must match cycle class" do
    visitor = Visitor.create!(public_id: "v#{SecureRandom.hex(10)}", status_id: VisitorStatus::ACTIVE)
    cycle = create_cycle("MFA_PENDING", principal_id: @client.id)

    assert_not_predicate ClientSignInFlowPolicy.new(cycle, user: visitor), :show_mfa?
  end

  private

  def create_client
    Client.create!(public_id: "c#{SecureRandom.hex(10)}", status_id: ClientStatus::ACTIVE)
  end

  def create_cycle(status_name, nonce: "nonce", **overrides)
    ClientSignInFlow.create!(
      {
        principal_id: nil,
        status_id: ClientSignInFlow.status_id_for(status_name),
        step: step_for_status(status_name),
        return_to: "/dashboard",
        nonce_digest: ClientSignInFlow.digest_nonce(nonce),
        issued_at: Time.current,
        expires_at: 15.minutes.from_now,
      }.merge(overrides),
    )
  end

  def step_for_status(status_name)
    {
      "PRIMARY_PENDING" => "primary",
      "MFA_PENDING" => "mfa",
      "SESSION_LIMIT_PENDING" => "session_limit",
      "GUARDRAIL_PENDING" => "guardrail",
      "SESSION_ISSUANCE_PENDING" => "session_issuance",
      "CHECKPOINT_PENDING" => "checkpoint",
      "SELECTOR_PENDING" => "selector",
      "DASHBOARD_PENDING" => "dashboard",
      "RETURN_PENDING" => "return_to",
      "COMPLETED" => "completed",
      "FAILED" => "failed",
    }.fetch(status_name)
  end
end
