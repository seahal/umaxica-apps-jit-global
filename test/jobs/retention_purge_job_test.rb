# typed: false
# frozen_string_literal: true

require "test_helper"
require_relative "../support/avatar_test_factory"
# require "helpers/global_test_support"

class RetentionPurgeJobTest < ActiveJob::TestCase
  setup do
    ENV["APP_SECRET_PURGE_DELAY_SECONDS"] = "86400"
    ENV["APP_SECRET_OUTBOX_RETENTION_SECONDS"] = "604800"
  end

  teardown { Flipper.disable(RetentionPurgeJob::FEATURE_NAME) }

  test "Avatar purge deferral preserves encrypted moniker history" do
    handle = Handle.create!(
      handle: "purge-avatar-#{SecureRandom.hex(4)}",
      cooldown_until: Time.current,
      is_system: false,
    )
    avatar = AvatarTestFactory.create!(
      moniker: "Purge",
      capability: AvatarCapability.find(AvatarCapability::NORMAL),
      active_handle: handle,
    )
    former_moniker = avatar.avatar_monikers.create!(
      moniker: "Former",
      valid_from: Time.utc(2024, 1, 1),
      valid_to: Time.utc(2025, 1, 1),
    )
    current_moniker = AvatarMoniker.current.find_by!(avatar_id: avatar.id)
    avatar.update_columns(purge_eligible_at: 1.hour.ago)

    assert_no_difference -> { Avatar.count } do
      assert_no_difference -> { AvatarMoniker.count } do
        RetentionPurgeJob.perform_now
      end
    end

    assert Avatar.exists?(avatar.id)
    assert AvatarMoniker.exists?(former_moniker.id)
    assert AvatarMoniker.exists?(current_moniker.id)
    assert AvatarPurgeDeferral.exists?(avatar_id: avatar.id, reason_code: "ownership_history")
  end

  test "rejects a retention batch size outside the bounded execution range" do
    error =
      assert_raises(ArgumentError) do
        RetentionPurgeJob.perform_now(batch_size: 501)
      end

    assert_equal "batch_size must be between 1 and 500", error.message
  end

  test "rejects fractional retention batch sizes instead of truncating them" do
    error =
      assert_raises(ArgumentError) do
        RetentionPurgeJob.perform_now(batch_size: 1.5)
      end

    assert_equal "batch_size must be between 1 and 500", error.message
  end

  test "rejects zero negative and missing retention batch sizes" do
    [0, -1, nil].each do |batch_size|
      error =
        assert_raises(ArgumentError) do
          RetentionPurgeJob.perform_now(batch_size: batch_size)
        end

      assert_equal "batch_size must be between 1 and 500", error.message
    end
  end

  test "accepts both inclusive retention batch-size boundaries before work" do
    FeatureFlags.stub(:enabled?, true) do
      [1, 500].each do |batch_size|
        assert_nothing_raised { RetentionPurgeJob.perform_now(batch_size:) }
      end
    end
  end

  test "accepts an integral string batch size through the public job interface" do
    FeatureFlags.stub(:enabled?, true) do
      # The validation is exercised before any destructive work is reached. The kill-switch stub
      # keeps this boundary test independent of retention rows while still using the public job
      # entrypoint.
      assert_nothing_raised { RetentionPurgeJob.perform_now(batch_size: "1") }
    end
  end

  test "continues after one retained model fails and re-raises the failure" do
    processed = []
    reported = []
    first_model = RetentionPurgeJob::RETAINABLE_MODELS.first
    failure = ActiveRecord::RecordNotDestroyed.new("retention target failed")
    job = RetentionPurgeJob.new

    SignUpArtifactCleanup.stub(:cleanup_pending!, nil) do
      ClientSecretIssuance.stub(:exists?, false) do
        ClientSecretCredential.stub(:exists?, false) do
          ClientSecretAuditOutbox.stub(:exists?, false) do
            job.stub(
              :purge_retained_model,
              lambda { |klass, batch_size:|
                processed << [klass, batch_size]
                raise failure if klass == first_model
              },
            ) do
              Rails.error.stub(:report, lambda { |error, **context| reported << [error, context] }) do
                assert_raises(ActiveRecord::RecordNotDestroyed) { job.perform(batch_size: 1) }
              end
            end
          end
        end
      end
    end

    assert_equal RetentionPurgeJob::RETAINABLE_MODELS.length, processed.length
    assert_equal failure, reported.fetch(0).fetch(0)
    assert_equal first_model.name, reported.fetch(0).fetch(1).fetch(:context).fetch(:retained_model)
  end

  test "reports orphan registration ids once without contact data and changes no registration state" do
    address = "stuck-report-#{SecureRandom.hex(6)}@example.com"
    client = Client.create!(
      public_id: PublicId.generate,
      security_mode_id: SecurityModeConfigurable::NORMAL,
      status_id: ClientStatus::UNVERIFIED_WITH_SIGN_UP,
    )
    email = ClientEmail.create!(
      user_id: client.id,
      address:,
      user_email_status_id: ClientEmailStatus::UNVERIFIED_WITH_SIGN_UP,
    )
    client_status_before = client.status_id
    email_status_before = email.user_email_status_id
    logged = []

    FeatureFlags.stub(:enabled?, true) do
      Rails.logger.stub(:warn, ->(_message) { }) do
        Rails.logger.stub(:info, ->(message) { logged << message }) do
          RetentionPurgeJob.perform_now
        end
      end
    end

    report_events =
      logged.filter_map do |message|
        event = JSON.parse(message.to_s)
        event if event["event"] == "sign_up.stuck_registrations.reported"
      rescue JSON::ParserError
        nil
      end

    assert_equal 1, report_events.length

    event = report_events.fetch(0)

    assert_equal "sign_up.stuck_registrations.reported", event.fetch("event")
    assert_equal 1, event.dig("data", "total_count")

    report = event.dig("data", "groups").fetch(0)

    assert_equal "app", report.fetch("surface")
    assert_equal "flow_missing", report.fetch("case")
    assert_equal 1, report.fetch("count")
    assert_equal client.public_id, report.dig("registrations", 0, "principal_public_id")
    assert_equal email.public_id, report.dig("registrations", 0, "contact_public_id")
    assert_not_includes report_events.fetch(0).to_json, address
    assert Client.exists?(client.id)
    assert_equal client_status_before, client.reload.status_id
    assert_equal email_status_before, email.reload.user_email_status_id
  end

  test "reports exhausted cleanup flow ids and attempt count in the structured event" do
    logged = []
    app_rows = [
      {
        surface: "app",
        case: "cleanup_attempts_exhausted",
        principal_public_id: "principal-public-id",
        contact_public_id: "contact-public-id",
        flow_public_id: "flow-public-id",
        cleanup_attempts_count: SignUpArtifactCleanup::MAX_CLEANUP_ATTEMPTS,
      },
    ]

    FeatureFlags.stub(:enabled?, true) do
      Rails.logger.stub(:warn, ->(_message) { }) do
        Rails.logger.stub(:info, ->(message) { logged << message }) do
          SignUpStuckRegistrationReportQuery.stub(
            :call,
            ->(surface:) { (surface == :app) ? app_rows : [] },
          ) do
            RetentionPurgeJob.perform_now
          end
        end
      end
    end

    report_event = logged.filter_map do |message|
      event = JSON.parse(message.to_s)
      event if event["event"] == "sign_up.stuck_registrations.reported"
    rescue JSON::ParserError
      nil
    end.fetch(0)
    report = report_event.dig("data", "groups").fetch(0)

    assert_equal 1, report.fetch("count")

    registration = report.fetch("registrations").fetch(0)

    assert_equal "principal-public-id", registration.fetch("principal_public_id")
    assert_equal "contact-public-id", registration.fetch("contact_public_id")
    assert_equal "flow-public-id", registration.fetch("flow_public_id")
    assert_equal SignUpArtifactCleanup::MAX_CLEANUP_ATTEMPTS, registration.fetch("cleanup_attempts_count")
  end

  test "logs query failures after cleanup and continues the retention job work" do
    events = []
    logged = []
    cleanup_completed = false
    job = RetentionPurgeJob.new

    SignUpArtifactCleanup.stub(
      :cleanup_pending!,
      lambda { |batch_size:|
        events << :cleanup
        cleanup_completed = batch_size == 1
      },
    ) do
      ClientSecretIssuance.stub(:exists?, false) do
        ClientSecretCredential.stub(:exists?, false) do
          ClientSecretAuditOutbox.stub(:exists?, false) do
            job.stub(
              :purge_retained_model,
              lambda { |klass, batch_size:|
                events << [:purge, klass, batch_size]
              },
            ) do
              SignUpStuckRegistrationReportQuery.stub(
                :call,
                lambda { |surface:|
                  events << [:query, surface]
                  raise ActiveRecord::QueryCanceled, "test query failure"
                },
              ) do
                Rails.logger.stub(:error, ->(message) { logged << message }) do
                  assert_nothing_raised { job.perform(batch_size: 1) }
                end
              end
            end
          end
        end
      end
    end

    assert cleanup_completed
    assert_equal RetentionPurgeJob::RETAINABLE_MODELS.length, events.count { |event| event.is_a?(Array) && event.first == :purge }
    last_purge = events.rindex { |event| event.is_a?(Array) && event.first == :purge }

    assert_operator events.index([:query, :app]), :>, last_purge
    assert_operator events.index([:query, :com]), :>, last_purge
    assert_equal 1, logged.length
    event = JSON.parse(logged.fetch(0))

    assert_equal "sign_up.stuck_registrations.report_failed", event.fetch("event")
    assert_equal ["app", "com"], event.dig("data", "failures").map { |failure| failure.fetch("surface") }
    assert event.dig("data", "failures").all? { |failure| failure.fetch("error_class") == "ActiveRecord::QueryCanceled" }
  end

  test "anonymizes account records where purge_eligible_at is in the past" do
    user_to_purge = Client.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL,
      public_id: PublicId.generate, status_id: ClientStatus::ACTIVE,
      created_at: 2.hours.ago,
    )
    user_to_keep = Client.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL, public_id: PublicId.generate,
      status_id: ClientStatus::ACTIVE,
    )

    user_to_purge.update_columns(discard_at: 1.hour.ago, purge_eligible_at: 1.hour.ago)
    user_to_keep.update_columns(discard_at: Retainable::SENTINEL, purge_eligible_at: Retainable::SENTINEL)

    assert_no_difference -> { Client.count } do
      RetentionPurgeJob.perform_now
    end

    assert_predicate user_to_purge.reload, :terminated?
    assert Client.exists?(user_to_keep.id)
    assert_nil user_to_keep.reload.terminated_at
  end

  # Staff (Operator) lifecycle and User (Client) withdrawal must NOT be
  # conflated by the purge worker. Clients are anonymized *in place*
  # (`terminated_at` set, row retained for referential history), while Operators
  # are *physically removed* via the set-based `purge_operators` path (no
  # `terminated_at` marker -- Staff has no withdrawal lifecycle). A regression
  # that routed Operators through `anonymize_accounts` (or Clients through
  # `purge_operators`) would silently corrupt one actor type's lifecycle.
  test "purge physically removes due operators but anonymizes due users in place" do
    user = Client.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL,
      public_id: PublicId.generate, status_id: ClientStatus::ACTIVE,
      created_at: 2.hours.ago,
    )
    operator_due = Operator.create!(security_mode_id: SecurityModeConfigurable::ADVANCED)
    operator_pending = Operator.create!(security_mode_id: SecurityModeConfigurable::ADVANCED)

    user.update_columns(discard_at: 1.hour.ago, purge_eligible_at: 1.hour.ago)
    operator_due.update_columns(discard_at: 1.hour.ago, purge_eligible_at: 1.hour.ago)
    operator_pending.update_columns(discard_at: Retainable::SENTINEL, purge_eligible_at: Retainable::SENTINEL)

    assert_difference -> { Operator.count }, -1 do
      assert_no_difference -> { Client.count } do
        RetentionPurgeJob.perform_now
      end
    end

    # User: retained but anonymized/terminated (User withdrawal lifecycle).
    assert Client.exists?(user.id)
    assert_predicate user.reload, :terminated?

    # Operator: physically deleted, never marked terminated (Staff lifecycle).
    assert_not Operator.exists?(operator_due.id)

    # Operator not yet due (purge_eligible_at = Infinity sentinel) must be untouched.
    assert Operator.exists?(operator_pending.id)
  end

  # Re-running the worker must be safe: already-anonymized users are skipped via
  # `where(terminated_at: nil)` and already-deleted operators are simply absent.
  test "purge is idempotent across repeated runs" do
    user = Client.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL,
      public_id: PublicId.generate, status_id: ClientStatus::ACTIVE,
      created_at: 2.hours.ago,
    )
    operator = Operator.create!(security_mode_id: SecurityModeConfigurable::ADVANCED)
    user.update_columns(discard_at: 1.hour.ago, purge_eligible_at: 1.hour.ago)
    operator.update_columns(discard_at: 1.hour.ago, purge_eligible_at: 1.hour.ago)

    RetentionPurgeJob.perform_now
    terminated_at_after_first = user.reload.terminated_at

    assert_nothing_raised { RetentionPurgeJob.perform_now }

    assert Client.exists?(user.id)
    assert_predicate user.reload, :terminated?
    assert_equal terminated_at_after_first, user.reload.terminated_at,
                 "terminated_at must not be rewritten on subsequent runs"
    assert_not Operator.exists?(operator.id)
  end

  test "purges visitor occurrences where purge_eligible_at is in the past" do
    VisitorOccurrenceStatus.ensure_defaults!
    occurrence_to_purge = VisitorOccurrence.create!(body: "purge-#{SecureRandom.hex(8)}")
    occurrence_to_keep = VisitorOccurrence.create!(body: "keep-#{SecureRandom.hex(8)}")

    occurrence_to_purge.update_columns(discard_at: 1.hour.ago, purge_eligible_at: 1.hour.ago)
    occurrence_to_keep.update_columns(discard_at: Retainable::SENTINEL, purge_eligible_at: Retainable::SENTINEL)

    assert_difference -> { VisitorOccurrence.count }, -1 do
      RetentionPurgeJob.perform_now
    end

    assert_not VisitorOccurrence.exists?(occurrence_to_purge.id)
    assert VisitorOccurrence.exists?(occurrence_to_keep.id)
  end

  test "runs sign up artifact cleanup before purging signup cycles" do
    ClientSignUpFlowStatus::DEFAULTS.each do |id|
      ClientSignUpFlowStatus.find_or_create_by!(id: id)
    end
    ClientSignUpFlowCleanupStatus::DEFAULTS.each do |id|
      ClientSignUpFlowCleanupStatus.find_or_create_by!(id: id)
    end
    user = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::UNVERIFIED_WITH_SIGN_UP)
    email = ClientEmail.create!(
      user: user,
      raw_address: "retention-cleanup-#{SecureRandom.hex(6)}@example.com",
      confirm_policy: true,
      user_email_status_id: ClientEmailStatus::UNVERIFIED_WITH_SIGN_UP,
    )
    cycle = ClientSignUpFlow.create!(
      auth_admission_binding: SignUpAdmissionTestFactory.binding_for!(ClientSignUpFlow),
      principal_id: user.id,
      status_id: ClientSignUpFlowStatus::CANCELLED,
      step: "cancelled",
      nonce_digest: ClientSignUpFlow.digest_nonce("nonce"),
      issued_at: 20.minutes.ago,
      expires_at: 5.minutes.ago,
      entry_method: "email",
      pending_contact_type: "email",
      pending_contact_id: email.id,
      cleanup_status_id: ClientSignUpFlowCleanupStatus::PENDING,
    )
    cycle.update_columns(discard_at: cycle.created_at, purge_eligible_at: cycle.created_at)

    RetentionPurgeJob.perform_now

    assert_not ClientSignUpFlow.exists?(cycle.id)
    assert_equal ClientEmailStatus::DELETED, email.reload.user_email_status_id
    assert_operator email.discard_at, :<=, Time.current
  end

  test "purges a COM sign-up Flow after cleanup is complete" do
    VisitorSignUpFlowStatus.ensure_defaults!
    VisitorSignUpFlowCleanupStatus.ensure_defaults!
    flow = VisitorSignUpFlow.create!(
      auth_admission_binding: SignUpAdmissionTestFactory.binding_for!(VisitorSignUpFlow),
      status_id: VisitorSignUpFlowStatus::CANCELLED,
      step: "cancelled",
      nonce_digest: VisitorSignUpFlow.digest_nonce("retention-complete-com"),
      issued_at: 2.hours.ago,
      expires_at: 90.minutes.ago,
      entry_method: "email",
      cleanup_status_id: VisitorSignUpFlowCleanupStatus::COMPLETED,
      cleanup_completed_at: 80.minutes.ago,
    )
    flow.update_columns(discard_at: 2.hours.ago, purge_eligible_at: 1.hour.ago)

    RetentionPurgeJob.perform_now

    assert_not VisitorSignUpFlow.exists?(flow.id)
  end

  test "retains APP and COM capped sign-up Flows and reports them before cleanup completes" do
    ClientSignUpFlowStatus.ensure_defaults!
    ClientSignUpFlowCleanupStatus.ensure_defaults!
    VisitorSignUpFlowStatus.ensure_defaults!
    VisitorSignUpFlowCleanupStatus.ensure_defaults!
    app_client = Client.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL,
      status_id: ClientStatus::UNVERIFIED_WITH_SIGN_UP,
    )
    app_email = ClientEmail.create!(
      user: app_client,
      raw_address: "retention-cap-app-#{SecureRandom.hex(6)}@example.com",
      confirm_policy: true,
      user_email_status_id: ClientEmailStatus::UNVERIFIED_WITH_SIGN_UP,
    )
    app_flow = ClientSignUpFlow.create!(
      auth_admission_binding: SignUpAdmissionTestFactory.binding_for!(ClientSignUpFlow),
      principal_id: app_client.id,
      pending_contact_type: "email",
      pending_contact_id: app_email.id,
      entry_method: "email",
      status_id: ClientSignUpFlowStatus::CANCELLED,
      step: "cancelled",
      nonce_digest: ClientSignUpFlow.digest_nonce("retention-cap-app"),
      issued_at: 2.hours.ago,
      expires_at: 90.minutes.ago,
      cleanup_status_id: ClientSignUpFlowCleanupStatus::FAILED,
      cleanup_attempts_count: SignUpArtifactCleanup::MAX_CLEANUP_ATTEMPTS,
    )
    com_visitor = Visitor.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL,
      status_id: VisitorStatus::UNVERIFIED_WITH_SIGN_UP,
    )
    com_email = VisitorEmail.create!(
      visitor: com_visitor,
      raw_address: "retention-cap-com-#{SecureRandom.hex(6)}@example.com",
      confirm_policy: true,
      visitor_email_status_id: VisitorEmailStatus::UNVERIFIED_WITH_SIGN_UP,
    )
    com_flow = VisitorSignUpFlow.create!(
      auth_admission_binding: SignUpAdmissionTestFactory.binding_for!(VisitorSignUpFlow),
      principal_id: com_visitor.id,
      pending_contact_type: "email",
      pending_contact_id: com_email.id,
      entry_method: "email",
      status_id: VisitorSignUpFlowStatus::CANCELLED,
      step: "cancelled",
      nonce_digest: VisitorSignUpFlow.digest_nonce("retention-cap-com"),
      issued_at: 2.hours.ago,
      expires_at: 90.minutes.ago,
      cleanup_status_id: VisitorSignUpFlowCleanupStatus::FAILED,
      cleanup_attempts_count: SignUpArtifactCleanup::MAX_CLEANUP_ATTEMPTS,
    )
    [app_flow, com_flow].each do |flow|
      flow.update_columns(discard_at: 2.hours.ago, purge_eligible_at: 1.hour.ago)
    end
    logged = []

    Rails.logger.stub(:info, ->(message) { logged << message }) do
      RetentionPurgeJob.perform_now
    end

    assert ClientSignUpFlow.exists?(app_flow.id)
    assert VisitorSignUpFlow.exists?(com_flow.id)
    assert_equal ClientStatus::UNVERIFIED_WITH_SIGN_UP, app_client.reload.status_id
    assert_equal VisitorStatus::UNVERIFIED_WITH_SIGN_UP, com_visitor.reload.status_id
    assert_equal ClientEmailStatus::UNVERIFIED_WITH_SIGN_UP, app_email.reload.user_email_status_id
    assert_equal VisitorEmailStatus::UNVERIFIED_WITH_SIGN_UP, com_email.reload.visitor_email_status_id
    assert_equal SignUpArtifactCleanup::MAX_CLEANUP_ATTEMPTS, app_flow.reload.cleanup_attempts_count
    assert_equal SignUpArtifactCleanup::MAX_CLEANUP_ATTEMPTS, com_flow.reload.cleanup_attempts_count

    report_event = logged.filter_map do |message|
      event = JSON.parse(message.to_s)
      event if event["event"] == "sign_up.stuck_registrations.reported"
    rescue JSON::ParserError
      nil
    end.fetch(0)
    groups = report_event.dig("data", "groups").index_by { |group| group.fetch("surface") }

    assert_equal ["app", "com"], groups.keys.sort
    assert_equal "cleanup_attempts_exhausted", groups.fetch("app").fetch("case")
    assert_equal "cleanup_attempts_exhausted", groups.fetch("com").fetch("case")
    assert_equal app_flow.public_id, groups.dig("app", "registrations", 0, "flow_public_id")
    assert_equal com_flow.public_id, groups.dig("com", "registrations", 0, "flow_public_id")
    assert_not_includes report_event.to_json, app_email.address
    assert_not_includes report_event.to_json, com_email.address
  end

  test "retention purge registers client sign-up flows and tokens independently" do
    models = RetentionPurgeJob::RETAINABLE_MODELS

    assert_includes models, ClientSignUpFlow
    assert_includes models, ClientToken
  end

  test "retention purge registers visitor sign-up flows and tokens independently" do
    models = RetentionPurgeJob::RETAINABLE_MODELS

    assert_includes models, VisitorSignUpFlow
    assert_includes models, VisitorToken
  end

  # Every Retainable model must be registered with RetentionPurgeJob so the
  # worker actually purges its rows. Forgetting to add a new model is silent --
  # `purge_eligible_at` ticks past forever with no one cleaning up. Compare against
  # the Retainable.registry that models populate on `included`.
  test "all Retainable-including models are registered in RETAINABLE_MODELS" do
    # Force eager load so every Retainable include block runs and registers.
    Rails.application.eager_load!

    missing =
      (Retainable.registry - RetentionPurgeJob::RETAINABLE_MODELS).reject do |model|
        model.name.to_s.match?(/\A(?:CycleBaseTest|RetainableTest|SecretCredentialConcernTest)::/) ||
          !model.table_exists?
      end

    assert_empty missing,
                 "Models include Retainable but are absent from RetentionPurgeJob::RETAINABLE_MODELS -- " \
                 "rows in these tables will never be physically purged: #{missing.map(&:name).sort.join(", ")}"
  end

  test "purge skips a client blocked by an in-force principal_hard_delete_blocked Principal Effect" do
    client = Client.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL, public_id: PublicId.generate,
      status_id: ClientStatus::ACTIVE,
    )
    operator = operators(:one)
    client.update_columns(discard_at: 1.hour.ago, purge_eligible_at: 1.hour.ago)

    the_case = AppEnforcementCase.new(
      kind: "permanent_ban",
      duration_mode: "permanent",
      visibility: "visible",
      release_mode: "break_glass_only",
      effective_at: Time.current,
      reason_code: "abuse",
      principal_public_id: client.public_id,
      applied_by_operator_public_id: operator.public_id,
    )
    the_case.build_principal_effect(
      principal_public_id: client.public_id,
      principal_hard_delete_blocked: true,
      effective_at: Time.current,
    )
    EnforcementCaseApplyOperation.call(
      enforcement_case: the_case,
      actor_operator_public_id: the_case.applied_by_operator_public_id,
    )

    assert_no_difference -> { Client.count } do
      RetentionPurgeJob.perform_now
    end

    assert Client.exists?(client.id)
    assert_nil client.reload.terminated_at
  end

  test "purge excludes an operator blocked by an in-force withdrawal_purge_blocked Principal Effect from the " \
       "batch delete" do
    blocked_operator = Operator.create!(security_mode_id: SecurityModeConfigurable::ADVANCED)
    applying_operator = operators(:one)
    blocked_operator.update_columns(discard_at: 1.hour.ago, purge_eligible_at: 1.hour.ago)

    the_case = OrgEnforcementCase.new(
      kind: "permanent_ban",
      duration_mode: "permanent",
      visibility: "visible",
      release_mode: "break_glass_only",
      effective_at: Time.current,
      reason_code: "abuse",
      principal_public_id: blocked_operator.public_id,
      applied_by_operator_public_id: applying_operator.public_id,
      approved_by_operator_public_id: operators(:two).public_id,
    )
    the_case.build_principal_effect(
      principal_public_id: blocked_operator.public_id,
      withdrawal_purge_blocked: true,
      effective_at: Time.current,
    )
    EnforcementCaseApplyOperation.call(
      enforcement_case: the_case,
      actor_operator_public_id: the_case.applied_by_operator_public_id,
    )

    assert_no_difference -> { Operator.count } do
      RetentionPurgeJob.perform_now
    end

    assert Operator.exists?(blocked_operator.id)
  end

  # The kill switch is operational, not a retention rule: a suspended run must
  # leave every due row exactly as it found it, finish without raising (a raise
  # would requeue deliberately paused work), and stay catch-up safe so the next
  # unsuspended run completes the deletion.
  test "a suspended purge deletes nothing and is not an error" do
    Flipper.enable(RetentionPurgeJob::FEATURE_NAME)
    user = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, public_id: PublicId.generate, status_id: ClientStatus::ACTIVE)
    operator_due = Operator.create!(security_mode_id: SecurityModeConfigurable::ADVANCED)
    user.update_columns(discard_at: 1.hour.ago, purge_eligible_at: 1.hour.ago)
    operator_due.update_columns(discard_at: 1.hour.ago, purge_eligible_at: 1.hour.ago)

    assert_nothing_raised do
      assert_no_difference -> { Operator.count } do
        RetentionPurgeJob.perform_now
      end
    end

    assert Operator.exists?(operator_due.id)
    assert_nil user.reload.terminated_at
  end

  test "the next unsuspended run catches up on work skipped while suspended" do
    operator_due = Operator.create!(security_mode_id: SecurityModeConfigurable::ADVANCED)
    operator_due.update_columns(discard_at: 1.hour.ago, purge_eligible_at: 1.hour.ago)

    Flipper.enable(RetentionPurgeJob::FEATURE_NAME)
    RetentionPurgeJob.perform_now

    assert Operator.exists?(operator_due.id)

    Flipper.disable(RetentionPurgeJob::FEATURE_NAME)
    RetentionPurgeJob.perform_now

    assert_not Operator.exists?(operator_due.id)
  end
end
