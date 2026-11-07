# frozen_string_literal: true

class CreateRpBaseOrgSessionAvatarSelections < ActiveRecord::Migration[8.2]
  def change
    create_table(:rp_base_org_session_avatar_selections)
  end
end
