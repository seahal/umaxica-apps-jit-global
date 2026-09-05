# typed: false
# frozen_string_literal: true

require "test_helper"

module Security
  class PublicEntrypointInventoryTest < ActiveSupport::TestCase
    self.fixture_table_names = []

    APP_CONTROLLER_PREFIXES = %w(
      auth base core side docs help info news palm
    ).freeze

    APPLICATION_CLASS_PREFIXES = %w(
      Auth:: Base:: Core:: Side:: Docs:: Help:: Info:: News:: Palm::
    ).freeze

    PUBLIC_MODES = %i(bare open guest).freeze
    PRIVATE_MODES = %i(private deny_all).freeze

    DOCUMENT_PATH = Rails.root.join("docs/security/public-entrypoints.md")
    DOCUMENTED_CATEGORY_IDS = %w(
      PUBLIC_ROOTS
      PUBLIC_HEALTH
      PUBLIC_REVISION
      PUBLIC_CSP_REPORTS
      PUBLIC_WELL_KNOWN
      PUBLIC_ROBOTS_SITEMAPS
      PUBLIC_PWA_OFFLINE
      PUBLIC_CONTENT_READ_APIS
      PUBLIC_PREFERENCE
      PUBLIC_WEB_EDGE
      PUBLIC_OAUTH_OIDC_SSO
      PUBLIC_SIGN_IN_UP
      PUBLIC_SIGN_OUT
      PUBLIC_WITHDRAWAL
      PUBLIC_IDENTITY_RECOVERY
      PUBLIC_SOCIAL
      PUBLIC_AUTH_APP_REDIRECTS
      PUBLIC_AUTH_APP_SETTINGS_COMPAT
      PUBLIC_CORE_API
      PUBLIC_PALM_API
      PUBLIC_AUTH_ORG_REDIRECTS
      PUBLIC_SIDE_SETTINGS
      PUBLIC_APPLE_NOTIFICATIONS
      PUBLIC_MCP
    ).freeze

    RouteEntry = Struct.new(:verb, :path, :controller_path, :action, :controller_class, :mode, keyword_init: true)

    test "public entrypoint documentation names every enforced category" do
      content = File.read(DOCUMENT_PATH)

      DOCUMENTED_CATEGORY_IDS.each do |category_id|
        assert_includes content, "`#{category_id}`"
      end
    end

    test "application routes resolve to locally declared authentication modes" do
      missing =
        application_route_entries.filter_map do |entry|
          next if local_authentication_declaration?(entry.controller_class)

          "#{entry.verb} #{entry.path} => #{entry.controller_path}##{entry.action}"
        end

      assert_empty missing, "Application routes must declare authentication mode locally:\n#{missing.join("\n")}"
    end

    test "public application routes are covered by the documented public categories" do
      undocumented =
        application_route_entries.filter_map do |entry|
          next unless PUBLIC_MODES.include?(entry.mode)
          next if documented_public_category(entry)

          "#{entry.mode} #{entry.verb} #{entry.path} => #{entry.controller_path}##{entry.action}"
        end

      assert_empty undocumented, "Public routes need a documented category:\n#{undocumented.join("\n")}"
    end

    test "private and deny-all routes are not public entrypoints" do
      wrongly_public =
        application_route_entries.filter_map do |entry|
          next unless PRIVATE_MODES.include?(entry.mode)
          next unless documented_public_category(entry)

          "#{entry.mode} #{entry.verb} #{entry.path} => #{entry.controller_path}##{entry.action}"
        end

      assert_empty wrongly_public, "Private routes must not match public categories:\n#{wrongly_public.join("\n")}"
    end

    test "PUBLIC_PWA_OFFLINE covers exactly the two Rails PWA endpoints" do
      # Rails::PwaController is a framework controller, so these routes are outside
      # application_route_entries by construction. They are still public entrypoints, so the category
      # is enforced here instead. See adr/pwa-offline-route-exception.md.
      entries =
        Rails.application.routes.routes.filter_map do |route|
          controller_path = route.defaults[:controller].to_s
          next unless controller_path == "rails/pwa"

          [route.verb, route.path.spec.to_s.sub(/\(\.:format\)\z/, ""), route.defaults[:action].to_s]
        end

      assert_equal 20, entries.size, "expected two PWA endpoints on each of the ten base/auth/side/palm hosts"
      assert_equal ["GET"], entries.map(&:first).uniq
      assert_equal(
        [["/offline", "offline"], ["/service-worker", "service_worker"]],
        entries.map { |entry| entry.drop(1) }.uniq.sort,
      )
    end

    private

    def application_route_entries
      Rails.application.routes.routes.filter_map do |route|
        controller_path = route.defaults[:controller].to_s
        action = route.defaults[:action].to_s
        next if controller_path.blank? || action.blank?
        next unless application_controller_path?(controller_path)

        controller_class = "#{controller_path.camelize}Controller".safe_constantize
        mode = authentication_mode(controller_class, action)

        RouteEntry.new(
          verb: route.verb.presence || "ANY",
          path: route.path.spec.to_s.sub(/\(\.:format\)\z/, ""),
          controller_path: controller_path,
          action: action,
          controller_class: controller_class,
          mode: mode,
        )
      end
    end

    def application_controller_path?(controller_path)
      APP_CONTROLLER_PREFIXES.any? { |prefix| controller_path.start_with?("#{prefix}/") }
    end

    def authentication_mode(controller_class, action)
      flunk("Missing controller class for application route") if controller_class.blank?
      flunk("Unexpected controller class #{controller_class.name}") unless
        application_controller_class?(controller_class)

      if controller_class.respond_to?(:authentication_mode_for)
        controller_class.authentication_mode_for(action)
      elsif controller_class.const_defined?(:AUTHENTICATION_MODE, false)
        controller_class.const_get(:AUTHENTICATION_MODE, false)
      else
        flunk("#{controller_class.name} does not expose authentication mode metadata")
      end
    end

    def application_controller_class?(controller_class)
      controller_class.name.start_with?(*APPLICATION_CLASS_PREFIXES)
    end

    def local_authentication_declaration?(controller_class)
      controller_class.const_defined?(:AUTHENTICATION_MODE, false) ||
        (controller_class.respond_to?(:local_authentication_mode_rules) &&
          controller_class.local_authentication_mode_rules.present?)
    end

    def documented_public_category(entry)
      return false unless PUBLIC_MODES.include?(entry.mode)

      documented_public_content?(entry) || documented_public_auth?(entry) || documented_public_api?(entry)
    end

    def documented_public_content?(entry)
      public_root?(entry) ||
        public_health?(entry) ||
        public_revision?(entry) ||
        public_csp_report?(entry) ||
        public_well_known?(entry) ||
        public_robots_or_sitemap?(entry) ||
        public_content_read_api?(entry) ||
        public_preference?(entry) ||
        public_web_or_edge?(entry)
    end

    def documented_public_auth?(entry)
      public_oauth_oidc_or_sso?(entry) ||
        public_sign_in_or_up?(entry) ||
        public_sign_out?(entry) ||
        public_withdrawal?(entry) ||
        public_identity_recovery?(entry) ||
        public_social?(entry) ||
        public_auth_app_redirect?(entry) ||
        public_auth_app_settings_compat?(entry)
    end

    def documented_public_api?(entry)
      public_core_api?(entry) ||
        public_palm_api?(entry) ||
        public_auth_org_redirect?(entry) ||
        public_side_settings?(entry) ||
        public_apple_notification?(entry) ||
        public_mcp?(entry)
    end

    # Base and Side only. Auth and the content surfaces do not serve MCP, so an MCP route appearing
    # under them is an undocumented entrypoint rather than a covered one.
    def public_mcp?(entry)
      post?(entry) && entry.path == "/mcp" &&
        entry.controller_path.match?(%r{\A(base|side)/(app|com|org)/mcps\z})
    end

    def public_root?(entry) = get?(entry) && entry.path == "/"

    def public_health?(entry)
      get?(entry) && (entry.path.start_with?("/health") || entry.path == "/api/v0/health.json")
    end

    def public_revision?(entry)
      get?(entry) && ["/revision", "/api/v0/revision.json"].include?(entry.path)
    end

    def public_csp_report?(entry) = post?(entry) && entry.path == "/csp-violation-report"

    def public_well_known?(entry) = get?(entry) && entry.path.start_with?("/.well-known/")

    def public_robots_or_sitemap?(entry) = get?(entry) && ["/robots.txt", "/sitemap.xml"].include?(entry.path)

    def public_content_read_api?(entry)
      return false unless get?(entry)

      entry.controller_path.start_with?("docs/", "help/", "info/", "news/") &&
        (entry.path == "/" || entry.path.start_with?("/api/v0/entries"))
    end

    def public_preference?(entry) = entry.path.start_with?("/preference")

    def public_web_or_edge?(entry) = entry.path.start_with?("/web/v0/", "/edge/v0/")

    def public_oauth_oidc_or_sso?(entry)
      entry.path.start_with?("/oauth", "/oidc", "/sso", "/auth/")
    end

    def public_sign_in_or_up?(entry)
      entry.path.start_with?("/sign/in", "/sign/up", "/web/v0/in/")
    end

    def public_sign_out?(entry)
      entry.path.start_with?("/sign/out") || entry.controller_path.end_with?("/sign_outs", "/sign/outs")
    end

    def public_withdrawal?(entry)
      (entry.path.start_with?("/identity/withdrawal") &&
        entry.controller_path.match?(%r{\Abase/(app|com)/identity/withdrawal(?:s|/sessions)\z})) ||
        (entry.path.start_with?("/identity/privacy/erasure") &&
          entry.controller_path.match?(%r{\Abase/(app|com)/identity/privacy/erasure(?:s|/statuses)\z}))
    end

    def public_identity_recovery?(entry)
      entry.path.start_with?("/identity/recovery") &&
        entry.controller_path.match?(%r{\Abase/(app|com)/identity/(?:recoveries|recovery/)})
    end

    def public_social?(entry)
      entry.path.start_with?("/social") || entry.controller_path.match?(%r{\A(auth|base)/app/social/})
    end

    def public_auth_app_redirect?(entry)
      get?(entry) && entry.controller_path == "auth/app/billings" && entry.path == "/billings"
    end

    def public_auth_app_settings_compat?(entry)
      entry.controller_path.start_with?("auth/app/settings/") && entry.path.start_with?("/settings/")
    end

    def public_core_api?(entry)
      entry.controller_path.start_with?("core/") &&
        ((get?(entry) && entry.path == "/api/v0/session") ||
          (post?(entry) && entry.path == "/api/v0/token/refresh"))
    end

    def public_palm_api?(entry)
      get?(entry) && entry.controller_path.start_with?("palm/") && entry.path == "/api/v0/profile"
    end

    def public_auth_org_redirect?(entry)
      return false unless get?(entry)

      entry.controller_path.start_with?("auth/org/") &&
        %w(/accounts /audit /billing /configuration /iam /support /system).include?(entry.path)
    end

    def public_side_settings?(entry)
      get?(entry) && entry.controller_path.start_with?("side/") && entry.path == "/settings"
    end

    def public_apple_notification?(entry) = post?(entry) && entry.path == "/apple/notifications"

    def get?(entry) = route_allows?(entry, "GET")

    def post?(entry) = route_allows?(entry, "POST")

    def route_allows?(entry, verb)
      entry.verb.split("|").include?(verb)
    end
  end
end
