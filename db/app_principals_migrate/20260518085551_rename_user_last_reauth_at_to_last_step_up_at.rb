# frozen_string_literal: true
class RenameUserLastReauthAtToLastStepUpAt < ActiveRecord::Migration[8.2]
  def change
    safety_assured do
      rename_column :users, :last_reauth_at, :last_step_up_at
    end
  end
end
