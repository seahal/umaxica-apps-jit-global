# typed: false
# frozen_string_literal: true

module Acme
  class OrganizationQuotaPolicy
    def initialize(surface:, principal:, scope: nil, limit: QuotaLimits::ORGANIZATION_LIMIT)
      @surface = surface.to_sym
      @principal = principal
      @scope = scope
      @limit = limit
    end

    def allowed?
      current_count < limit
    end

    def exceeded?
      !allowed?
    end

    def limit
      @limit
    end

    def current_count
      scope_relation.count
    end

    def remaining
      [limit - current_count, 0].max
    end

    private

    attr_reader :surface, :principal, :scope

    def scope_relation
      owned_resources = organization_class.where(id: ownership_relation.select(resource_foreign_key))
      return owned_resources if scope.nil?

      validate_scope!
      owned_resources.where(id: scope.select(:id))
    end

    def organization_class
      case surface
      when :app then Enterprise
      when :org then Bureau
      when :com then Company
      else
        raise ArgumentError, "unsupported surface: #{surface.inspect}"
      end
    end

    def ownership_relation
      case surface
      when :app
        validate_principal!(Client)
        EnterpriseOwnership.where(client_id: principal.id)
      when :org
        validate_principal!(Operator)
        BureauOwnership.where(operator_id: principal.id)
      when :com
        validate_principal!(Visitor)
        CompanyOwnership.where(visitor_id: principal.id)
      else
        raise ArgumentError, "unsupported surface: #{surface.inspect}"
      end
    end

    def resource_foreign_key
      case surface
      when :app then :enterprise_id
      when :org then :bureau_id
      when :com then :company_id
      else
        raise ArgumentError, "unsupported surface: #{surface.inspect}"
      end
    end

    def validate_principal!(expected_class)
      return if principal.instance_of?(expected_class)

      raise ArgumentError, "principal must be a #{expected_class.name} for #{surface.inspect}"
    end

    def validate_scope!
      return if scope.respond_to?(:klass) && scope.klass == organization_class

      raise ArgumentError, "quota scope must be an #{organization_class.name} relation"
    end
  end
end
