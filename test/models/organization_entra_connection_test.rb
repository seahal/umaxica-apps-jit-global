# typed: false
# frozen_string_literal: true

require "test_helper"

class OrganizationEntraConnectionTest < ActiveSupport::TestCase
  VALID_TENANT_ID = "11111111-2222-3333-4444-555555555555"
  VALID_CLIENT_ID = "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
  OTHER_TENANT_ID = "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
  OTHER_ORG_ID    = 999

  setup do
    OrganizationEntraConnectionState.ensure_defaults!
  end

  # --- schema invariants ---

  test "table has no email column" do
    assert_not OrganizationEntraConnection.column_names.include?("email"),
               "email column must not exist on organization_entra_connections"
  end

  test "table has no upn column" do
    assert_not OrganizationEntraConnection.column_names.include?("upn"),
               "upn column must not exist on organization_entra_connections"
  end

  test "table has no preferred_username column" do
    assert_not OrganizationEntraConnection.column_names.include?("preferred_username"),
               "preferred_username column must not exist on organization_entra_connections"
  end

  test "uses org_zenith database" do
    assert_equal OrgRpRecord.connection_db_config.name,
                 OrganizationEntraConnection.connection_db_config.name
  end

  # --- default status ---

  test "defaults to NOTHING status" do
    connection = OrganizationEntraConnection.new

    assert_equal OrganizationEntraConnectionState::NOTHING, connection.status_id
  end

  test "stores only a credential reference" do
    connection = OrganizationEntraConnection.create!(
      organization_id: 1,
      entra_tenant_id: VALID_TENANT_ID,
      entra_client_id: VALID_CLIENT_ID,
      entra_credential_key: "ENTRA_TEST_CERTIFICATE",
      status_id: OrganizationEntraConnectionState::NOTHING,
    )

    raw = OrganizationEntraConnection.connection.select_one(
      "SELECT entra_credential_key FROM organization_entra_connections WHERE id = #{connection.id}",
    )

    assert_equal "ENTRA_TEST_CERTIFICATE", raw["entra_credential_key"]
  end

  # --- valid record ---

  test "saves a valid record and generates public_id" do
    connection = OrganizationEntraConnection.create!(
      organization_id: 1,
      entra_tenant_id: VALID_TENANT_ID,
      entra_client_id: VALID_CLIENT_ID,
      entra_credential_key: "secret",
      status_id: OrganizationEntraConnectionState::NOTHING,
    )

    assert_predicate connection.public_id, :present?
    assert_equal 21, connection.public_id.length
  end

  # --- presence validations ---

  test "requires organization_id" do
    connection = build_connection(organization_id: nil)

    assert_not connection.valid?
    assert connection.errors.of_kind?(:organization_id, :blank)
  end

  test "requires entra_tenant_id" do
    connection = build_connection(entra_tenant_id: nil)

    assert_not connection.valid?
    assert connection.errors.of_kind?(:entra_tenant_id, :blank)
  end

  test "requires entra_client_id" do
    connection = build_connection(entra_client_id: nil)

    assert_not connection.valid?
    assert connection.errors.of_kind?(:entra_client_id, :blank)
  end

  test "requires entra_credential_key" do
    connection = build_connection(entra_credential_key: nil)

    assert_not connection.valid?
    assert connection.errors.of_kind?(:entra_credential_key, :blank)
  end

  # --- UUID format validation ---

  test "rejects non-UUID entra_tenant_id" do
    connection = build_connection(entra_tenant_id: "not-a-uuid")

    assert_not connection.valid?
    assert connection.errors.of_kind?(:entra_tenant_id, :invalid)
  end

  test "rejects entra_tenant_id with wrong UUID format" do
    connection = build_connection(entra_tenant_id: "ZZZZZZZZ-ZZZZ-ZZZZ-ZZZZ-ZZZZZZZZZZZZ")

    assert_not connection.valid?
    assert connection.errors.of_kind?(:entra_tenant_id, :invalid)
  end

  test "accepts valid UUID entra_tenant_id" do
    connection = build_connection(entra_tenant_id: VALID_TENANT_ID)

    assert_predicate connection, :valid?
  end

  # --- uniqueness constraints ---

  test "disallows duplicate entra_tenant_id for same organization" do
    OrganizationEntraConnection.create!(
      organization_id: 1,
      entra_tenant_id: VALID_TENANT_ID,
      entra_client_id: VALID_CLIENT_ID,
      entra_credential_key: "secret",
      status_id: OrganizationEntraConnectionState::NOTHING,
    )

    duplicate = build_connection(
      organization_id: 1, entra_tenant_id: VALID_TENANT_ID,
      entra_client_id: "different-client-id",
    )

    assert_not duplicate.valid?
    assert duplicate.errors.of_kind?(:entra_tenant_id, :taken)
  end

  test "allows same entra_tenant_id for different organizations" do
    OrganizationEntraConnection.create!(
      organization_id: 1,
      entra_tenant_id: VALID_TENANT_ID,
      entra_client_id: VALID_CLIENT_ID,
      entra_credential_key: "secret",
      status_id: OrganizationEntraConnectionState::NOTHING,
    )

    other = build_connection(
      organization_id: OTHER_ORG_ID, entra_tenant_id: VALID_TENANT_ID,
      entra_client_id: "other-client",
    )

    assert_predicate other, :valid?
  end

  test "disallows duplicate entra_client_id for same entra_tenant_id" do
    OrganizationEntraConnection.create!(
      organization_id: 1,
      entra_tenant_id: VALID_TENANT_ID,
      entra_client_id: VALID_CLIENT_ID,
      entra_credential_key: "secret",
      status_id: OrganizationEntraConnectionState::NOTHING,
    )

    duplicate = build_connection(
      organization_id: OTHER_ORG_ID, entra_tenant_id: VALID_TENANT_ID,
      entra_client_id: VALID_CLIENT_ID,
    )

    assert_not duplicate.valid?
    assert duplicate.errors.of_kind?(:entra_client_id, :taken)
  end

  # --- no callback-facing provisioning API ---

  test "has no find_or_create_by_entra_claims class method" do
    assert_not OrganizationEntraConnection.respond_to?(:find_or_create_by_entra_claims)
  end

  test "has no upsert_from_token class method" do
    assert_not OrganizationEntraConnection.respond_to?(:upsert_from_token)
  end

  test "public_id is a fixed 21-character NanoID" do
    assert_public_id_fixed_length(::OrganizationEntraConnection)
  end

  private

  def build_connection(overrides = {})
    OrganizationEntraConnection.new(
      {
        organization_id: 1,
        entra_tenant_id: VALID_TENANT_ID,
        entra_client_id: VALID_CLIENT_ID,
        entra_credential_key: "secret",
        status_id: OrganizationEntraConnectionState::NOTHING,
      }.merge(overrides),
    )
  end
end
