# frozen_string_literal: true

require "test_helper"

class EnterpriseGrantUniquenessTest < ActiveSupport::TestCase
  GRANTS = [EnterpriseAdministrationGrant, EnterpriseDelegationGrant, EnterpriseViewGrant].freeze

  GRANTS.each do |model|
    test "#{model.name} preserves pair scope DB enforcement and ownership boundaries" do
      first_principal = Client.create!(
        security_mode_id: SecurityModeConfigurable::NORMAL,
        status_id: ClientStatus::ACTIVE, visibility_id: ClientVisibility::USER,
      )
      second_principal = Client.create!(
        security_mode_id: SecurityModeConfigurable::NORMAL,
        status_id: ClientStatus::ACTIVE, visibility_id: ClientVisibility::USER,
      )
      first_resource = Enterprise.create!(name: "First resource", title: "First")
      second_resource = Enterprise.create!(name: "Second resource", title: "Second")

      first = model.create!(enterprise: first_resource, client: first_principal)
      other_principal = model.create!(enterprise: first_resource, client: second_principal)
      other_resource = model.create!(enterprise: second_resource, client: first_principal)

      assert_predicate first, :valid?
      first.save!

      assert_equal first_resource.id, first.reload.enterprise_id
      assert_not_equal first.id, other_principal.id
      assert_not_equal first.id, other_resource.id
      assert_empty AuthorityOwnerResourceScopeQuery.call(
        surface: :app, resource_kind: :enterprise,
        principal: first_principal,
      )
      assert_empty AuthorityOwnerResourceScopeQuery.call(
        surface: :app, resource_kind: :enterprise,
        principal: second_principal,
      )
      error =
        assert_raises(ActiveRecord::RecordNotUnique) do
          model.transaction(requires_new: true) do
            model.new(enterprise: first_resource, client: first_principal).save!(validate: false)
          end
        end
      assert_instance_of PG::UniqueViolation, error.cause
      assert_equal 3, model.where(enterprise_id: [first_resource.id, second_resource.id]).count
    end

    test "#{model.name} rejects duplicates and colliding scope changes before SQL" do
      first_principal = Client.create!(
        security_mode_id: SecurityModeConfigurable::NORMAL,
        status_id: ClientStatus::ACTIVE, visibility_id: ClientVisibility::USER,
      )
      second_principal = Client.create!(
        security_mode_id: SecurityModeConfigurable::NORMAL,
        status_id: ClientStatus::ACTIVE, visibility_id: ClientVisibility::USER,
      )
      first_resource = Enterprise.create!(name: "First resource", title: "First")
      second_resource = Enterprise.create!(name: "Second resource", title: "Second")

      first = model.create!(enterprise: first_resource, client: first_principal)
      duplicate = model.new(enterprise: first_resource, client: first_principal)

      assert_not duplicate.valid?
      assert duplicate.errors.of_kind?(:enterprise_id, :taken)
      assert_raises(ActiveRecord::RecordInvalid) { duplicate.save! }
      assert_predicate duplicate, :new_record?
      existing = model.create!(enterprise: second_resource, client: first_principal)
      assert_raises(ActiveRecord::RecordInvalid) { existing.update!(enterprise: first_resource) }
      assert_equal second_resource.id, existing.reload.enterprise_id
      other = model.create!(enterprise: first_resource, client: second_principal)
      assert_raises(ActiveRecord::RecordInvalid) { other.update!(client: first_principal) }
      assert_equal second_principal.id, other.reload.client_id
      assert_equal first.id, model.find_by!(enterprise: first_resource, client: first_principal).id
    end

    test "#{model.name} distinguishes missing foreign keys from the existing zero client" do
      first_principal = Client.create!(
        security_mode_id: SecurityModeConfigurable::NORMAL,
        status_id: ClientStatus::ACTIVE, visibility_id: ClientVisibility::USER,
      )
      Client.create!(
        security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE,
        visibility_id: ClientVisibility::USER,
      )
      first_resource = Enterprise.create!(name: "First resource", title: "First")
      Enterprise.create!(name: "Second resource", title: "Second")

      [nil, "", 0, false].each do |missing|
        absent_resource = model.new(enterprise_id: missing, client: first_principal)
        absent_principal = model.new(enterprise: first_resource, client_id: missing)

        assert_not absent_resource.valid?
        # Client id 0 exists in the fixture contract; false casts to the same integer key.
        if [0, false].include?(missing)
          assert_predicate absent_principal, :valid?
        else
          assert_not absent_principal.valid?
        end

        assert_predicate absent_resource, :new_record?
        assert_predicate absent_principal, :new_record?
      end
    end
    test "#{model.name} adds one pair probe and skips unchanged existing keys" do
      first_principal = Client.create!(
        security_mode_id: SecurityModeConfigurable::NORMAL,
        status_id: ClientStatus::ACTIVE, visibility_id: ClientVisibility::USER,
      )
      second_principal = Client.create!(
        security_mode_id: SecurityModeConfigurable::NORMAL,
        status_id: ClientStatus::ACTIVE, visibility_id: ClientVisibility::USER,
      )
      first_resource = Enterprise.create!(name: "First resource", title: "First")
      second_resource = Enterprise.create!(name: "Second resource", title: "Second")

      existing = model.create!(enterprise: first_resource, client: first_principal)
      candidate = model.new(enterprise: second_resource, client: second_principal)
      queries = []
      subscriber =
        lambda do |_name, _start, _finish, _id, payload|
          sql = payload.fetch(:sql)
          queries << sql if sql.match?(/\ASELECT/i) && sql.include?(model.table_name)
        end
      ActiveSupport::Notifications.subscribed(subscriber, "sql.active_record") do
        assert_predicate candidate, :valid?
        assert_predicate existing, :valid?
      end
      assert_equal 1, queries.size
    end
  end
