# typed: false
# frozen_string_literal: true

require "test_helper"

class UmaxicaValkeyConnectionAndCleanupTest < ActiveSupport::TestCase
  setup do
    @suite = "suite-#{SecureRandom.hex(4)}"
    @namespace = Umaxica::Valkey::Namespaces.authorization_codes(
      suite_run_id: @suite,
      worker_id: "w0",
      test_id: "connection",
    )
    @connection = Umaxica::Valkey::Connection.new(
      url: Umaxica::Valkey::Settings.current.auth_state.url,
      namespace: @namespace,
    )
  end

  teardown do
    next if @connection.nil?

    prefix = "#{@namespace}:"
    Umaxica::Valkey::Cleanup.delete_by_prefix(@connection, prefix: prefix)
    Umaxica::Valkey::Cleanup.ensure_empty!(@connection, prefix: prefix)
    @connection.close
  end

  test "uses hiredis driver and forbids FLUSH" do
    assert_predicate @connection, :hiredis_driver?

    assert_raises(Umaxica::Valkey::OperationError) do
      @connection.call("FLUSHDB")
    end
  end

  test "cleanup deletes only the namespaced prefix" do
    key = @connection.key("probe")
    @connection.call("SET", key, "1", "EX", 30)

    assert_equal "1", @connection.call("GET", key)
    deleted = Umaxica::Valkey::Cleanup.delete_by_prefix(@connection, prefix: "#{@namespace}:")

    assert_operator deleted, :>=, 1
    assert_nil @connection.call("GET", key)
  end

  test "cleanup consumes every scan cursor including empty and duplicate batches" do
    scan_results = [
      ["17", []],
      ["0", ["auth_state:test:one", "auth_state:test:one"]],
    ]
    deleted = []
    fake_connection = Object.new
    fake_connection.define_singleton_method(:call) do |command, *arguments|
      case command
      when "SCAN"
        scan_results.shift
      when "DEL"
        deleted << arguments.fetch(0)
        1
      else
        raise RuntimeError, "unexpected command: #{command}"
      end
    end

    assert_equal 1, Umaxica::Valkey::Cleanup.delete_by_prefix(
      fake_connection,
      prefix: "auth_state:test:",
    )
    assert_equal ["auth_state:test:one"], deleted
  end
end
