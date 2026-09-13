# typed: false
# frozen_string_literal: true

# Deployment scope: Global
# Shared worldwide. A single database instance serves all regions (jp, us, etc.).
# com_zenith is Global canonical Account / Identity / Organization authority per
# adr/global-regional-database-ownership.md; the future Regional repository never owns it.
class ComRpRecord < ApplicationRecord
  self.abstract_class = true

  connects_to database: { writing: :com_zenith, reading: :com_zenith_replica }
end
