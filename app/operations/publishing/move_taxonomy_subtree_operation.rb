# typed: false
# frozen_string_literal: true

module Publishing
  # The only supported way to change a term's place in its tree. parent_id and
  # depth must move together for a whole subtree, so ordinary code never
  # assigns them directly.
  #
  # PostgreSQL remains the final authority: a trigger rejects a cycle or an
  # inconsistent depth even when a caller bypasses this operation entirely.
  # The checks here exist to fail with a useful domain error first.
  class MoveTaxonomySubtreeOperation < ApplicationService
    class CycleError < StandardError; end

    class ScopeMismatchError < StandardError; end

    class DepthLimitError < StandardError; end

    MAX_DEPTH = PublishingTaxonomyTermRecord::MAX_DEPTH

    # `new_parent: nil` promotes the term to a root.
    def initialize(term:, new_parent:)
      super()
      @term = term
      @new_parent = new_parent
    end

    def call
      term.class.transaction do
        # Locking the vocabulary serializes concurrent moves within one tree,
        # so two moves cannot interleave into a cycle that each alone avoids.
        term.vocabulary.lock!

        term.reload
        validate_scope!
        validate_cycle!
        validate_depth!

        apply_move
        term
      end
    end

    private

    attr_reader :term, :new_parent

    def target_depth = new_parent ? new_parent.depth + 1 : 0

    def validate_scope!
      return unless new_parent

      unless new_parent.class == term.class
        raise(ScopeMismatchError, "cannot move term #{term.id} into a different taxonomy scope")
      end
      unless new_parent.vocabulary_id == term.vocabulary_id
        raise(ScopeMismatchError, "cannot move term #{term.id} into a different vocabulary")
      end
      return if new_parent.locale == term.locale

      raise(ScopeMismatchError, "cannot move term #{term.id} into a different locale")
    end

    def validate_cycle!
      return unless new_parent
      raise(CycleError, "term #{term.id} cannot be its own parent") if new_parent.id == term.id
      return unless term.descendants.exists?(id: new_parent.id)

      raise(CycleError, "term #{term.id} cannot move under its own descendant #{new_parent.id}")
    end

    def validate_depth!
      deepest = subtree_height + target_depth
      return if deepest <= MAX_DEPTH

      raise(DepthLimitError, "move would place a descendant at depth #{deepest}, above the limit of #{MAX_DEPTH}")
    end

    # How far the subtree extends below the moved term today.
    def subtree_height
      (term.descendants.maximum(:depth) || term.depth) - term.depth
    end

    # Rows are rewritten shallowest-first so that each row's parent already
    # holds its new depth when the trigger checks depth = parent.depth + 1. The
    # moved term also takes the next free position under its new parent, since
    # sibling positions are unique.
    def apply_move
      shift = target_depth - term.depth
      descendants = term.descendants.order(:depth).to_a

      term.update!(parent: new_parent, depth: target_depth, position: next_position)
      descendants.each { |descendant| descendant.update!(depth: descendant.depth + shift) }
    end

    def next_position
      return term.position if term.parent_id == new_parent&.id

      term.class.next_sibling_position(
        vocabulary_id: term.vocabulary_id, locale: term.locale, parent_id: new_parent&.id,
      )
    end
  end
end
