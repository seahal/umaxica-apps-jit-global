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
      owned_resources = account_class.where(id: ownership_relation.select(resource_foreign_key))
      return owned_resources if scope.nil?

      validate_scope!
      owned_resources.where(id: scope.select(:id))
    end

    def account_class
      case surface
      when :app then ClientPersona
      when :org then Agent
      when :com then Individual
      else
        raise ArgumentError, "unsupported surface: #{surface.inspect}"
      end
    end

    def ownership_relation
      case surface
      when :app
        validate_principal!(Client)
        ClientPersonaOwnership.where(client_id: principal.id)
      when :org
        validate_principal!(Operator)
        AgentOwnership.where(operator_id: principal.id)
      when :com
        validate_principal!(Visitor)
        IndividualOwnership.where(visitor_id: principal.id)
      else
        raise ArgumentError, "unsupported surface: #{surface.inspect}"
      end
    end

    def resource_foreign_key
      case surface
      when :app then :client_persona_id
      when :org then :agent_id
      when :com then :individual_id
      else
        raise ArgumentError, "unsupported surface: #{surface.inspect}"
      end
    end

    def validate_principal!(expected_class)
      return if principal.instance_of?(expected_class)

      raise ArgumentError, "principal must be a #{expected_class.name} for #{surface.inspect}"
    end

    def validate_scope!
      return if scope.respond_to?(:klass) && scope.klass == account_class

      raise ArgumentError, "quota scope must be an #{account_class.name} relation"
    end
  end
end
