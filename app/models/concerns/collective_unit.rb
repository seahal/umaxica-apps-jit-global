# typed: false
# frozen_string_literal: true

module CollectiveUnit
  extend ActiveSupport::Concern

  include ::PublicId

  # FIXME: Violates Umaxica/NoConcernInclusionHooks; move the declarations in this block into each class that includes this concern.
  included do
    self.belongs_to_required_by_default = false

    after_create :create_closure_rows

    validates :name, presence: true
    validate :parent_must_belong_to_same_collective
    validate :parent_id_is_immutable, on: :update
  end

  CONFIG_REGISTRY = {}
  private_constant :CONFIG_REGISTRY

  def ancestors(include_self: false)
    relation = self.class.where(id: ancestor_links.select(:ancestor_id))
    include_self ? relation : relation.where.not(id:)
  end

  def descendants(include_self: false)
    relation = self.class.where(id: descendant_links.select(:descendant_id))
    include_self ? relation : relation.where.not(id:)
  end

  def subtree
    descendants(include_self: true)
  end

  def root?
    parent_id.nil?
  end

  def leaf?
    !children.exists?
  end

  private

  def create_closure_rows
    self.class.closure_class.transaction do
      self.class.closure_class.create!(ancestor: self, descendant: self, depth: 0)

      parent&.ancestor_links&.find_each do |link|
        self.class.closure_class.create!(
          ancestor_id: link.ancestor_id,
          descendant: self,
          depth: link.depth + 1,
        )
      end
    end
  end

  def parent_must_belong_to_same_collective
    return if parent.blank?

    key = self.class.collective_foreign_key
    return if public_send(key) == parent.public_send(key)

    errors.add(:parent, :invalid)
  end

  def parent_id_is_immutable
    errors.add(:parent_id, :invalid) if will_save_change_to_parent_id?
  end

  class_methods do
    def collective_unit_config(collective_foreign_key:, closure_class_name:)
      CONFIG_REGISTRY[self] = {
        collective_foreign_key: collective_foreign_key,
        closure_class_name: closure_class_name,
      }
    end

    def collective_foreign_key
      CONFIG_REGISTRY.fetch(self)[:collective_foreign_key]
    end

    def closure_class_name
      CONFIG_REGISTRY.fetch(self)[:closure_class_name]
    end

    def closure_class
      case closure_class_name
      when "BureauUnitClosure" then BureauUnitClosure
      when "CompanyUnitClosure" then CompanyUnitClosure
      when "EnterpriseUnitClosure" then EnterpriseUnitClosure
      end
    end
  end
end
