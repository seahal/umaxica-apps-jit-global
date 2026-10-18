# typed: false
# frozen_string_literal: true

# adr/operator-capability-authorization.md, Not provided: operator lifecycle requests (join,
# withdraw, suspend, terminate, restore) have services but no route, and no capability for
# operator-to-operator administration is defined. Being an Operator is not enough to request,
# approve, reject, or execute a change to another Operator, so every rule denies until the
# capability, approval, and last-administrator rules are specified.
class OperatorLifecycleRequestPolicy < ApplicationPolicy
  def index? = false

  def show? = false

  def create? = false

  def approve? = false

  def reject? = false

  def execute? = false
end
