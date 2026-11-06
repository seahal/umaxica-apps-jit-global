# frozen_string_literal: true

class CreateRpBaseOrgSessionSelections < ActiveRecord::Migration[8.2]
  def change
    create_table(:rp_base_org_session_selections)
  end
end
