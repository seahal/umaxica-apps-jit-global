# typed: false
# frozen_string_literal: true

# Deployment scope: Global
# Shared worldwide. A single database instance serves all regions (jp, us, etc.).
class AppSettingRecord < ApplicationRecord
  self.abstract_class = true
  self.strict_loading_by_default = true

  connects_to database: { writing: :app_setting, reading: :app_setting_replica }
end
