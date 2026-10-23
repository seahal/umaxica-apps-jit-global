# typed: false
# frozen_string_literal: true

require "test_helper"

class OperatorEntraIdentityProvisionerTest < ActiveSupport::TestCase
  TENANT_ID = "11111111-2222-3333-4444-555555555555"
  OBJECT_ID = "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"

  setup do
    OperatorEntraIdentityState.ensure_defaults!
    @operator = Operator.create!(security_mode_id: SecurityModeConfigurable::ADVANCED, status_id: OperatorStatus::ACTIVE)
  end

  test "creates the identity in the pinned tenant, inactive" do
    result = with_pinned_tenant { provision(@operator.public_id, OBJECT_ID) }

    assert_equal TENANT_ID, result.identity.entra_tenant_id
    assert_equal OBJECT_ID, result.identity.entra_object_id
    assert_equal @operator.id, result.identity.operator_id
    # Deny-by-default at the data layer: provisioning alone must not permit sign-in.
    assert_equal OperatorEntraIdentityState::NOTHING, result.identity.status_id
    assert_not result.identity.reload.status_id == OperatorEntraIdentityState::ACTIVE
  end

  # The tenant is configuration, not input. An administrator must not be able to
  # bind an operator to a tenant this deployment does not federate, so there is
  # no tenant parameter to pass and the record follows whatever is configured.
  test "takes the tenant from configuration and offers no way to override it" do
    other_tenant = "99999999-8888-7777-6666-555555555555"

    result =
      ExternalAuthentication::ProviderRegistry.stub(:tenant_id, ->(_) { other_tenant }) do
        provision(@operator.public_id, OBJECT_ID)
      end

    assert_equal other_tenant, result.identity.entra_tenant_id
    assert_equal %i(operator_public_id entra_object_id),
                 OperatorEntraIdentityProvisioner.instance_method(:initialize).parameters.map(&:last)
  end

  test "accepts the public_id in the form an administrator reads it" do
    hyphenated = @operator.public_id.scan(/.{1,4}/).join("-").downcase

    result = with_pinned_tenant { provision(hyphenated, OBJECT_ID) }

    assert_equal @operator.id, result.identity.operator_id
  end

  test "rejects an object id that is not a UUID" do
    error =
      assert_raises(OperatorEntraIdentityProvisioner::InvalidObjectId) do
        with_pinned_tenant { provision(@operator.public_id, "someone@example.com") }
      end

    assert_match(/UUID/, error.message)
    assert_equal 0, OperatorEntraIdentity.count
  end

  test "rejects an unknown operator" do
    assert_raises(OperatorEntraIdentityProvisioner::OperatorNotFound) do
      with_pinned_tenant { provision("NOSUCHOPERATOR", OBJECT_ID) }
    end

    assert_equal 0, OperatorEntraIdentity.count
  end

  test "rejects an app Client identifier as an org Entra provisioning target" do
    client = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, public_id: PublicId.generate)

    assert_raises(OperatorEntraIdentityProvisioner::OperatorNotFound) do
      with_pinned_tenant { provision(client.public_id, OBJECT_ID) }
    end
    assert_equal 0, OperatorEntraIdentity.count
  end

  test "refuses to give one operator a second Entra identity" do
    with_pinned_tenant { provision(@operator.public_id, OBJECT_ID) }

    assert_raises(OperatorEntraIdentityProvisioner::AlreadyProvisioned) do
      with_pinned_tenant { provision(@operator.public_id, "bbbbbbbb-cccc-dddd-eeee-ffffffffffff") }
    end

    assert_equal 1, OperatorEntraIdentity.count
  end

  # A typo'd public_id must not silently move an Entra account onto another operator.
  test "refuses to map one Entra object to a second operator" do
    with_pinned_tenant { provision(@operator.public_id, OBJECT_ID) }
    other = Operator.create!(security_mode_id: SecurityModeConfigurable::ADVANCED, status_id: OperatorStatus::ACTIVE)

    error =
      assert_raises(OperatorEntraIdentityProvisioner::AlreadyProvisioned) do
        with_pinned_tenant { provision(other.public_id, OBJECT_ID) }
      end

    assert_match(/another operator/, error.message)
    assert_equal 1, OperatorEntraIdentity.count
  end

  # A rehire is a new operator, so the returning person is provisioned fresh. Until
  # retention purge removes the withdrawn mapping it still occupies the (tid, oid),
  # and the administrator needs to know that is what they are waiting on rather
  # than go hunting for an operator that no longer exists.
  test "says the mapping is withdrawn and awaiting purge, not that it belongs to someone" do
    with_pinned_tenant { provision(@operator.public_id, OBJECT_ID) }
    OperatorEntraIdentity.find_by(operator_id: @operator.id)
      .update!(status_id: OperatorEntraIdentityState::REVOKED)
    returning = Operator.create!(security_mode_id: SecurityModeConfigurable::ADVANCED, status_id: OperatorStatus::ACTIVE)

    error =
      assert_raises(OperatorEntraIdentityProvisioner::AlreadyProvisioned) do
        with_pinned_tenant { provision(returning.public_id, OBJECT_ID) }
      end

    assert_match(/withdrawn operator/, error.message)
    assert_match(/retention purge/, error.message)
  end

  test "fails loudly when the tenant is not configured" do
    ExternalAuthentication::ProviderRegistry.stub(:tenant_id, ->(_) { raise KeyError, "credential missing" }) do
      assert_raises(KeyError) { provision(@operator.public_id, OBJECT_ID) }
    end

    assert_equal 0, OperatorEntraIdentity.count
  end

  private

  def provision(operator_public_id, entra_object_id)
    OperatorEntraIdentityProvisioner.call(
      operator_public_id: operator_public_id,
      entra_object_id: entra_object_id,
    )
  end

  def with_pinned_tenant(&)
    ExternalAuthentication::ProviderRegistry.stub(:tenant_id, ->(_) { TENANT_ID }, &)
  end
end
