# typed: false
# frozen_string_literal: true

# The single authoritative decision on whether an Operator may start an
# Emergency (Restricted Mode) sign-in ceremony.
#
# Emergency Access is currently open to every Operator who may sign in at all,
# so `eligible?` returns the ordinary sign-in eligibility. It exists as its own
# decision anyway: restricting Emergency Access to a subset of Operators later
# must be a change to this one method, not a hunt for scattered assumptions
# across controllers, concerns, token code, and views.
#
# Nothing reachable from an Emergency session may write the inputs this policy
# reads. An Emergency session must never be able to grant or widen its own
# eligibility (see docs/security/org-emergency-access.md).
module OrgEmergencyAccessPolicy
  module_function

  # @param operator [Operator, nil]
  # @return [Boolean]
  def eligible?(operator)
    return false unless operator.is_a?(::Operator)
    return false unless operator.login_allowed?
    return false if AuthenticationCurrentResourceResolver.administratively_locked?(operator)

    true
  end
end
