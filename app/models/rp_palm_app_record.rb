# typed: false
# frozen_string_literal: true

# R5 cell-local authentication state. The connection is fixed by the boot-time role binding.
class RpPalmAppRecord < ApplicationRecord
  self.abstract_class = true

  connects_to database: { writing: :rp_palm_app, reading: :rp_palm_app_replica }
end
