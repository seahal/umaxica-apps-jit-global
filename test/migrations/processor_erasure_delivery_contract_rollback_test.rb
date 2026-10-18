# frozen_string_literal: true

require "active_record"
require "minitest/autorun"
require_relative "../../db/app_principals_migrate/20260923160000_validate_client_processor_delivery_contract"
require_relative "../../db/com_principals_migrate/20260923160001_validate_visitor_processor_delivery_contract"

class ProcessorErasureDeliveryContractRollbackTest < Minitest::Test
  class MigrationProbe
    attr_reader :removed_constraints

    def initialize(expected_constraint)
      @expected_constraint = expected_constraint
      @removed_constraints = []
    end

    def add_check_constraint(*)
    end

    def change_column_null(*)
    end

    def remove_check_constraint(_table, name:)
      @removed_constraints << name
      return if name == @expected_constraint

      raise RuntimeError, "rollback referenced an unknown helper constraint: #{name}"
    end

    def safety_assured
      yield
    end
  end

  def test_client_validation_rollback_removes_the_helper_constraint_it_adds
    probe = MigrationProbe.new("chk_client_proc_notif_idem_digest_nn")
    migration = migration_with_probe(ValidateClientProcessorDeliveryContract, probe)

    migration.down

    assert_equal ["chk_client_proc_notif_idem_digest_nn"], probe.removed_constraints
  end

  def test_visitor_validation_rollback_removes_the_helper_constraint_it_adds
    probe = MigrationProbe.new("chk_visitor_proc_notif_idem_digest_nn")
    migration = migration_with_probe(ValidateVisitorProcessorDeliveryContract, probe)

    migration.down

    assert_equal ["chk_visitor_proc_notif_idem_digest_nn"], probe.removed_constraints
  end

  private

  def migration_with_probe(migration_class, probe)
    migration = migration_class.new
    migration.define_singleton_method(:add_check_constraint) do |*args, **kwargs|
      probe.add_check_constraint(*args, **kwargs)
    end
    migration.define_singleton_method(:change_column_null) do |*args, **kwargs|
      probe.change_column_null(*args, **kwargs)
    end
    migration.define_singleton_method(:remove_check_constraint) do |*args, **kwargs|
      probe.remove_check_constraint(*args, **kwargs)
    end
    migration.define_singleton_method(:safety_assured) { |&block| probe.safety_assured(&block) }
    migration
  end
end
