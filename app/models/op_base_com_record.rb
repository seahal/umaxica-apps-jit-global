# typed: false
# frozen_string_literal: true

# Deployment scope: Global
# Shared worldwide. A single database instance serves all regions (jp, us, etc.).
class OpBaseComRecord < ApplicationRecord
  self.abstract_class = true
  # Keep token-like ticket serialization aligned with OpBaseAppRecord and OpBaseOrgRecord.
  include TokenJsonSanitizable

  connects_to database: { writing: :op_base_com, reading: :op_base_com_replica }
end
