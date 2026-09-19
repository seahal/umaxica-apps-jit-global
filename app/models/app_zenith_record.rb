# typed: false
# frozen_string_literal: true

# Canonical app_zenith writer boundary. Semantic RP and principal base classes
# remain separate, but all app_zenith rows that must commit together inherit
# this single connection owner.
class AppZenithRecord < ApplicationRecord
  self.abstract_class = true

  connects_to database: { writing: :app_zenith, reading: :app_zenith_replica }
end
