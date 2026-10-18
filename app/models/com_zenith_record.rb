# typed: false
# frozen_string_literal: true

# Canonical com_zenith writer boundary. Semantic RP and principal base classes
# remain separate, but all com_zenith rows that must commit together inherit
# this single connection owner.
class ComZenithRecord < ApplicationRecord
  self.abstract_class = true

  connects_to database: { writing: :com_zenith, reading: :com_zenith_replica }
end
