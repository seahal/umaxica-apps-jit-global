# typed: false
# frozen_string_literal: true

class DropVisitorAuthorizationCodes < ActiveRecord::Migration[8.2]
  def change
    drop_table :visitor_authorization_codes, if_exists: true
  end
end
