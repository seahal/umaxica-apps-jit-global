# typed: false
# frozen_string_literal: true

class ClientPreferencePolicy < ApplicationPolicy
  def update?
    user.is_a?(Client) && record.is_a?(ClientPreference) && record.client_id == user.id
  end
end
