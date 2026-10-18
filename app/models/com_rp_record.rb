# typed: false
# frozen_string_literal: true

# Deployment scope: Global
# Shared worldwide. A single database instance serves all regions (jp, us, etc.).
# com_zenith is Global canonical Persona / Identity / Organization authority per
# adr/global-regional-database-ownership.md; the future Regional repository never owns it.
class ComRpRecord < ComZenithRecord
  self.abstract_class = true
end
