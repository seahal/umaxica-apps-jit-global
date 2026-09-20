# typed: false
# frozen_string_literal: true

require "test_helper"

# Ownership gates and status gates that decide whether one actor may act on
# another's record. Every arm that answers false is the one keeping a surface's
# accounts and organizations out of another surface's reach, and the checkpoint
# gate is what keeps a sign-in cycle from being advanced from the wrong step.
class OwnershipAndStatusGateSweepTest < ActiveSupport::TestCase
  fixtures :clients, :client_statuses, :client_visibilities, :operators, :operator_statuses

  test "a record type the account gate does not serve is never shown" do
    assert_not AccountPolicy.new(Object.new, user: clients(:one)).show?
  end

  test "a record type the organization gate does not serve is never shown" do
    assert_not OrganizationPolicy.new(Object.new, user: operators(:one)).show?
  end

  # Enforcement cases are staff-only across the board; a client holding one is
  # not a reason to read or raise them.
  test "enforcement cases are refused to anyone who is not an operator" do
    as_client = EnforcementCasePolicy.new(Object.new, user: clients(:one))

    assert_not as_client.index?
    assert_not as_client.show?
    assert_not as_client.create?

    as_operator = EnforcementCasePolicy.new(Object.new, user: operators(:one))

    assert_predicate as_operator, :index?
    assert_predicate as_operator, :show?
    assert_predicate as_operator, :create?
  end

  # A checkpoint may only be shown, and only completed, while the cycle is
  # actually waiting at one -- the two answer identically by design.
  test "the checkpoint gate follows the cycle's own status and nothing else" do
    ClientSignInFlowStatus.ensure_defaults!
    pending = ClientSignInFlow.new(status_id: ClientSignInFlow::STATUS_NAMES.key("CHECKPOINT_PENDING"))
    elsewhere = ClientSignInFlow.new(status_id: ClientSignInFlow::STATUS_NAMES.key("STARTED"))

    assert_predicate SignIn::CyclePolicy.new(pending, user: clients(:one)), :show_checkpoint?
    assert_predicate SignIn::CyclePolicy.new(pending, user: clients(:one)), :complete_checkpoint?
    assert_not SignIn::CyclePolicy.new(elsewhere, user: clients(:one)).show_checkpoint?
    assert_not SignIn::CyclePolicy.new(Object.new, user: clients(:one)).show_checkpoint?
  end

  test "a session-limit token reference that was not signed here resolves to no token" do
    assert_nil SessionLimitResolutionTokenRef.find_client_token("not-a-signed-ref")
    assert_nil SessionLimitResolutionTokenRef.find_client_token(nil)
  end
end
