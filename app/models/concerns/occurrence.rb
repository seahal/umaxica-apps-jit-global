# typed: false
# frozen_string_literal: true

module Occurrence
  extend ActiveSupport::Concern

  include Retainable

  # FIXME: Violates Umaxica/NoConcernInclusionHooks; move the declarations in this block into each class that includes this concern.
  included do
    validates :public_id,
              length: { is: 21 },
              format: { with: /\A[A-Za-z0-9_-]{21}\z/ },
              uniqueness: true
    validates :body, presence: true, uniqueness: true
    validates :status_id, presence: true
    validates :memo, length: { maximum: 1024 }, allow_nil: true
  end
end
