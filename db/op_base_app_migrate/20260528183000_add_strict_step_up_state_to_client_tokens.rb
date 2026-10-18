# frozen_string_literal: true

class AddStrictStepUpStateToClientTokens < ActiveRecord::Migration[8.2]
  def up
    add_column :client_tokens, :last_step_up_aal, :string unless column_exists?(:client_tokens, :last_step_up_aal)
    add_column :client_tokens, :last_step_up_method, :string unless column_exists?(:client_tokens, :last_step_up_method)
    add_column :client_tokens, :last_step_up_purpose, :string unless column_exists?(:client_tokens, :last_step_up_purpose)
    add_column :client_tokens, :last_step_up_audience, :string unless column_exists?(:client_tokens, :last_step_up_audience)
    unless column_exists?(:client_tokens, :last_step_up_session_public_id)
      add_column :client_tokens, :last_step_up_session_public_id, :string
    end
  end

  def down
    remove_column :client_tokens, :last_step_up_session_public_id if column_exists?(:client_tokens, :last_step_up_session_public_id)
    remove_column :client_tokens, :last_step_up_audience if column_exists?(:client_tokens, :last_step_up_audience)
    remove_column :client_tokens, :last_step_up_purpose if column_exists?(:client_tokens, :last_step_up_purpose)
    remove_column :client_tokens, :last_step_up_method if column_exists?(:client_tokens, :last_step_up_method)
    remove_column :client_tokens, :last_step_up_aal if column_exists?(:client_tokens, :last_step_up_aal)
  end
end
