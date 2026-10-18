# frozen_string_literal: true

class RemoveClientVerificationTokenDefault < ActiveRecord::Migration[8.2]
  def change
    change_column_default :client_verifications, :user_token_id, from: -> { "nextval('user_verifications_user_token_id_seq'::regclass)" }, to: nil
  end
end
