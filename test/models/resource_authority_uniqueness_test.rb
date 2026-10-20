# frozen_string_literal: true

require "test_helper"

class EnterpriseAuthorityUniquenessTest < ActiveSupport::TestCase
  MODELS = [[EnterpriseOwnership, { ownership_revision: 0 }, :client_id],
            [EnterpriseLifecycle, { state: AuthorityResourceLifecycleStateValue::ACTIVE }, nil],].freeze

  MODELS.each do |model, initial, principal_key|
    test "#{model.name} retains DB one-row ownership and ordinary updates" do
      first_principal = Client.create!(status_id: ClientStatus::ACTIVE, visibility_id: ClientVisibility::USER)
      Client.create!(status_id: ClientStatus::ACTIVE, visibility_id: ClientVisibility::USER)
      first_resource = Enterprise.create!(name: "First resource", title: "First")
      second_resource = Enterprise.create!(name: "Second resource", title: "Second")

      attributes = initial.dup
      attributes[principal_key] = first_principal.id unless principal_key.nil?
      attributes[:enterprise_id] = first_resource.id
      first = model.create!(attributes)
      second = model.create!(attributes.merge(enterprise_id: second_resource.id))

      assert_predicate first, :valid?
      first.save!

      assert_equal first_resource.id, first.reload.enterprise_id
      assert_equal second_resource.id, second.reload.enterprise_id
      error =
        assert_raises(ActiveRecord::RecordNotUnique) do
          model.transaction(requires_new: true) { model.new(attributes).save!(validate: false) }
        end
      assert_instance_of PG::UniqueViolation, error.cause
      assert_equal 2, model.where(enterprise_id: [first_resource.id, second_resource.id]).count
    end

    test "#{model.name} rejects duplicate and reassigned resource keys before SQL" do
      first_principal = Client.create!(status_id: ClientStatus::ACTIVE, visibility_id: ClientVisibility::USER)
      Client.create!(status_id: ClientStatus::ACTIVE, visibility_id: ClientVisibility::USER)
      first_resource = Enterprise.create!(name: "First resource", title: "First")
      second_resource = Enterprise.create!(name: "Second resource", title: "Second")

      attributes = initial.dup
      attributes[principal_key] = first_principal.id unless principal_key.nil?
      attributes[:enterprise_id] = first_resource.id
      model.create!(attributes)
      duplicate = model.new(attributes)

      assert_not duplicate.valid?
      assert duplicate.errors.of_kind?(:enterprise_id, :taken)
      assert_raises(ActiveRecord::RecordInvalid) { duplicate.save! }
      assert_predicate duplicate, :new_record?
      second = model.create!(attributes.merge(enterprise_id: second_resource.id))
      assert_raises(ActiveRecord::RecordInvalid) { second.update!(enterprise_id: first_resource.id) }
      assert_equal second_resource.id, second.reload.enterprise_id
      [nil, "", 0, false].each do |missing|
        candidate = model.new(attributes.merge(enterprise_id: missing))

        assert_not candidate.valid?
      end
    end

    test "#{model.name} adds one resource probe and skips an unchanged persisted key" do
      first_principal = Client.create!(status_id: ClientStatus::ACTIVE, visibility_id: ClientVisibility::USER)
      Client.create!(status_id: ClientStatus::ACTIVE, visibility_id: ClientVisibility::USER)
      first_resource = Enterprise.create!(name: "First resource", title: "First")
      second_resource = Enterprise.create!(name: "Second resource", title: "Second")

      attributes = initial.dup
      attributes[principal_key] = first_principal.id unless principal_key.nil?
      attributes[:enterprise_id] = first_resource.id
      first = model.create!(attributes)
      candidate = model.new(attributes.merge(enterprise_id: second_resource.id))
      queries = []
      subscriber =
        lambda do |_name, _start, _finish, _id, payload|
          sql = payload.fetch(:sql)
          queries << sql if sql.match?(/\ASELECT/i) && sql.include?(model.table_name)
        end
      ActiveSupport::Notifications.subscribed(subscriber, "sql.active_record") do
        assert_predicate candidate, :valid?
        assert_predicate first, :valid?
      end
      assert_equal 1, queries.size
    end
  end
