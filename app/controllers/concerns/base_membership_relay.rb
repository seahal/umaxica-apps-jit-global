# typed: false
# frozen_string_literal: true

# Relay for Base Self-RP account / organization / membership pages (R5-WU15): the owner answers
# lists and decisions over HTTPS; the page renders them and decides nothing itself.
module BaseMembershipRelay
  extend ActiveSupport::Concern

  private

  def membership_authority
    @membership_authority ||= MembershipAuthorityClient.new(
      surface: self.class.const_get(:MEMBERSHIP_SURFACE, false),
      access_token: BrowserCredentialCookie.read(cookies, OidcRpBrowserCredentialContract::ACCESS_COOKIE),
      persona: Actor.selection.account_public_id,
    )
  end

  # Records the owner's decision for verify_authorized; refusals use the authorization handler,
  # a missing record is 404 and an unreachable owner is never a permission.
  def membership_result!(result)
    authorize!(result, to: :show?, with: MembershipRemoteResultPolicy)
    raise ActiveRecord::RecordNotFound, "not found" if result.status == :not_found

    if result.status == :dependency
      head :service_unavailable
      return
    end

    result
  end

  def membership_allowed?(org_ref, rule, id: nil)
    result = membership_authority.authorization(org_ref, rule, id:)
    result.ok? && result.data["allowed"] == true
  end
end
