# typed: false
# frozen_string_literal: true

# R5 cell-local authentication state. The connection is fixed by the boot-time role binding.
class RpBaseAppRecord < ApplicationRecord
  self.abstract_class = true
  self.strict_loading_by_default = true

  connects_to database: { writing: :rp_base_app, reading: :rp_base_app_replica }
end
