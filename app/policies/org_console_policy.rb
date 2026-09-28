# typed: false
# frozen_string_literal: true

# adr/operator-capability-authorization.md: landing pages of the org administration consoles. Each
# console names its own fixed capability. Billing, audit, configuration, and system have no
# authoritative data source this application owns yet, so they stay closed for every operator.
class OrgConsolePolicy < ApplicationPolicy
  public

  def support?
    operator_capability?(OperatorCapabilityGrant::SUPPORT_CONSOLE_READ)
  end

  def iam?
    operator_capability?(OperatorCapabilityGrant::IAM_CAPABILITY_READ)
  end

  def audit?
    false
  end

  def billing?
    false
  end

  def configuration?
    false
  end

  def system?
    false
  end
end
