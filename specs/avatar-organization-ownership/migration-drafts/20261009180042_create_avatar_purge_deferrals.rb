# frozen_string_literal: true

class CreateAvatarPurgeDeferrals < ActiveRecord::Migration[8.2]
  def change
    create_table(:avatar_purge_deferrals) do |t|
    end
  end
end
