# typed: false
# frozen_string_literal: true

require "test_helper"

class XperRetiredHostsTest < ActionDispatch::IntegrationTest
  rate_limit_counters!

  RETIRED_HOSTS = %w(
    umaxica.app
    umaxica.com
    umaxica.org
    xper.app.localhost
    xper.com.localhost
    xper.org.localhost
  ).freeze

  REQUESTS = [
    [:get, "/", {}],
    [:get, "/health", {}],
    [:get, "/revision", {}],
    [:get, "/api/v0/health.json", { headers: { "Accept" => "application/json" } }],
    [:get, "/api/v0/revision.json", { headers: { "Accept" => "application/json" } }],
    [:post, "/csp-violation-report", { headers: { "CONTENT_TYPE" => "application/csp-report" } }],
    [:get, "/robots.txt", {}],
    [:get, "/sitemap.xml", {}],
  ].freeze

  SURFACE_CONTROLLER_NAMESPACES = %w(
    auth base core docs edit guid help info news palm warp xper
  ).freeze

  RETAINED_HOST = "base.app.localhost"

  test "retired Xper hosts do not reach any surface controller" do
    RETIRED_HOSTS.each do |host|
      REQUESTS.each do |method, path, options|
        host!(host)
        public_send(method, path, **options)

        controller = request.path_parameters[:controller].to_s
        served_by_surface =
          SURFACE_CONTROLLER_NAMESPACES.any? do |namespace|
            controller.start_with?("#{namespace}/")
          end

        assert_not served_by_surface, "#{host} #{method.upcase} #{path} reached #{controller.inspect}"
      end
    end
  end

  test "a retained Base host still owns the same endpoint paths" do
    REQUESTS.each do |method, path, options|
      host!(RETAINED_HOST)
      public_send(method, path, **options)

      assert_match(/\Abase\/app\//, request.path_parameters.fetch(:controller))
      assert_response :success
    end
  end
end
