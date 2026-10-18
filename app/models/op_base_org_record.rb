# typed: false
# frozen_string_literal: true

# Deployment scope: Global
# Shared worldwide. A single database instance serves all regions (jp, us, etc.).
class OpBaseOrgRecord < ApplicationRecord
  self.abstract_class = true
  include TokenJsonSanitizable

  connects_to database: { writing: :op_base_org, reading: :op_base_org_replica }
end
