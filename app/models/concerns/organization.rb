# typed: false
# frozen_string_literal: true

# Common Ruby interface for surface-local Organization implementations.
#
# It is intentionally only behavior. No shared table, STI hierarchy, or
# polymorphic authority relation is implied by including this module.
module Organization
  extend ActiveSupport::Concern

  class_methods do
    def organization_interface_validations
      validates :name, presence: true, if: -> { has_attribute?(:name) }
      validates :title, presence: true, length: { in: 1..10 },
                        format: { with: /\A[A-Za-z0-9]{1,10}\z/ }, if: -> { has_attribute?(:title) }
    end
  end
end
