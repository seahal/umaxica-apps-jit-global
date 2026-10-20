# frozen_string_literal: true

class ValidateNanoidPublicIdLengthAvatar < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def change
    validate_check_constraint(:avatars, name: "chk_avatars_pid")
    validate_check_constraint(:avatar_agent_bindings, name: "chk_avatar_agent_bindings_pid")
    validate_check_constraint(:avatar_bureau_agent_grants, name: "chk_avatar_bureau_agent_grants_pid")
    validate_check_constraint(:avatar_enterprise_persona_grants, name: "chk_avatar_enterprise_persona_grants_pid")
    validate_check_constraint(:avatar_groups, name: "chk_avatar_groups_pid")
    validate_check_constraint(:avatar_individual_bindings, name: "chk_avatar_individual_bindings_pid")
    validate_check_constraint(:avatar_ownership_transfers, name: "chk_avatar_ownership_transfers_pid")
    validate_check_constraint(:avatar_persona_bindings, name: "chk_avatar_persona_bindings_pid")
    validate_check_constraint(:avatar_transfer_reservations, name: "chk_avatar_transfer_reservations_pid")
    validate_check_constraint(:group_avatar_memberships, name: "chk_group_avatar_memberships_pid")
    validate_check_constraint(:handles, name: "chk_handles_pid")
  end
end
