# frozen_string_literal: true

require "test_helper"

module Publishing
  class ArchitectureGuardTest < ActiveSupport::TestCase
    self.fixture_table_names = []

    PUBLISHING_MODEL_GLOB = "app/models/publishing/**/*.rb"
    PUBLISHING_PUBLIC_CONTROLLER_GLOB = "app/controllers/{info,docs,news,help}/**/*.rb"
    FORBIDDEN_POLYMORPHISM = [
      /polymorphic:\s*true/,
      /has_many\b.+\bas:/,
      /has_one\b.+\bas:/,
      /source_type:/,
    ].freeze
    FORBIDDEN_DYNAMIC_DISPATCH = [
      /\bconstantize\b/,
      /\bsafe_constantize\b/,
    ].freeze
    AUTHORITY_ASSOCIATION =
      /\bbelongs_to\s+:(?:client|operator|visitor|member|account|organization|persona|agent|individual)\b/

    test "publishing models inherit PublishingRecord" do
      offenders = publishing_model_classes.reject { |klass| klass < PublishingRecord }

      assert_empty offenders.map(&:name),
                   "Publishing models must use PublishingRecord, not other databases"
    end

    test "publishing models connect only to the publishing database" do
      databases = publishing_model_classes.map { |klass| klass.connection_db_config.name }.uniq

      assert_equal ["publishing"], databases
    end

    test "publishing models do not associate to authority records" do
      offenders = scan_paths(PUBLISHING_MODEL_GLOB, AUTHORITY_ASSOCIATION)

      assert_empty offenders, "Publishing must stay decoupled from authority models:\n#{offenders.join("\n")}"
    end

    test "publishing models do not use Active Record polymorphism" do
      offenders = scan_paths(PUBLISHING_MODEL_GLOB, FORBIDDEN_POLYMORPHISM)

      assert_empty offenders, "CMS publishing must not introduce AR polymorphism:\n#{offenders.join("\n")}"
    end

    test "publishing models do not use STI" do
      offenders = publishing_model_classes.select { |klass| klass.columns_hash.key?("type") }

      named = offenders.map(&:name)

      assert_empty named, "CMS publishing must not introduce STI:\n#{named.join("\n")}"
    end

    test "publishing models and public CMS controllers do not constantize untrusted names" do
      offenders = scan_paths(PUBLISHING_MODEL_GLOB, FORBIDDEN_DYNAMIC_DISPATCH) +
        scan_paths(PUBLISHING_PUBLIC_CONTROLLER_GLOB, FORBIDDEN_DYNAMIC_DISPATCH)

      assert_empty offenders, "Public CMS path must not dispatch models via constantize:\n#{offenders.join("\n")}"
    end

    test "publishing tables do not use polymorphic type plus id ownership" do
      offenders = publishing_tables.filter_map do |table|
        names = PublishingRecord.connection.columns(table).map(&:name)
        type_owners =
          names.select { |name| name.end_with?("_type") }.filter_map do |type_column|
            id_column = type_column.delete_suffix("_type") + "_id"
            next unless names.include?(id_column)

            "#{table}.#{type_column}/#{id_column}"
          end
        type_owners.presence
      end.flatten

      assert_empty offenders, "CMS persistence must not use *_type + *_id ownership:\n#{offenders.join("\n")}"
    end

    test "publishing tables do not keep exclusive-arc owner foreign keys" do
      offenders =
        publishing_tables.select do |table|
          names = PublishingRecord.connection.columns(table).map(&:name)
          names.include?("entry_revision_id") && names.include?("entry_version_id")
        end

      assert_empty offenders,
                   "CMS persistence must not use revision-or-version owner unions:\n#{offenders.join("\n")}"
    end

    test "taxonomy kind remains a homogeneous classification column" do
      columns = PublishingRecord.connection.columns("publishing_vocabularies").map(&:name)

      assert_includes columns, "kind"
      assert_not_includes columns, "type"
    end

    test "edition uniqueness is audience surface locale without region_code" do
      # Characterization of the unresolved region model: uniqueness ignores
      # region_code while regional surfaces still require one at the database.
      indexes = PublishingRecord.connection.indexes("publishing_editions")
      scope = indexes.find { |index| index.unique && index.columns == %w(audience surface locale) }

      assert_not_nil scope, "expected UNIQUE (audience, surface, locale)"
      assert_not_includes scope.columns, "region_code"
    end

    private

    def publishing_tables
      PublishingRecord.connection.tables.grep(/\Apublishing_/)
    end

    def publishing_model_classes
      Rails.root.glob(PUBLISHING_MODEL_GLOB).map do |path|
        relative = path.relative_path_from(Rails.root.join("app/models")).to_s.delete_suffix(".rb")
        relative.camelize.constantize
      end
    end

    def scan_paths(glob, patterns)
      patterns = Array(patterns)
      Rails.root.glob(glob).flat_map do |path|
        relative = path.relative_path_from(Rails.root).to_s
        path.each_line.with_index(1).filter_map do |line, line_number|
          next unless patterns.any? { |pattern| line.match?(pattern) }

          "#{relative}:#{line_number}: #{line.strip}"
        end
      end
    end
  end
end
