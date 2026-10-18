# frozen_string_literal: true

class RemoveOperatorVerificationTokenDefault < ActiveRecord::Migration[8.2]
  def change
    change_column_default :operator_verifications, :staff_token_id, from: -> { "nextval('staff_verifications_staff_token_id_seq'::regclass)" }, to: nil
  end
end
