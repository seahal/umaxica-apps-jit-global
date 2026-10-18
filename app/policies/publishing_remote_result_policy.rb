# typed: false
# frozen_string_literal: true

# RP-side record of the Publishing authority's own decision (R5-WU13). The Edit RP never decides
# Publishing access itself; it only refuses to render when the authority answered forbidden or
# unauthenticated, so verify_authorized still holds for every private CMS action.
class PublishingRemoteResultPolicy < ApplicationPolicy
  public

  def show?
    record.is_a?(PublishingAuthorityClient::Result) && %i(forbidden unauthorized).exclude?(record.status)
  end
end
