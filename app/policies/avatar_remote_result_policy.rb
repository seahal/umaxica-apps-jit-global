# typed: false
# frozen_string_literal: true

# RP-side record of the Avatar owner's own decision (R5-WU14); the Base Self-RP decides nothing.
class AvatarRemoteResultPolicy < ApplicationPolicy
  public

  # The owner answered with a specific outcome the RP must relay exactly (an owner-lock denial or a
  # Step-Up request, or the image status). The RP does not reinterpret it as its own permission.
  def relay?
    [AvatarAuthorityClient::Result, OrgAdminAuthorityClient::Result].any? { |klass| record.is_a?(klass) }
  end

  def show?
    [AvatarAuthorityClient::Result, OrgAdminAuthorityClient::Result].any? { |klass|
      record.is_a?(klass)
    } && %i(forbidden unauthorized).exclude?(record.status)
  end
end
