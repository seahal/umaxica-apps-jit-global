# typed: false
# frozen_string_literal: true

require "test_helper"

class ExternalSignIn::OrgEntraResolverTest < ActiveSupport::TestCase
  TENANT_ID = "11111111-2222-3333-4444-555555555555"
  OBJECT_ID = "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"

  setup do
    OrganizationEntraConnectionState.ensure_defaults!
    OperatorEntraIdentityState.ensure_defaults!

    @active_connection = OrganizationEntraConnection.create!(
      organization_id: 1,
      entra_tenant_id: TENANT_ID,
      entra_client_id: "resolver-test-client-id",
      entra_credential_key: "resolver-test-secret",
      status_id: OrganizationEntraConnectionState::ACTIVE,
    )

    @operator = Operator.create!(security_mode_id: SecurityModeConfigurable::ADVANCED, status_id: OperatorStatus::ACTIVE)

    @active_identity = OperatorEntraIdentity.create!(
      operator_id: @operator.id,
      connection_id: @active_connection.id,
      entra_tenant_id: TENANT_ID,
      entra_object_id: OBJECT_ID,
      status_id: OperatorEntraIdentityState::ACTIVE,
    )
  end

  # --- success path ---

  test "returns the OperatorEntraIdentity when identity and connection are both ACTIVE" do
    result = resolve(tenant_id: TENANT_ID, object_id: OBJECT_ID)

    assert_equal @active_identity.id, result.identity.id
    assert_equal @operator.id, result.identity.operator_id
  end

  test "resolves an identity that has no connection reference" do
    detached_oid = "99999999-8888-7777-6666-555555555555"
    OperatorEntraIdentity.create!(
      operator_id: 9101,
      connection_id: nil,
      entra_tenant_id: TENANT_ID,
      entra_object_id: detached_oid,
      status_id: OperatorEntraIdentityState::ACTIVE,
    )

    result = resolve(tenant_id: TENANT_ID, object_id: detached_oid)

    assert_equal detached_oid, result.identity.entra_object_id
  end

  test "returns the Operator for the resolved identity" do
    result = resolve(tenant_id: TENANT_ID, object_id: OBJECT_ID)

    assert_equal @operator, result.operator
  end

  test "returns nil operator when the logical operator reference is stale" do
    stale_oid = "bbbbbbbb-cccc-dddd-eeee-ffffffffffff"
    OperatorEntraIdentity.create!(
      operator_id: 9002,
      connection_id: @active_connection.id,
      entra_tenant_id: TENANT_ID,
      entra_object_id: stale_oid,
      status_id: OperatorEntraIdentityState::ACTIVE,
    )

    result = resolve(tenant_id: TENANT_ID, object_id: stale_oid)

    assert_nil result.operator
  end

  # The tenant is part of the lookup key, so an oid that exists under a
  # different tenant must not resolve. Tenant restriction itself is enforced
  # upstream by the strategy's ID token verification against the single
  # configured tenant.
  test "raises IdentityNotFoundError when the oid belongs to a different tenant" do
    other_tenant = "44444444-5555-6666-7777-888888888888"
    OperatorEntraIdentity.create!(
      operator_id: 9102,
      connection_id: nil,
      entra_tenant_id: other_tenant,
      entra_object_id: OBJECT_ID,
      status_id: OperatorEntraIdentityState::ACTIVE,
    )

    assert_raises(ExternalSignIn::IdentityNotFoundError) do
      resolve(tenant_id: "55555555-6666-7777-8888-999999999999", object_id: OBJECT_ID)
    end
  end

  # --- identity not found ---

  test "raises IdentityNotFoundError when no identity matches (tid, oid)" do
    assert_raises(ExternalSignIn::IdentityNotFoundError) do
      resolve(tenant_id: TENANT_ID, object_id: "00000000-0000-0000-0000-000000000000")
    end
  end

  test "raises IdentityNotFoundError when identity is NOTHING (not yet activated)" do
    inactive_identity = OperatorEntraIdentity.create!(
      operator_id: 9002,
      connection_id: @active_connection.id,
      entra_tenant_id: TENANT_ID,
      entra_object_id: "bbbbbbbb-cccc-dddd-eeee-000000000000",
      status_id: OperatorEntraIdentityState::NOTHING,
    )

    assert_raises(ExternalSignIn::IdentityNotFoundError) do
      resolve(tenant_id: TENANT_ID, object_id: inactive_identity.entra_object_id)
    end
  end

  test "raises IdentityNotFoundError when identity is SUSPENDED" do
    suspended = OperatorEntraIdentity.create!(
      operator_id: 9003,
      connection_id: @active_connection.id,
      entra_tenant_id: TENANT_ID,
      entra_object_id: "cccccccc-dddd-eeee-ffff-000000000000",
      status_id: OperatorEntraIdentityState::SUSPENDED,
    )

    assert_raises(ExternalSignIn::IdentityNotFoundError) do
      resolve(tenant_id: TENANT_ID, object_id: suspended.entra_object_id)
    end
  end

  test "raises IdentityNotFoundError when identity is REVOKED" do
    revoked = OperatorEntraIdentity.create!(
      operator_id: 9004,
      connection_id: @active_connection.id,
      entra_tenant_id: TENANT_ID,
      entra_object_id: "dddddddd-eeee-ffff-0000-111111111111",
      status_id: OperatorEntraIdentityState::REVOKED,
    )

    assert_raises(ExternalSignIn::IdentityNotFoundError) do
      resolve(tenant_id: TENANT_ID, object_id: revoked.entra_object_id)
    end
  end

  # Connection-state cases were removed with the connection concept: the org
  # surface federates one tenant configured in Rails credentials, so
  # OrganizationEntraConnection is no longer read during sign-in. Revoking
  # access is now an identity-state change, covered by the SUSPENDED and
  # REVOKED cases above.

  # --- no provisioning side-effects ---

  test "does not create any record when no identity is found" do
    count_before = OperatorEntraIdentity.count

    assert_raises(ExternalSignIn::IdentityNotFoundError) do
      resolve(tenant_id: TENANT_ID, object_id: "00000000-0000-0000-0000-000000000000")
    end

    assert_equal count_before, OperatorEntraIdentity.count
  end

  private

  def resolve(tenant_id:, object_id:)
    ExternalSignIn::OrgEntraResolver.new(
      tenant_context: ExternalAuthentication::EntraTenantContext.new(
        tenant_id: tenant_id,
        object_identifier: object_id,
      ),
    ).call
  end
end