end

class ClientPersonaAuthorityUniquenessTest < ActiveSupport::TestCase
  MODELS = [[ClientPersonaOwnership, { ownership_revision: 0 }, :client_id],
            [ClientPersonaLifecycle, { state: AuthorityResourceLifecycleStateValue::ACTIVE }, nil],].freeze

  MODELS.each do |model, initial, principal_key|
    test "#{model.name} retains DB one-row ownership and ordinary updates" do
      first_principal = Client.create!(status_id: ClientStatus::ACTIVE, visibility_id: ClientVisibility::USER)
      second_principal = Client.create!(status_id: ClientStatus::ACTIVE, visibility_id: ClientVisibility::USER)
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

      attributes = initial.dup
      attributes[principal_key] = first_principal.id unless principal_key.nil?
      attributes[:client_persona_id] = first_resource.id
      first = model.create!(attributes)
      second = model.create!(attributes.merge(client_persona_id: second_resource.id))

      assert_predicate first, :valid?
      first.save!

      assert_equal first_resource.id, first.reload.client_persona_id
      assert_equal second_resource.id, second.reload.client_persona_id
      error =
        assert_raises(ActiveRecord::RecordNotUnique) do
          model.transaction(requires_new: true) { model.new(attributes).save!(validate: false) }
        end
      assert_instance_of PG::UniqueViolation, error.cause
      assert_equal 2, model.where(client_persona_id: [first_resource.id, second_resource.id]).count
    end

    test "#{model.name} rejects duplicate and reassigned resource keys before SQL" do
      first_principal = Client.create!(status_id: ClientStatus::ACTIVE, visibility_id: ClientVisibility::USER)
      second_principal = Client.create!(status_id: ClientStatus::ACTIVE, visibility_id: ClientVisibility::USER)
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

      attributes = initial.dup
      attributes[principal_key] = first_principal.id unless principal_key.nil?
      attributes[:client_persona_id] = first_resource.id
      model.create!(attributes)
      duplicate = model.new(attributes)

      assert_not duplicate.valid?
      assert duplicate.errors.of_kind?(:client_persona_id, :taken)
      assert_raises(ActiveRecord::RecordInvalid) { duplicate.save! }
      assert_predicate duplicate, :new_record?
      second = model.create!(attributes.merge(client_persona_id: second_resource.id))
      assert_raises(ActiveRecord::RecordInvalid) { second.update!(client_persona_id: first_resource.id) }
      assert_equal second_resource.id, second.reload.client_persona_id
      [nil, "", 0, false].each do |missing|
        candidate = model.new(attributes.merge(client_persona_id: missing))

        assert_not candidate.valid?
      end
    end

    test "#{model.name} adds one resource probe and skips an unchanged persisted key" do
      first_principal = Client.create!(status_id: ClientStatus::ACTIVE, visibility_id: ClientVisibility::USER)
      second_principal = Client.create!(status_id: ClientStatus::ACTIVE, visibility_id: ClientVisibility::USER)
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

      attributes = initial.dup
      attributes[principal_key] = first_principal.id unless principal_key.nil?
      attributes[:client_persona_id] = first_resource.id
      first = model.create!(attributes)
      candidate = model.new(attributes.merge(client_persona_id: second_resource.id))
      queries = []
      subscriber =
        lambda do |_name, _start, _finish, _id, payload|
          sql = payload.fetch(:sql)
          queries << sql if sql.match?(/\ASELECT/i) && sql.include?(model.table_name)
        end
      ActiveSupport::Notifications.subscribed(subscriber, "sql.active_record") do
        assert_predicate candidate, :valid?
        assert_predicate first, :valid?
      end
      assert_equal 1, queries.size
    end
  end
