# typed: false
# frozen_string_literal: true

module AvatarOwnershipTransfers
  Unauthorized = AvatarOwnerMembershipLockService::AuthorizationDenied
  InvalidTransfer = Class.new(StandardError)
  Expired = Class.new(StandardError)
end
