# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

module Security
  class AcmeRenameInventoryTest < ActiveSupport::TestCase
    self.fixture_table_names = []

    SEARCH_ROOTS = %w(app config lib test docs adr plans notes .github).freeze
    DNS_APEX_ALLOWLIST = [
      %r{\Aapp/services/core_cookie_domain\.rb\z},
      %r{\Atest/lib/core/cookie_domain_test\.rb\z},
      %r{\Aadr/acme-rp-boundary-naming\.md\z},
      %r{\Aadr/cookie-domain-scope-by-surface\.md\z},
      %r{\Aadr/split-into-regional-and-global-repos\.md\z},
      %r{\Adocs/security/cookie-domain-scope\.md\z},
      %r{\Adocs/security/refresh-token-rotation\.md\z},
      %r{\Adocs/architecture/preference\.md\z},
    ].freeze

    OLD_BOUNDARY_PATTERNS = [
      /\bApex\b/,
      /\bAPEX_(?:SERVICE|CORPORATE|STAFF|NETWORK|DEVELOPER)_URL\b/,
      /\bapex_(?:app|com|org|network|developer)\b/,
      %r{\bapp/controllers/apex/},
      %r{\bapp/views/apex/},
      %r{\bapp/views/layouts/apex/},
      %r{\bapp/assets/stylesheets/apex/},
      /module:\s*:apex\b/,
      /as:\s*:apex\b/,
      /umaxica-#{Regexp.escape("apex")}-/,
    ].freeze

    test "old Apex RP boundary names are absent outside DNS apex terminology" do
      offenders =
        scanned_files.flat_map do |path|
          relative = path.relative_path_from(Rails.root).to_s
          next [] if relative == "test/unit/security/acme_rename_inventory_test.rb"

          content = File.binread(path).encode("UTF-8", invalid: :replace, undef: :replace)

          content.each_line.with_index(1).filter_map do |line, line_number|
            next if dns_apex_line_allowed?(relative, line)
            next unless OLD_BOUNDARY_PATTERNS.any? { |pattern| line.match?(pattern) }

            "#{relative}:#{line_number}: #{line.strip}"
          end
        end

      assert_empty offenders, "Old Apex RP boundary names remain:\n#{offenders.join("\n")}"
    end

    test "Base route helpers and OIDC clients are present" do
      assert_respond_to Rails.application.routes.url_helpers, :base_app_root_path
      assert_respond_to Rails.application.routes.url_helpers, :base_com_root_path
      assert_respond_to Rails.application.routes.url_helpers, :base_org_root_path

      client_ids = OidcClientRegistry.client_ids

      assert_includes client_ids, "base-rails-rp"
      assert_not_includes client_ids, "apex_app"
      assert_not_includes client_ids, "apex_com"
      assert_not_includes client_ids, "apex_org"
    end

    private

    def scanned_files
      SEARCH_ROOTS.flat_map do |root|
        Rails.root.glob("#{root}/**/*").select { |path| path.file? && text_file?(path) }
      end
    end

    def text_file?(path)
      path.extname.in?(%w(.rb .erb .builder .yml .yaml .md .js .css .json .lock)) ||
        path.basename.to_s.in?(%w(Gemfile package.json pnpm-lock.yaml))
    end

    def dns_apex_line_allowed?(relative, line)
      DNS_APEX_ALLOWLIST.any? { |pattern| relative.match?(pattern) } &&
        line.match?(/\bapex(?:-| )?(?:domain|scope|scoped|terminology)|best_effort_apex|same apex\b/i)
    end
  end
end

# DAMP local route helper aliases for former shared test support.
class Security::AcmeRenameInventoryTest
  SURFACE_ROUTE_PREFIX_MAP = {
    "sign_app_" => "auth_app_",
    "sign_org_" => "auth_org_",
    "sign_com_" => "auth_com_",
    "acme_app_" => "base_app_",
    "acme_org_" => "base_org_",
    "acme_com_" => "base_com_",
  }.freeze unless const_defined?(:SURFACE_ROUTE_PREFIX_MAP, false)

  private

  def method_missing(name, ...)
    aliased_name = aliased_surface_route_helper_name(name)
    return public_send(aliased_name, ...) if aliased_name && respond_to?(aliased_name, true)

    super
  end

  def respond_to_missing?(name, include_private = false)
    aliased_name = aliased_surface_route_helper_name(name)
    (aliased_name && respond_to?(aliased_name, include_private)) || super
  end

  def aliased_surface_route_helper_name(name)
    helper_name = name.to_s
    self.class::SURFACE_ROUTE_PREFIX_MAP.each do |source_prefix, target_prefix|
      return helper_name.sub(source_prefix, target_prefix).to_sym if helper_name.start_with?(source_prefix)
    end
    nil
  end
end
