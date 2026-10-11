# typed: false
# frozen_string_literal: true

require "test_helper"

class AvatarPersonaBindingTest < ActiveSupport::TestCase
  test "defaults public id and assigned timestamp" do
    ClientIdentityState.ensure_defaults!
    persona = build_persona
    avatar = build_avatar

    binding = AvatarPersonaBinding.create!(avatar: avatar, persona: persona)

    assert_predicate binding, :persisted?
    assert_predicate binding.public_id, :present?
    assert_predicate binding.assigned_at, :present?
    assert_predicate binding, :active?
    assert_not_predicate binding, :revoked?
  end

  test "enforces one active avatar per persona and one active persona per avatar" do
    ClientIdentityState.ensure_defaults!
    persona = build_persona
    avatar = build_avatar

    AvatarPersonaBinding.create!(avatar: avatar, persona: persona)

    same_avatar = AvatarPersonaBinding.new(avatar: avatar, persona: build_persona)

    assert_not same_avatar.valid?
    assert_equal :taken, same_avatar.errors.details.fetch(:avatar_id).first.fetch(:error)

    same_persona = AvatarPersonaBinding.new(avatar: build_avatar, persona: persona)

    assert_not same_persona.valid?
    assert_equal :taken, same_persona.errors.details.fetch(:persona_id).first.fetch(:error)
  end

  test "database enforces one active avatar persona pair" do
    ClientIdentityState.ensure_defaults!
    persona = build_persona
    avatar = build_avatar

    AvatarPersonaBinding.create!(avatar: avatar, persona: persona)

    assert_raises(ActiveRecord::RecordNotUnique) do
      AvatarPersonaBinding.new(
        avatar: avatar,
        persona: persona,
        public_id: Nanoid.generate(size: 21),
        assigned_at: Time.current,
      ).save!(validate: false)
    end
  end

  test "revoked binding keeps history and allows a new active binding" do
    ClientIdentityState.ensure_defaults!
    persona = build_persona
    avatar = build_avatar
    original = AvatarPersonaBinding.create!(avatar: avatar, persona: persona)

    original.revoke!(force: true)
    replacement = AvatarPersonaBinding.create!(avatar: avatar, persona: persona)

    assert_predicate original.reload, :revoked?
    assert_predicate replacement, :active?
    assert_equal [replacement], AvatarPersonaBinding.active.to_a
  end

  test "avatar reads current active binding and persona" do
    ClientIdentityState.ensure_defaults!
    persona = build_persona
    avatar = build_avatar
    binding = AvatarPersonaBinding.create!(avatar: avatar, persona: persona)

    assert_equal binding, avatar.current_avatar_persona_binding
    assert_equal persona, avatar.current_persona
  end

  test "persona reads current active binding and avatar" do
    ClientIdentityState.ensure_defaults!
    persona = build_persona
    avatar = build_avatar
    binding = AvatarPersonaBinding.create!(avatar: avatar, persona: persona)

    assert_equal binding, persona.current_avatar_persona_binding
    assert_equal avatar, persona.current_avatar
  end

  test "current read paths ignore revoked bindings" do
    ClientIdentityState.ensure_defaults!
    persona = build_persona
    avatar = build_avatar
    binding = AvatarPersonaBinding.create!(avatar: avatar, persona: persona)

    binding.revoke!(force: true)

    assert_nil avatar.current_avatar_persona_binding
    assert_nil avatar.current_persona
    assert_nil persona.current_avatar_persona_binding
    assert_nil persona.current_avatar
  end

  test "current read paths return nil when binding is missing" do
    ClientIdentityState.ensure_defaults!
    persona = build_persona
    avatar = build_avatar

    assert_nil avatar.current_avatar_persona_binding
    assert_nil avatar.current_persona
    assert_nil persona.current_avatar_persona_binding
    assert_nil persona.current_avatar
  end

  test "revoke! denies active binding revocation by default" do
    ClientIdentityState.ensure_defaults!
    persona = build_persona
    avatar = build_avatar
    binding = AvatarPersonaBinding.create!(avatar: avatar, persona: persona)

    assert_no_changes -> { binding.reload.revoked_at } do
      assert_raises(AvatarPersonaBindingRevocation::RevocationDenied) do
        binding.revoke!
      end
    end

    assert_equal persona, avatar.current_persona
  end

  test "revoke! with force revokes active binding and removes current persona" do
    ClientIdentityState.ensure_defaults!
    persona = build_persona
    avatar = build_avatar
    binding = AvatarPersonaBinding.create!(avatar: avatar, persona: persona)
    revoked_at = binding.assigned_at + 1.minute

    result = binding.revoke!(at: revoked_at, force: true)

    assert_same binding, result
    assert_equal revoked_at, binding.reload.revoked_at
    assert_nil avatar.current_persona
  end

  test "revoke! is idempotent for already revoked bindings" do
    ClientIdentityState.ensure_defaults!
    persona = build_persona
    avatar = build_avatar
    binding = AvatarPersonaBinding.create!(avatar: avatar, persona: persona)
    original_revoked_at = binding.assigned_at + 1.minute

    binding.revoke!(at: original_revoked_at, force: true)
    result = binding.revoke!(at: original_revoked_at + 1.hour)

    assert_same binding, result
    assert_equal original_revoked_at, binding.reload.revoked_at
  end

  private

  def build_persona
    identity = ClientIdentity.create!(
      issuer: "https://id.example.test",
      subject: "avatar-persona-binding-#{SecureRandom.hex(4)}",
      audience: "acme_app",
      source_record_id: SecureRandom.random_number(1_000_000) + 4000,
      status_id: ClientIdentityState::ACTIVE,
    )
    ClientPersona.create!(client_identity: identity, moniker: "Default ClientPersona", title: "Persona01")
  end

  def build_avatar
    handle = Handle.create!(
      handle: "user-#{SecureRandom.hex(3)}",
      handle_status_id: HandleStatus::ACTIVE,
      cooldown_until: Time.current,
      is_system: false,
    )

    Avatar.create!(
      moniker: "Default Avatar",
      active_handle: handle,
      capability_id: AvatarCapability::NORMAL,
      client_id: nil,
      owner_organization_id: "ORG1",
      representing_organization_id: "ORG1",
    )
  end
end
