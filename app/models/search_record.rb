# typed: false
# frozen_string_literal: true

# Deployment scope: Local
# Region-specific. Each region (jp, us, etc.) has its own isolated database instance.
class SearchRecord < ApplicationRecord
  self.abstract_class = true
  self.strict_loading_by_default = true

  connects_to database: { writing: :search, reading: :search_replica }
end
