# typed: false
# frozen_string_literal: true

class DropOperatorAuthorizationCodes < ActiveRecord::Migration[8.2]
  def change
    drop_table :operator_authorization_codes, if_exists: true
  end
end
