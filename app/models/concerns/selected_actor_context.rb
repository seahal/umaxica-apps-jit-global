# typed: false
# frozen_string_literal: true

# Tokens declare SELECTED_ACTOR_CONTEXT_COLUMNS and provide revoke_step_up_authority!.
# Context mutation and ceremony revocation share the token's writer transaction and lock.
module SelectedActorContext
  extend ActiveSupport::Concern

  public

  def selected_actor_context?
    selected_account_public_id.present? &&
      selected_collective_public_id.present? &&
      selected_collective_unit_public_id.present?
  end

  def clear_selected_actor_context!
    self.class.connection_class_for_self.connected_to(role: :writing) do
      with_lock do
        revoke_step_up_authority!
        update!(self.class::SELECTED_ACTOR_CONTEXT_COLUMNS.index_with(nil))
      end
    end
  end
end
