# typed: false
# frozen_string_literal: true

require "test_helper"

module Security
  module Invariants
    class UmaxicaArchitectureGuardTest < ActiveSupport::TestCase
      self.fixture_table_names = []

      AUTHORITY_TABLE_PATTERNS = [
        /avatar_assignments/,
        /avatar_memberships/,
        /avatar_persona_bindings/,
        /avatar_agent_bindings/,
        /avatar_individual_bindings/,
        /group_avatar_memberships/,
        /account_assignments/,
        /organization_memberships/,
        /unit_memberships/,
        /persona_assignments/,
        /agent_assignments/,
        /individual_assignments/,
      ].freeze

      DIRECT_WRITE_PATTERN = /\.(?:create!|update!|destroy!)\b/

      KNOWN_CONTROLLER_AUTHORITY_WRITES = [].freeze

      AVATAR_PROVISIONING_CREATE_PATH = "app/services/avatar_provisioning/create.rb"
      AVATAR_BACKFILL_LEGACY_CLIENT_BINDINGS_PATH = "app/services/avatar_backfill/backfill_legacy_client_bindings.rb"
      NON_PERSISTENT_AVATAR_FORM_BUILDS = [
        "app/controllers/base/app/avatars_controller.rb",
      ].freeze

      FORBIDDEN_AVATAR_UGC_TABLES = %w(
        posts comments replies captions stories videos short_videos messages reactions feeds
        timelines ranking_events
      ).freeze

      KNOWN_AVATAR_UGC_TABLES = [
        "db/avatars_migrate/20251225200010_create_avatar_identity_core_tables.rb:98",
        "db/avatars_migrate/20260201160000_convert_avatar_uuid_pks_to_bigint.rb:252",
      ].freeze

      FORBIDDEN_AVATAR_SNAPSHOT_TABLES = %w(
        actor_snapshots post_actor_snapshots avatar_snapshots_for_posts content_actor_snapshots
      ).freeze

      CROSS_DB_INTEGER_REFERENCE_PATTERN =
        # rubocop:disable Layout/LineLength -- splitting this regex corrupts it
        /\bt\.(?:bigint|integer|references)\(?\s*:?(?:avatar|account|organization|unit|identity|persona|agent|individual|member)_(?:id|identity_id)\b/
      # rubocop:enable Layout/LineLength

      KNOWN_CROSS_DB_INTEGER_REFERENCES = [
        "db/app_zenith_migrate/20260520120000_create_persona_enterprise_model_layer.rb:10",
        "db/app_zenith_migrate/20260627000001_create_persona_assignments.rb:8",
        "db/app_principals_migrate/20260305114337_create_user_members.rb:7",
        "db/com_zenith_migrate/20260520120001_create_individual_company_model_layer.rb:10",
        "db/com_zenith_migrate/20260627000001_create_individual_assignments.rb:8",
        "db/org_principals_migrate/20260518130000_create_operator_lifecycle_requests.rb:11",
        "db/org_zenith_migrate/20260520120002_create_agent_bureau_model_layer.rb:10",
        "db/org_zenith_migrate/20260627000001_create_agent_assignments.rb:8",
        "db/org_zenith_migrate/20260630000003_create_organization_entra_connections.rb:7",
        "db/avatars_migrate/20260201160000_convert_avatar_uuid_pks_to_bigint.rb:123",
        "db/avatars_migrate/20260201160000_convert_avatar_uuid_pks_to_bigint.rb:171",
        "db/avatars_migrate/20260627000002_create_avatar_account_bindings.rb:7",
        "db/avatars_migrate/20260627000002_create_avatar_account_bindings.rb:8",
        "db/avatars_migrate/20260627000002_create_avatar_account_bindings.rb:23",
        "db/avatars_migrate/20260627000002_create_avatar_account_bindings.rb:24",
        "db/avatars_migrate/20260627000002_create_avatar_account_bindings.rb:38",
        "db/avatars_migrate/20260627000002_create_avatar_account_bindings.rb:39",
        "db/avatars_migrate/20260627000002_create_avatar_account_bindings.rb:44",
        "db/avatars_migrate/20260627000002_create_avatar_account_bindings.rb:45",
      ].freeze

      test "controllers do not directly write authority or lifecycle tables beyond known violations" do
        offenders =
          Rails.root.glob("app/controllers/**/*.rb").flat_map do |path|
            relative_path = path.relative_path_from(Rails.root).to_s
            File.readlines(path, chomp: true).each_with_index.filter_map do |line, index|
              next unless line.match?(DIRECT_WRITE_PATTERN)
              next unless AUTHORITY_TABLE_PATTERNS.any? { |pattern| line.match?(pattern) }

              location = "#{relative_path}:#{index + 1}"
              next if KNOWN_CONTROLLER_AUTHORITY_WRITES.include?(location)

              "#{location}: #{line.strip}"
            end
          end

        assert_empty offenders,
                     "Controller authority/lifecycle writes must move to use-case services:\n#{offenders.join("\n")}"
      end

      test "new code does not add canonical avatars client_id writes beyond known violations" do
        offenders =
          production_ruby_paths.flat_map do |path|
            relative_path = path.relative_path_from(Rails.root).to_s
            File.readlines(path, chomp: true).each_with_index.filter_map do |line, index|
              next unless line.match?(
                # rubocop:disable Layout/LineLength -- splitting this regex corrupts it
                /\bclient_id:\s*(?:(?:current_client|principal|actor|user|client|@user|@client)\.id|legacy_compatibility_client_id)\b/,
                # rubocop:enable Layout/LineLength
              )
              # Authority ownership lookups filter by the owning principal; they are not avatars writes.
              next if line.match?(/\b[A-Z]\w*Ownership\.where\(/)
              next if [AVATAR_PROVISIONING_CREATE_PATH,
                       AVATAR_BACKFILL_LEGACY_CLIENT_BINDINGS_PATH,].include?(relative_path)

              location = "#{relative_path}:#{index + 1}"

              "#{location}: #{line.strip}"
            end
          end

        assert_empty offenders, "Do not add new canonical writes to legacy avatars.client_id:\n#{offenders.join("\n")}"
      end

      test "production avatar creation entry points stay inside AvatarProvisioning Create" do
        patterns = {
          "Avatar.create_with_owner" => /Avatar\.create_with_owner\(/,
          "Avatar.create!" => /Avatar\.create!\(/,
          "avatar_assignments.create!" => /avatar_assignments\.create!\(/,
          "Handle.create!" => /Handle\.create!\(/,
          I18n.t("architecture_guard.avatar_binding_create") => /Avatar(?:Persona|Agent|Individual)Binding\.create!\(/,
        }
        offenders =
          production_ruby_paths.flat_map do |path|
            relative_path = path.relative_path_from(Rails.root).to_s
            File.readlines(path, chomp: true).each_with_index.filter_map do |line, index|
              matched_name = patterns.find { |_name, pattern| line.match?(pattern) }&.first
              next unless matched_name
              next if [AVATAR_PROVISIONING_CREATE_PATH,
                       AVATAR_BACKFILL_LEGACY_CLIENT_BINDINGS_PATH,].include?(relative_path)

              "#{relative_path}:#{index + 1}: #{matched_name}: #{line.strip}"
            end
          end

        assert_empty offenders,
                     "Avatar graph creation must go through AvatarProvisioning::Create:\n#{offenders.join("\n")}"
      end

      test "production Avatar new calls do not become creation entry points" do
        offenders =
          production_ruby_paths.flat_map do |path|
            relative_path = path.relative_path_from(Rails.root).to_s
            next [] if NON_PERSISTENT_AVATAR_FORM_BUILDS.include?(relative_path)

            File.readlines(path, chomp: true).each_with_index.filter_map do |line, index|
              next unless line.match?(/Avatar\.new\(/)

              "#{relative_path}:#{index + 1}: #{line.strip}"
            end
          end

        assert_empty offenders,
                     "Production Avatar.new calls must not bypass AvatarProvisioning::Create:\n#{offenders.join("\n")}"
      end

      test "avatar database migrations do not add UGC tables beyond known violations" do
        pattern = /create_table\(?\s*:?(#{FORBIDDEN_AVATAR_UGC_TABLES.join("|")})\b/
        offenders =
          Rails.root.glob("db/avatars_migrate/**/*.rb").flat_map do |path|
            relative_path = path.relative_path_from(Rails.root).to_s
            File.readlines(path, chomp: true).each_with_index.filter_map do |line, index|
              next unless line.match?(pattern)

              location = "#{relative_path}:#{index + 1}"
              next if KNOWN_AVATAR_UGC_TABLES.include?(location)

              "#{location}: #{line.strip}"
            end
          end

        assert_empty offenders, "Avatar DB must not add UGC tables:\n#{offenders.join("\n")}"
      end

      test "avatar database migrations do not add actor snapshot tables" do
        pattern = /create_table\(?\s*:?(#{FORBIDDEN_AVATAR_SNAPSHOT_TABLES.join("|")})\b/
        offenders =
          Rails.root.glob("db/avatars_migrate/**/*.rb").flat_map do |path|
            relative_path = path.relative_path_from(Rails.root).to_s
            File.readlines(path, chomp: true).each_with_index.filter_map do |line, index|
              next unless line.match?(pattern)

              "#{relative_path}:#{index + 1}: #{line.strip}"
            end
          end

        assert_empty offenders,
                     "Actor snapshots belong to content/read-model DBs, not Avatar DB:\n#{offenders.join("\n")}"
      end

      test "new migrations do not add cross database integer references beyond known violations" do
        offenders =
          Rails.root.glob("db/{app,com,org,avatars}_*_migrate/**/*.rb").flat_map do |path|
            relative_path = path.relative_path_from(Rails.root).to_s
            File.readlines(path, chomp: true).each_with_index.filter_map do |line, index|
              next unless line.match?(CROSS_DB_INTEGER_REFERENCE_PATTERN)

              location = "#{relative_path}:#{index + 1}"
              next if KNOWN_CROSS_DB_INTEGER_REFERENCES.include?(location)

              "#{location}: #{line.strip}"
            end
          end

        assert_empty offenders,
                     "Use public_id/gid/surface/resource_type for cross-DB references, not integer IDs:\n" \
                     "#{offenders.join("\n")}"
      end

      private

      def production_ruby_paths
        Rails.root.glob("{app,lib}/**/*.rb").map { |path| Pathname.new(path) }
      end
    end
  end
end