end

class CompanyAuthorityUniquenessTest < ActiveSupport::TestCase
  MODELS = [[CompanyOwnership, { ownership_revision: 0 }, :visitor_id],
            [CompanyLifecycle, { state: AuthorityResourceLifecycleStateValue::ACTIVE }, nil],].freeze

  MODELS.each do |model, initial, principal_key|
    test "#{model.name} retains DB one-row ownership and ordinary updates" do
      first_principal = Visitor.create!(status_id: VisitorStatus::ACTIVE, visibility_id: VisitorVisibility::VISITOR)
      Visitor.create!(status_id: VisitorStatus::ACTIVE, visibility_id: VisitorVisibility::VISITOR)
      first_resource = Company.create!(name: "First resource", title: "First")
      second_resource = Company.create!(name: "Second resource", title: "Second")

      attributes = initial.dup
      attributes[principal_key] = first_principal.id unless principal_key.nil?
      attributes[:company_id] = first_resource.id
      first = model.create!(attributes)
      second = model.create!(attributes.merge(company_id: second_resource.id))

      assert_predicate first, :valid?
      first.save!

      assert_equal first_resource.id, first.reload.company_id
      assert_equal second_resource.id, second.reload.company_id
      error =
        assert_raises(ActiveRecord::RecordNotUnique) do
          model.transaction(requires_new: true) { model.new(attributes).save!(validate: false) }
        end
      assert_instance_of PG::UniqueViolation, error.cause
      assert_equal 2, model.where(company_id: [first_resource.id, second_resource.id]).count
    end

    test "#{model.name} rejects duplicate and reassigned resource keys before SQL" do
      first_principal = Visitor.create!(status_id: VisitorStatus::ACTIVE, visibility_id: VisitorVisibility::VISITOR)
      Visitor.create!(status_id: VisitorStatus::ACTIVE, visibility_id: VisitorVisibility::VISITOR)
      first_resource = Company.create!(name: "First resource", title: "First")
      second_resource = Company.create!(name: "Second resource", title: "Second")

      attributes = initial.dup
      attributes[principal_key] = first_principal.id unless principal_key.nil?
      attributes[:company_id] = first_resource.id
      model.create!(attributes)
      duplicate = model.new(attributes)

      assert_not duplicate.valid?
      assert duplicate.errors.of_kind?(:company_id, :taken)
      assert_raises(ActiveRecord::RecordInvalid) { duplicate.save! }
      assert_predicate duplicate, :new_record?
      second = model.create!(attributes.merge(company_id: second_resource.id))
      assert_raises(ActiveRecord::RecordInvalid) { second.update!(company_id: first_resource.id) }
      assert_equal second_resource.id, second.reload.company_id
      [nil, "", 0, false].each do |missing|
        candidate = model.new(attributes.merge(company_id: missing))

        assert_not candidate.valid?
      end
    end

    test "#{model.name} adds one resource probe and skips an unchanged persisted key" do
      first_principal = Visitor.create!(status_id: VisitorStatus::ACTIVE, visibility_id: VisitorVisibility::VISITOR)
      Visitor.create!(status_id: VisitorStatus::ACTIVE, visibility_id: VisitorVisibility::VISITOR)
      first_resource = Company.create!(name: "First resource", title: "First")
      second_resource = Company.create!(name: "Second resource", title: "Second")

      attributes = initial.dup
      attributes[principal_key] = first_principal.id unless principal_key.nil?
      attributes[:company_id] = first_resource.id
      first = model.create!(attributes)
      candidate = model.new(attributes.merge(company_id: second_resource.id))
      queries = []
      subscriber =
        lambda do |_name, _start, _finish, _id, payload|
          sql = payload.fetch(:sql)
          queries << sql if sql.match?(/\ASELECT/i) && sql.include?(model.table_name)
        end
      ActiveSupport::Notifications.subscribed(subscriber, "sql.active_record") do
        assert_predicate candidate, :valid?
        assert_predicate first, :valid?
      end
      assert_equal 1, queries.size
    end
  end
