# typed: false
# frozen_string_literal: true

require "open3"
require "test_helper"
# require "helpers/global_test_support"

module Security
  module Invariants
    class FlatRubySourceMappingTest < ActiveSupport::TestCase
      self.fixture_table_names = []

      Target = Data.define(:root, :concern)
      Mapping = Data.define(:old_path, :old_constant, :new_path, :new_constant, :reference_count)

      TARGETS = [
        Target.new(root: "app/services", concern: false),
        Target.new(root: "app/models/concerns", concern: true),
        Target.new(root: "app/controllers/concerns", concern: true),
        Target.new(root: "lib", concern: false),
      ].freeze

      LIB_EXCLUDED_PREFIXES = %w(
        lib/tasks/
        lib/assets/
        lib/templates/
        lib/generators/
      ).freeze

      test "proposed flat ruby source mapping has no collisions" do
        mappings = self.class.mappings

        path_collisions = collisions_for(mappings, &:new_path)
        constant_collisions = collisions_for(mappings, &:new_constant)

        assert_empty path_collisions, collision_message("flat path", path_collisions)
        assert_empty constant_collisions, collision_message("flat constant", constant_collisions)
      end

      def self.mappings
        target_files.map do |path, target|
          old_path = path.relative_path_from(Rails.root).to_s
          new_path = flat_path(path, target)

          Mapping.new(
            old_path: old_path,
            old_constant: constant_for_path(path, target.root),
            new_path: new_path,
            new_constant: constant_for_relative_path(new_path.delete_prefix("#{target.root}/").delete_suffix(".rb")),
            reference_count: reference_count(old_path),
          )
        end
      end

      def self.mapping_table
        rows =
          mappings.map do |mapping|
            [
              mapping.old_path,
              mapping.old_constant,
              mapping.new_path,
              mapping.new_constant,
              mapping.reference_count,
            ]
          end

        [%w(old_path old_constant new_path new_constant reference_count), *rows]
      end

      def self.target_files
        TARGETS.flat_map do |target|
          Rails.root.glob("#{target.root}/**/*.rb").filter_map do |path|
            relative_path = path.relative_path_from(Rails.root).to_s
            next if excluded_lib_path?(relative_path)

            [path, target]
          end
        end.sort_by { |path, _target| path.to_s }
      end

      def self.flat_path(path, target)
        relative = path.relative_path_from(Rails.root.join(target.root)).sub_ext("").to_s
        flat_name = relative.tr("/", "_")

        "#{target.root}/#{flat_name}.rb"
      end

      def self.constant_for_path(path, root)
        relative = path.relative_path_from(Rails.root.join(root)).sub_ext("").to_s

        constant_for_relative_path(relative)
      end

      def self.constant_for_relative_path(relative_path)
        relative_path.split("/").map { |segment| segment.camelize }.join("::")
      end

      def self.reference_count(old_path)
        old_constant = nil
        TARGETS.each do |target|
          root = Rails.root.join(target.root)
          path = Rails.root.join(old_path)
          next unless path.to_s.start_with?(root.to_s)

          old_constant = constant_for_path(path, target.root)
          break
        end

        return 0 if old_constant.blank?

        stdout, _stderr, status = Open3.capture3(
          *fixed_string_search_command(old_constant),
          chdir: Rails.root.to_s,
        )

        # git grep exits 1 when there are no matches; treat that as zero hits.
        return 0 if status.exitstatus == 1
        return 0 unless status.success?

        stdout.lines.count
      end

      # Prefer ripgrep when the sandbox exposes it (bin/rg or /usr/bin/rg). Fall
      # back to `git grep` which remains available when system rg is filtered out.
      def self.fixed_string_search_command(needle)
        rg =
          [
            ENV["RG_PATH"],
            Rails.root.join("bin/rg").to_s,
            "/usr/bin/rg",
            "/bin/rg",
          ].compact.find { |candidate| File.executable?(candidate) }

        if rg
          return [rg, "--fixed-strings", needle, "app", "lib", "config", "test"]
        end

        ["git", "grep", "-F", "-n", "--", needle, "--", "app", "lib", "config", "test"]
      end

      def self.excluded_lib_path?(relative_path)
        relative_path.start_with?(*LIB_EXCLUDED_PREFIXES)
      end

      private

      def collisions_for(mappings)
        mappings.group_by { |mapping| yield(mapping) }.select { |_key, matches| matches.many? }
      end

      def collision_message(kind, collisions)
        return "" if collisions.empty?

        collisions.map do |key, matches|
          "#{kind} collision #{key}: #{matches.map(&:old_path).join(", ")}"
        end.join("\n")
      end
    end
  end
end