end

class ClientPersonaGrantUniquenessTest < ActiveSupport::TestCase
  GRANTS = [ClientPersonaAdministrationGrant, ClientPersonaDelegationGrant, ClientPersonaUsageGrant,
            ClientPersonaViewGrant,].freeze

  GRANTS.each do |model|
    test "#{model.name} preserves pair scope DB enforcement and ownership boundaries" do
      first_principal = Client.create!(
        security_mode_id: SecurityModeConfigurable::NORMAL,
        status_id: ClientStatus::ACTIVE, visibility_id: ClientVisibility::USER,
      )
      second_principal = Client.create!(
        security_mode_id: SecurityModeConfigurable::NORMAL,
        status_id: ClientStatus::ACTIVE, visibility_id: ClientVisibility::USER,
      )
      ClientIdentityState.ensure_defaults!
      first_identity = ClientIdentity.create!(
        issuer: "https://grants.example.test", subject: "first",
        audience: "acme_app", source_record_id: first_principal.id, status_id: ClientIdentityState::ACTIVE,
      )
      second_identity = ClientIdentity.create!(
        issuer: "https://grants.example.test", subject: "second",
        audience: "acme_app", source_record_id: second_principal.id, status_id: ClientIdentityState::ACTIVE,
      )
      first_resource = ClientPersona.create!(client_identity: first_identity, title: "First")
      second_resource = ClientPersona.create!(client_identity: second_identity, title: "Second")

      first = model.create!(client_persona: first_resource, client: first_principal)
      other_principal = model.create!(client_persona: first_resource, client: second_principal)
      other_resource = model.create!(client_persona: second_resource, client: first_principal)

      assert_predicate first, :valid?
      first.save!

      assert_equal first_resource.id, first.reload.client_persona_id
      assert_not_equal first.id, other_principal.id
      assert_not_equal first.id, other_resource.id
      assert_empty AuthorityOwnerResourceScopeQuery.call(
        surface: :app, resource_kind: :client_persona,
        principal: first_principal,
      )
      assert_empty AuthorityOwnerResourceScopeQuery.call(
        surface: :app, resource_kind: :client_persona,
        principal: second_principal,
      )
      error =
        assert_raises(ActiveRecord::RecordNotUnique) do
          model.transaction(requires_new: true) do
            model.new(client_persona: first_resource, client: first_principal).save!(validate: false)
          end
        end
      assert_instance_of PG::UniqueViolation, error.cause
      assert_equal 3, model.where(client_persona_id: [first_resource.id, second_resource.id]).count
    end

    test "#{model.name} rejects duplicates and colliding scope changes before SQL" do
      first_principal = Client.create!(
        security_mode_id: SecurityModeConfigurable::NORMAL,
        status_id: ClientStatus::ACTIVE, visibility_id: ClientVisibility::USER,
      )
      second_principal = Client.create!(
        security_mode_id: SecurityModeConfigurable::NORMAL,
        status_id: ClientStatus::ACTIVE, visibility_id: ClientVisibility::USER,
      )
      ClientIdentityState.ensure_defaults!
      first_identity = ClientIdentity.create!(
        issuer: "https://grants.example.test", subject: "first",
        audience: "acme_app", source_record_id: first_principal.id, status_id: ClientIdentityState::ACTIVE,
      )
      second_identity = ClientIdentity.create!(
        issuer: "https://grants.example.test", subject: "second",
        audience: "acme_app", source_record_id: second_principal.id, status_id: ClientIdentityState::ACTIVE,
      )
      first_resource = ClientPersona.create!(client_identity: first_identity, title: "First")
      second_resource = ClientPersona.create!(client_identity: second_identity, title: "Second")

      first = model.create!(client_persona: first_resource, client: first_principal)
      duplicate = model.new(client_persona: first_resource, client: first_principal)

      assert_not duplicate.valid?
      assert duplicate.errors.of_kind?(:client_persona_id, :taken)
      assert_raises(ActiveRecord::RecordInvalid) { duplicate.save! }
      assert_predicate duplicate, :new_record?
      existing = model.create!(client_persona: second_resource, client: first_principal)
      assert_raises(ActiveRecord::RecordInvalid) { existing.update!(client_persona: first_resource) }
      assert_equal second_resource.id, existing.reload.client_persona_id
      other = model.create!(client_persona: first_resource, client: second_principal)
      assert_raises(ActiveRecord::RecordInvalid) { other.update!(client: first_principal) }
      assert_equal second_principal.id, other.reload.client_id
      assert_equal first.id, model.find_by!(client_persona: first_resource, client: first_principal).id
    end

    test "#{model.name} distinguishes missing foreign keys from the existing zero client" do
      first_principal = Client.create!(
        security_mode_id: SecurityModeConfigurable::NORMAL,
        status_id: ClientStatus::ACTIVE, visibility_id: ClientVisibility::USER,
      )
      second_principal = Client.create!(
        security_mode_id: SecurityModeConfigurable::NORMAL,
        status_id: ClientStatus::ACTIVE, visibility_id: ClientVisibility::USER,
      )
      ClientIdentityState.ensure_defaults!
      first_identity = ClientIdentity.create!(
        issuer: "https://grants.example.test", subject: "first",
        audience: "acme_app", source_record_id: first_principal.id, status_id: ClientIdentityState::ACTIVE,
      )
      second_identity = ClientIdentity.create!(
        issuer: "https://grants.example.test", subject: "second",
        audience: "acme_app", source_record_id: second_principal.id, status_id: ClientIdentityState::ACTIVE,
      )
      first_resource = ClientPersona.create!(client_identity: first_identity, title: "First")
      ClientPersona.create!(client_identity: second_identity, title: "Second")

      [nil, "", 0, false].each do |missing|
        absent_resource = model.new(client_persona_id: missing, client: first_principal)
        absent_principal = model.new(client_persona: first_resource, client_id: missing)

        assert_not absent_resource.valid?
        # Client id 0 exists in the fixture contract; false casts to the same integer key.
        if [0, false].include?(missing)
          assert_predicate absent_principal, :valid?
        else
          assert_not absent_principal.valid?
        end

        assert_predicate absent_resource, :new_record?
        assert_predicate absent_principal, :new_record?
      end
    end
    test "#{model.name} adds one pair probe and skips unchanged existing keys" do
      first_principal = Client.create!(
        security_mode_id: SecurityModeConfigurable::NORMAL,
        status_id: ClientStatus::ACTIVE, visibility_id: ClientVisibility::USER,
      )
      second_principal = Client.create!(
        security_mode_id: SecurityModeConfigurable::NORMAL,
        status_id: ClientStatus::ACTIVE, visibility_id: ClientVisibility::USER,
      )
      ClientIdentityState.ensure_defaults!
      first_identity = ClientIdentity.create!(
        issuer: "https://grants.example.test", subject: "first",
        audience: "acme_app", source_record_id: first_principal.id, status_id: ClientIdentityState::ACTIVE,
      )
      second_identity = ClientIdentity.create!(
        issuer: "https://grants.example.test", subject: "second",
        audience: "acme_app", source_record_id: second_principal.id, status_id: ClientIdentityState::ACTIVE,
      )
      first_resource = ClientPersona.create!(client_identity: first_identity, title: "First")
      second_resource = ClientPersona.create!(client_identity: second_identity, title: "Second")

      existing = model.create!(client_persona: first_resource, client: first_principal)
      candidate = model.new(client_persona: second_resource, client: second_principal)
      queries = []
      subscriber =
        lambda do |_name, _start, _finish, _id, payload|
          sql = payload.fetch(:sql)
          queries << sql if sql.match?(/\ASELECT/i) && sql.include?(model.table_name)
        end
      ActiveSupport::Notifications.subscribed(subscriber, "sql.active_record") do
        assert_predicate candidate, :valid?
        assert_predicate existing, :valid?
      end
      assert_equal 1, queries.size
    end
  end
