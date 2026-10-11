# typed: false
# frozen_string_literal: true

# Canonical org_zenith writer boundary. Semantic RP and principal base classes
# remain separate, but all org_zenith rows that must commit together inherit
# this single connection owner.
class OrgZenithRecord < ApplicationRecord
  self.abstract_class = true

  connects_to database: { writing: :org_zenith, reading: :org_zenith_replica }
end
