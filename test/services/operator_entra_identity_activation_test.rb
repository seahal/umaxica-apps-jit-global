# typed: false
# frozen_string_literal: true

require "test_helper"

class OperatorEntraIdentityActivationTest < ActiveSupport::TestCase
  TENANT_ID = "11111111-2222-3333-4444-555555555555"
  OBJECT_ID = "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"

  setup do
    OperatorEntraIdentityState.ensure_defaults!
    @operator = Operator.create!(security_mode_id: SecurityModeConfigurable::ADVANCED, status_id: OperatorStatus::ACTIVE)
    @identity = OperatorEntraIdentity.create!(
      operator_id: @operator.id,
      entra_tenant_id: TENANT_ID,
      entra_object_id: OBJECT_ID,
      status_id: OperatorEntraIdentityState::NOTHING,
    )
  end

  test "activation is what makes a provisioned identity usable" do
    result = activate(@operator.public_id, "active")

    assert_equal "inactive", result.previous_state
    assert_equal OperatorEntraIdentityState::ACTIVE, @identity.reload.status_id
  end

  test "suspension stops sign-in without deleting the mapping" do
    activate(@operator.public_id, "active")

    result = activate(@operator.public_id, "suspended")

    assert_equal "active", result.previous_state
    assert_equal OperatorEntraIdentityState::SUSPENDED, @identity.reload.status_id
    assert_equal 1, OperatorEntraIdentity.count
  end

  test "revocation keeps the record and its audit evidence" do
    activate(@operator.public_id, "revoked")

    assert_equal OperatorEntraIdentityState::REVOKED, @identity.reload.status_id
    assert_equal OBJECT_ID, @identity.entra_object_id
  end

  test "rejects a state that is not one of the three" do
    assert_raises(OperatorEntraIdentityActivation::UnsupportedState) do
      activate(@operator.public_id, "enabled")
    end

    assert_equal OperatorEntraIdentityState::NOTHING, @identity.reload.status_id
  end

  test "rejects an operator with no provisioned identity" do
    other = Operator.create!(security_mode_id: SecurityModeConfigurable::ADVANCED, status_id: OperatorStatus::ACTIVE)

    error =
      assert_raises(OperatorEntraIdentityActivation::IdentityNotFound) do
        activate(other.public_id, "active")
      end

    assert_match(/no Entra identity/, error.message)
  end

  test "rejects an unknown operator" do
    assert_raises(OperatorEntraIdentityActivation::IdentityNotFound) do
      activate("NOSUCHOPERATOR", "active")
    end
  end

  private

  def activate(operator_public_id, state)
    OperatorEntraIdentityActivation.call(operator_public_id: operator_public_id, state: state)
  end
end
