# typed: false
# frozen_string_literal: true

# Deployment scope: Global
# Shared worldwide. A single database instance serves all regions (jp, us, etc.).
class OpBaseAppRecord < ApplicationRecord
  include TokenJsonSanitizable

  self.abstract_class = true

  connects_to database: { writing: :op_base_app, reading: :op_base_app_replica }
end
