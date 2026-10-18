# typed: false
# frozen_string_literal: true

# RP-side Tech gate (R5-WU11): the decision is the org authority's, asked over HTTPS on every check
# through TechCapabilityClient. The record carries only the Operator's current Access JWT; the RP
# never reads the Global Operator or its capability grants itself.
class TechRemoteAccessPolicy < ApplicationPolicy
  Request = Data.define(:access_token)

  public

  def show?
    record.is_a?(Request) && TechCapabilityClient.allowed?(access_token: record.access_token)
  end
end
