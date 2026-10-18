# typed: false
# frozen_string_literal: true

module Acme
  class AccountQuotaPolicy
    def initialize(surface:, principal:, scope: nil, limit: QuotaLimits::ACCOUNT_LIMIT)
      @surface = surface.to_sym
      @principal = principal
      @scope = scope
      @limit = limit
    end

    def allowed?
      principal_eligible? && lifecycle_complete? && current_count < limit
    end

    def exceeded?
      !allowed?
    end

    def limit
      @limit
    end

    def current_count
      lifecycle_class.where(
        lifecycle_foreign_key => scope_relation.select(:id),
        :state => AuthorityResourceLifecycleStateValue::ACTIVE,
      ).count
    end

    def remaining
      return 0 unless principal_eligible? && lifecycle_complete?

      [limit - current_count, 0].max
    end

    private

    attr_reader :surface, :principal, :scope

    def scope_relation
      AuthorityOwnerResourceScopeQuery.call(
        surface:,
        resource_kind: authority_configuration.fetch(:resource_kind),
        principal:,
        scope:,
      )
    end

    def lifecycle_complete?
      !scope_relation.where.not(
        id: lifecycle_class.where(lifecycle_foreign_key => scope_relation.select(:id)).select(lifecycle_foreign_key),
      ).exists?
    end

    def principal_eligible?
      principal.status_id == authority_configuration.fetch(:principal_active_status_id) &&
        principal.login_allowed? &&
        principal.access_enabled?
    end

    def authority_configuration
      AuthorityOwnerMigrationInventory.configuration_for(
        surface:,
        resource_kind: AuthorityOwnerMigrationInventory.resource_kind_for(
          surface:,
          category: :account,
        ),
      )
    end

    def lifecycle_class
      authority_configuration.fetch(:lifecycle_class)
    end

    def lifecycle_foreign_key
      authority_configuration.fetch(:lifecycle_resource_foreign_key)
    end
  end
end
