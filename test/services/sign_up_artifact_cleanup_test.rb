# typed: false
# frozen_string_literal: true

require "test_helper"
require "support/external_identity_test_helper"

class SignUpArtifactCleanupTest < ActiveSupport::TestCase
  include ExternalIdentityTestHelper

  setup do
    ClientStatus.ensure_defaults!
    ClientMfaLevel.ensure_defaults!
    ClientMfaStatus.ensure_defaults!
    ClientVisibility.ensure_defaults!
    ClientSignUpFlowStatus.ensure_defaults!
    ClientSignUpFlowCleanupStatus.ensure_defaults!
    ClientEmailStatus.ensure_defaults!
    ClientTelephoneStatus.ensure_defaults!
    ClientPasskeyStatus.ensure_defaults!

    VisitorStatus.ensure_defaults!
    VisitorMfaLevel.ensure_defaults!
    VisitorMfaStatus.ensure_defaults!
    VisitorVisibility.ensure_defaults!
    VisitorSignUpFlowStatus.ensure_defaults!
    VisitorSignUpFlowCleanupStatus.ensure_defaults!
    VisitorEmailStatus.ensure_defaults!
    VisitorTelephoneStatus.ensure_defaults!
    VisitorPasskeyStatus.ensure_defaults!
  end

  test "returns unsupported cycles unchanged" do
    cycle = Struct.new(:cleanup_status_id) do
      def has_attribute?(_name)
        false
      end
    end.new(nil)

    result = SignUpArtifactCleanup.call(cycle: cycle)

    assert_same cycle, result
  end

  test "returns completed cycles unchanged" do
    cycle = build_client_cycle(
      cleanup_status_id: ClientSignUpFlowCleanupStatus::COMPLETED,
      status_id: ClientSignUpFlowStatus::CANCELLED,
      entry_method: "google",
    )

    result = SignUpArtifactCleanup.call(cycle: cycle)

    assert_same cycle, result
    assert_equal ClientSignUpFlowCleanupStatus::COMPLETED, cycle.reload.cleanup_status_id
    assert_nil cycle.cleanup_completed_at
  end

  test "schedules client social identity cleanup for google and apple" do
    now = Time.current.change(usec: 0)

    %w(google apple).each do |provider|
      user = Client.create!(status_id: ClientStatus::UNVERIFIED_WITH_SIGN_UP)
      identity = create_active_external_identity(
        client: user, provider: provider,
        subject: "cleanup-#{provider}-#{SecureRandom.hex(4)}",
      )
      cycle = build_client_cycle(
        principal_id: user.id,
        status_id: ClientSignUpFlowStatus::CANCELLED,
        cleanup_status_id: ClientSignUpFlowCleanupStatus::PENDING,
        entry_method: provider,
        social_provider: provider,
        pending_contact_type: "social_identity",
        pending_contact_id: identity.id,
      )

      SignUpArtifactCleanup.call(cycle: cycle, now: now)

      assert_equal ClientSignUpFlowCleanupStatus::COMPLETED, cycle.reload.cleanup_status_id
      assert_not ClientExternalIdentity.exists?(identity.id)
      assert_operator user.reload.discard_at, :>=, now
    end
  end

  test "schedules visitor email cleanup and actor retention" do
    now = Time.current.change(usec: 0)
    visitor = Visitor.create!(status_id: VisitorStatus::ACTIVE, visibility_id: VisitorVisibility::VISITOR)
    email = VisitorEmail.create!(
      visitor: visitor,
      address: "cleanup-#{SecureRandom.hex(4)}@example.com",
      confirm_policy: true,
      visitor_email_status_id: VisitorEmailStatus::UNVERIFIED_WITH_SIGN_UP,
    )
    cycle = build_visitor_cycle(
      principal_id: visitor.id,
      status_id: VisitorSignUpFlowStatus::CANCELLED,
      cleanup_status_id: VisitorSignUpFlowCleanupStatus::PENDING,
      pending_contact_type: "email",
      pending_contact_id: email.id,
    )

    SignUpArtifactCleanup.call(cycle: cycle, now: now)

    assert_equal VisitorSignUpFlowCleanupStatus::COMPLETED, cycle.reload.cleanup_status_id
    assert_equal VisitorEmailStatus::DELETED, email.reload.visitor_email_status_id
    assert_operator email.reload.discard_at, :>=, now
    assert_operator email.reload.purge_eligible_at, :>, email.reload.discard_at
    assert_operator visitor.reload.discard_at, :>=, now
  end

  test "cleanup_pending_for claims one eligible cycle and skips missing statuses" do
    claimed_cycle = FakeCleanupCycle.new(cleanup_attempts_count: 9)
    cycle_class = FakeCleanupCycleClass.new(claimed_cycle)
    now = Time.current.change(usec: 0)

    SignUpArtifactCleanup.cleanup_pending_for(cycle_class, now: now, batch_size: 2)

    assert_operator cycle_class.where_calls.size, :>=, 2
    assert_operator claimed_cycle.updates.size, :>=, 2
    assert_equal 10, claimed_cycle.cleanup_attempts_count
    assert_equal "completed_cleanup", claimed_cycle.cleanup_status_id
    assert_equal now, claimed_cycle.cleanup_completed_at
    assert_nil claimed_cycle.cleanup_error_code
  end

  test "call marks cleanup failed when dependent retention raises" do
    now = Time.current.change(usec: 0)
    cycle = build_client_cycle(
      principal_id: 0,
      status_id: ClientSignUpFlowStatus::CANCELLED,
      cleanup_status_id: ClientSignUpFlowCleanupStatus::PENDING,
    )
    service = SignUpArtifactCleanup.new(cycle: cycle, now: now)

    service.stub(:schedule_dependent_retention!, -> { raise ActiveRecord::ActiveRecordError, "boom" }) do
      service.call
    end

    assert_equal ClientSignUpFlowCleanupStatus::FAILED, cycle.reload.cleanup_status_id
    assert_equal now, cycle.cleanup_attempted_at
    assert_match(/ActiveRecord::ActiveRecordError: boom/, cycle.cleanup_error_code)
  end

  test "client pending telephone cleanup updates the phone and pending passkey" do
    now = Time.current.change(usec: 0)
    user = Client.create!(status_id: ClientStatus::UNVERIFIED_WITH_SIGN_UP)
    telephone = ClientTelephone.create!(
      user: user,
      raw_number: "+12345670001",
      confirm_policy: true,
      confirm_using_mfa: true,
      user_telephone_status_id: ClientTelephoneStatus::UNVERIFIED_WITH_SIGN_UP,
    )
    pending_passkey = ClientPasskey.new(
      user: user,
      webauthn_id: "pending-#{SecureRandom.hex(8)}",
      external_id: SecureRandom.uuid,
      public_key: "pending-public-key",
      sign_count: 0,
      description: "pending passkey",
      status_id: ClientPasskeyStatus::ACTIVE,
    )
    pending_passkey.save!(validate: false)
    cycle = build_client_cycle(
      principal_id: user.id,
      status_id: ClientSignUpFlowStatus::CANCELLED,
      cleanup_status_id: ClientSignUpFlowCleanupStatus::PENDING,
      entry_method: "telephone",
      pending_contact_type: "telephone",
      pending_contact_id: telephone.id,
      pending_passkey_registration_id: pending_passkey.id,
    )

    SignUpArtifactCleanup.call(cycle: cycle, now: now)

    assert_equal ClientSignUpFlowCleanupStatus::COMPLETED, cycle.reload.cleanup_status_id
    assert_equal ClientTelephoneStatus::DELETED, telephone.reload.user_telephone_status_id
    assert_equal ClientPasskeyStatus::DELETED, pending_passkey.reload.status_id
    assert_operator user.reload.discard_at, :>=, now
  end

  test "visitor pending telephone cleanup updates the phone and pending passkey" do
    now = Time.current.change(usec: 0)
    visitor = Visitor.create!(status_id: VisitorStatus::ACTIVE, visibility_id: VisitorVisibility::VISITOR)
    telephone = VisitorTelephone.create!(
      visitor: visitor,
      raw_number: "+12345670002",
      confirm_policy: true,
      visitor_telephone_status_id: VisitorTelephoneStatus::UNVERIFIED_WITH_SIGN_UP,
    )
    pending_passkey = VisitorPasskey.new(
      visitor: visitor,
      webauthn_id: "pending-#{SecureRandom.hex(8)}",
      external_id: SecureRandom.uuid,
      public_key: "pending-public-key",
      sign_count: 0,
      description: "pending passkey",
      status_id: VisitorPasskeyStatus::ACTIVE,
    )
    pending_passkey.save!(validate: false)
    cycle = build_visitor_cycle(
      principal_id: visitor.id,
      status_id: VisitorSignUpFlowStatus::CANCELLED,
      cleanup_status_id: VisitorSignUpFlowCleanupStatus::PENDING,
      entry_method: "telephone",
      pending_contact_type: "telephone",
      pending_contact_id: telephone.id,
      pending_passkey_registration_id: pending_passkey.id,
    )

    SignUpArtifactCleanup.call(cycle: cycle, now: now)

    assert_equal VisitorSignUpFlowCleanupStatus::COMPLETED, cycle.reload.cleanup_status_id
    assert_equal VisitorTelephoneStatus::DELETED, telephone.reload.visitor_telephone_status_id
    assert_equal VisitorPasskeyStatus::DELETED, pending_passkey.reload.status_id
    assert_operator visitor.reload.discard_at, :>=, now
  end

  private

  def build_client_cycle(attrs = {})
    ClientSignUpFlow.create!(
      {
        principal_id: 123,
        status_id: ClientSignUpFlowStatus::CHECKPOINT_PENDING,
        step: "checkpoint",
        nonce_digest: ClientSignUpFlow.digest_nonce("nonce"),
        issued_at: Time.current,
        expires_at: 15.minutes.from_now,
        entry_method: "google",
      }.merge(attrs),
    )
  end

  def build_visitor_cycle(attrs = {})
    VisitorSignUpFlow.create!(
      {
        principal_id: 456,
        status_id: VisitorSignUpFlowStatus::CHECKPOINT_PENDING,
        step: "checkpoint",
        nonce_digest: VisitorSignUpFlow.digest_nonce("nonce"),
        issued_at: Time.current,
        expires_at: 15.minutes.from_now,
        entry_method: "email",
      }.merge(attrs),
    )
  end

  class FakeCleanupCycleClass
    attr_reader :claimed_cycle, :transaction_count, :where_calls

    def initialize(claimed_cycle)
      @claimed_cycle = claimed_cycle
      @transaction_count = 0
      @where_calls = []
    end

    def column_names
      %w(cleanup_attempts_count)
    end

    def cleanup_status_id_for(name)
      "#{name}_cleanup"
    end

    def status_id_for(name)
      case name
      when "CANCELLED"
        "cancelled_status"
      when "FAILED"
        "failed_status"
      else
        raise KeyError, name
      end
    end

    def connection_class_for_self
      self
    end

    def connected_to(role:)
      raise ArgumentError, "writing role required" unless role == :writing

      yield
    end

    def transaction
      @transaction_count += 1
      yield
    end

    def where(*args, **kwargs)
      @where_calls << [args, kwargs]
      self
    end

    def order(*)
      self
    end

    def limit(*)
      self
    end

    def lock(*)
      self
    end

    def first
      cycle = @claimed_cycle
      @claimed_cycle = nil
      cycle
    end
  end

  class FakeCleanupCycle
    attr_accessor :cleanup_attempts_count, :cleanup_status_id, :cleanup_attempted_at,
                  :cleanup_completed_at, :cleanup_error_code
    attr_reader :updates

    def initialize(cleanup_attempts_count:)
      @cleanup_attempts_count = cleanup_attempts_count
      @updates = []
    end

    def has_attribute?(name)
      %i(cleanup_status_id cleanup_attempts_count).include?(name)
    end

    def with_cycle_lock
      yield
    end

    def reload
      self
    end

    def cleanup_completed?
      false
    end

    def cleanup_status_id_for(name)
      "#{name}_cleanup"
    end

    def update!(attrs)
      @updates << attrs
      self.cleanup_attempts_count = attrs[:cleanup_attempts_count] if attrs.key?(:cleanup_attempts_count)
      self.cleanup_status_id = attrs[:cleanup_status_id] if attrs.key?(:cleanup_status_id)
      self.cleanup_attempted_at = attrs[:cleanup_attempted_at] if attrs.key?(:cleanup_attempted_at)
      self.cleanup_completed_at = attrs[:cleanup_completed_at] if attrs.key?(:cleanup_completed_at)
      self.cleanup_error_code = attrs[:cleanup_error_code] if attrs.key?(:cleanup_error_code)
      self
    end
  end
end
