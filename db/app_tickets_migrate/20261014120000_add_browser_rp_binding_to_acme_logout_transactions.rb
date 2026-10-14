# frozen_string_literal: true

class AddBrowserRpBindingToAcmeLogoutTransactions < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  TABLE = :acme_logout_transactions
  BINDING_VERSION_CONSTRAINT = "acme_logout_transactions_binding_version"
  BINDING_SHAPE_CONSTRAINT = "acme_logout_transactions_browser_rp_binding_shape"

  def up
    add_column(TABLE, :binding_version, :integer, null: false, default: 0)
    add_column(TABLE, :realm, :string)
    add_column(TABLE, :parent_session_ref, :string)
    add_column(TABLE, :captured_root_ref, :string)
    add_column(TABLE, :root_refresh_family_ref, :string)
    add_column(TABLE, :captured_root_generation, :integer)
    add_column(TABLE, :origin_intent_digest, :binary)

    add_check_constraint(
      TABLE,
      "binding_version IN (0, 1)",
      name: BINDING_VERSION_CONSTRAINT,
      validate: false,
    )
    add_check_constraint(
      TABLE,
      <<~SQL.squish,
        binding_version = 0 OR (
          realm IN ('app', 'com', 'org') AND
          NULLIF(BTRIM(parent_session_ref), '') IS NOT NULL AND
          NULLIF(BTRIM(captured_root_ref), '') IS NOT NULL AND
          NULLIF(BTRIM(root_refresh_family_ref), '') IS NOT NULL AND
          captured_root_generation >= 0 AND
          origin_intent_digest IS NOT NULL AND
          OCTET_LENGTH(origin_intent_digest) = 32
        )
      SQL
      name: BINDING_SHAPE_CONSTRAINT,
      validate: false,
    )

    validate_check_constraint(TABLE, name: BINDING_VERSION_CONSTRAINT)
    validate_check_constraint(TABLE, name: BINDING_SHAPE_CONSTRAINT)
  end

  def down
    remove_check_constraint(TABLE, name: BINDING_SHAPE_CONSTRAINT)
    remove_check_constraint(TABLE, name: BINDING_VERSION_CONSTRAINT)
    remove_column(TABLE, :origin_intent_digest)
    remove_column(TABLE, :captured_root_generation)
    remove_column(TABLE, :root_refresh_family_ref)
    remove_column(TABLE, :captured_root_ref)
    remove_column(TABLE, :parent_session_ref)
    remove_column(TABLE, :realm)
    remove_column(TABLE, :binding_version)
  end
end
