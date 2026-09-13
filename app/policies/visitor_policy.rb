# typed: false
# frozen_string_literal: true

class VisitorPolicy < ApplicationPolicy
  # A visitor may view their own account-scoped attributes (e.g. the birthdate page).
  def show?
    owner?
  end

  # A visitor may update their own account-scoped attributes (e.g. the MFA level page).
  def update?
    owner?
  end

  def purge_sessions?
    user.is_a?(Operator)
  end
end
