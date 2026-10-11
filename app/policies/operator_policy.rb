# typed: false
# frozen_string_literal: true

class OperatorPolicy < ApplicationPolicy
  # An operator may view their own account-scoped attributes (e.g. the birthdate page).
  def show?
    owner?
  end

  # Read-only org audit stub is scoped to the current operator record.
  def audit?
    show?
  end

  # Read-only org billing stub is scoped to the current operator record.
  def billing?
    show?
  end

  # Read-only org IAM stub is scoped to the current operator record.
  def iam?
    show?
  end

  # Read-only org support stub is scoped to the current operator record.
  def support?
    show?
  end

  # An operator may update their own account-scoped attributes (e.g. the MFA level page).
  def update?
    owner?
  end

  def purge_sessions?
    user.is_a?(Operator)
  end
end
