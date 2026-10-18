# typed: false
# frozen_string_literal: true

require "test_helper"

class ParallelTestDatabaseClonerTest < ActiveSupport::TestCase
  test "clone_task rebuilds a missing clone" do
    stamped = { "test_com_principal_db" => nil }

    task = ParallelTestDatabaseCloner.clone_task(
      stamped,
      source: "test_com_principal_db",
      clone: "test_com_principal_replica_db",
      sha: "schema-sha",
    )

    assert_equal(
      { source: "test_com_principal_db",
        clone: "test_com_principal_replica_db",
        sha: "schema-sha",
        clone_exists: false, },
      task,
    )
  end

  test "clone_task rebuilds an existing clone whose stamped sha differs" do
    stamped = {
      "test_com_principal_db" => nil,
      "test_com_principal_replica_db" => "old-sha",
    }

    task = ParallelTestDatabaseCloner.clone_task(
      stamped,
      source: "test_com_principal_db",
      clone: "test_com_principal_replica_db",
      sha: "schema-sha",
    )

    assert task
    assert task.fetch(:clone_exists)
  end

  test "clone_task skips a clone whose stamped sha matches" do
    stamped = {
      "test_com_principal_db" => nil,
      "test_com_principal_replica_db" => "schema-sha",
    }

    assert_nil ParallelTestDatabaseCloner.clone_task(
      stamped,
      source: "test_com_principal_db",
      clone: "test_com_principal_replica_db",
      sha: "schema-sha",
    )
  end

  test "clone_task rebuilds every run when the schema dump sha is unavailable" do
    stamped = {
      "test_com_principal_db" => nil,
      "test_com_principal_replica_db" => "anything",
    }

    task = ParallelTestDatabaseCloner.clone_task(
      stamped,
      source: "test_com_principal_db",
      clone: "test_com_principal_replica_db",
      sha: nil,
    )

    assert task
    assert_nil task.fetch(:sha)
  end

  test "run_clone_tasks serializes clones sharing a template source" do
    tasks = [
      { source: "a", clone: "a_0", sha: "s", clone_exists: false },
      { source: "a", clone: "a_1", sha: "s", clone_exists: false },
      { source: "b", clone: "b_0", sha: "s", clone_exists: false },
    ]
    mutex = Mutex.new
    active_by_source = Hash.new(0)
    overlap = false
    order = []

    ParallelTestDatabaseCloner.stub(
      :connect, ->(*) {
                  Struct.new(:closed).new.tap { |c|
                    def c.close
                    end
                  }
                },
    ) do
      ParallelTestDatabaseCloner.stub(
        :rebuild_clone,
        lambda do |_connection, source:, clone:, sha:, clone_exists:|
          mutex.synchronize do
            active_by_source[source] += 1
            overlap ||= active_by_source[source] > 1
            order << clone
          end
          sleep 0.01
          mutex.synchronize { active_by_source[source] -= 1 }
        end,
      ) do
        ParallelTestDatabaseCloner.run_clone_tasks({ host: "unused", username: "unused" }, tasks)
      end
    end

    assert_not overlap, "clones from the same template source must not run concurrently"
    assert_equal %w(a_0 a_1 b_0).sort, order.sort
  end
end
