# typed: false
# frozen_string_literal: true

class AccountPolicy < ApplicationPolicy
  ACCOUNT_RESOURCE_KINDS = AuthorityOwnerMigrationInventory::RESOURCE_KIND_BY_CATEGORY.fetch(:account).values.freeze

  def show?
    account_owned_by_current_principal?
  end

  private

  def account_owned_by_current_principal?
    return owner_authorized_after_cutover? if account_authority_cut_over?

    legacy_account_owned_by_current_principal?
  end

  def owner_authorized_after_cutover?
    configuration = authority_configuration
    return false unless configuration
    return false unless user.instance_of?(configuration.fetch(:principal_class))
    return false unless principal_eligible?(configuration)
    return false unless resource_lifecycle_active?(configuration)

    AuthorityOwnerResourceScopeQuery.call(
      surface: configuration.fetch(:surface),
      resource_kind: configuration.fetch(:resource_kind),
      principal: user,
      scope: record.class.where(id: record.id),
    ).exists?
  end

  def legacy_account_owned_by_current_principal?
    case record
    when ClientPersona
      user.is_a?(Client) && record.client_identity&.source_record_id == user.id
    when Individual
      user.is_a?(Visitor) && record.visitor_identity&.source_record_id == user.id
    when Agent
      user.is_a?(Operator) && record.operator_identity&.source_record_id == user.id
    else
      false
    end
  end

  def account_authority_cut_over?
    configuration = authority_configuration
    return false unless configuration

    cutover_class = configuration.fetch(:cutover_class)
    cutover_class.table_exists? && cutover_class.established?
  end

  def authority_configuration
    @authority_configuration ||=
      AuthorityOwnerMigrationInventory::RESOURCE_CONFIGS.find do |configuration|
        configuration.fetch(:resource_class) == record.class &&
          ACCOUNT_RESOURCE_KINDS.include?(configuration.fetch(:resource_kind))
      end
  end

  def principal_eligible?(configuration)
    user.status_id == configuration.fetch(:principal_active_status_id) &&
      user.login_allowed? && user.access_enabled?
  end

  def resource_lifecycle_active?(configuration)
    configuration.fetch(:lifecycle_class).exists?(
      configuration.fetch(:lifecycle_resource_foreign_key) => record.id,
      :state => AuthorityResourceLifecycleStateValue::ACTIVE,
    )
  end
end
