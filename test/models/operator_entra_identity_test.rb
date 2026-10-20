# typed: false
# frozen_string_literal: true

require "test_helper"

class OperatorEntraIdentityTest < ActiveSupport::TestCase
  VALID_TENANT_ID = "11111111-2222-3333-4444-555555555555"
  VALID_OID       = "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
  OTHER_OID       = "ffffffff-eeee-dddd-cccc-bbbbbbbbbbbb"

  setup do
    OrganizationEntraConnectionState.ensure_defaults!
    OperatorEntraIdentityState.ensure_defaults!

    @connection = OrganizationEntraConnection.create!(
      organization_id: 1,
      entra_tenant_id: VALID_TENANT_ID,
      entra_client_id: "client-id-for-identity-tests",
      entra_credential_key: "secret",
      status_id: OrganizationEntraConnectionState::ACTIVE,
    )
  end

  # --- schema invariants ---

  test "table has no email column" do
    assert_not OperatorEntraIdentity.column_names.include?("email"),
               "email column must not exist on operator_entra_identities"
  end

  test "table has no upn column" do
    assert_not OperatorEntraIdentity.column_names.include?("upn"),
               "upn column must not exist on operator_entra_identities"
  end

  test "table has no preferred_username column" do
    assert_not OperatorEntraIdentity.column_names.include?("preferred_username"),
               "preferred_username column must not exist on operator_entra_identities"
  end

  test "table has no display_name column" do
    assert_not OperatorEntraIdentity.column_names.include?("display_name"),
               "display_name column must not exist on operator_entra_identities"
  end

  test "evidence_issuer and evidence_subject are nullable" do
    col_issuer  = OperatorEntraIdentity.columns_hash["evidence_issuer"]
    col_subject = OperatorEntraIdentity.columns_hash["evidence_subject"]

    assert col_issuer.null,  "evidence_issuer must be nullable (protocol evidence only)"
    assert col_subject.null, "evidence_subject must be nullable (protocol evidence only)"
  end

  test "uses org_zenith database" do
    assert_equal OrgRpRecord.connection_db_config.name,
                 OperatorEntraIdentity.connection_db_config.name
  end

  # --- default status ---

  test "defaults to NOTHING status" do
    identity = OperatorEntraIdentity.new

    assert_equal OperatorEntraIdentityState::NOTHING, identity.status_id
  end

  # --- valid record ---

  test "saves a valid record and generates public_id" do
    identity = OperatorEntraIdentity.create!(
      operator_id: 101,
      connection_id: @connection.id,
      entra_tenant_id: VALID_TENANT_ID,
      entra_object_id: VALID_OID,
      status_id: OperatorEntraIdentityState::NOTHING,
    )

    assert_predicate identity.public_id, :present?
    assert_equal 21, identity.public_id.length
  end

  test "saves with optional evidence fields" do
    identity = OperatorEntraIdentity.create!(
      operator_id: 102,
      connection_id: @connection.id,
      entra_tenant_id: VALID_TENANT_ID,
      entra_object_id: OTHER_OID,
      evidence_issuer: "https://login.microsoftonline.com/#{VALID_TENANT_ID}/v2.0",
      evidence_subject: "sub-value-for-this-client",
      status_id: OperatorEntraIdentityState::NOTHING,
    )

    assert_equal "https://login.microsoftonline.com/#{VALID_TENANT_ID}/v2.0", identity.evidence_issuer
    assert_equal "sub-value-for-this-client", identity.evidence_subject
  end

  # --- presence validations ---

  test "requires operator_id" do
    identity = build_identity(operator_id: nil)

    assert_not identity.valid?
    assert identity.errors.of_kind?(:operator_id, :blank)
  end

  # connection_id is optional: sign-in resolves an identity by (tid, oid) and
  # never reads a connection, so an identity provisioned for the single
  # configured tenant carries no connection reference.
  test "does not require connection_id" do
    identity = build_identity(connection_id: nil)

    assert_predicate identity, :valid?
  end

  test "requires entra_tenant_id" do
    identity = build_identity(entra_tenant_id: nil)

    assert_not identity.valid?
    assert identity.errors.of_kind?(:entra_tenant_id, :blank)
  end

  test "requires entra_object_id" do
    identity = build_identity(entra_object_id: nil)

    assert_not identity.valid?
    assert identity.errors.of_kind?(:entra_object_id, :blank)
  end

  # --- UUID format validation ---

  test "rejects non-UUID entra_tenant_id" do
    identity = build_identity(entra_tenant_id: "not-a-uuid")

    assert_not identity.valid?
    assert identity.errors.of_kind?(:entra_tenant_id, :invalid)
  end

  test "rejects non-UUID entra_object_id" do
    identity = build_identity(entra_object_id: "not-a-uuid")

    assert_not identity.valid?
    assert identity.errors.of_kind?(:entra_object_id, :invalid)
  end

  test "accepts valid UUID entra_object_id" do
    identity = build_identity(entra_object_id: VALID_OID)

    assert_predicate identity, :valid?
  end

  # --- uniqueness constraints ---

  test "disallows duplicate (entra_tenant_id, entra_object_id)" do
    OperatorEntraIdentity.create!(
      operator_id: 201,
      connection_id: @connection.id,
      entra_tenant_id: VALID_TENANT_ID,
      entra_object_id: VALID_OID,
      status_id: OperatorEntraIdentityState::NOTHING,
    )

    duplicate = build_identity(
      operator_id: 202, entra_tenant_id: VALID_TENANT_ID,
      entra_object_id: VALID_OID,
    )

    assert_not duplicate.valid?
    assert duplicate.errors.of_kind?(:entra_tenant_id, :taken)
  end

  test "allows same tenant with different oid" do
    OperatorEntraIdentity.create!(
      operator_id: 203,
      connection_id: @connection.id,
      entra_tenant_id: VALID_TENANT_ID,
      entra_object_id: VALID_OID,
      status_id: OperatorEntraIdentityState::NOTHING,
    )

    other = build_identity(
      operator_id: 204, entra_tenant_id: VALID_TENANT_ID,
      entra_object_id: OTHER_OID,
    )

    assert_predicate other, :valid?
  end

  test "disallows duplicate operator_id" do
    OperatorEntraIdentity.create!(
      operator_id: 301,
      connection_id: @connection.id,
      entra_tenant_id: VALID_TENANT_ID,
      entra_object_id: VALID_OID,
      status_id: OperatorEntraIdentityState::NOTHING,
    )

    duplicate = build_identity(operator_id: 301, entra_object_id: OTHER_OID)

    assert_not duplicate.valid?
    assert duplicate.errors.of_kind?(:operator_id, :taken)
  end

  # --- no callback-facing provisioning API ---

  test "has no find_or_create_by_entra_claims class method" do
    assert_not OperatorEntraIdentity.respond_to?(:find_or_create_by_entra_claims)
  end

  test "has no upsert_from_token class method" do
    assert_not OperatorEntraIdentity.respond_to?(:upsert_from_token)
  end

  test "public_id is a fixed 21-character NanoID" do
    assert_public_id_fixed_length(::OperatorEntraIdentity)
  end

  private

  def build_identity(overrides = {})
    OperatorEntraIdentity.new(
      {
        operator_id: 101,
        connection_id: @connection.id,
        entra_tenant_id: VALID_TENANT_ID,
        entra_object_id: VALID_OID,
        status_id: OperatorEntraIdentityState::NOTHING,
      }.merge(overrides),
    )
  end
end
