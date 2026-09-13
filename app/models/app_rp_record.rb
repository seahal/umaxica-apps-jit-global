# typed: false
# frozen_string_literal: true

# Deployment scope: Global
# Shared worldwide. A single database instance serves all regions (jp, us, etc.).
# app_zenith is Global canonical Account / Identity / Organization authority per
# adr/global-regional-database-ownership.md; the future Regional repository never owns it.
class AppRpRecord < ApplicationRecord
  self.abstract_class = true

  connects_to database: { writing: :app_zenith, reading: :app_zenith_replica }
end
