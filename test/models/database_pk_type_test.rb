# typed: false
# frozen_string_literal: true

require "test_helper"

class DatabasePkTypeTest < ActiveSupport::TestCase
  # Test that representative tables from each schema have bigint PKs
  # After migration, all status/kind/master tables should use bigint

  test "operator schema tables use bigint primary keys" do
    assert_bigint_pk(OperatorWorkspaceAccountStatus)
    assert_bigint_pk(OperatorStatus)
    assert_bigint_pk(OrganizationStatus)
  end

  test "principal schema tables use bigint primary keys" do
    assert_bigint_pk(ClientStatus)
    assert_bigint_pk(MemberStatus)
    assert_bigint_pk(ClientSecretCredential)
  end

  test "avatar schema tables use bigint primary keys" do
    assert_bigint_pk(HandleStatus)
    assert_bigint_pk(AvatarCapability)
  end

  test "occurrence schema tables use bigint primary keys" do
    assert_bigint_pk(AreaOccurrenceStatus)
    assert_bigint_pk(EmailOccurrenceStatus)
  end

  test "config, option, and setting schemas tables use bigint primary keys" do
    assert_bigint_pk(ComPreferenceStatus)
    assert_bigint_pk(ComPreferenceLanguageOption)
    assert_bigint_pk(ComPreference)
  end

  test "guest schema tables use bigint primary keys" do
    assert_bigint_pk(VisitorStatus)
    assert_bigint_pk(VisitorSecretCredentialKind)
  end

  test "chronicle schema tables use bigint primary keys" do
    assert_bigint_pk(OperatorChronicleEvent)
    assert_bigint_pk(ClientChronicleLevel)
  end

  test "models with code column use citext" do
    models = [OperatorTokenKind, OperatorTokenStatus, ClientTokenKind, ClientTokenStatus]
    models.select! { |model| model.column_names.include?("code") }

    if models.empty?
      assert true, "No models with code column found (migrated to fixed IDs)"
      return
    end

    models.each { |model| assert_code_is_citext(model) }
  end

  private

  def assert_bigint_pk(model)
    id_column = model.columns_hash["id"]

    assert id_column, "#{model.name} should have 'id' column"

    # PostgreSQL bigint is reported as :integer with limit: 8
    sql_type = id_column.sql_type.downcase

    assert ["bigint", "bigserial"].any? { |type| sql_type.include?(type) },
           "#{model.name}.id should be bigint/bigserial, got: #{sql_type}"
  end

  def assert_code_is_citext(model)
    code_column = model.columns_hash["code"]

    assert code_column, "#{model.name} should have 'code' column"

    sql_type = code_column.sql_type.downcase

    assert_includes sql_type, "citext",
                    "#{model.name}.code should be citext, got: #{sql_type}"
  end
end
