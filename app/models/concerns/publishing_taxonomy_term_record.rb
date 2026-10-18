# frozen_string_literal: true

module PublishingTaxonomyTermRecord
  extend ActiveSupport::Concern

  MAX_DEPTH = 8

  # FIXME: Violates Umaxica/NoConcernInclusionHooks; move the declarations in this block into each class that includes this concern.
  included do
    include PublicId

    family = name.deconstantize
    belongs_to :vocabulary, class_name: "#{family}::Vocabulary", inverse_of: :terms
    belongs_to :parent, class_name: "#{family}::TaxonomyTerm", optional: true, inverse_of: :children
    has_many :children, class_name: "#{family}::TaxonomyTerm", foreign_key: :parent_id, inverse_of: :parent,
                        dependent: :restrict_with_exception

    validates :locale, presence: true
    validates :slug, format: { with: /\A[a-z0-9](?:[a-z0-9-]*[a-z0-9])?\z/ }
    validates :name, presence: true

    scope :available, -> { where(archived_at: nil) }
    scope :roots, -> { where(parent_id: nil) }
    scope :ordered, -> { order(:position, :id) }
  end

  def archived? = archived_at.present?

  def root? = parent_id.nil?

  def archived_in_path
    path.select(&:archived?)
  end

  class_methods do
    def next_sibling_position(vocabulary_id:, locale:, parent_id:)
      (where(vocabulary_id:, locale:, parent_id:).maximum(:position) || -1) + 1
    end
  end

  def ancestors
    chain = []
    parent_id = self[:parent_id]
    while parent_id
      node = self.class.find_by(id: parent_id)
      break unless node

      chain.unshift(node)
      parent_id = node[:parent_id]
    end
    chain
  end

  def path = ancestors + [self]

  def descendants
    # Walk the tree with parameterized queries only (no identifier interpolation).
    # Caps recursion at MAX_DEPTH so a cycle cannot fan out unboundedly.
    next_ids = [id]
    found_ids = []
    MAX_DEPTH.times do
      next_ids = self.class.where(parent_id: next_ids).pluck(:id)
      break if next_ids.empty?

      found_ids.concat(next_ids)
    end
    self.class.where(id: found_ids)
  end

  def breadcrumb
    path.map { |term| { "public_id" => term.public_id, "slug" => term.slug, "name" => term.name } }
  end
end
