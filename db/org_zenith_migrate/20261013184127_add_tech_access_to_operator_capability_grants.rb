# frozen_string_literal: true

# Adds Tech's delegable authorization capability to the existing operator grant catalog.
# A rollback restores the old vocabulary and therefore refuses while any Tech grant remains.
# Resolve that condition only with an approved forward migration; never erase grant history.
class AddTechAccessToOperatorCapabilityGrants < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  PREVIOUS_CAPABILITIES = %w(
    support.console.read
    support.account.read.app
    support.account.read.com
    support.session.revoke.app
    support.session.revoke.com
    enforcement.read.app
    enforcement.read.com
    enforcement.apply.app
    enforcement.apply.com
    enforcement.approve.app
    enforcement.approve.com
    enforcement.release.app
    enforcement.release.com
    enforcement.review_appeal.app
    enforcement.review_appeal.com
    iam.capability.read
    iam.capability.grant
    iam.capability.revoke
  ).freeze

  CAPABILITIES = (PREVIOUS_CAPABILITIES + ["tech.access"]).freeze
  PREVIOUS_CONSTRAINT = "chk_operator_capability_grants_capability"
  TECH_CONSTRAINT = "chk_operator_capability_grants_capability_with_tech"

  def up
    add_check_constraint(
      :operator_capability_grants,
      "capability IN (#{quoted_list(CAPABILITIES)})",
      name: TECH_CONSTRAINT,
      validate: false,
    )
    validate_check_constraint(:operator_capability_grants, name: TECH_CONSTRAINT)
    remove_check_constraint(:operator_capability_grants, name: PREVIOUS_CONSTRAINT)
  end

  def down
    if select_value("SELECT EXISTS (SELECT 1 FROM operator_capability_grants WHERE capability = 'tech.access')")
      raise ActiveRecord::IrreversibleMigration,
            "tech.access grants exist; preserve them and repair with a forward capability migration"
    end

    add_check_constraint(
      :operator_capability_grants,
      "capability IN (#{quoted_list(PREVIOUS_CAPABILITIES)})",
      name: PREVIOUS_CONSTRAINT,
      validate: false,
    )
    validate_check_constraint(:operator_capability_grants, name: PREVIOUS_CONSTRAINT)
    remove_check_constraint(:operator_capability_grants, name: TECH_CONSTRAINT)
  end

  private

  def quoted_list(values)
    values.map { |value| "'#{value}'" }.join(", ")
  end
end