end

class CompanyGrantUniquenessTest < ActiveSupport::TestCase
  GRANTS = [CompanyAdministrationGrant, CompanyDelegationGrant, CompanyViewGrant].freeze

  GRANTS.each do |model|
    test "#{model.name} preserves pair scope DB enforcement and ownership boundaries" do
      first_principal = Visitor.create!(
        security_mode_id: SecurityModeConfigurable::NORMAL,
        status_id: VisitorStatus::ACTIVE, visibility_id: VisitorVisibility::VISITOR,
      )
      second_principal = Visitor.create!(
        security_mode_id: SecurityModeConfigurable::NORMAL,
        status_id: VisitorStatus::ACTIVE, visibility_id: VisitorVisibility::VISITOR,
      )
      first_resource = Company.create!(name: "First resource", title: "First")
      second_resource = Company.create!(name: "Second resource", title: "Second")

      first = model.create!(company: first_resource, visitor: first_principal)
      other_principal = model.create!(company: first_resource, visitor: second_principal)
      other_resource = model.create!(company: second_resource, visitor: first_principal)

      assert_predicate first, :valid?
      first.save!

      assert_equal first_resource.id, first.reload.company_id
      assert_not_equal first.id, other_principal.id
      assert_not_equal first.id, other_resource.id
      assert_empty AuthorityOwnerResourceScopeQuery.call(
        surface: :com, resource_kind: :company,
        principal: first_principal,
      )
      assert_empty AuthorityOwnerResourceScopeQuery.call(
        surface: :com, resource_kind: :company,
        principal: second_principal,
      )
      error =
        assert_raises(ActiveRecord::RecordNotUnique) do
          model.transaction(requires_new: true) do
            model.new(company: first_resource, visitor: first_principal).save!(validate: false)
          end
        end
      assert_instance_of PG::UniqueViolation, error.cause
      assert_equal 3, model.where(company_id: [first_resource.id, second_resource.id]).count
    end

    test "#{model.name} rejects duplicates and colliding scope changes before SQL" do
      first_principal = Visitor.create!(
        security_mode_id: SecurityModeConfigurable::NORMAL,
        status_id: VisitorStatus::ACTIVE, visibility_id: VisitorVisibility::VISITOR,
      )
      second_principal = Visitor.create!(
        security_mode_id: SecurityModeConfigurable::NORMAL,
        status_id: VisitorStatus::ACTIVE, visibility_id: VisitorVisibility::VISITOR,
      )
      first_resource = Company.create!(name: "First resource", title: "First")
      second_resource = Company.create!(name: "Second resource", title: "Second")

      first = model.create!(company: first_resource, visitor: first_principal)
      duplicate = model.new(company: first_resource, visitor: first_principal)

      assert_not duplicate.valid?
      assert duplicate.errors.of_kind?(:company_id, :taken)
      assert_raises(ActiveRecord::RecordInvalid) { duplicate.save! }
      assert_predicate duplicate, :new_record?
      existing = model.create!(company: second_resource, visitor: first_principal)
      assert_raises(ActiveRecord::RecordInvalid) { existing.update!(company: first_resource) }
      assert_equal second_resource.id, existing.reload.company_id
      other = model.create!(company: first_resource, visitor: second_principal)
      assert_raises(ActiveRecord::RecordInvalid) { other.update!(visitor: first_principal) }
      assert_equal second_principal.id, other.reload.visitor_id
      assert_equal first.id, model.find_by!(company: first_resource, visitor: first_principal).id
    end

    test "#{model.name} keeps missing and sentinel foreign keys invalid" do
      first_principal = Visitor.create!(
        security_mode_id: SecurityModeConfigurable::NORMAL,
        status_id: VisitorStatus::ACTIVE, visibility_id: VisitorVisibility::VISITOR,
      )
      Visitor.create!(
        security_mode_id: SecurityModeConfigurable::NORMAL, status_id: VisitorStatus::ACTIVE,
        visibility_id: VisitorVisibility::VISITOR,
      )
      first_resource = Company.create!(name: "First resource", title: "First")
      Company.create!(name: "Second resource", title: "Second")

      [nil, "", 0, false].each do |missing|
        absent_resource = model.new(company_id: missing, visitor: first_principal)
        absent_principal = model.new(company: first_resource, visitor_id: missing)

        assert_not absent_resource.valid?
        assert_not absent_principal.valid?
        assert_predicate absent_resource, :new_record?
        assert_predicate absent_principal, :new_record?
      end
    end
    test "#{model.name} adds one pair probe and skips unchanged existing keys" do
      first_principal = Visitor.create!(
        security_mode_id: SecurityModeConfigurable::NORMAL,
        status_id: VisitorStatus::ACTIVE, visibility_id: VisitorVisibility::VISITOR,
      )
      second_principal = Visitor.create!(
        security_mode_id: SecurityModeConfigurable::NORMAL,
        status_id: VisitorStatus::ACTIVE, visibility_id: VisitorVisibility::VISITOR,
      )
      first_resource = Company.create!(name: "First resource", title: "First")
      second_resource = Company.create!(name: "Second resource", title: "Second")

      existing = model.create!(company: first_resource, visitor: first_principal)
      candidate = model.new(company: second_resource, visitor: second_principal)
      queries = []
      subscriber =
        lambda do |_name, _start, _finish, _id, payload|
          sql = payload.fetch(:sql)
          queries << sql if sql.match?(/\ASELECT/i) && sql.include?(model.table_name)
        end
      ActiveSupport::Notifications.subscribed(subscriber, "sql.active_record") do
        assert_predicate candidate, :valid?
        assert_predicate existing, :valid?
      end
      assert_equal 1, queries.size
    end
  end
