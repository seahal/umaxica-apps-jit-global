# frozen_string_literal: true

require "test_helper"
require_relative "../support/avatar_test_factory"

class AvatarMonikerWriterOperationTest < ActiveSupport::TestCase
  fixtures :avatars

  test "replaces the current moniker with one contiguous temporal transition" do
    avatar = avatars(:one)
    previous = avatar.current_avatar_moniker
    effective_at = Time.utc(2026, 9, 24, 12, 0, 0)

    result = Time.stub(:current, effective_at) do
      AvatarMonikerWriterOperation.call(
        avatar: avatar,
        moniker: "Updated moniker",
        expected_current: :present,
      )
    end
    second_effective_at = effective_at + 1.second
    second_result = Time.stub(:current, second_effective_at) do
      AvatarMonikerWriterOperation.call(
        avatar: avatar,
        moniker: "Second name",
        expected_current: :present,
      )
    end

    assert_predicate result, :success?
    assert_equal avatar.id, result.avatar_moniker.avatar_id
    assert_equal effective_at, previous.reload.valid_to
    assert_equal effective_at, result.avatar_moniker.reload.valid_from
    assert_equal second_effective_at, result.avatar_moniker.valid_to
    assert_predicate second_result, :success?
    assert_equal second_effective_at, second_result.avatar_moniker.reload.valid_from
    assert_equal Float::INFINITY, second_result.avatar_moniker.valid_to
    assert_equal "Second name", avatar.moniker
    assert_equal "Second name", avatar.reload.moniker
  end

  test "same normalized moniker is a no-op and does not add history" do
    avatar = avatars(:one)
    current = avatar.current_avatar_moniker
    count_before = AvatarMoniker.count

    result = AvatarMonikerWriterOperation.call(
      avatar: avatar,
      moniker: "Moniker One",
      expected_current: :present,
    )

    assert_predicate result, :success?
    assert_equal current.id, result.avatar_moniker.id
    assert_equal count_before, AvatarMoniker.count
    assert_equal Float::INFINITY, current.reload.valid_to
  end

  test "canonically equivalent Unicode input resolves to the existing NFC value" do
    avatar = avatars(:one)
    changed = AvatarMonikerWriterOperation.call(
      avatar: avatar,
      moniker: "é",
      expected_current: :present,
    )
    current_id = changed.avatar_moniker.id
    count_before_equivalent_input = AvatarMoniker.count

    equivalent = AvatarMonikerWriterOperation.call(
      avatar: avatar,
      moniker: "e\u0301",
      expected_current: :present,
    )

    assert_predicate changed, :success?
    assert_predicate equivalent, :success?
    assert_equal current_id, equivalent.avatar_moniker.id
    assert_equal count_before_equivalent_input, AvatarMoniker.count
    assert_equal "é", avatar.reload.moniker
  end

  test "invalid replacement rolls back closing the existing current row" do
    avatar = avatars(:one)
    current = avatar.current_avatar_moniker
    moniker_count = AvatarMoniker.count

    result = AvatarMonikerWriterOperation.call(
      avatar: avatar,
      moniker: " ",
      expected_current: :present,
    )

    assert_not_predicate result, :success?
    assert_not_empty result.errors.fetch(:moniker)
    assert_equal moniker_count, AvatarMoniker.count
    assert_equal current.id, avatar.reload.current_avatar_moniker.id
    assert_equal Float::INFINITY, current.reload.valid_to
  end

  test "expected current state and enum inputs fail closed" do
    avatar = avatars(:one)

    assert_raises(ActiveRecord::RecordNotSaved) do
      AvatarMonikerWriterOperation.call(
        avatar: avatar,
        moniker: "Unexpected second initial name",
        expected_current: :absent,
      )
    end

    avatar.current_avatar_moniker.update!(valid_to: Time.current)

    assert_raises(ActiveRecord::RecordNotFound) do
      AvatarMonikerWriterOperation.call(
        avatar: avatar,
        moniker: "Missing current name",
        expected_current: :present,
      )
    end

    assert_raises(ArgumentError) do
      AvatarMonikerWriterOperation.call(
        avatar: avatar,
        moniker: "Unsupported state",
        expected_current: :unknown,
      )
    end
  end
end

class AvatarMonikerWriterConcurrencyTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  setup do
    AvatarCapability.find_or_create_by!(id: AvatarCapability::NORMAL)
    HandleStatus.ensure_defaults!
    @handle = Handle.create!(
      handle: "moniker-race-#{SecureRandom.hex(4)}",
      handle_status_id: HandleStatus::ACTIVE,
      cooldown_until: Time.current,
      is_system: false,
    )
    @avatar = AvatarTestFactory.create!(
      moniker: "Initial",
      capability: AvatarCapability.find_by!(id: AvatarCapability::NORMAL),
      active_handle: @handle,
    )
  end

  teardown do
    AvatarMoniker.where(avatar_id: @avatar.id).delete_all
    Avatar.where(id: @avatar.id).delete_all
    Handle.where(id: @handle.id).delete_all
  end

  test "independent connections serialize concurrent renames without duplicate current rows" do
    ready = Queue.new
    start = Queue.new
    avatar_id = @avatar.id

    # The test pool has two connections, both of which must be available to the workers.
    # Rails returns this thread's leased connection to the pool until their race completes.
    # Source: https://api.rubyonrails.org/classes/ActiveRecord/ConnectionAdapters/ConnectionPool.html#method-i-release_connection
    AvatarRecord.connection_pool.release_connection

    threads = ["Concurrent One", "Concurrent Two"].map do |moniker|
      Thread.new do
        ready << true
        start.pop
        AvatarRecord.connection_pool.with_connection do |connection|
          backend_pid = connection.select_value("SELECT pg_backend_pid()")
          result = AvatarMonikerWriterOperation.call(
            avatar: Avatar.find(avatar_id),
            moniker: moniker,
            expected_current: :present,
          )
          [backend_pid, result]
        end
      rescue StandardError => error
        error
      end
    end

    2.times { ready.pop }
    2.times { start << true }
    results = threads.map(&:value)
    thread_errors = results.grep(StandardError)
    completed_results = results.grep(Array)
    pids = completed_results.map(&:first)
    operation_results = completed_results.map(&:last)
    rows = AvatarMoniker.where(avatar_id: avatar_id).order(:id).to_a
    current_rows = rows.select { |row| row.valid_to == Float::INFINITY }

    assert_equal 2, pids.uniq.length
    assert_empty thread_errors, thread_errors.map(&:message).join("; ")
    assert operation_results.all?(&:success?)
    assert_equal 3, rows.length
    assert_equal 1, current_rows.length
    assert_equal rows[0].valid_to, rows[1].valid_from
    assert_equal rows[1].valid_to, rows[2].valid_from
    assert_includes ["Concurrent One", "Concurrent Two"], Avatar.find(avatar_id).moniker
  end
end
