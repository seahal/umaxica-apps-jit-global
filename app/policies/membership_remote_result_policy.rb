# typed: false
# frozen_string_literal: true

# RP-side record of the membership owner's own decision (R5-WU15). A decision response is allowed
# only when the owner answered allowed: true; any other answer is a refusal.
class MembershipRemoteResultPolicy < ApplicationPolicy
  public

  def show?
    return false unless record.is_a?(AvatarAuthorityClient::Result)
    return false if %i(forbidden unauthorized).include?(record.status)
    return record.data["allowed"] == true if record.data.is_a?(Hash) && record.data.key?("allowed")

    true
  end
end