end

class IndividualAuthorityUniquenessTest < ActiveSupport::TestCase
  MODELS = [[IndividualOwnership, { ownership_revision: 0 }, :visitor_id],
            [IndividualLifecycle, { state: AuthorityResourceLifecycleStateValue::ACTIVE }, nil],].freeze

  MODELS.each do |model, initial, principal_key|
    test "#{model.name} retains DB one-row ownership and ordinary updates" do
      first_principal = Visitor.create!(status_id: VisitorStatus::ACTIVE, visibility_id: VisitorVisibility::VISITOR)
      second_principal = Visitor.create!(status_id: VisitorStatus::ACTIVE, visibility_id: VisitorVisibility::VISITOR)
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

      attributes = initial.dup
      attributes[principal_key] = first_principal.id unless principal_key.nil?
      attributes[:individual_id] = first_resource.id
      first = model.create!(attributes)
      second = model.create!(attributes.merge(individual_id: second_resource.id))

      assert_predicate first, :valid?
      first.save!

      assert_equal first_resource.id, first.reload.individual_id
      assert_equal second_resource.id, second.reload.individual_id
      error =
        assert_raises(ActiveRecord::RecordNotUnique) do
          model.transaction(requires_new: true) { model.new(attributes).save!(validate: false) }
        end
      assert_instance_of PG::UniqueViolation, error.cause
      assert_equal 2, model.where(individual_id: [first_resource.id, second_resource.id]).count
    end

    test "#{model.name} rejects duplicate and reassigned resource keys before SQL" do
      first_principal = Visitor.create!(status_id: VisitorStatus::ACTIVE, visibility_id: VisitorVisibility::VISITOR)
      second_principal = Visitor.create!(status_id: VisitorStatus::ACTIVE, visibility_id: VisitorVisibility::VISITOR)
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

      attributes = initial.dup
      attributes[principal_key] = first_principal.id unless principal_key.nil?
      attributes[:individual_id] = first_resource.id
      model.create!(attributes)
      duplicate = model.new(attributes)

      assert_not duplicate.valid?
      assert duplicate.errors.of_kind?(:individual_id, :taken)
      assert_raises(ActiveRecord::RecordInvalid) { duplicate.save! }
      assert_predicate duplicate, :new_record?
      second = model.create!(attributes.merge(individual_id: second_resource.id))
      assert_raises(ActiveRecord::RecordInvalid) { second.update!(individual_id: first_resource.id) }
      assert_equal second_resource.id, second.reload.individual_id
      [nil, "", 0, false].each do |missing|
        candidate = model.new(attributes.merge(individual_id: missing))

        assert_not candidate.valid?
      end
    end

    test "#{model.name} adds one resource probe and skips an unchanged persisted key" do
      first_principal = Visitor.create!(status_id: VisitorStatus::ACTIVE, visibility_id: VisitorVisibility::VISITOR)
      second_principal = Visitor.create!(status_id: VisitorStatus::ACTIVE, visibility_id: VisitorVisibility::VISITOR)
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

      attributes = initial.dup
      attributes[principal_key] = first_principal.id unless principal_key.nil?
      attributes[:individual_id] = first_resource.id
      first = model.create!(attributes)
      candidate = model.new(attributes.merge(individual_id: second_resource.id))
      queries = []
      subscriber =
        lambda do |_name, _start, _finish, _id, payload|
          sql = payload.fetch(:sql)
          queries << sql if sql.match?(/\ASELECT/i) && sql.include?(model.table_name)
        end
      ActiveSupport::Notifications.subscribed(subscriber, "sql.active_record") do
        assert_predicate candidate, :valid?
        assert_predicate first, :valid?
      end
      assert_equal 1, queries.size
    end
  end
