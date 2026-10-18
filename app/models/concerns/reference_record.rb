# typed: false
# frozen_string_literal: true

module ReferenceRecord
  extend ActiveSupport::Concern

  # FIXME: Violates Umaxica/NoConcernInclusionHooks; move the declarations in this block into each class that includes this concern.
  included do
    self.record_timestamps = false
  end

  class_methods do
    def nothing_id
      self::NOTHING
    end

    def ensure_defaults!
      insert_missing_fixed_ids!(self::DEFAULTS)
    end
  end
end
