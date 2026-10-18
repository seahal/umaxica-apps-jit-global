# typed: false
# frozen_string_literal: true

# adr/operator-capability-authorization.md: org Support acting on app-realm Clients. Only the app
# capabilities are consulted, so a com grant can never reach a Client.
class SupportClientPolicy < ApplicationPolicy
  public

  def index?
    operator_capability?(OperatorCapabilityGrant::SUPPORT_ACCOUNT_READ_APP)
  end

  def show?
    record.is_a?(::Client) && index?
  end

  # Revocation shows the target first, so it needs the read capability as well.
  def revoke_sessions?
    show? && operator_capability?(OperatorCapabilityGrant::SUPPORT_SESSION_REVOKE_APP)
  end
end