end

class IndividualGrantUniquenessTest < ActiveSupport::TestCase
  GRANTS = [IndividualAdministrationGrant, IndividualDelegationGrant, IndividualUsageGrant, IndividualViewGrant].freeze

  GRANTS.each do |model|
    test "#{model.name} preserves pair scope DB enforcement and ownership boundaries" do
      first_principal = Visitor.create!(
        security_mode_id: SecurityModeConfigurable::NORMAL,
        status_id: VisitorStatus::ACTIVE, visibility_id: VisitorVisibility::VISITOR,
      )
      second_principal = Visitor.create!(
        security_mode_id: SecurityModeConfigurable::NORMAL,
        status_id: VisitorStatus::ACTIVE, visibility_id: VisitorVisibility::VISITOR,
      )
      VisitorIdentityState.ensure_defaults!
      first_identity = VisitorIdentity.create!(
        issuer: "https://grants.example.test", subject: "first",
        audience: "acme_com", source_record_id: first_principal.id, status_id: VisitorIdentityState::ACTIVE,
      )
      second_identity = VisitorIdentity.create!(
        issuer: "https://grants.example.test", subject: "second",
        audience: "acme_com", source_record_id: second_principal.id, status_id: VisitorIdentityState::ACTIVE,
      )
      first_resource = Individual.create!(visitor_identity: first_identity, title: "First")
      second_resource = Individual.create!(visitor_identity: second_identity, title: "Second")

      first = model.create!(individual: first_resource, visitor: first_principal)
      other_principal = model.create!(individual: first_resource, visitor: second_principal)
      other_resource = model.create!(individual: second_resource, visitor: first_principal)

      assert_predicate first, :valid?
      first.save!

      assert_equal first_resource.id, first.reload.individual_id
      assert_not_equal first.id, other_principal.id
      assert_not_equal first.id, other_resource.id
      assert_empty AuthorityOwnerResourceScopeQuery.call(
        surface: :com, resource_kind: :individual,
        principal: first_principal,
      )
      assert_empty AuthorityOwnerResourceScopeQuery.call(
        surface: :com, resource_kind: :individual,
        principal: second_principal,
      )
      error =
        assert_raises(ActiveRecord::RecordNotUnique) do
          model.transaction(requires_new: true) do
            model.new(individual: first_resource, visitor: first_principal).save!(validate: false)
          end
        end
      assert_instance_of PG::UniqueViolation, error.cause
      assert_equal 3, model.where(individual_id: [first_resource.id, second_resource.id]).count
    end

    test "#{model.name} rejects duplicates and colliding scope changes before SQL" do
      first_principal = Visitor.create!(
        security_mode_id: SecurityModeConfigurable::NORMAL,
        status_id: VisitorStatus::ACTIVE, visibility_id: VisitorVisibility::VISITOR,
      )
      second_principal = Visitor.create!(
        security_mode_id: SecurityModeConfigurable::NORMAL,
        status_id: VisitorStatus::ACTIVE, visibility_id: VisitorVisibility::VISITOR,
      )
      VisitorIdentityState.ensure_defaults!
      first_identity = VisitorIdentity.create!(
        issuer: "https://grants.example.test", subject: "first",
        audience: "acme_com", source_record_id: first_principal.id, status_id: VisitorIdentityState::ACTIVE,
      )
      second_identity = VisitorIdentity.create!(
        issuer: "https://grants.example.test", subject: "second",
        audience: "acme_com", source_record_id: second_principal.id, status_id: VisitorIdentityState::ACTIVE,
      )
      first_resource = Individual.create!(visitor_identity: first_identity, title: "First")
      second_resource = Individual.create!(visitor_identity: second_identity, title: "Second")

      first = model.create!(individual: first_resource, visitor: first_principal)
      duplicate = model.new(individual: first_resource, visitor: first_principal)

      assert_not duplicate.valid?
      assert duplicate.errors.of_kind?(:individual_id, :taken)
      assert_raises(ActiveRecord::RecordInvalid) { duplicate.save! }
      assert_predicate duplicate, :new_record?
      existing = model.create!(individual: second_resource, visitor: first_principal)
      assert_raises(ActiveRecord::RecordInvalid) { existing.update!(individual: first_resource) }
      assert_equal second_resource.id, existing.reload.individual_id
      other = model.create!(individual: first_resource, visitor: second_principal)
      assert_raises(ActiveRecord::RecordInvalid) { other.update!(visitor: first_principal) }
      assert_equal second_principal.id, other.reload.visitor_id
      assert_equal first.id, model.find_by!(individual: first_resource, visitor: first_principal).id
    end

    test "#{model.name} keeps missing and sentinel foreign keys invalid" do
      first_principal = Visitor.create!(
        security_mode_id: SecurityModeConfigurable::NORMAL,
        status_id: VisitorStatus::ACTIVE, visibility_id: VisitorVisibility::VISITOR,
      )
      second_principal = Visitor.create!(
        security_mode_id: SecurityModeConfigurable::NORMAL,
        status_id: VisitorStatus::ACTIVE, visibility_id: VisitorVisibility::VISITOR,
      )
      VisitorIdentityState.ensure_defaults!
      first_identity = VisitorIdentity.create!(
        issuer: "https://grants.example.test", subject: "first",
        audience: "acme_com", source_record_id: first_principal.id, status_id: VisitorIdentityState::ACTIVE,
      )
      second_identity = VisitorIdentity.create!(
        issuer: "https://grants.example.test", subject: "second",
        audience: "acme_com", source_record_id: second_principal.id, status_id: VisitorIdentityState::ACTIVE,
      )
      first_resource = Individual.create!(visitor_identity: first_identity, title: "First")
      Individual.create!(visitor_identity: second_identity, title: "Second")

      [nil, "", 0, false].each do |missing|
        absent_resource = model.new(individual_id: missing, visitor: first_principal)
        absent_principal = model.new(individual: first_resource, visitor_id: missing)

        assert_not absent_resource.valid?
        assert_not absent_principal.valid?
        assert_predicate absent_resource, :new_record?
        assert_predicate absent_principal, :new_record?
      end
    end
    test "#{model.name} adds one pair probe and skips unchanged existing keys" do
      first_principal = Visitor.create!(
        security_mode_id: SecurityModeConfigurable::NORMAL,
        status_id: VisitorStatus::ACTIVE, visibility_id: VisitorVisibility::VISITOR,
      )
      second_principal = Visitor.create!(
        security_mode_id: SecurityModeConfigurable::NORMAL,
        status_id: VisitorStatus::ACTIVE, visibility_id: VisitorVisibility::VISITOR,
      )
      VisitorIdentityState.ensure_defaults!
      first_identity = VisitorIdentity.create!(
        issuer: "https://grants.example.test", subject: "first",
        audience: "acme_com", source_record_id: first_principal.id, status_id: VisitorIdentityState::ACTIVE,
      )
      second_identity = VisitorIdentity.create!(
        issuer: "https://grants.example.test", subject: "second",
        audience: "acme_com", source_record_id: second_principal.id, status_id: VisitorIdentityState::ACTIVE,
      )
      first_resource = Individual.create!(visitor_identity: first_identity, title: "First")
      second_resource = Individual.create!(visitor_identity: second_identity, title: "Second")

      existing = model.create!(individual: first_resource, visitor: first_principal)
      candidate = model.new(individual: second_resource, visitor: second_principal)
      queries = []
      subscriber =
        lambda do |_name, _start, _finish, _id, payload|
          sql = payload.fetch(:sql)
          queries << sql if sql.match?(/\ASELECT/i) && sql.include?(model.table_name)
        end
      ActiveSupport::Notifications.subscribed(subscriber, "sql.active_record") do
        assert_predicate candidate, :valid?
        assert_predicate existing, :valid?
      end
      assert_equal 1, queries.size
    end
  end
