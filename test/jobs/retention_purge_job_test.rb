# typed: false
# frozen_string_literal: true

require "test_helper"
require_relative "../support/avatar_test_factory"
# require "helpers/global_test_support"

class RetentionPurgeJobTest < ActiveJob::TestCase
  teardown { Flipper.disable(RetentionPurgeJob::FEATURE_NAME) }

  test "set-based Avatar purge cascades through encrypted moniker history" do
    handle = Handle.create!(
      handle: "purge-avatar-#{SecureRandom.hex(4)}",
      cooldown_until: Time.current,
      is_system: false,
    )
    avatar = AvatarTestFactory.create!(
      moniker: "Purge",
      capability: AvatarCapability.find_by!(id: AvatarCapability::NORMAL),
      active_handle: handle,
    )
    former_moniker = avatar.avatar_monikers.create!(
      moniker: "Former",
      valid_from: Time.utc(2024, 1, 1),
      valid_to: Time.utc(2025, 1, 1),
    )
    current_moniker = avatar.current_avatar_moniker
    avatar.update_columns(purge_eligible_at: 1.hour.ago)

    assert_difference -> { Avatar.count }, -1 do
      assert_difference -> { AvatarMoniker.count }, -2 do
        RetentionPurgeJob.perform_now
      end
    end

    assert_not Avatar.exists?(avatar.id)
    assert_not AvatarMoniker.exists?(former_moniker.id)
    assert_not AvatarMoniker.exists?(current_moniker.id)
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

  test "anonymizes account records where purge_eligible_at is in the past" do
    user_to_purge = Client.create!(public_id: "purge_#{SecureRandom.uuid}".chars.first(16).join, status_id: ClientStatus::ACTIVE)
    user_to_keep = Client.create!(public_id: "keep_#{SecureRandom.uuid}".chars.first(16).join, status_id: ClientStatus::ACTIVE)

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
    user = Client.create!(public_id: "puser_#{SecureRandom.uuid}".chars.first(16).join, status_id: ClientStatus::ACTIVE)
    operator_due = Operator.create!
    operator_pending = Operator.create!

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
    user = Client.create!(public_id: "iuser_#{SecureRandom.uuid}".chars.first(16).join, status_id: ClientStatus::ACTIVE)
    operator = Operator.create!
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
    user = Client.create!(status_id: ClientStatus::UNVERIFIED_WITH_SIGN_UP)
    email = ClientEmail.create!(
      user: user,
      raw_address: "retention-cleanup-#{SecureRandom.hex(6)}@example.com",
      confirm_policy: true,
      user_email_status_id: ClientEmailStatus::UNVERIFIED_WITH_SIGN_UP,
    )
    cycle = ClientSignUpFlow.create!(
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
    client = Client.create!(public_id: "block_#{SecureRandom.uuid}".chars.first(16).join, status_id: ClientStatus::ACTIVE)
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
    EnforcementCaseApplyOperation.call(enforcement_case: the_case)

    assert_no_difference -> { Client.count } do
      RetentionPurgeJob.perform_now
    end

    assert Client.exists?(client.id)
    assert_nil client.reload.terminated_at
  end

  test "purge excludes an operator blocked by an in-force withdrawal_purge_blocked Principal Effect from the " \
       "batch delete" do
    blocked_operator = Operator.create!
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
    EnforcementCaseApplyOperation.call(enforcement_case: the_case)

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
    user = Client.create!(public_id: "suser_#{SecureRandom.uuid}".chars.first(16).join, status_id: ClientStatus::ACTIVE)
    operator_due = Operator.create!
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
    operator_due = Operator.create!
    operator_due.update_columns(discard_at: 1.hour.ago, purge_eligible_at: 1.hour.ago)

    Flipper.enable(RetentionPurgeJob::FEATURE_NAME)
    RetentionPurgeJob.perform_now

    assert Operator.exists?(operator_due.id)

    Flipper.disable(RetentionPurgeJob::FEATURE_NAME)
    RetentionPurgeJob.perform_now

    assert_not Operator.exists?(operator_due.id)
  end
end
