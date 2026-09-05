# frozen_string_literal: true

require "test_helper"
require_relative "../support/openapi_contract"

# Holds the bundled OpenAPI descriptions and the router to the same set of endpoints, in both
# directions.
#
# Committee catches a documented endpoint whose payload is wrong, and it raises when a request is
# made to a path the description omits. Neither notices an endpoint the tests never call. This test
# closes that gap: it reads the router rather than the test suite, so a route added without a
# corresponding description fails here even if nobody writes a request test for it.
#
# The failure this guards against is the one recorded in
# adr/api-versioning-and-client-conventions.md: a description that names routes the router does not
# serve, or omits routes it does.
class OpenapiRouteCoverageTest < ActiveSupport::TestCase
  # Paths the descriptions are responsible for. Everything else the router serves -- HTML ceremony
  # routes, OAuth, OIDC, WebAuthn, DBSC, MCP, `.well-known` -- is out of scope by
  # docs/reference/api-design-standards.md, and `/edge/v0` and `/web/v0` are deferred until they
  # converge on `/api/v0` (adr/api-route-vocabulary-consolidation.md).
  DESCRIBED_PREFIXES = %r{\A/(api/v0|health)(/|\z)}

  # The text operational endpoints render `text/plain` and do not negotiate
  # (`HealthCheckRendering#render_snapshot` / `#render_probe`). They are not part of a JSON
  # contract, so they are deliberately absent from the descriptions; only the machine-readable
  # `/api/v0/health.json` and `/api/v0/revision.json` are described.
  TEXT_ONLY_PATHS = ["/health", "/health/startup", "/health/liveness", "/health/readiness"].freeze

  # Surfaces with their own description. `net` and `dev` are internal-only and have none.
  SURFACES = OpenapiContract::SURFACES

  test "every described surface has a bundled description that parses" do
    SURFACES.each do |surface|
      path = OpenapiContract.schema_path(surface)

      assert_path_exists path, "missing bundled description for the #{surface} surface: #{path}"

      driver = Committee::Drivers.load_from_file(path, parser_options: { strict_reference_validation: true })

      # Committee only accepts OpenAPI 3.0.x; anything else raises OpenAPI3Unsupported on load.
      # Reaching this assertion is itself the version check.
      assert_kind_of Committee::Drivers::OpenAPI3::Schema, driver,
                     "the #{surface} description did not load as an OpenAPI 3 schema"
    end
  end

  test "no route the router serves is missing from its surface description" do
    SURFACES.each do |surface|
      undescribed = routed_operations(surface) - described_operations(surface)

      assert_empty undescribed,
                   "the #{surface} surface routes these operations but openapi/#{surface}.yml does not " \
                   "describe them: #{undescribed.to_a.sort.join(", ")}"
    end
  end

  test "no operation in a surface description is absent from the router" do
    SURFACES.each do |surface|
      unrouted = described_operations(surface) - routed_operations(surface)

      assert_empty unrouted,
                   "openapi/#{surface}.yml describes these operations but the #{surface} surface does " \
                   "not route them: #{unrouted.to_a.sort.join(", ")}"
    end
  end

  test "the surfaces differ only where the routes differ" do
    # Palm serves the app surface only, so `/api/v0/profile` must be app-only in the descriptions
    # too. This is the concrete case that a single shared description could not express.
    assert_includes described_operations("app"), "GET /api/v0/profile"
    assert_not_includes described_operations("com"), "GET /api/v0/profile"
    assert_not_includes described_operations("org"), "GET /api/v0/profile"
  end

  private

  # "<METHOD> <path>" for every in-scope route on the surface, with Rails' `:slug` rewritten to
  # OpenAPI's `{slug}`. Deduplicated: several services serve the same path on the same surface --
  # `/api/v0/entries` comes from docs, help, info, and news -- and the description states the path
  # once.
  def routed_operations(surface)
    Rails.application.routes.routes.filter_map { |route|
      name = route.name.to_s
      next unless name.include?("_#{surface}_")

      path = route.path.spec.to_s.sub(/\(\.:format\)\z/, "")
      next unless path.match?(DESCRIBED_PREFIXES)
      next if TEXT_ONLY_PATHS.include?(path)

      verb = route.verb.to_s
      next if verb.empty?

      "#{verb} #{path.gsub(/:(\w+)/) { "{#{Regexp.last_match(1)}}" }}"
    }.to_set
  end

  def described_operations(surface)
    document = YAML.safe_load_file(OpenapiContract.schema_path(surface), aliases: true)

    document.fetch("paths").flat_map { |path, item|
      item.keys.grep(/\A(get|put|post|delete|patch|head|options|trace)\z/).map do |method|
        "#{method.upcase} #{path}"
      end
    }.to_set
  end
end