end

class BureauGrantUniquenessTest < ActiveSupport::TestCase
  GRANTS = [BureauAdministrationGrant, BureauDelegationGrant, BureauViewGrant].freeze

  GRANTS.each do |model|
    test "#{model.name} preserves pair scope DB enforcement and ownership boundaries" do
      first_principal = Operator.create!(
        security_mode_id: SecurityModeConfigurable::ADVANCED,
        status_id: OperatorStatus::ACTIVE, visibility_id: OperatorVisibility::STAFF,
      )
      second_principal = Operator.create!(
        security_mode_id: SecurityModeConfigurable::ADVANCED,
        status_id: OperatorStatus::ACTIVE, visibility_id: OperatorVisibility::STAFF,
      )
      first_resource = Bureau.create!(name: "First resource", title: "First")
      second_resource = Bureau.create!(name: "Second resource", title: "Second")

      first = model.create!(bureau: first_resource, operator: first_principal)
      other_principal = model.create!(bureau: first_resource, operator: second_principal)
      other_resource = model.create!(bureau: second_resource, operator: first_principal)

      assert_predicate first, :valid?
      first.save!

      assert_equal first_resource.id, first.reload.bureau_id
      assert_not_equal first.id, other_principal.id
      assert_not_equal first.id, other_resource.id
      assert_empty AuthorityOwnerResourceScopeQuery.call(
        surface: :org, resource_kind: :bureau,
        principal: first_principal,
      )
      assert_empty AuthorityOwnerResourceScopeQuery.call(
        surface: :org, resource_kind: :bureau,
        principal: second_principal,
      )
      error =
        assert_raises(ActiveRecord::RecordNotUnique) do
          model.transaction(requires_new: true) do
            model.new(bureau: first_resource, operator: first_principal).save!(validate: false)
          end
        end
      assert_instance_of PG::UniqueViolation, error.cause
      assert_equal 3, model.where(bureau_id: [first_resource.id, second_resource.id]).count
    end

    test "#{model.name} rejects duplicates and colliding scope changes before SQL" do
      first_principal = Operator.create!(
        security_mode_id: SecurityModeConfigurable::ADVANCED,
        status_id: OperatorStatus::ACTIVE, visibility_id: OperatorVisibility::STAFF,
      )
      second_principal = Operator.create!(
        security_mode_id: SecurityModeConfigurable::ADVANCED,
        status_id: OperatorStatus::ACTIVE, visibility_id: OperatorVisibility::STAFF,
      )
      first_resource = Bureau.create!(name: "First resource", title: "First")
      second_resource = Bureau.create!(name: "Second resource", title: "Second")

      first = model.create!(bureau: first_resource, operator: first_principal)
      duplicate = model.new(bureau: first_resource, operator: first_principal)

      assert_not duplicate.valid?
      assert duplicate.errors.of_kind?(:bureau_id, :taken)
      assert_raises(ActiveRecord::RecordInvalid) { duplicate.save! }
      assert_predicate duplicate, :new_record?
      existing = model.create!(bureau: second_resource, operator: first_principal)
      assert_raises(ActiveRecord::RecordInvalid) { existing.update!(bureau: first_resource) }
      assert_equal second_resource.id, existing.reload.bureau_id
      other = model.create!(bureau: first_resource, operator: second_principal)
      assert_raises(ActiveRecord::RecordInvalid) { other.update!(operator: first_principal) }
      assert_equal second_principal.id, other.reload.operator_id
      assert_equal first.id, model.find_by!(bureau: first_resource, operator: first_principal).id
    end

    test "#{model.name} keeps missing and sentinel foreign keys invalid" do
      first_principal = Operator.create!(
        security_mode_id: SecurityModeConfigurable::ADVANCED,
        status_id: OperatorStatus::ACTIVE, visibility_id: OperatorVisibility::STAFF,
      )
      Operator.create!(
        security_mode_id: SecurityModeConfigurable::ADVANCED, status_id: OperatorStatus::ACTIVE,
        visibility_id: OperatorVisibility::STAFF,
      )
      first_resource = Bureau.create!(name: "First resource", title: "First")
      Bureau.create!(name: "Second resource", title: "Second")

      [nil, "", 0, false].each do |missing|
        absent_resource = model.new(bureau_id: missing, operator: first_principal)
        absent_principal = model.new(bureau: first_resource, operator_id: missing)

        assert_not absent_resource.valid?
        assert_not absent_principal.valid?
        assert_predicate absent_resource, :new_record?
        assert_predicate absent_principal, :new_record?
      end
    end
    test "#{model.name} adds one pair probe and skips unchanged existing keys" do
      first_principal = Operator.create!(
        security_mode_id: SecurityModeConfigurable::ADVANCED,
        status_id: OperatorStatus::ACTIVE, visibility_id: OperatorVisibility::STAFF,
      )
      second_principal = Operator.create!(
        security_mode_id: SecurityModeConfigurable::ADVANCED,
        status_id: OperatorStatus::ACTIVE, visibility_id: OperatorVisibility::STAFF,
      )
      first_resource = Bureau.create!(name: "First resource", title: "First")
      second_resource = Bureau.create!(name: "Second resource", title: "Second")

      existing = model.create!(bureau: first_resource, operator: first_principal)
      candidate = model.new(bureau: second_resource, operator: second_principal)
      queries = []
      subscriber =
        lambda do |_name, _start, _finish, _id, payload|
          sql = payload.fetch(:sql)
          queries << sql if sql.match?(/\ASELECT/i) && sql.include?(model.table_name)
        end
      ActiveSupport::Notifications.subscribed(subscriber, "sql.active_record") do
        assert_predicate candidate, :valid?
        assert_predicate existing, :valid?
      end
      assert_equal 1, queries.size
    end
  end
