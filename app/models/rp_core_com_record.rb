# typed: false
# frozen_string_literal: true

# R5 cell-local authentication state. The connection is fixed by the boot-time role binding.
class RpCoreComRecord < ApplicationRecord
  self.abstract_class = true

  connects_to database: { writing: :rp_core_com, reading: :rp_core_com_replica }
end