end

class BureauAuthorityUniquenessTest < ActiveSupport::TestCase
  MODELS = [[BureauOwnership, { ownership_revision: 0 }, :operator_id],
            [BureauLifecycle, { state: AuthorityResourceLifecycleStateValue::ACTIVE }, nil],].freeze

  MODELS.each do |model, initial, principal_key|
    test "#{model.name} retains DB one-row ownership and ordinary updates" do
      first_principal = Operator.create!(status_id: OperatorStatus::ACTIVE, visibility_id: OperatorVisibility::STAFF)
      Operator.create!(status_id: OperatorStatus::ACTIVE, visibility_id: OperatorVisibility::STAFF)
      first_resource = Bureau.create!(name: "First resource", title: "First")
      second_resource = Bureau.create!(name: "Second resource", title: "Second")

      attributes = initial.dup
      attributes[principal_key] = first_principal.id unless principal_key.nil?
      attributes[:bureau_id] = first_resource.id
      first = model.create!(attributes)
      second = model.create!(attributes.merge(bureau_id: second_resource.id))

      assert_predicate first, :valid?
      first.save!

      assert_equal first_resource.id, first.reload.bureau_id
      assert_equal second_resource.id, second.reload.bureau_id
      error =
        assert_raises(ActiveRecord::RecordNotUnique) do
          model.transaction(requires_new: true) { model.new(attributes).save!(validate: false) }
        end
      assert_instance_of PG::UniqueViolation, error.cause
      assert_equal 2, model.where(bureau_id: [first_resource.id, second_resource.id]).count
    end

    test "#{model.name} rejects duplicate and reassigned resource keys before SQL" do
      first_principal = Operator.create!(status_id: OperatorStatus::ACTIVE, visibility_id: OperatorVisibility::STAFF)
      Operator.create!(status_id: OperatorStatus::ACTIVE, visibility_id: OperatorVisibility::STAFF)
      first_resource = Bureau.create!(name: "First resource", title: "First")
      second_resource = Bureau.create!(name: "Second resource", title: "Second")

      attributes = initial.dup
      attributes[principal_key] = first_principal.id unless principal_key.nil?
      attributes[:bureau_id] = first_resource.id
      model.create!(attributes)
      duplicate = model.new(attributes)

      assert_not duplicate.valid?
      assert duplicate.errors.of_kind?(:bureau_id, :taken)
      assert_raises(ActiveRecord::RecordInvalid) { duplicate.save! }
      assert_predicate duplicate, :new_record?
      second = model.create!(attributes.merge(bureau_id: second_resource.id))
      assert_raises(ActiveRecord::RecordInvalid) { second.update!(bureau_id: first_resource.id) }
      assert_equal second_resource.id, second.reload.bureau_id
      [nil, "", 0, false].each do |missing|
        candidate = model.new(attributes.merge(bureau_id: missing))

        assert_not candidate.valid?
      end
    end

    test "#{model.name} adds one resource probe and skips an unchanged persisted key" do
      first_principal = Operator.create!(status_id: OperatorStatus::ACTIVE, visibility_id: OperatorVisibility::STAFF)
      Operator.create!(status_id: OperatorStatus::ACTIVE, visibility_id: OperatorVisibility::STAFF)
      first_resource = Bureau.create!(name: "First resource", title: "First")
      second_resource = Bureau.create!(name: "Second resource", title: "Second")

      attributes = initial.dup
      attributes[principal_key] = first_principal.id unless principal_key.nil?
      attributes[:bureau_id] = first_resource.id
      first = model.create!(attributes)
      candidate = model.new(attributes.merge(bureau_id: second_resource.id))
      queries = []
      subscriber =
        lambda do |_name, _start, _finish, _id, payload|
          sql = payload.fetch(:sql)
          queries << sql if sql.match?(/\ASELECT/i) && sql.include?(model.table_name)
        end
      ActiveSupport::Notifications.subscribed(subscriber, "sql.active_record") do
        assert_predicate candidate, :valid?
        assert_predicate first, :valid?
      end
      assert_equal 1, queries.size
    end
  end
