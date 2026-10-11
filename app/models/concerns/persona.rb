# typed: false
# frozen_string_literal: true

# Common Ruby interface for the surface-local Persona implementations.
#
# This module deliberately carries no persistence or authorization state. Each
# surface keeps its concrete Persona implementation, authority tables, and
# database connection independent.
module Persona
  extend ActiveSupport::Concern

  include ::PublicId

  public

  def memberships
    public_send(self.class.membership_association_name)
  end

  def current_memberships
    memberships
      .includes(*self.class.membership_context_association_names)
      .active
      .primary_first
  end

  def primary_membership
    memberships
      .includes(*self.class.membership_context_association_names)
      .primary_active
      .first
  end

  def current_membership
    primary_membership || current_memberships.first
  end

  def current_organization
    current_membership&.organization
  end

  def current_organization_unit
    current_membership&.organization_unit
  end

  # Kept as protocol vocabulary for the existing membership operation layer;
  # new authority code uses the Organization names above.
  def current_collective
    current_organization
  end

  def current_collective_unit
    current_organization_unit
  end

  class_methods do
    def persona_interface_validations
      validates :status_id, numericality: { only_integer: true }, if: -> { has_attribute?(:status_id) }
      validates :title, presence: true, length: { in: 1..10 },
                        format: { with: /\A[A-Za-z0-9]{1,10}\z/ }, if: -> { has_attribute?(:title) }
    end

    def membership_association_name
      membership_association&.name ||
        raise(NotImplementedError, "#{name} does not define a collective membership association")
    end

    def membership_context_association_names
      membership_class = membership_association.klass
      [membership_class.collective_association_name, membership_class.unit_association_name]
    end

    private

    def membership_association
      reflect_on_all_associations(:has_many).find do |association|
        association.klass.included_modules.include?(CollectiveMembership)
      end
    end
  end
end
