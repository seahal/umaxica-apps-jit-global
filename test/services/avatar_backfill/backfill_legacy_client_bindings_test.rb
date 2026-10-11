# typed: false
# frozen_string_literal: true

require "test_helper"

module AvatarBackfill
  class BackfillLegacyClientBindingsTest < ActiveSupport::TestCase
    setup do
      [ClientStatus, ClientVisibility, ClientIdentityState, HandleStatus].each do |klass|
        klass.ensure_defaults! if klass.respond_to?(:ensure_defaults!)
      end
      AvatarCapability.find_or_create_by!(id: AvatarCapability::NORMAL)
      AvatarLifecycleState.find_or_create_by!(key: "active") do |state|
        state.title = "Active"
        state.sort_order = 10
        state.can_create_content = true
        state.visible_by_default = true
        state.editable_by_owner = true
        state.restorable_by_owner = false
        state.followable = true
        state.group_attachable = true
        state.discoverable = true
        state.moderation_visible = true
        state.terminal = false
      end
    end

    test "dry run reports created bucket without creating binding" do
      client = create_client
      create_persona(client)
      create_avatar(client: client)

      assert_no_difference -> { AvatarPersonaBinding.count } do
        result = BackfillLegacyClientBindings.call

        assert_not result.summary.fetch(:apply)
        assert_equal 1, result.summary.fetch(:created_count)
      end
    end

    test "apply creates binding for safe candidate" do
      client = create_client
      persona = create_persona(client)
      avatar = create_avatar(client: client)

      assert_difference -> { AvatarPersonaBinding.count }, 1 do
        result = BackfillLegacyClientBindings.call(apply: true)

        assert_equal 1, result.summary.fetch(:created_count)
      end

      assert_equal persona, AvatarPersonaBinding.active.find_by!(avatar_id: avatar.id).persona
    end

    test "apply is idempotent" do
      client = create_client
      create_persona(client)
      create_avatar(client: client)

      BackfillLegacyClientBindings.call(apply: true)

      assert_no_difference -> { AvatarPersonaBinding.count } do
        result = BackfillLegacyClientBindings.call(apply: true)

        assert_equal 1, result.summary.fetch(:skipped_already_bound_consistent_count)
      end
    end

    test "conflict candidates are skipped" do
      client = create_client
      create_persona(client)
      create_avatar(client: client)
      create_avatar(client: client)

      assert_no_difference -> { AvatarPersonaBinding.count } do
        result = BackfillLegacyClientBindings.call(apply: true)

        assert_equal 2, result.summary.fetch(:skipped_multiple_legacy_avatars_count)
      end
    end

    test "maps every non-writing audit outcome" do
      candidates = [
        candidate("deleted_avatar_skipped"),
        candidate("missing_client"),
        candidate("unresolved_subject"),
        candidate("ambiguous_subject"),
        candidate("already_bound_inconsistent"),
      ]
      audit = AuditLegacyClientBindings::Result.new(summary: {}, details: candidates)

      AuditLegacyClientBindings.stub(:call, audit) do
        result = BackfillLegacyClientBindings.call

        assert_equal 1, result.summary.fetch(:skipped_deleted_count)
        assert_equal 1, result.summary.fetch(:skipped_missing_subject_count)
        assert_equal 2, result.summary.fetch(:skipped_unresolved_count)
        assert_equal 1, result.summary.fetch(:skipped_conflict_count)
      end
    end

    test "writes a json report" do
      audit = AuditLegacyClientBindings::Result.new(
        summary: {},
        details: [candidate("already_bound_consistent")],
      )
      path = "tmp/avatar-backfill-test.json"
      absolute = Rails.root.join(path)
      FileUtils.rm_f(absolute)

      AuditLegacyClientBindings.stub(:call, audit) do
        BackfillLegacyClientBindings.call(output_path: path)
      end

      report = JSON.parse(File.read(absolute))

      assert_equal 1, report.dig("summary", "skipped_already_bound_consistent_count")
    ensure
      FileUtils.rm_f(absolute)
    end

    private

    def candidate(bucket)
      {
        avatar_id: 1,
        resolved_subject_id: 1,
        conflict_bucket: bucket,
        reason: "audit reason",
      }
    end

    def create_client
      Client.create!(status_id: ClientStatus::ACTIVE, visibility_id: ClientVisibility::USER)
    end

    def create_persona(client)
      identity = ClientIdentity.create!(
        issuer: "https://id.example.test",
        subject: "legacy-client-backfill-#{SecureRandom.hex(6)}",
        audience: "acme_app",
        source_record_id: client.id,
        status_id: ClientIdentityState::ACTIVE,
      )
      ClientPersona.create!(client_identity: identity, moniker: "Backfill ClientPersona", title: "Backfill1")
    end

    def create_avatar(client:)
      handle = Handle.create!(
        handle: "legacy-apply-#{SecureRandom.hex(6)}",
        handle_status_id: HandleStatus::ACTIVE,
        cooldown_until: Time.current,
        is_system: false,
      )
      Avatar.create!(
        moniker: "Backfill Avatar",
        active_handle: handle,
        capability_id: AvatarCapability::NORMAL,
        client_id: client.id,
        lifecycle_state: AvatarLifecycleState.find_by!(key: "active"),
      )
    end
  end
end
