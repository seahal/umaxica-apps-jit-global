# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class SignUpCycleLocatorTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "raises for unsupported surface" do
    assert_raises(ArgumentError, match: "unsupported sign-up cycle surface") do
      SignUpCycleLocator.new({}, surface: :invalid)
    end
  end

  test "raises for wrong cycle class in issue!" do
    session = {}
    locator = SignUpCycleLocator.new(session, surface: :app)
    wrong_cycle = VisitorSignUpFlow.new

    assert_raises(ArgumentError, match: "unsupported sign-up cycle") do
      locator.issue!(wrong_cycle)
    end
  end

  test "issue! persists nonce while request is on a read connection" do
    session = {}
    cycle = ClientSignUpFlow.create!(
      auth_admission_binding: SignUpAdmissionTestFactory.binding_for!(ClientSignUpFlow),
      principal_id: 123,
      status_id: ClientSignUpFlowStatus::STARTED,
      step: "start",
      nonce_digest: ClientSignUpFlow.digest_nonce("old-nonce"),
      issued_at: Time.current,
      expires_at: 15.minutes.from_now,
      entry_method: "email",
    )
    locator = SignUpCycleLocator.new(session, surface: :app)

    ActiveRecord::Base.connected_to(role: :reading, prevent_writes: true) do
      locator.issue!(cycle, nonce: "fresh-nonce")
    end

    assert_equal cycle.public_id, session.dig(:app_sign_up_flow_locator, "public_id")
    assert_equal "fresh-nonce", session.dig(:app_sign_up_flow_locator, "nonce")
    assert cycle.reload.nonce_matches?("fresh-nonce")
  end

  test "refuses a session payload without a nonce for the admitted owner" do
    binding = SignUpAdmissionTestFactory.binding_for!(ClientSignUpFlow)
    ceremony = ClientAuthCeremonySession.find(binding.admitted_auth_ceremony_session_id)
    cycle = ClientSignUpFlow.create!(
      auth_admission_binding: binding,
      status_id: ClientSignUpFlowStatus::STARTED,
      step: "start",
      nonce_digest: ClientSignUpFlow.digest_nonce("a-nonce"),
      issued_at: Time.current,
      expires_at: 15.minutes.from_now,
      entry_method: "email",
    )
    session = { app_sign_up_flow_locator: { "public_id" => cycle.public_id } }
    locator = SignUpCycleLocator.new(session, surface: :app)

    assert_raises(SignUpCycleLocator::OwnershipMismatch) do
      locator.current(admission_binding: binding, ceremony_session: ceremony)
    end
  end

  test "returns nil for an admitted owner without a flow or a session payload" do
    binding = SignUpAdmissionTestFactory.binding_for!(ClientSignUpFlow)
    ceremony = ClientAuthCeremonySession.find(binding.admitted_auth_ceremony_session_id)
    locator = SignUpCycleLocator.new({}, surface: :app)

    assert_nil locator.current(admission_binding: binding, ceremony_session: ceremony)
  end

  test "an admitted owner without any flow holds no unreleased attempt" do
    binding = SignUpAdmissionTestFactory.binding_for!(ClientSignUpFlow)
    ceremony = ClientAuthCeremonySession.find(binding.admitted_auth_ceremony_session_id)

    assert_not SignUpCycleLocator.new({}, surface: :app)
      .unreleased_attempt?(admission_binding: binding, ceremony_session: ceremony)
  end

  # The predicate reads only status and cleanup, never the clock: a nonterminal flow, including one
  # past its deadline, is released only by the expiry job. Travelling past the deadline would also
  # expire the admission parent, which refuses the lookup before the predicate is reached.
  test "a nonterminal flow stays unreleased until the expiry job ends it" do
    binding, ceremony, flow = owned_flow

    assert_not_predicate flow, :sign_up_terminal?
    assert SignUpCycleLocator.new({}, surface: :app)
      .unreleased_attempt?(admission_binding: binding, ceremony_session: ceremony)
  end

  test "a terminal flow stays unreleased while its cleanup is pending, failed, or past the retry cap" do
    binding, ceremony, flow = owned_flow
    locator = SignUpCycleLocator.new({}, surface: :app)
    [
      { cleanup_status_id: flow.cleanup_status_id_for(:pending), cleanup_attempts_count: 0 },
      { cleanup_status_id: flow.cleanup_status_id_for(:failed), cleanup_attempts_count: 1 },
      {
        cleanup_status_id: flow.cleanup_status_id_for(:failed),
        cleanup_attempts_count: SignUpArtifactCleanup::MAX_CLEANUP_ATTEMPTS,
      },
    ].each do |cleanup|
      flow.update_columns(cleanup.merge(status_id: ClientSignUpFlowStatus::CANCELLED))

      assert locator.unreleased_attempt?(admission_binding: binding, ceremony_session: ceremony), cleanup.inspect
    end
  end

  test "a terminal flow whose cleanup completed, or a completed sign-up, releases the entry" do
    binding, ceremony, flow = owned_flow
    locator = SignUpCycleLocator.new({}, surface: :app)
    flow.update_columns(
      status_id: ClientSignUpFlowStatus::CANCELLED, cleanup_status_id: flow.cleanup_status_id_for(:completed),
    )

    assert_not locator.unreleased_attempt?(admission_binding: binding, ceremony_session: ceremony)

    flow.update_columns(
      status_id: ClientSignUpFlowStatus::COMPLETED,
      cleanup_status_id: flow.cleanup_status_id_for(:idle),
    )

    assert_not locator.unreleased_attempt?(admission_binding: binding, ceremony_session: ceremony)
  end

  private

  def owned_flow
    binding = SignUpAdmissionTestFactory.binding_for!(ClientSignUpFlow)
    ceremony = ClientAuthCeremonySession.find(binding.admitted_auth_ceremony_session_id)
    flow = ClientSignUpFlow.create!(
      auth_admission_binding: binding,
      status_id: ClientSignUpFlowStatus::STARTED,
      step: "start",
      nonce_digest: ClientSignUpFlow.digest_nonce("a-nonce"),
      issued_at: Time.current,
      expires_at: 15.minutes.from_now,
      entry_method: "email",
    )
    [binding, ceremony, flow]
  end
end
