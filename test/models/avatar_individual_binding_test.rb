# typed: false
# frozen_string_literal: true

require "test_helper"
require_relative "../support/avatar_test_factory"

class AvatarIndividualBindingTest < ActiveSupport::TestCase
  setup do
    HandleStatus.ensure_defaults!
    VisitorIdentityState.ensure_defaults!
    AvatarCapability.find_or_create_by!(id: AvatarCapability::NORMAL)
    AvatarLifecycleState.find_or_create_by!(key: "active") do |state|
      state.title = "Active"
      state.sort_order = 10
      state.terminal = false if state.respond_to?(:terminal=)
    end
  end

  test "defaults public id and assigned timestamp" do
    identity = VisitorIdentity.create!(
      issuer: "https://id.example.test",
      subject: "avatar-individual-binding-#{SecureRandom.hex(4)}",
      audience: "acme_com",
      source_record_id: SecureRandom.random_number(1_000_000) + 30_000,
      status_id: VisitorIdentityState::ACTIVE,
    )
    individual = Individual.create!(visitor_identity: identity, moniker: "Default Individual", title: "Indiv01")
    handle = Handle.create!(
      handle: "individual-avatar-#{SecureRandom.hex(3)}",
      handle_status_id: HandleStatus::ACTIVE,
      cooldown_until: Time.current,
      is_system: false,
    )
    avatar = AvatarTestFactory.create!(
      moniker: "Default Avatar",
      active_handle: handle,
      capability_id: AvatarCapability::NORMAL,
    )

    binding = AvatarIndividualBinding.create!(avatar: avatar, individual: individual)

    assert_predicate binding, :persisted?
    assert_predicate binding.public_id, :present?
    assert_predicate binding.assigned_at, :present?
    assert_predicate binding, :active?
    assert_not_predicate binding, :revoked?
  end

  test "validates public id presence and uniqueness" do
    first_identity = VisitorIdentity.create!(
      issuer: "https://id.example.test",
      subject: "avatar-individual-public-id-#{SecureRandom.hex(4)}",
      audience: "acme_com",
      source_record_id: SecureRandom.random_number(1_000_000) + 31_000,
      status_id: VisitorIdentityState::ACTIVE,
    )
    second_identity = VisitorIdentity.create!(
      issuer: "https://id.example.test",
      subject: "avatar-individual-public-id-#{SecureRandom.hex(4)}",
      audience: "acme_com",
      source_record_id: SecureRandom.random_number(1_000_000) + 32_000,
      status_id: VisitorIdentityState::ACTIVE,
    )
    first_individual = Individual.create!(visitor_identity: first_identity, moniker: "Individual One", title: "Indiv01")
    second_individual = Individual.create!(
      visitor_identity: second_identity, moniker: "Individual Two",
      title: "Indiv02",
    )
    first_handle = Handle.create!(
      handle: "individual-public-one-#{SecureRandom.hex(3)}",
      handle_status_id: HandleStatus::ACTIVE,
      cooldown_until: Time.current,
      is_system: false,
    )
    second_handle = Handle.create!(
      handle: "individual-public-two-#{SecureRandom.hex(3)}",
      handle_status_id: HandleStatus::ACTIVE,
      cooldown_until: Time.current,
      is_system: false,
    )
    first_avatar = AvatarTestFactory.create!(
      moniker: "Avatar One",
      active_handle: first_handle,
      capability_id: AvatarCapability::NORMAL,
    )
    second_avatar = AvatarTestFactory.create!(
      moniker: "Avatar Two",
      active_handle: second_handle,
      capability_id: AvatarCapability::NORMAL,
    )
    binding = AvatarIndividualBinding.create!(avatar: first_avatar, individual: first_individual)
    original_public_id = binding.public_id

    binding.public_id = nil

    assert_not binding.valid?
    assert_equal :blank, binding.errors.details.fetch(:public_id).first.fetch(:error)

    duplicate = AvatarIndividualBinding.new(
      avatar: second_avatar,
      individual: second_individual,
      public_id: original_public_id,
    )

    assert_not duplicate.valid?
    assert_equal :taken, duplicate.errors.details.fetch(:public_id).first.fetch(:error)
  end

  test "validates assigned and revoked ordering" do
    identity = VisitorIdentity.create!(
      issuer: "https://id.example.test",
      subject: "avatar-individual-ordering-#{SecureRandom.hex(4)}",
      audience: "acme_com",
      source_record_id: SecureRandom.random_number(1_000_000) + 33_000,
      status_id: VisitorIdentityState::ACTIVE,
    )
    individual = Individual.create!(visitor_identity: identity, moniker: "Ordering Individual", title: "Indiv03")
    handle = Handle.create!(
      handle: "individual-ordering-#{SecureRandom.hex(3)}",
      handle_status_id: HandleStatus::ACTIVE,
      cooldown_until: Time.current,
      is_system: false,
    )
    avatar = AvatarTestFactory.create!(
      moniker: "Ordering Avatar",
      active_handle: handle,
      capability_id: AvatarCapability::NORMAL,
    )
    binding = AvatarIndividualBinding.create!(avatar: avatar, individual: individual)

    binding.assigned_at = nil

    assert_not binding.valid?
    assert_equal :blank, binding.errors.details.fetch(:assigned_at).first.fetch(:error)

    binding.assigned_at = Time.utc(2026, 7, 3, 12, 0, 0)
    binding.revoked_at = Time.utc(2026, 7, 3, 11, 0, 0)

    assert_not binding.valid?
    assert_equal :greater_than_or_equal_to, binding.errors.details.fetch(:revoked_at).first.fetch(:error)
  end

  test "database enforces active uniqueness and allows rebinding after revoke" do
    first_identity = VisitorIdentity.create!(
      issuer: "https://id.example.test",
      subject: "avatar-individual-db-one-#{SecureRandom.hex(4)}",
      audience: "acme_com",
      source_record_id: SecureRandom.random_number(1_000_000) + 34_000,
      status_id: VisitorIdentityState::ACTIVE,
    )
    second_identity = VisitorIdentity.create!(
      issuer: "https://id.example.test",
      subject: "avatar-individual-db-two-#{SecureRandom.hex(4)}",
      audience: "acme_com",
      source_record_id: SecureRandom.random_number(1_000_000) + 35_000,
      status_id: VisitorIdentityState::ACTIVE,
    )
    first_individual = Individual.create!(
      visitor_identity: first_identity, moniker: "DB Individual One",
      title: "Indiv04",
    )
    second_individual = Individual.create!(
      visitor_identity: second_identity, moniker: "DB Individual Two",
      title: "Indiv05",
    )
    first_handle = Handle.create!(
      handle: "individual-db-one-#{SecureRandom.hex(3)}",
      handle_status_id: HandleStatus::ACTIVE,
      cooldown_until: Time.current,
      is_system: false,
    )
    second_handle = Handle.create!(
      handle: "individual-db-two-#{SecureRandom.hex(3)}",
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
    original = AvatarIndividualBinding.create!(avatar: first_avatar, individual: first_individual)

    assert_raises(ActiveRecord::RecordNotUnique) do
      AvatarIndividualBinding.new(
        avatar: first_avatar,
        individual: second_individual,
        public_id: Nanoid.generate(size: 21),
        assigned_at: Time.current,
      ).save!(validate: false)
    end

    assert_raises(ActiveRecord::RecordNotUnique) do
      AvatarIndividualBinding.new(
        avatar: second_avatar,
        individual: first_individual,
        public_id: Nanoid.generate(size: 21),
        assigned_at: Time.current,
      ).save!(validate: false)
    end

    assert_raises(ActiveRecord::RecordNotUnique) do
      AvatarIndividualBinding.new(
        avatar: first_avatar,
        individual: first_individual,
        public_id: Nanoid.generate(size: 21),
        assigned_at: Time.current,
      ).save!(validate: false)
    end

    original.revoke!(force: true)
    replacement = AvatarIndividualBinding.create!(avatar: first_avatar, individual: first_individual)

    assert_predicate original.reload, :revoked?
    assert_predicate replacement, :active?
  end
end