end

class AgentGrantUniquenessTest < ActiveSupport::TestCase
  GRANTS = [AgentAdministrationGrant, AgentDelegationGrant, AgentUsageGrant, AgentViewGrant].freeze

  GRANTS.each do |model|
    test "#{model.name} preserves pair scope DB enforcement and ownership boundaries" do
      first_principal = Operator.create!(
        security_mode_id: SecurityModeConfigurable::ADVANCED,
        status_id: OperatorStatus::ACTIVE, visibility_id: OperatorVisibility::STAFF,
      )
      second_principal = Operator.create!(
        security_mode_id: SecurityModeConfigurable::ADVANCED,
        status_id: OperatorStatus::ACTIVE, visibility_id: OperatorVisibility::STAFF,
      )
      OperatorIdentityState.ensure_defaults!
      first_identity = OperatorIdentity.create!(
        issuer: "https://grants.example.test", subject: "first",
        audience: "acme_org", source_record_id: first_principal.id, status_id: OperatorIdentityState::ACTIVE,
      )
      second_identity = OperatorIdentity.create!(
        issuer: "https://grants.example.test", subject: "second",
        audience: "acme_org", source_record_id: second_principal.id, status_id: OperatorIdentityState::ACTIVE,
      )
      first_resource = Agent.create!(operator_identity: first_identity, title: "First")
      second_resource = Agent.create!(operator_identity: second_identity, title: "Second")

      first = model.create!(agent: first_resource, operator: first_principal)
      other_principal = model.create!(agent: first_resource, operator: second_principal)
      other_resource = model.create!(agent: second_resource, operator: first_principal)

      assert_predicate first, :valid?
      first.save!

      assert_equal first_resource.id, first.reload.agent_id
      assert_not_equal first.id, other_principal.id
      assert_not_equal first.id, other_resource.id
      assert_empty AuthorityOwnerResourceScopeQuery.call(
        surface: :org, resource_kind: :agent,
        principal: first_principal,
      )
      assert_empty AuthorityOwnerResourceScopeQuery.call(
        surface: :org, resource_kind: :agent,
        principal: second_principal,
      )
      error =
        assert_raises(ActiveRecord::RecordNotUnique) do
          model.transaction(requires_new: true) do
            model.new(agent: first_resource, operator: first_principal).save!(validate: false)
          end
        end
      assert_instance_of PG::UniqueViolation, error.cause
      assert_equal 3, model.where(agent_id: [first_resource.id, second_resource.id]).count
    end

    test "#{model.name} rejects duplicates and colliding scope changes before SQL" do
      first_principal = Operator.create!(
        security_mode_id: SecurityModeConfigurable::ADVANCED,
        status_id: OperatorStatus::ACTIVE, visibility_id: OperatorVisibility::STAFF,
      )
      second_principal = Operator.create!(
        security_mode_id: SecurityModeConfigurable::ADVANCED,
        status_id: OperatorStatus::ACTIVE, visibility_id: OperatorVisibility::STAFF,
      )
      OperatorIdentityState.ensure_defaults!
      first_identity = OperatorIdentity.create!(
        issuer: "https://grants.example.test", subject: "first",
        audience: "acme_org", source_record_id: first_principal.id, status_id: OperatorIdentityState::ACTIVE,
      )
      second_identity = OperatorIdentity.create!(
        issuer: "https://grants.example.test", subject: "second",
        audience: "acme_org", source_record_id: second_principal.id, status_id: OperatorIdentityState::ACTIVE,
      )
      first_resource = Agent.create!(operator_identity: first_identity, title: "First")
      second_resource = Agent.create!(operator_identity: second_identity, title: "Second")

      first = model.create!(agent: first_resource, operator: first_principal)
      duplicate = model.new(agent: first_resource, operator: first_principal)

      assert_not duplicate.valid?
      assert duplicate.errors.of_kind?(:agent_id, :taken)
      assert_raises(ActiveRecord::RecordInvalid) { duplicate.save! }
      assert_predicate duplicate, :new_record?
      existing = model.create!(agent: second_resource, operator: first_principal)
      assert_raises(ActiveRecord::RecordInvalid) { existing.update!(agent: first_resource) }
      assert_equal second_resource.id, existing.reload.agent_id
      other = model.create!(agent: first_resource, operator: second_principal)
      assert_raises(ActiveRecord::RecordInvalid) { other.update!(operator: first_principal) }
      assert_equal second_principal.id, other.reload.operator_id
      assert_equal first.id, model.find_by!(agent: first_resource, operator: first_principal).id
    end

    test "#{model.name} keeps missing and sentinel foreign keys invalid" do
      first_principal = Operator.create!(
        security_mode_id: SecurityModeConfigurable::ADVANCED,
        status_id: OperatorStatus::ACTIVE, visibility_id: OperatorVisibility::STAFF,
      )
      second_principal = Operator.create!(
        security_mode_id: SecurityModeConfigurable::ADVANCED,
        status_id: OperatorStatus::ACTIVE, visibility_id: OperatorVisibility::STAFF,
      )
      OperatorIdentityState.ensure_defaults!
      first_identity = OperatorIdentity.create!(
        issuer: "https://grants.example.test", subject: "first",
        audience: "acme_org", source_record_id: first_principal.id, status_id: OperatorIdentityState::ACTIVE,
      )
      second_identity = OperatorIdentity.create!(
        issuer: "https://grants.example.test", subject: "second",
        audience: "acme_org", source_record_id: second_principal.id, status_id: OperatorIdentityState::ACTIVE,
      )
      first_resource = Agent.create!(operator_identity: first_identity, title: "First")
      Agent.create!(operator_identity: second_identity, title: "Second")

      [nil, "", 0, false].each do |missing|
        absent_resource = model.new(agent_id: missing, operator: first_principal)
        absent_principal = model.new(agent: first_resource, operator_id: missing)

        assert_not absent_resource.valid?
        assert_not absent_principal.valid?
        assert_predicate absent_resource, :new_record?
        assert_predicate absent_principal, :new_record?
      end
    end
    test "#{model.name} adds one pair probe and skips unchanged existing keys" do
      first_principal = Operator.create!(
        security_mode_id: SecurityModeConfigurable::ADVANCED,
        status_id: OperatorStatus::ACTIVE, visibility_id: OperatorVisibility::STAFF,
      )
      second_principal = Operator.create!(
        security_mode_id: SecurityModeConfigurable::ADVANCED,
        status_id: OperatorStatus::ACTIVE, visibility_id: OperatorVisibility::STAFF,
      )
      OperatorIdentityState.ensure_defaults!
      first_identity = OperatorIdentity.create!(
        issuer: "https://grants.example.test", subject: "first",
        audience: "acme_org", source_record_id: first_principal.id, status_id: OperatorIdentityState::ACTIVE,
      )
      second_identity = OperatorIdentity.create!(
        issuer: "https://grants.example.test", subject: "second",
        audience: "acme_org", source_record_id: second_principal.id, status_id: OperatorIdentityState::ACTIVE,
      )
      first_resource = Agent.create!(operator_identity: first_identity, title: "First")
      second_resource = Agent.create!(operator_identity: second_identity, title: "Second")

      existing = model.create!(agent: first_resource, operator: first_principal)
      candidate = model.new(agent: second_resource, operator: second_principal)
      queries = []
      subscriber =
        lambda do |_name, _start, _finish, _id, payload|
          sql = payload.fetch(:sql)
          queries << sql if sql.match?(/\ASELECT/i) && sql.include?(model.table_name)
        end
      ActiveSupport::Notifications.subscribed(subscriber, "sql.active_record") do
        assert_predicate candidate, :valid?
        assert_predicate existing, :valid?
      end
      assert_equal 1, queries.size
    end
  end
end
