# typed: false
# frozen_string_literal: true

require "test_helper"

class AvatarAuthorityLifecycleConstraintTest < ActiveSupport::TestCase
  setup do
    [ClientStatus, ClientVisibility, ClientIdentityState, HandleStatus].each do |klass|
      klass.ensure_defaults! if klass.respond_to?(:ensure_defaults!)
    end
    AvatarCapability.find_or_create_by!(id: AvatarCapability::NORMAL)
  end

  test "database rejects invalid avatar assignment role" do
    handle = Handle.create!(
      handle: "constraint-role-#{SecureRandom.hex(4)}",
      handle_status_id: HandleStatus::ACTIVE,
      cooldown_until: Time.current,
      is_system: false,
    )
    avatar = Avatar.create!(
      moniker: "Constraint Role Avatar",
      active_handle: handle,
      capability_id: AvatarCapability::NORMAL,
    )
    now = AvatarRecord.lease_connection.quote(Time.current)

    assert_raises(ActiveRecord::StatementInvalid) do
      AvatarRecord.lease_connection.execute(<<~SQL.squish)
        INSERT INTO avatar_assignments (avatar_id, user_id, role, created_at, updated_at)
        VALUES (#{avatar.id}, 900001, 'superuser', #{now}, #{now})
      SQL
    end
  end

  test "database rejects avatar membership period inversion" do
    handle = Handle.create!(
      handle: "constraint-membership-period-#{SecureRandom.hex(4)}",
      handle_status_id: HandleStatus::ACTIVE,
      cooldown_until: Time.current,
      is_system: false,
    )
    avatar = Avatar.create!(
      moniker: "Constraint Membership Period Avatar",
      active_handle: handle,
      capability_id: AvatarCapability::NORMAL,
    )
    now = AvatarRecord.lease_connection.quote(Time.current)
    valid_from = AvatarRecord.lease_connection.quote(Time.utc(2026, 7, 3, 12, 0, 0))
    valid_to = AvatarRecord.lease_connection.quote(Time.utc(2026, 7, 3, 11, 0, 0))

    assert_raises(ActiveRecord::StatementInvalid) do
      AvatarRecord.lease_connection.execute(<<~SQL.squish)
        INSERT INTO avatar_memberships
          (avatar_id, actor_id, role_id, valid_from, valid_to, created_at, updated_at)
        VALUES
          (#{avatar.id}, 910001, #{avatar_roles(:viewer).id}, #{valid_from}, #{valid_to}, #{now}, #{now})
      SQL
    end
  end

  test "database rejects duplicate active avatar membership relation" do
    handle = Handle.create!(
      handle: "constraint-membership-unique-#{SecureRandom.hex(4)}",
      handle_status_id: HandleStatus::ACTIVE,
      cooldown_until: Time.current,
      is_system: false,
    )
    avatar = Avatar.create!(
      moniker: "Constraint Membership Unique Avatar",
      active_handle: handle,
      capability_id: AvatarCapability::NORMAL,
    )
    now = AvatarRecord.lease_connection.quote(Time.current)
    valid_from = AvatarRecord.lease_connection.quote(Time.utc(2026, 7, 3, 12, 0, 0))

    AvatarRecord.lease_connection.execute(<<~SQL.squish)
      INSERT INTO avatar_memberships
        (avatar_id, actor_id, role_id, valid_from, valid_to, created_at, updated_at)
      VALUES
        (#{avatar.id}, 910002, #{avatar_roles(:viewer).id}, #{valid_from}, 'infinity', #{now}, #{now})
    SQL

    assert_raises(ActiveRecord::RecordNotUnique) do
      AvatarRecord.lease_connection.execute(<<~SQL.squish)
        INSERT INTO avatar_memberships
          (avatar_id, actor_id, role_id, valid_from, valid_to, created_at, updated_at)
        VALUES
          (#{avatar.id}, 910002, #{avatar_roles(:viewer).id}, #{valid_from}, 'infinity', #{now}, #{now})
      SQL
    end
  end

  test "database rejects duplicate active primary avatar assignment" do
    handle = Handle.create!(
      handle: "constraint-primary-#{SecureRandom.hex(4)}",
      handle_status_id: HandleStatus::ACTIVE,
      cooldown_until: Time.current,
      is_system: false,
    )
    avatar = Avatar.create!(
      moniker: "Constraint Primary Avatar",
      active_handle: handle,
      capability_id: AvatarCapability::NORMAL,
    )
    now = AvatarRecord.lease_connection.quote(Time.current)

    AvatarRecord.lease_connection.execute(<<~SQL.squish)
      INSERT INTO avatar_assignments (avatar_id, user_id, role, created_at, updated_at)
      VALUES (#{avatar.id}, 920001, 'owner', #{now}, #{now})
    SQL

    assert_raises(ActiveRecord::RecordNotUnique) do
      AvatarRecord.lease_connection.execute(<<~SQL.squish)
        INSERT INTO avatar_assignments (avatar_id, user_id, role, created_at, updated_at)
        VALUES (#{avatar.id}, 920002, 'owner', #{now}, #{now})
      SQL
    end
  end

  test "database rejects revoked avatar persona binding before assignment" do
    handle = Handle.create!(
      handle: "constraint-persona-revoke-#{SecureRandom.hex(4)}",
      handle_status_id: HandleStatus::ACTIVE,
      cooldown_until: Time.current,
      is_system: false,
    )
    avatar = Avatar.create!(
      moniker: "Constraint ClientPersona Revoke Avatar",
      active_handle: handle,
      capability_id: AvatarCapability::NORMAL,
    )
    now = AvatarRecord.lease_connection.quote(Time.current)
    assigned_at = AvatarRecord.lease_connection.quote(Time.utc(2026, 7, 3, 12, 0, 0))
    revoked_at = AvatarRecord.lease_connection.quote(Time.utc(2026, 7, 3, 11, 0, 0))

    assert_raises(ActiveRecord::StatementInvalid) do
      AvatarRecord.lease_connection.execute(<<~SQL.squish)
        INSERT INTO avatar_persona_bindings
          (public_id, avatar_id, persona_id, assigned_at, revoked_at, created_at, updated_at)
        VALUES
          ('#{Nanoid.generate(size: 21)}', #{avatar.id}, 930001, #{assigned_at}, #{revoked_at}, #{now}, #{now})
      SQL
    end
  end

  test "database rejects revoked avatar agent binding before assignment" do
    handle = Handle.create!(
      handle: "constraint-agent-revoke-#{SecureRandom.hex(4)}",
      handle_status_id: HandleStatus::ACTIVE,
      cooldown_until: Time.current,
      is_system: false,
    )
    avatar = Avatar.create!(
      moniker: "Constraint Agent Revoke Avatar",
      active_handle: handle,
      capability_id: AvatarCapability::NORMAL,
    )
    now = AvatarRecord.lease_connection.quote(Time.current)
    assigned_at = AvatarRecord.lease_connection.quote(Time.utc(2026, 7, 3, 12, 0, 0))
    revoked_at = AvatarRecord.lease_connection.quote(Time.utc(2026, 7, 3, 11, 0, 0))

    assert_raises(ActiveRecord::StatementInvalid) do
      AvatarRecord.lease_connection.execute(<<~SQL.squish)
        INSERT INTO avatar_agent_bindings
          (public_id, avatar_id, agent_id, assigned_at, revoked_at, created_at, updated_at)
        VALUES
          ('#{Nanoid.generate(size: 21)}', #{avatar.id}, 940001, #{assigned_at}, #{revoked_at}, #{now}, #{now})
      SQL
    end
  end

  test "database rejects revoked avatar individual binding before assignment" do
    handle = Handle.create!(
      handle: "constraint-individual-revoke-#{SecureRandom.hex(4)}",
      handle_status_id: HandleStatus::ACTIVE,
      cooldown_until: Time.current,
      is_system: false,
    )
    avatar = Avatar.create!(
      moniker: "Constraint Individual Revoke Avatar",
      active_handle: handle,
      capability_id: AvatarCapability::NORMAL,
    )
    now = AvatarRecord.lease_connection.quote(Time.current)
    assigned_at = AvatarRecord.lease_connection.quote(Time.utc(2026, 7, 3, 12, 0, 0))
    revoked_at = AvatarRecord.lease_connection.quote(Time.utc(2026, 7, 3, 11, 0, 0))

    assert_raises(ActiveRecord::StatementInvalid) do
      AvatarRecord.lease_connection.execute(<<~SQL.squish)
        INSERT INTO avatar_individual_bindings
          (public_id, avatar_id, individual_id, assigned_at, revoked_at, created_at, updated_at)
        VALUES
          ('#{Nanoid.generate(size: 21)}', #{avatar.id}, 950001, #{assigned_at}, #{revoked_at}, #{now}, #{now})
      SQL
    end
  end

  test "database rejects duplicate active avatar persona relation" do
    handle = Handle.create!(
      handle: "constraint-persona-unique-#{SecureRandom.hex(4)}",
      handle_status_id: HandleStatus::ACTIVE,
      cooldown_until: Time.current,
      is_system: false,
    )
    avatar = Avatar.create!(
      moniker: "Constraint ClientPersona Unique Avatar",
      active_handle: handle,
      capability_id: AvatarCapability::NORMAL,
    )
    now = AvatarRecord.lease_connection.quote(Time.current)

    AvatarRecord.lease_connection.execute(<<~SQL.squish)
      INSERT INTO avatar_persona_bindings
        (public_id, avatar_id, persona_id, assigned_at, created_at, updated_at)
      VALUES
        ('#{Nanoid.generate(size: 21)}', #{avatar.id}, 930002, #{now}, #{now}, #{now})
    SQL

    assert_raises(ActiveRecord::RecordNotUnique) do
      AvatarRecord.lease_connection.execute(<<~SQL.squish)
        INSERT INTO avatar_persona_bindings
          (public_id, avatar_id, persona_id, assigned_at, created_at, updated_at)
        VALUES
          ('#{Nanoid.generate(size: 21)}', #{avatar.id}, 930003, #{now}, #{now}, #{now})
      SQL
    end
  end

  test "database rejects invalid avatar lifecycle event state key" do
    handle = Handle.create!(
      handle: "constraint-lifecycle-key-#{SecureRandom.hex(4)}",
      handle_status_id: HandleStatus::ACTIVE,
      cooldown_until: Time.current,
      is_system: false,
    )
    avatar = Avatar.create!(
      moniker: "Constraint Lifecycle Key Avatar",
      active_handle: handle,
      capability_id: AvatarCapability::NORMAL,
    )
    now = AvatarRecord.lease_connection.quote(Time.current)

    assert_raises(ActiveRecord::StatementInvalid) do
      AvatarRecord.lease_connection.execute(<<~SQL.squish)
        INSERT INTO avatar_lifecycle_events
          (avatar_id, from_state_key, to_state_key, metadata, created_at)
        VALUES
          (#{avatar.id}, 'unknown', 'active', '{}', #{now})
      SQL
    end
  end

  test "database rejects avatar lifecycle event without a state change" do
    handle = Handle.create!(
      handle: "constraint-lifecycle-same-#{SecureRandom.hex(4)}",
      handle_status_id: HandleStatus::ACTIVE,
      cooldown_until: Time.current,
      is_system: false,
    )
    avatar = Avatar.create!(
      moniker: "Constraint Lifecycle Same Avatar",
      active_handle: handle,
      capability_id: AvatarCapability::NORMAL,
    )
    now = AvatarRecord.lease_connection.quote(Time.current)

    assert_raises(ActiveRecord::StatementInvalid) do
      AvatarRecord.lease_connection.execute(<<~SQL.squish)
        INSERT INTO avatar_lifecycle_events
          (avatar_id, from_state_key, to_state_key, metadata, created_at)
        VALUES
          (#{avatar.id}, 'active', 'active', '{}', #{now})
      SQL
    end
  end
end
