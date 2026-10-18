# frozen_string_literal: true

class AddAvatarAccessGrantAuthoritySurface < ActiveRecord::Migration[8.2]
  def up
    add_column(:avatar_enterprise_persona_grants, :granted_by_surface, :string, null: false, default: "app", limit: 3)
    add_column(:avatar_bureau_agent_grants, :granted_by_surface, :string, null: false, default: "org", limit: 3)
    add_check_constraint(
      :avatar_enterprise_persona_grants,
      "granted_by_surface = 'app'",
      name: "chk_avatar_enterprise_persona_grants_authority_surface",
      validate: false,
    )
    add_check_constraint(
      :avatar_bureau_agent_grants,
      "granted_by_surface = 'org'",
      name: "chk_avatar_bureau_agent_grants_authority_surface",
      validate: false,
    )
  end

  def down
    remove_check_constraint(
      :avatar_bureau_agent_grants,
      name: "chk_avatar_bureau_agent_grants_authority_surface",
    )
    remove_check_constraint(
      :avatar_enterprise_persona_grants,
      name: "chk_avatar_enterprise_persona_grants_authority_surface",
    )
    remove_column(:avatar_bureau_agent_grants, :granted_by_surface)
    remove_column(:avatar_enterprise_persona_grants, :granted_by_surface)
  end
end
