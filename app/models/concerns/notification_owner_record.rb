# typed: false
# frozen_string_literal: true

module NotificationOwnerRecord
  extend ActiveSupport::Concern

  # FIXME: Violates Umaxica/NoConcernInclusionHooks; move the declarations in this block into each class that includes this concern.
  included do
    include ::PublicId
  end
end
