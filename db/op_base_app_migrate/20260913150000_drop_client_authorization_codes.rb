# typed: false
# frozen_string_literal: true

class DropClientAuthorizationCodes < ActiveRecord::Migration[8.2]
  def change
    drop_table :client_authorization_codes, if_exists: true
  end
end
