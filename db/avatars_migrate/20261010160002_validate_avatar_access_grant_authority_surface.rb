# frozen_string_literal: true

class ValidateAvatarAccessGrantAuthoritySurface < ActiveRecord::Migration[8.2]
  def up
    validate_check_constraint(
      :avatar_enterprise_persona_grants,
      name: "chk_avatar_enterprise_persona_grants_authority_surface",
    )
    validate_check_constraint(
      :avatar_bureau_agent_grants,
      name: "chk_avatar_bureau_agent_grants_authority_surface",
    )
  end

  def down
    # The preceding migration owns constraint removal.
  end
end
