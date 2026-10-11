# typed: false
# frozen_string_literal: true

class Actor
  class SelectedContext
    attr_reader :account_public_id, :collective_public_id, :collective_unit_public_id,
                :avatar_public_id, :selected_at

    def initialize(account_public_id: nil, collective_public_id: nil, collective_unit_public_id: nil,
                   avatar_public_id: nil, selected_at: nil)
      @account_public_id = account_public_id
      @collective_public_id = collective_public_id
      @collective_unit_public_id = collective_unit_public_id
      @avatar_public_id = avatar_public_id
      @selected_at = selected_at
      freeze
    end

    public

    def persona_selected?
      account_public_id.present?
    end

    def organization_context_selected?
      persona_selected? && collective_public_id.present? && collective_unit_public_id.present?
    end

    def selected?
      organization_context_selected?
    end

    def ==(other)
      other.is_a?(self.class) &&
        account_public_id == other.account_public_id &&
        collective_public_id == other.collective_public_id &&
        collective_unit_public_id == other.collective_unit_public_id &&
        avatar_public_id == other.avatar_public_id &&
        selected_at == other.selected_at
    end

    alias eql? ==

    def hash
      [
        self.class,
        account_public_id,
        collective_public_id,
        collective_unit_public_id,
        avatar_public_id,
        selected_at,
      ].hash
    end

    NULL = new.freeze
  end
end
