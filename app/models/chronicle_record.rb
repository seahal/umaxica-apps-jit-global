# typed: false
# frozen_string_literal: true

class ChronicleRecord < ApplicationRecord
  self.abstract_class = true
  self.strict_loading_by_default = true

  connects_to database: { writing: :chronicle, reading: :chronicle_replica }
end
