# frozen_string_literal: true

# WU-16 / WU-22 (two.md 5.8 v2, D-172): add explicitly restrictive references without
# taking a validation lock. The next migration validates them before removing the old FKs.
class EnforceOpOrgAuthorityStopForeignKeyRestrictionsOpBaseOrg < ActiveRecord::Migration[8.2]
  FOREIGN_KEYS = [
    %w(op_org_authority_stops op_org_authority_stop_causes cause_id fk_org_stop_restrict_01),
    %w(op_org_authority_stops op_org_authority_stop_scopes scope_id fk_org_stop_restrict_02),
    %w(op_org_authority_stop_root_targets op_org_authority_stops stop_id fk_org_stop_restrict_03),
    %w(op_org_authority_stop_root_targets operator_tokens root_id fk_org_stop_restrict_04),
    %w(op_org_authority_stop_grant_targets op_org_authority_stops stop_id fk_org_stop_restrict_05),
    %w(op_org_authority_stop_grant_targets op_org_grants grant_id fk_org_stop_restrict_06),
    %w(op_org_authority_stop_epoch_cutoffs op_org_authority_stops stop_id fk_org_stop_restrict_07),
    %w(op_org_authority_stop_participants op_org_authority_stops stop_id fk_org_stop_restrict_08),
    %w(op_org_authority_stop_participants op_org_grants grant_id fk_org_stop_restrict_09),
    %w(op_org_authority_stop_participants op_org_authority_stop_participant_statuses status_id fk_org_stop_restrict_10),
    %w(op_org_authority_stop_browser_logouts op_org_authority_stops stop_id fk_org_stop_restrict_11),
  ].freeze

  def up
    FOREIGN_KEYS.each do |table, target, column, name|
      add_foreign_key(table, target, column:, name:, on_delete: :restrict, validate: false)
    end
  end

  def down
    FOREIGN_KEYS.each do |table, _target, _column, name|
      remove_foreign_key(table, name:) if foreign_key_exists?(table, name:)
    end
  end
end