end

class AgentAuthorityUniquenessTest < ActiveSupport::TestCase
  MODELS = [[AgentOwnership, { ownership_revision: 0 }, :operator_id],
            [AgentLifecycle, { state: AuthorityResourceLifecycleStateValue::ACTIVE }, nil],].freeze

  MODELS.each do |model, initial, principal_key|
    test "#{model.name} retains DB one-row ownership and ordinary updates" do
      first_principal = Operator.create!(status_id: OperatorStatus::ACTIVE, visibility_id: OperatorVisibility::STAFF)
      second_principal = Operator.create!(status_id: OperatorStatus::ACTIVE, visibility_id: OperatorVisibility::STAFF)
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

      attributes = initial.dup
      attributes[principal_key] = first_principal.id unless principal_key.nil?
      attributes[:agent_id] = first_resource.id
      first = model.create!(attributes)
      second = model.create!(attributes.merge(agent_id: second_resource.id))

      assert_predicate first, :valid?
      first.save!

      assert_equal first_resource.id, first.reload.agent_id
      assert_equal second_resource.id, second.reload.agent_id
      error =
        assert_raises(ActiveRecord::RecordNotUnique) do
          model.transaction(requires_new: true) { model.new(attributes).save!(validate: false) }
        end
      assert_instance_of PG::UniqueViolation, error.cause
      assert_equal 2, model.where(agent_id: [first_resource.id, second_resource.id]).count
    end

    test "#{model.name} rejects duplicate and reassigned resource keys before SQL" do
      first_principal = Operator.create!(status_id: OperatorStatus::ACTIVE, visibility_id: OperatorVisibility::STAFF)
      second_principal = Operator.create!(status_id: OperatorStatus::ACTIVE, visibility_id: OperatorVisibility::STAFF)
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

      attributes = initial.dup
      attributes[principal_key] = first_principal.id unless principal_key.nil?
      attributes[:agent_id] = first_resource.id
      model.create!(attributes)
      duplicate = model.new(attributes)

      assert_not duplicate.valid?
      assert duplicate.errors.of_kind?(:agent_id, :taken)
      assert_raises(ActiveRecord::RecordInvalid) { duplicate.save! }
      assert_predicate duplicate, :new_record?
      second = model.create!(attributes.merge(agent_id: second_resource.id))
      assert_raises(ActiveRecord::RecordInvalid) { second.update!(agent_id: first_resource.id) }
      assert_equal second_resource.id, second.reload.agent_id
      [nil, "", 0, false].each do |missing|
        candidate = model.new(attributes.merge(agent_id: missing))

        assert_not candidate.valid?
      end
    end

    test "#{model.name} adds one resource probe and skips an unchanged persisted key" do
      first_principal = Operator.create!(status_id: OperatorStatus::ACTIVE, visibility_id: OperatorVisibility::STAFF)
      second_principal = Operator.create!(status_id: OperatorStatus::ACTIVE, visibility_id: OperatorVisibility::STAFF)
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

      attributes = initial.dup
      attributes[principal_key] = first_principal.id unless principal_key.nil?
      attributes[:agent_id] = first_resource.id
      first = model.create!(attributes)
      candidate = model.new(attributes.merge(agent_id: second_resource.id))
      queries = []
      subscriber =
        lambda do |_name, _start, _finish, _id, payload|
          sql = payload.fetch(:sql)
          queries << sql if sql.match?(/\ASELECT/i) && sql.include?(model.table_name)
        end
      ActiveSupport::Notifications.subscribed(subscriber, "sql.active_record") do
        assert_predicate candidate, :valid?
        assert_predicate first, :valid?
      end
      assert_equal 1, queries.size
    end
  end
end
