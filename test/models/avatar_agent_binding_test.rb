# typed: false
# frozen_string_literal: true

require "test_helper"
require_relative "../support/avatar_test_factory"

class AvatarAgentBindingTest < ActiveSupport::TestCase
  setup do
    HandleStatus.ensure_defaults!
    OperatorIdentityState.ensure_defaults!
    AvatarCapability.find_or_create_by!(id: AvatarCapability::NORMAL)
    AvatarLifecycleState.find_or_create_by!(key: "active") do |state|
      state.title = "Active"
      state.sort_order = 10
      state.terminal = false if state.respond_to?(:terminal=)
    end
  end

  test "defaults public id and assigned timestamp" do
    identity = OperatorIdentity.create!(
      issuer: "https://id.example.test",
      subject: "avatar-agent-binding-#{SecureRandom.hex(4)}",
      audience: "acme_org",
      source_record_id: SecureRandom.random_number(1_000_000) + 20_000,
      status_id: OperatorIdentityState::ACTIVE,
    )
    agent = Agent.create!(operator_identity: identity, moniker: "Default Agent", title: "Agent01")
    handle = Handle.create!(
      handle: "agent-avatar-#{SecureRandom.hex(3)}",
      handle_status_id: HandleStatus::ACTIVE,
      cooldown_until: Time.current,
      is_system: false,
    )
    avatar = AvatarTestFactory.create!(
      moniker: "Default Avatar",
      active_handle: handle,
      capability_id: AvatarCapability::NORMAL,
    )

    binding = AvatarAgentBinding.create!(avatar: avatar, agent: agent)

    assert_predicate binding, :persisted?
    assert_predicate binding.public_id, :present?
    assert_predicate binding.assigned_at, :present?
    assert_predicate binding, :active?
    assert_not_predicate binding, :revoked?
  end

  test "validates public id presence and uniqueness" do
    first_identity = OperatorIdentity.create!(
      issuer: "https://id.example.test",
      subject: "avatar-agent-public-id-#{SecureRandom.hex(4)}",
      audience: "acme_org",
      source_record_id: SecureRandom.random_number(1_000_000) + 21_000,
      status_id: OperatorIdentityState::ACTIVE,
    )
    second_identity = OperatorIdentity.create!(
      issuer: "https://id.example.test",
      subject: "avatar-agent-public-id-#{SecureRandom.hex(4)}",
      audience: "acme_org",
      source_record_id: SecureRandom.random_number(1_000_000) + 22_000,
      status_id: OperatorIdentityState::ACTIVE,
    )
    first_agent = Agent.create!(operator_identity: first_identity, moniker: "Agent One", title: "Agent01")
    second_agent = Agent.create!(operator_identity: second_identity, moniker: "Agent Two", title: "Agent02")
    first_handle = Handle.create!(
      handle: "agent-public-one-#{SecureRandom.hex(3)}",
      handle_status_id: HandleStatus::ACTIVE,
      cooldown_until: Time.current,
      is_system: false,
    )
    second_handle = Handle.create!(
      handle: "agent-public-two-#{SecureRandom.hex(3)}",
      handle_status_id: HandleStatus::ACTIVE,
      cooldown_until: Time.current,
      is_system: false,
    )
    first_avatar = AvatarTestFactory.create!(
      moniker: "Agent Avatar One",
      active_handle: first_handle,
      capability_id: AvatarCapability::NORMAL,
    )
    second_avatar = AvatarTestFactory.create!(
      moniker: "Agent Avatar Two",
      active_handle: second_handle,
      capability_id: AvatarCapability::NORMAL,
    )
    binding = AvatarAgentBinding.create!(avatar: first_avatar, agent: first_agent)
    original_public_id = binding.public_id

    binding.public_id = nil

    assert_not binding.valid?
    assert_equal :blank, binding.errors.details.fetch(:public_id).first.fetch(:error)

    duplicate = AvatarAgentBinding.new(avatar: second_avatar, agent: second_agent, public_id: original_public_id)

    assert_not duplicate.valid?
    assert_equal :taken, duplicate.errors.details.fetch(:public_id).first.fetch(:error)
  end

  test "validates assigned and revoked ordering" do
    identity = OperatorIdentity.create!(
      issuer: "https://id.example.test",
      subject: "avatar-agent-ordering-#{SecureRandom.hex(4)}",
      audience: "acme_org",
      source_record_id: SecureRandom.random_number(1_000_000) + 23_000,
      status_id: OperatorIdentityState::ACTIVE,
    )
    agent = Agent.create!(operator_identity: identity, moniker: "Ordering Agent", title: "Agent03")
    handle = Handle.create!(
      handle: "agent-ordering-#{SecureRandom.hex(3)}",
      handle_status_id: HandleStatus::ACTIVE,
      cooldown_until: Time.current,
      is_system: false,
    )
    avatar = AvatarTestFactory.create!(
      moniker: "Ordering Avatar",
      active_handle: handle,
      capability_id: AvatarCapability::NORMAL,
    )
    binding = AvatarAgentBinding.create!(avatar: avatar, agent: agent)

    binding.assigned_at = nil

    assert_not binding.valid?
    assert_equal :blank, binding.errors.details.fetch(:assigned_at).first.fetch(:error)

    binding.assigned_at = Time.utc(2026, 7, 3, 12, 0, 0)
    binding.revoked_at = Time.utc(2026, 7, 3, 11, 0, 0)

    assert_not binding.valid?
    assert_equal :greater_than_or_equal_to, binding.errors.details.fetch(:revoked_at).first.fetch(:error)
  end

  test "database enforces active uniqueness and allows rebinding after revoke" do
    first_identity = OperatorIdentity.create!(
      issuer: "https://id.example.test",
      subject: "avatar-agent-db-one-#{SecureRandom.hex(4)}",
      audience: "acme_org",
      source_record_id: SecureRandom.random_number(1_000_000) + 24_000,
      status_id: OperatorIdentityState::ACTIVE,
    )
    second_identity = OperatorIdentity.create!(
      issuer: "https://id.example.test",
      subject: "avatar-agent-db-two-#{SecureRandom.hex(4)}",
      audience: "acme_org",
      source_record_id: SecureRandom.random_number(1_000_000) + 25_000,
      status_id: OperatorIdentityState::ACTIVE,
    )
    first_agent = Agent.create!(operator_identity: first_identity, moniker: "DB Agent One", title: "Agent04")
    second_agent = Agent.create!(operator_identity: second_identity, moniker: "DB Agent Two", title: "Agent05")
    first_handle = Handle.create!(
      handle: "agent-db-one-#{SecureRandom.hex(3)}",
      handle_status_id: HandleStatus::ACTIVE,
      cooldown_until: Time.current,
      is_system: false,
    )
    second_handle = Handle.create!(
      handle: "agent-db-two-#{SecureRandom.hex(3)}",
      handle_status_id: HandleStatus::ACTIVE,
      cooldown_until: Time.current,
      is_system: false,
    )
    first_avatar = AvatarTestFactory.create!(
      moniker: "DB Avatar One",
      active_handle: first_handle,
      capability_id: AvatarCapability::NORMAL,
    )
    second_avatar = AvatarTestFactory.create!(
      moniker: "DB Avatar Two",
      active_handle: second_handle,
      capability_id: AvatarCapability::NORMAL,
    )
    original = AvatarAgentBinding.create!(avatar: first_avatar, agent: first_agent)

    assert_raises(ActiveRecord::RecordNotUnique) do
      AvatarAgentBinding.new(
        avatar: first_avatar,
        agent: second_agent,
        public_id: Nanoid.generate(size: 21),
        assigned_at: Time.current,
      ).save!(validate: false)
    end

    assert_raises(ActiveRecord::RecordNotUnique) do
      AvatarAgentBinding.new(
        avatar: second_avatar,
        agent: first_agent,
        public_id: Nanoid.generate(size: 21),
        assigned_at: Time.current,
      ).save!(validate: false)
    end

    assert_raises(ActiveRecord::RecordNotUnique) do
      AvatarAgentBinding.new(
        avatar: first_avatar,
        agent: first_agent,
        public_id: Nanoid.generate(size: 21),
        assigned_at: Time.current,
      ).save!(validate: false)
    end

    original.revoke!(force: true)
    replacement = AvatarAgentBinding.create!(avatar: first_avatar, agent: first_agent)

    assert_predicate original.reload, :revoked?
    assert_predicate replacement, :active?
  end
end
