# typed: false
# frozen_string_literal: true

# Applies an explicitly reviewed, unambiguous direct identity-binding mapping to one resource.
#
# Legacy identity bindings are candidate evidence only; they are never promoted without the
# reviewed surface-local owner identifier. This operation also deliberately does not infer ownership
# from memberships, assignments, legacy organizations, or administrator relations. It is not wired
# to authorization consumers: resource lifecycle state and family-level cutover remain separate
# gates.
class AuthorityOwnerDirectBindingBackfillOperation
  Result = Data.define(:status, :surface, :resource_kind, :resource_public_id, :owner_public_id, :reason)

  class OwnershipConflict < StandardError; end

  def self.call(...)
    new(...).call
  end
  public_class_method :call

  public

  def initialize(surface:, resource_kind:, resource_public_id:, owner_public_id: nil)
    @configuration = AuthorityOwnerMigrationInventory.configuration_for(
      surface:, resource_kind:,
    )
    @resource_public_id = resource_public_id.to_s
    @owner_public_id = owner_public_id.to_s.presence
  end

  def call
    return manual_review(:authority_schema_not_applied) unless
      AuthorityOwnerMigrationInventory.authority_schema_state(surface: configuration.fetch(:surface)) == :applied
    return manual_review(:family_already_cut_over) if family_cut_over?

    resource = resource_class.find_by!(public_id: resource_public_id)
    if owner_public_id.blank?
      reason = membership_configuration? ? :membership_not_ownership : :explicit_owner_required
      return manual_review(reason)
    end

    return manual_review(:cross_surface_owner_candidate) if owner_public_id.present? && cross_surface_owner_public_id?

    identity = resource_identity(resource)
    principal = explicit_owner
    return manual_review(:explicit_owner_not_found) if owner_public_id.present? && principal.blank?
    return manual_review(:membership_not_ownership) if membership_configuration? && explicit_owner.blank?
    return manual_review(:explicit_owner_mismatch) if owner_mismatch?(identity, principal)

    classification = candidate_classification(identity, principal)
    return manual_review(classification) unless classification == :legacy_binding_candidate

    resource_class.transaction { apply_candidate!(resource, principal) }
  end

  private

  attr_reader :configuration, :resource_public_id, :owner_public_id

  def membership_configuration?
    configuration.key?(:membership_association)
  end

  def resource_class
    configuration.fetch(:resource_class)
  end

  def principal_class
    configuration.fetch(:principal_class)
  end

  def identity_class
    configuration.fetch(:identity_class)
  end

  def ownership_class
    configuration.fetch(:ownership_class)
  end

  def authority_lock_class
    configuration.fetch(:authority_lock_class)
  end

  def identity_active_status_id
    configuration.fetch(:identity_active_status_id)
  end

  def principal_active_status_id
    configuration.fetch(:principal_active_status_id)
  end

  def resource_foreign_key
    configuration.fetch(:ownership_resource_foreign_key)
  end

  def principal_foreign_key
    configuration.fetch(:ownership_principal_foreign_key)
  end

  def authority_lock_principal_foreign_key
    configuration.fetch(:authority_lock_principal_foreign_key)
  end

  def candidate_classification(identity, principal)
    return :missing_principal if principal.nil?
    return principal_lifecycle_classification(principal) unless principal_eligible?(principal)
    return :legacy_binding_candidate if membership_configuration? && identity.nil?
    return :missing_identity_binding if identity.nil?
    return :inactive_identity_binding unless identity.status_id == identity_active_status_id

    :legacy_binding_candidate
  end

  def explicit_owner
    return if owner_public_id.blank?

    principal_class.find_by(public_id: owner_public_id)
  end

  def cross_surface_owner_public_id?
    principal_classes =
      AuthorityOwnerMigrationInventory::RESOURCE_CONFIGS
        .map { |entry| entry.fetch(:principal_class) }
    principal_classes.uniq!

    principal_classes
      .reject { |candidate_class| candidate_class == principal_class }
      .any? { |candidate_class| candidate_class.exists?(public_id: owner_public_id) }
  end

  def resource_identity(resource)
    association = configuration.fetch(:identity_association)
    resource.public_send(association) if resource.respond_to?(association)
  end

  def owner_mismatch?(identity, principal)
    return false if membership_configuration? || owner_public_id.blank? || identity.blank? || principal.blank?

    identity.source_record_id != principal.id
  end

  def principal_eligible?(principal)
    principal.status_id == principal_active_status_id &&
      principal.login_allowed? &&
      principal.access_enabled?
  end

  def principal_lifecycle_classification(principal)
    return :inactive_principal unless principal.status_id == principal_active_status_id
    return :suspended_principal unless principal.login_allowed? && principal.access_enabled?

    :active_principal
  end

  def validate_locked_candidate!(identity, principal)
    return if membership_configuration? && identity.blank? && principal_eligible?(principal)

    return if identity.instance_of?(identity_class) &&
      identity.source_record_id == principal.id &&
      candidate_classification(identity, principal) == :legacy_binding_candidate

    raise ActiveRecord::RecordNotSaved, "direct owner candidate changed while backfill was locked"
  end

  def apply_candidate!(resource, principal)
    AuthorityOwnerMigrationInventory.lock_resource_family!(configuration)
    return manual_review(:family_already_cut_over) if family_cut_over?

    authority_lock_class.acquire_for!(**{ authority_lock_principal_foreign_key => principal.id })
    locked_principal = principal_class.lock.find(principal.id)
    locked_resource = resource_class.lock.find(resource.id)
    locked_identity = resource_identity(locked_resource)
    validate_locked_candidate!(locked_identity, locked_principal)

    ownership = ownership_class.lock.find_by(resource_foreign_key => locked_resource.id)
    return resolve_existing_ownership(ownership, locked_principal) if ownership

    ownership_class.create!(
      resource_foreign_key => locked_resource.id,
      principal_foreign_key => locked_principal.id,
      :ownership_revision => 0,
    )
    applied(locked_principal)
  end

  def family_cut_over?
    configuration.fetch(:cutover_class).established?
  end

  def resolve_existing_ownership(ownership, principal)
    return already_applied(principal) if ownership.public_send(principal_foreign_key) == principal.id

    raise OwnershipConflict, "resource #{resource_public_id} already has a different explicit owner"
  end

  def manual_review(reason)
    Result.new(
      status: :manual_review,
      surface: configuration.fetch(:surface),
      resource_kind: configuration.fetch(:resource_kind),
      resource_public_id: resource_public_id,
      owner_public_id: nil,
      reason:,
    )
  end

  def applied(principal)
    Result.new(
      status: :applied,
      surface: configuration.fetch(:surface),
      resource_kind: configuration.fetch(:resource_kind),
      resource_public_id: resource_public_id,
      owner_public_id: principal.public_id,
      reason: nil,
    )
  end

  def already_applied(principal)
    Result.new(
      status: :already_applied,
      surface: configuration.fetch(:surface),
      resource_kind: configuration.fetch(:resource_kind),
      resource_public_id: resource_public_id,
      owner_public_id: principal.public_id,
      reason: nil,
    )
  end
end
