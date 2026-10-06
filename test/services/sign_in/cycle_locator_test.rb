# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

module SignIn
  class CycleLocatorTest < ActiveSupport::TestCase
    test "issue stores a session locator and current resolves the db cycle" do
      session = {}
      cycle = create_client_cycle(nonce: "old-nonce")
      locator = SignInCycleLocator.new(session, surface: :app)

      locator.issue!(cycle, nonce: "fresh-nonce")

      assert_equal cycle.public_id, session.dig(:app_sign_in_flow_locator, "public_id")
      assert_equal "fresh-nonce", session.dig(:app_sign_in_flow_locator, "nonce")
      assert_equal cycle, locator.current
      assert cycle.reload.nonce_matches?("fresh-nonce")
      assert_not cycle.nonce_matches?("old-nonce")
    end

    test "bad nonce rejects without mutating cycle state" do
      session = {}
      cycle = create_client_cycle(nonce: "correct-nonce")
      locator = SignInCycleLocator.new(session, surface: :app)
      locator.issue!(cycle, nonce: "correct-nonce")
      original_state_id = cycle.state_id
      original_nonce_digest = cycle.nonce_digest

      session[:app_sign_in_flow_locator]["nonce"] = "bad-nonce"

      assert_nil locator.current
      cycle.reload

      assert_equal original_state_id, cycle.state_id
      assert_equal original_nonce_digest, cycle.nonce_digest
    end

    test "expired cycle rejects without mutation" do
      now = Time.zone.local(2026, 5, 20, 12, 0, 0)
      session = {}
      cycle = create_client_cycle(
        nonce: "nonce",
        issued_at: now - 20.minutes,
        expires_at: now - 1.minute,
      )
      locator = SignInCycleLocator.new(session, surface: :app)
      locator.issue!(cycle, nonce: "nonce")

      travel_to now do
        assert_nil locator.current
      end

      assert_equal ClientSignInFlowState::PRIMARY_PENDING, cycle.reload.state_id
    end

    test "principal-bound cycle requires matching actor" do
      session = {}
      actor = create_client
      other_actor = create_client
      cycle = create_client_cycle(nonce: "nonce", principal_id: actor.id)
      SignInCycleLocator.new(session, surface: :app).issue!(cycle, nonce: "nonce")

      assert_nil SignInCycleLocator.new(session, surface: :app).current
      assert_nil SignInCycleLocator.new(session, surface: :app, actor: other_actor).current
      assert_equal cycle, SignInCycleLocator.new(session, surface: :app, actor: actor).current
    end

    test "token-bound cycle requires matching current token" do
      session = {}
      actor = create_client
      token = ClientToken.create!(user: actor)
      other_token = ClientToken.create!(user: actor)
      cycle = create_client_cycle(nonce: "nonce", principal_id: actor.id, token: token)
      SignInCycleLocator.new(session, surface: :app).issue!(cycle, nonce: "nonce")

      assert_nil SignInCycleLocator.new(session, surface: :app, actor: actor).current
      assert_nil SignInCycleLocator.new(session, surface: :app, actor: actor, token: other_token).current
      assert_equal cycle, SignInCycleLocator.new(session, surface: :app, actor: actor, token: token).current
    end

    test "terminal cycles reject" do
      session = {}
      completed = create_client_cycle(
        nonce: "nonce",
        state_id: ClientSignInFlowState::COMPLETED,
        completed_at: Time.current,
      )
      SignInCycleLocator.new(session, surface: :app).issue!(completed, nonce: "nonce")

      assert_nil SignInCycleLocator.new(session, surface: :app).current

      failed = create_client_cycle(
        nonce: "failed-nonce",
        state_id: ClientSignInFlowState::FAILED,
      )
      SignInCycleLocator.new(session, surface: :app).issue!(failed, nonce: "failed-nonce")

      assert_nil SignInCycleLocator.new(session, surface: :app).current
    end

    test "rotate replaces nonce and old session nonce no longer resolves" do
      session = {}
      cycle = create_client_cycle(nonce: "old-nonce")
      locator = SignInCycleLocator.new(session, surface: :app)
      locator.issue!(cycle, nonce: "old-nonce")
      old_payload = session[:app_sign_in_flow_locator].dup

      locator.rotate!(cycle)
      new_nonce = session.dig(:app_sign_in_flow_locator, "nonce")

      assert_not_equal "old-nonce", new_nonce
      assert_equal cycle, locator.current

      session[:app_sign_in_flow_locator] = old_payload

      assert_nil locator.current
    end

    test "surface-specific locator does not read another surface key" do
      session = {}
      cycle = create_client_cycle(nonce: "nonce")
      SignInCycleLocator.new(session, surface: :app).issue!(cycle, nonce: "nonce")

      assert_nil SignInCycleLocator.new(session, surface: :com).current
    end

    private

    def create_client(public_id: "c#{SecureRandom.hex(10)}")
      Client.create!(public_id: public_id, status_id: ClientStatus::ACTIVE)
    end

    def create_client_cycle(nonce:, **overrides)
      ClientSignInFlow.create!(
        {
          principal_id: nil,
          state_id: ClientSignInFlowState::PRIMARY_PENDING,
          return_to: "/dashboard",
          nonce_digest: ClientSignInFlow.digest_nonce(nonce),
          issued_at: Time.current,
          expires_at: 15.minutes.from_now,
        }.merge(overrides),
      )
    end
  end
end
