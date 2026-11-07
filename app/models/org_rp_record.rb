# typed: false
# frozen_string_literal: true

# Deployment scope: Global
# Shared worldwide. A single database instance serves all regions (jp, us, etc.).
class OrgRpRecord < OrgZenithRecord
  self.abstract_class = true
  self.strict_loading_by_default = true
end
