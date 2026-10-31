# frozen_string_literal: true

require "test_helper"
require "timeout"

class EnforcementReconciliationEndRaceTest < ActiveSupport::TestCase
  self.use_transactional_tests = false
  self.fixture_table_names = []

  test "a Case ended during principal lock retry is not relocked" do
    actor = Client.create!(
      id: SecureRandom.random_number(1 << 60) + 1_000_000_000,
      security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE,
    )
    operator = Operator.create!(
      id: SecureRandom.random_number(1 << 60) + 1_000_000_000,
      security_mode_id: SecurityModeConfigurable::ADVANCED, status_id: OperatorStatus::ACTIVE,
    )
    the_case = AppEnforcementCase.create!(
      kind: "security_lock", state: "active", duration_mode: "indefinite", visibility: "visible",
      release_mode: "verification_required", effective_at: Time.current, reason_code: "security_incident",
      principal_public_id: actor.public_id, applied_by_operator_public_id: operator.public_id,
    )
    AppEnforcementPrincipalEffect.create!(
      enforcement_case: the_case, principal_public_id: actor.public_id,
      access_blocking: true, effective_at: Time.current,
    )
    ready = Queue.new
    proceed = Queue.new
    worker = nil
    original = AdministrativeAccessLock.method(:lock!)
    pause_lock =
      lambda do |**args, &block|
        ready << true
        proceed.pop
        original.call(**args, &block)
      end

    OpIdentityEventInvalidator.stub(:deliver, :applied) do
      AdministrativeAccessLock.stub(:lock!, pause_lock) do
        worker = Thread.new { EnforcementReconciliationJob.perform_now }
        Timeout.timeout(10) { ready.pop }
        EnforcementCaseEndOperation.call(enforcement_case: AppEnforcementCase.find(the_case.id), reason: "revoked")
        proceed << true
        Timeout.timeout(10) { worker.value }
      end
    end

    assert_predicate the_case.reload.ended_at, :present?
    assert_predicate actor.reload, :access_enabled?
    assert_not AppIdentityAuthenticationEvent.exists?(actor_ref: actor.id.to_s)
  ensure
    proceed << true if proceed
    begin
      worker&.join(10)
    rescue StandardError
      # Preserve the test failure while still removing its synthetic records.
    end
    EnforcementEvent.where(case_public_id: the_case.public_id).delete_all if the_case&.persisted?
    AccountAccessEvent.where(account_type: "Client", account_id: actor.id).delete_all if actor
    AppIdentityAuthenticationEvent.where(actor_ref: actor.id.to_s).delete_all if actor
    AppEnforcementPrincipalEffect.where(app_enforcement_case_id: the_case.id).delete_all if the_case&.persisted?
    the_case&.delete
    actor&.delete
    operator&.delete
  end

  test "a new blocking Case prevents an earlier Case from releasing the principal" do
    actor = Client.create!(
      id: SecureRandom.random_number(1 << 60) + 1_000_000_000,
      security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE,
    )
    operator = Operator.create!(
      id: SecureRandom.random_number(1 << 60) + 1_000_000_000,
      security_mode_id: SecurityModeConfigurable::ADVANCED, status_id: OperatorStatus::ACTIVE,
    )
    build_case =
      lambda do
        record = AppEnforcementCase.new(
          kind: "security_lock", state: "draft", duration_mode: "indefinite", visibility: "visible",
          release_mode: "verification_required", effective_at: Time.current, reason_code: "security_incident",
          principal_public_id: actor.public_id, applied_by_operator_public_id: operator.public_id,
        )
        record.build_principal_effect(
          principal_public_id: actor.public_id, access_blocking: true,
          effective_at: Time.current,
        )
        record
      end
    first = build_case.call
    second = build_case.call
    ready = Queue.new
    proceed = Queue.new
    worker = nil
    original = AdministrativeAccessLock.method(:unlock!)
    pause_unlock =
      lambda do |**args, &block|
        ready << true
        proceed.pop
        original.call(**args, &block)
      end

    OpIdentityEventInvalidator.stub(:deliver, :applied) do
      EnforcementCaseApplyOperation.call(enforcement_case: first, actor_operator_public_id: operator.public_id)
      AdministrativeAccessLock.stub(:unlock!, pause_unlock) do
        worker =
          Thread.new do
            EnforcementCaseEndOperation.call(
              enforcement_case: AppEnforcementCase.find(first.id),
              reason: "revoked",
            )
          end
        Timeout.timeout(10) { ready.pop }
        EnforcementCaseApplyOperation.call(enforcement_case: second, actor_operator_public_id: operator.public_id)
        proceed << true
        Timeout.timeout(10) { worker.value }
      end
    end

    assert_predicate first.reload.ended_at, :present?
    assert_nil second.reload.ended_at
    assert_predicate actor.reload, :admin_locked?
  ensure
    proceed << true if proceed
    begin
      worker&.join(10)
    rescue StandardError
      # Preserve the test failure while still removing its synthetic records.
    end
    [first, second].compact.each do |record|
      next unless record.persisted?

      EnforcementEvent.where(case_public_id: record.public_id).delete_all
      AppEnforcementPrincipalEffect.where(app_enforcement_case_id: record.id).delete_all
      record.delete
    end
    AccountAccessEvent.where(account_type: "Client", account_id: actor.id).delete_all if actor
    AppIdentityAuthenticationEvent.where(actor_ref: actor.id.to_s).delete_all if actor
    actor&.delete
    operator&.delete
  end

  test "a new ORG blocking Case prevents an earlier Case from releasing the operator" do
    actor = Operator.create!(
      id: SecureRandom.random_number(1 << 60) + 1_000_000_000,
      security_mode_id: SecurityModeConfigurable::ADVANCED, status_id: OperatorStatus::ACTIVE,
    )
    operator = Operator.create!(
      id: SecureRandom.random_number(1 << 60) + 1_000_000_000,
      security_mode_id: SecurityModeConfigurable::ADVANCED, status_id: OperatorStatus::ACTIVE,
    )
    build_case =
      lambda do
        record = OrgEnforcementCase.new(
          kind: "security_lock", state: "draft", duration_mode: "indefinite", visibility: "visible",
          release_mode: "verification_required", effective_at: Time.current, reason_code: "security_incident",
          principal_public_id: actor.public_id, applied_by_operator_public_id: operator.public_id,
        )
        record.build_principal_effect(
          principal_public_id: actor.public_id, access_blocking: true,
          effective_at: Time.current,
        )
        record
      end
    first = build_case.call
    second = build_case.call
    ready = Queue.new
    proceed = Queue.new
    worker = nil
    original = AdministrativeAccessLock.method(:unlock!)
    pause_unlock =
      lambda do |**args, &block|
        ready << true
        proceed.pop
        original.call(**args, &block)
      end

    OpIdentityEventInvalidator.stub(:deliver, :applied) do
      EnforcementCaseApplyOperation.call(enforcement_case: first, actor_operator_public_id: operator.public_id)
      AdministrativeAccessLock.stub(:unlock!, pause_unlock) do
        worker =
          Thread.new do
            EnforcementCaseEndOperation.call(
              enforcement_case: OrgEnforcementCase.find(first.id),
              reason: "revoked",
            )
          end
        Timeout.timeout(10) { ready.pop }
        EnforcementCaseApplyOperation.call(enforcement_case: second, actor_operator_public_id: operator.public_id)
        proceed << true
        Timeout.timeout(10) { worker.value }
      end
    end

    assert_predicate first.reload.ended_at, :present?
    assert_nil second.reload.ended_at
    assert_predicate actor.reload, :admin_locked?
  ensure
    proceed << true if proceed
    begin
      worker&.join(10)
    rescue StandardError
      # Preserve the test failure while still removing its synthetic records.
    end
    [first, second].compact.each do |record|
      next unless record.persisted?

      EnforcementEvent.where(case_public_id: record.public_id).delete_all
      OrgEnforcementPrincipalEffect.where(org_enforcement_case_id: record.id).delete_all
      record.delete
    end
    AccountAccessEvent.where(account_type: "Operator", account_id: actor.id).delete_all if actor
    OrgIdentityAuthenticationEvent.where(actor_ref: actor.id.to_s).delete_all if actor
    actor&.delete
    operator&.delete
  end

  test "ORG Case end waits for the committed operator lock and then releases it" do
    actor = Operator.create!(
      id: SecureRandom.random_number(1 << 60) + 1_000_000_000,
      security_mode_id: SecurityModeConfigurable::ADVANCED, status_id: OperatorStatus::ACTIVE,
    )
    operator = Operator.create!(
      id: SecureRandom.random_number(1 << 60) + 1_000_000_000,
      security_mode_id: SecurityModeConfigurable::ADVANCED, status_id: OperatorStatus::ACTIVE,
    )
    the_case = OrgEnforcementCase.new(
      kind: "security_lock", state: "draft", duration_mode: "indefinite", visibility: "visible",
      release_mode: "verification_required", effective_at: Time.current, reason_code: "security_incident",
      principal_public_id: actor.public_id, applied_by_operator_public_id: operator.public_id,
    )
    the_case.build_principal_effect(
      principal_public_id: actor.public_id, access_blocking: true,
      effective_at: Time.current,
    )
    locked = Queue.new
    proceed = Queue.new
    end_ready = Queue.new
    source_visible = Queue.new
    worker = ending = nil
    paused = false
    observer =
      lambda do |_name, _start, _finish, _id, event|
        next unless Thread.current == worker && !paused && event.fetch(:sql).match?(/\A\s*UPDATE\s+"operators"/i)

        paused = true
        locked << Operator.lease_connection.select_value("SELECT pg_backend_pid()").to_i
        proceed.pop
      end

    inspect_delivery =
      lambda do |event:|
        reader =
          Thread.new do
            OrgIdentityAuthenticationEvent.connection_pool.with_connection(prevent_permanent_checkout: true) do
              OrgIdentityAuthenticationEvent.exists?(id: event.id)
            end
          end
        source_visible << Timeout.timeout(10) { reader.value }
        :applied
      end
    OpIdentityEventInvalidator.stub(:deliver, inspect_delivery) do
      ActiveSupport::Notifications.subscribed(observer, "sql.active_record") do
        worker =
          Thread.new do
            EnforcementCaseApplyOperation.call(
              enforcement_case: the_case,
              actor_operator_public_id: operator.public_id,
            )
          end
        worker_pid = Timeout.timeout(10) { locked.pop }
        ending =
          Thread.new do
            OrgEnforcementCase.connection_pool.with_connection(prevent_permanent_checkout: true) do |connection|
              end_ready << connection.select_value("SELECT pg_backend_pid()").to_i
              EnforcementCaseEndOperation.call(
                enforcement_case: OrgEnforcementCase.find(the_case.id),
                reason: "revoked",
              )
            end
          end
        ending_pid = Timeout.timeout(10) { end_ready.pop }
        Timeout.timeout(10) do
          loop do
            waiting =
              OrgEnforcementCase.uncached do
                OrgEnforcementCase.lease_connection.select_value(
                  "SELECT #{Integer(worker_pid)} = ANY(pg_blocking_pids(#{Integer(ending_pid)}))",
                )
              end
            break if waiting

            Thread.pass
          end
        end
        proceed << true
        Timeout.timeout(10) { worker.value }

        assert Timeout.timeout(10) { ending.value }
      end
    end

    assert_predicate the_case.reload.ended_at, :present?
    assert_predicate actor.reload, :access_enabled?
    assert Timeout.timeout(10) { source_visible.pop }, "the Source event must commit before OP delivery"
  ensure
    proceed << true if proceed
    [worker, ending].compact.each do |thread|
      begin
        thread.join(10)
      rescue StandardError
        # Preserve the test failure while still removing its synthetic records.
      end
    end
    EnforcementEvent.where(case_public_id: the_case.public_id).delete_all if the_case&.persisted?
    AccountAccessEvent.where(account_type: "Operator", account_id: actor.id).delete_all if actor
    OrgIdentityAuthenticationEvent.where(actor_ref: actor.id.to_s).delete_all if actor
    OrgEnforcementPrincipalEffect.where(org_enforcement_case_id: the_case.id).delete_all if the_case&.persisted?
    the_case&.delete
    actor&.delete
    operator&.delete
  end

  test "an ended ORG Case cannot apply a late operator lock" do
    actor = Operator.create!(
      id: SecureRandom.random_number(1 << 60) + 1_000_000_000,
      security_mode_id: SecurityModeConfigurable::ADVANCED, status_id: OperatorStatus::ACTIVE,
    )
    operator = Operator.create!(
      id: SecureRandom.random_number(1 << 60) + 1_000_000_000,
      security_mode_id: SecurityModeConfigurable::ADVANCED, status_id: OperatorStatus::ACTIVE,
    )
    the_case = OrgEnforcementCase.new(
      kind: "security_lock", state: "draft", duration_mode: "indefinite", visibility: "visible",
      release_mode: "verification_required", effective_at: Time.current, reason_code: "security_incident",
      principal_public_id: actor.public_id, applied_by_operator_public_id: operator.public_id,
    )
    the_case.build_principal_effect(
      principal_public_id: actor.public_id, access_blocking: true,
      effective_at: Time.current,
    )
    ready = Queue.new
    proceed = Queue.new
    worker = nil
    original = AdministrativeAccessLock.method(:lock!)
    pause_lock =
      lambda do |**args, &block|
        ready << true
        proceed.pop
        original.call(**args, &block)
      end

    OpIdentityEventInvalidator.stub(:deliver, :applied) do
      AdministrativeAccessLock.stub(:lock!, pause_lock) do
        worker =
          Thread.new do
            EnforcementCaseApplyOperation.call(
              enforcement_case: the_case,
              actor_operator_public_id: operator.public_id,
            )
          end
        Timeout.timeout(10) { ready.pop }
        EnforcementCaseEndOperation.call(enforcement_case: OrgEnforcementCase.find(the_case.id), reason: "revoked")
        proceed << true
        Timeout.timeout(10) { worker.value }
      end
    end

    assert_predicate the_case.reload.ended_at, :present?
    assert_predicate actor.reload, :access_enabled?
    assert_not OrgIdentityAuthenticationEvent.exists?(actor_ref: actor.id.to_s)
  ensure
    proceed << true if proceed
    begin
      worker&.join(10)
    rescue StandardError
      # Preserve the test failure while still removing its synthetic records.
    end
    EnforcementEvent.where(case_public_id: the_case.public_id).delete_all if the_case&.persisted?
    AccountAccessEvent.where(account_type: "Operator", account_id: actor.id).delete_all if actor
    OrgIdentityAuthenticationEvent.where(actor_ref: actor.id.to_s).delete_all if actor
    OrgEnforcementPrincipalEffect.where(org_enforcement_case_id: the_case.id).delete_all if the_case&.persisted?
    the_case&.delete
    actor&.delete
    operator&.delete
  end

  test "an ended Case cannot apply a late principal lock" do
    actor = Client.create!(
      id: SecureRandom.random_number(1 << 60) + 1_000_000_000,
      security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE,
    )
    operator = Operator.create!(
      id: SecureRandom.random_number(1 << 60) + 1_000_000_000,
      security_mode_id: SecurityModeConfigurable::ADVANCED, status_id: OperatorStatus::ACTIVE,
    )
    the_case = AppEnforcementCase.new(
      kind: "security_lock", state: "draft", duration_mode: "indefinite", visibility: "visible",
      release_mode: "verification_required", effective_at: Time.current, reason_code: "security_incident",
      principal_public_id: actor.public_id, applied_by_operator_public_id: operator.public_id,
    )
    the_case.build_principal_effect(
      principal_public_id: actor.public_id, access_blocking: true,
      effective_at: Time.current,
    )
    ready = Queue.new
    proceed = Queue.new
    worker = nil
    original = AdministrativeAccessLock.method(:lock!)
    pause_lock =
      lambda do |**args, &block|
        ready << true
        proceed.pop
        original.call(**args, &block)
      end

    OpIdentityEventInvalidator.stub(:deliver, :applied) do
      AdministrativeAccessLock.stub(:lock!, pause_lock) do
        worker =
          Thread.new do
            EnforcementCaseApplyOperation.call(
              enforcement_case: the_case,
              actor_operator_public_id: operator.public_id,
            )
          end
        Timeout.timeout(10) { ready.pop }
        EnforcementCaseEndOperation.call(enforcement_case: AppEnforcementCase.find(the_case.id), reason: "revoked")
        proceed << true
        Timeout.timeout(10) { worker.value }
      end
    end

    assert_predicate the_case.reload.ended_at, :present?
    assert_predicate actor.reload, :access_enabled?
    assert_not AppIdentityAuthenticationEvent.exists?(actor_ref: actor.id.to_s)
  ensure
    proceed << true if proceed
    begin
      worker&.join(10)
    rescue StandardError
      # Preserve the test failure while still removing its synthetic records.
    end
    EnforcementEvent.where(case_public_id: the_case.public_id).delete_all if the_case&.persisted?
    AccountAccessEvent.where(account_type: "Client", account_id: actor.id).delete_all if actor
    AppIdentityAuthenticationEvent.where(actor_ref: actor.id.to_s).delete_all if actor
    AppEnforcementPrincipalEffect.where(app_enforcement_case_id: the_case.id).delete_all if the_case&.persisted?
    the_case&.delete
    actor&.delete
    operator&.delete
  end

  test "Case end waits for the committed principal lock and then releases it" do
    actor = Client.create!(
      id: SecureRandom.random_number(1 << 60) + 1_000_000_000,
      security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE,
    )
    operator = Operator.create!(
      id: SecureRandom.random_number(1 << 60) + 1_000_000_000,
      security_mode_id: SecurityModeConfigurable::ADVANCED, status_id: OperatorStatus::ACTIVE,
    )
    the_case = AppEnforcementCase.new(
      kind: "security_lock", state: "draft", duration_mode: "indefinite", visibility: "visible",
      release_mode: "verification_required", effective_at: Time.current, reason_code: "security_incident",
      principal_public_id: actor.public_id, applied_by_operator_public_id: operator.public_id,
    )
    the_case.build_principal_effect(
      principal_public_id: actor.public_id, access_blocking: true,
      effective_at: Time.current,
    )
    locked = Queue.new
    proceed = Queue.new
    end_ready = Queue.new
    source_visible = Queue.new
    worker = ending = nil
    paused = false
    observer =
      lambda do |_name, _start, _finish, _id, event|
        next unless Thread.current == worker && !paused && event.fetch(:sql).match?(/\A\s*UPDATE\s+"clients"/i)

        paused = true
        locked << Client.lease_connection.select_value("SELECT pg_backend_pid()").to_i
        proceed.pop
      end

    inspect_delivery =
      lambda do |event:|
        reader =
          Thread.new do
            AppIdentityAuthenticationEvent.connection_pool.with_connection(prevent_permanent_checkout: true) do
              AppIdentityAuthenticationEvent.exists?(id: event.id)
            end
          end
        source_visible << Timeout.timeout(10) { reader.value }
        :applied
      end
    OpIdentityEventInvalidator.stub(:deliver, inspect_delivery) do
      ActiveSupport::Notifications.subscribed(observer, "sql.active_record") do
        worker =
          Thread.new do
            EnforcementCaseApplyOperation.call(
              enforcement_case: the_case,
              actor_operator_public_id: operator.public_id,
            )
          end
        worker_pid = Timeout.timeout(10) { locked.pop }
        ending =
          Thread.new do
            AppEnforcementCase.connection_pool.with_connection(prevent_permanent_checkout: true) do |connection|
              end_ready << connection.select_value("SELECT pg_backend_pid()").to_i
              EnforcementCaseEndOperation.call(
                enforcement_case: AppEnforcementCase.find(the_case.id),
                reason: "revoked",
              )
            end
          end
        ending_pid = Timeout.timeout(10) { end_ready.pop }
        Timeout.timeout(10) do
          loop do
            waiting =
              AppEnforcementCase.uncached do
                AppEnforcementCase.lease_connection.select_value(
                  "SELECT #{Integer(worker_pid)} = ANY(pg_blocking_pids(#{Integer(ending_pid)}))",
                )
              end
            break if waiting

            Thread.pass
          end
        end
        proceed << true
        Timeout.timeout(10) { worker.value }

        assert Timeout.timeout(10) { ending.value }
      end
    end

    assert_predicate the_case.reload.ended_at, :present?
    assert_predicate actor.reload, :access_enabled?
    assert Timeout.timeout(10) { source_visible.pop }, "the Source event must commit before OP delivery"
  ensure
    proceed << true if proceed
    [worker, ending].compact.each do |thread|
      begin
        thread.join(10)
      rescue StandardError
        # Preserve the test failure while still removing its synthetic records.
      end
    end
    EnforcementEvent.where(case_public_id: the_case.public_id).delete_all if the_case&.persisted?
    AccountAccessEvent.where(account_type: "Client", account_id: actor.id).delete_all if actor
    AppIdentityAuthenticationEvent.where(actor_ref: actor.id.to_s).delete_all if actor
    AppEnforcementPrincipalEffect.where(app_enforcement_case_id: the_case.id).delete_all if the_case&.persisted?
    the_case&.delete
    actor&.delete
    operator&.delete
  end

  test "a Case end waits for in-flight reconciliation and stays ended on a later scan" do
    actor = Client.create!(
      id: SecureRandom.random_number(1 << 60) + 1_000_000_000,
      security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE,
    )
    the_case = AppEnforcementCase.create!(
      kind: "security_lock", state: "active", duration_mode: "indefinite", visibility: "visible",
      release_mode: "verification_required", effective_at: Time.current, reason_code: "security_incident",
      principal_public_id: actor.public_id, applied_by_operator_public_id: "race-test-operator",
    )
    started = Queue.new
    proceed = Queue.new
    end_ready = Queue.new
    worker = ending = nil
    paused = false
    observer =
      lambda do |_name, _start, _finish, _id, event|
        next unless Thread.current == worker && !paused &&
          event.fetch(:sql).match?(/\A\s*UPDATE\s+"app_enforcement_cases"/i)

        paused = true
        started << AppEnforcementCase.lease_connection.select_value("SELECT pg_backend_pid()").to_i
        proceed.pop
      end

    ActiveSupport::Notifications.subscribed(observer, "sql.active_record") do
      worker = Thread.new { EnforcementReconciliationJob.perform_now }
      worker_pid = Timeout.timeout(10) { started.pop }
      ending =
        Thread.new do
          AppEnforcementCase.connection_pool.with_connection(prevent_permanent_checkout: true) do |connection|
            end_ready << connection.select_value("SELECT pg_backend_pid()").to_i
            EnforcementCaseEndOperation.call(
              enforcement_case: AppEnforcementCase.find(the_case.id),
              reason: "revoked",
            )
          end
        ensure
          ActiveRecord::Base.connection_handler.clear_active_connections!
        end
      ending_pid = Timeout.timeout(10) { end_ready.pop }
      Timeout.timeout(10) do
        loop do
          waiting =
            AppEnforcementCase.uncached do
              AppEnforcementCase.lease_connection.select_value(
                "SELECT #{Integer(worker_pid)} = ANY(pg_blocking_pids(#{Integer(ending_pid)}))",
              )
            end
          break if waiting

          Thread.pass
        end
      end
      proceed << true
      Timeout.timeout(10) { worker.value }

      assert Timeout.timeout(10) { ending.value }
    end

    the_case.reload

    assert_predicate the_case.ended_at, :present?
    assert_operator the_case.sessions_revoked_at, :<=, the_case.ended_at
    assert the_case.audit_event_recorded?("revocation_reconciled")
    assert the_case.audit_event_recorded?("ended")
    EnforcementReconciliationJob.perform_now

    assert_equal 1,
                 EnforcementEvent.where(case_public_id: the_case.public_id, event_type: "revocation_reconciled").count
  ensure
    proceed << true if proceed
    [worker, ending].compact.each do |thread|
      begin
        thread.join(10)
      rescue StandardError
        # Preserve the test failure while still removing its synthetic records.
      end
    end
    EnforcementEvent.where(case_public_id: the_case.public_id).delete_all if the_case
    the_case&.delete
    actor&.delete
  end

  test "a Case ended after selection is not reconciled as active" do
    actor = Client.create!(
      id: SecureRandom.random_number(1 << 60) + 1_000_000_000,
      security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE,
    )
    the_case = AppEnforcementCase.create!(
      kind: "security_lock", state: "active", duration_mode: "indefinite", visibility: "visible",
      release_mode: "verification_required", effective_at: Time.current, reason_code: "security_incident",
      principal_public_id: actor.public_id, applied_by_operator_public_id: "race-test-operator",
    )
    selected = Queue.new
    proceed = Queue.new
    worker = nil
    paused = false
    observer =
      lambda do |_name, _start, _finish, _id, event|
        sql = event.fetch(:sql)
        next unless Thread.current == worker && !paused && sql.match?(/\ASELECT\s+"app_enforcement_cases"\.\*/i)

        paused = true
        selected << true
        proceed.pop
      end

    ActiveSupport::Notifications.subscribed(observer, "sql.active_record") do
      worker = Thread.new { EnforcementReconciliationJob.perform_now }
      Timeout.timeout(10) { selected.pop }
      EnforcementCaseEndOperation.call(enforcement_case: the_case, reason: "revoked")
      proceed << true
      Timeout.timeout(10) { worker.value }
    end

    assert_predicate the_case.reload.ended_at, :present?
    assert_nil the_case.sessions_revoked_at
    assert_not the_case.audit_event_recorded?("revocation_reconciled")
  ensure
    proceed << true if proceed
    begin
      worker&.join(10)
    rescue StandardError
      # Preserve the failure while still removing this test's synthetic records.
    end
    EnforcementEvent.where(case_public_id: the_case.public_id).delete_all if the_case
    the_case&.delete
    actor&.delete
  end
end
