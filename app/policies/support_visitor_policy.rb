# typed: false
# frozen_string_literal: true

# adr/operator-capability-authorization.md: org Support acting on com-realm Visitors. Only the com
# capabilities are consulted, so an app grant can never reach a Visitor.
class SupportVisitorPolicy < ApplicationPolicy
  public

  def index?
    operator_capability?(OperatorCapabilityGrant::SUPPORT_ACCOUNT_READ_COM)
  end

  def show?
    record.is_a?(::Visitor) && index?
  end

  # Revocation shows the target first, so it needs the read capability as well.
  def revoke_sessions?
    show? && operator_capability?(OperatorCapabilityGrant::SUPPORT_SESSION_REVOKE_COM)
  end
end
