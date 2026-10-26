# frozen_string_literal: true

class CreateExtensions < ActiveRecord::Migration[7.2]
  def up
    enable_extension('pgcrypto') unless extension_enabled?('pgcrypto')
  end

  def down
    disable_extension('pgcrypto') if extension_enabled?('pgcrypto')
  end
end
