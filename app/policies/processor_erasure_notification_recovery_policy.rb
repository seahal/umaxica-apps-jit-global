# typed: false
# frozen_string_literal: true

class ProcessorErasureNotificationRecoveryPolicy < ApplicationPolicy
  public

  def recover?
    user.is_a?(Operator) && user.access_enabled?
  end
end
