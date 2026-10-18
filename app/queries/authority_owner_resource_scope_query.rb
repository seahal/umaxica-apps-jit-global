# typed: false
# frozen_string_literal: true

# Reads the approved surface-local ownership relation for owner-specific policies.
#
# This query deliberately does not consult identity bindings, assignments, memberships, or legacy
# organization rows. Those relationships may remain valid delegated-access data, but they are not
# owner authority. Selector/switcher consumers stay on their separate act-as contract.
class AuthorityOwnerResourceScopeQuery
  def self.call(...)
    new(...).call
  end
  public_class_method :call

  public

  def initialize(surface:, resource_kind:, principal:, scope: nil)
    @configuration = AuthorityOwnerMigrationInventory.configuration_for(
      surface:, resource_kind:,
    )
    @principal = principal
    @scope = scope
  end

  def call
    validate_principal!

    owned_resources = resource_class.where(id: ownership_relation.select(resource_foreign_key))
    return owned_resources if scope.nil?

    validate_scope!
    owned_resources.where(id: scope.select(:id))
  end

  private

  attr_reader :configuration, :principal, :scope

  def resource_class
    configuration.fetch(:resource_class)
  end

  def ownership_relation
    ownership_class.where(principal_foreign_key => principal.id)
  end

  def ownership_class
    configuration.fetch(:ownership_class)
  end

  def principal_foreign_key
    configuration.fetch(:ownership_principal_foreign_key)
  end

  def resource_foreign_key
    configuration.fetch(:ownership_resource_foreign_key)
  end

  def validate_principal!
    return if principal.instance_of?(configuration.fetch(:principal_class))

    raise ArgumentError, "principal must be a #{configuration.fetch(:principal_class).name}"
  end

  def validate_scope!
    return if scope.respond_to?(:klass) && scope.klass == resource_class

    raise ArgumentError, "scope must be an #{resource_class.name} relation"
  end
end
