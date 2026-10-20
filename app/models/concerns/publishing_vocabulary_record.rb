# frozen_string_literal: true

module PublishingVocabularyRecord
  extend ActiveSupport::Concern

  # FIXME: Violates Umaxica/NoConcernInclusionHooks; move the declarations in this block into each class that includes this concern.
  included do
    include PublicId

    family = name.deconstantize
    has_many :terms, class_name: "#{family}::TaxonomyTerm", inverse_of: :vocabulary,
                     dependent: :restrict_with_exception

    validates :kind, inclusion: { in: Publishing::TaxonomyKind::KEYS }
    # Keys remain reserved after archival; existing keys are immutable in PostgreSQL.
    validates :key, uniqueness: true, on: :create
    validates :key, format: { with: /\A[a-z][a-z0-9_]*\z/ }
    validates :internal_name, presence: true

    scope :available, -> { where(archived_at: nil) }
  end

  def archived? = archived_at.present?

  def structural_kind = Publishing::TaxonomyKind.fetch(kind)

  def root_terms
    terms.where(parent_id: nil)
  end
end
