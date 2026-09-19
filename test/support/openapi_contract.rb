# frozen_string_literal: true

# Committee is declared `require: false` in the Gemfile, and only the contract tests need it.
# Requiring it here rather than from `test_helper.rb` keeps it off the load path of the other
# ~1490 test files.
require "committee"
require "committee/rails/test/methods"

# Validates a request and the response it produced against the bundled OpenAPI description for the
# surface under test.
#
# The descriptions in `openapi/bundled/openapi.{app,com,org}.yml` are the source of truth for the JSON API
# (adr/api-versioning-and-client-conventions.md section 4). Before this module existed nothing read
# them, so the accuracy requirement in that ADR had no enforcement and the descriptions drifted.
#
# `Committee::Rails::Test::Methods` is a thin adapter: it supplies `committee_options`,
# `request_object`, and `response_data` from `integration_session`. Its README carries "Looking for
# maintainers!", so the coupling is kept to this one file; if the gem is abandoned, those three
# methods can be defined here against `committee` directly.
module OpenapiContract
  extend ActiveSupport::Concern
  include Committee::Rails::Test::Methods

  SURFACES = %w(app com org).freeze

  # The one directory every consumer reads the bundled descriptions from: Committee here, Redocly
  # on write (redocly.yaml), and rswag-api when it serves them to Swagger UI
  # (config/initializers/rswag_api.rb). Deliberately outside `public/`, which development serves
  # statically and without credentials.
  BUNDLE_DIRECTORY = "openapi/bundled"

  # Committee caches parsed schemas by path and content digest, so this is read once per process.
  def self.schema_path(surface)
    unless SURFACES.include?(surface.to_s)
      raise ArgumentError, "unknown OpenAPI surface: #{surface.inspect} (expected one of #{SURFACES.join(", ")})"
    end

    Rails.root.join(BUNDLE_DIRECTORY, "openapi.#{surface}.yml").to_s
  end

  class_methods do
    # Declares which surface description this test class validates against. Surfaces are
    # independent trust boundaries with their own description, so there is no default: a test that
    # does not say which one it exercises cannot be validated against the right contract.
    def openapi_surface(surface = nil)
      @openapi_surface = surface.to_s if surface
      @openapi_surface
    end
  end

  # Per-test override, for a class that exercises the same endpoint on more than one surface.
  # `/api/v0/entries` is served by four services on all three surfaces, and one class covering all
  # twelve is clearer than twelve classes.
  def openapi_surface=(surface)
    @openapi_surface = surface.to_s
    # `schema`, `router`, and `schema_validator` are memoised per test instance and all derive from
    # the surface, so switching surfaces has to drop them.
    @schema = nil
    @router = nil
    reset_committee_memoisation!
  end

  def openapi_surface
    @openapi_surface || self.class.openapi_surface ||
      raise(
        ArgumentError,
        "#{self.class.name} must declare `openapi_surface :app | :com | :org`, or set it per test",
      )
  end

  def committee_options
    {
      schema_path: OpenapiContract.schema_path(openapi_surface),
      # Fails the load when a `$ref` points at nothing, instead of validating against a silently
      # empty schema. Committee warns when this is unset because it becomes the default in the
      # next major version.
      strict_reference_validation: true,
      # Committee 5 validates the request as well as the response; `old_assert_behavior` would
      # skip the request half.
      old_assert_behavior: false,
    }
  end

  # `assert_schema_conform` memoises `request_object` and `schema_validator` on the test instance,
  # so a second request in the same test would otherwise be checked against the first request's
  # operation. Clearing both makes the assertion safe to call once per request.
  #
  # Passing the expected status is mandatory in practice: omitting it makes Committee emit a
  # `need_good_option` warning and skips the status check entirely.
  def assert_openapi_conform(expected_status)
    reset_committee_memoisation!

    assert_schema_conform(expected_status)
  end

  # Validates the response only.
  #
  # Use this when the request is deliberately invalid -- a missing required header, a malformed
  # body -- and the response under test is the refusal. Checking such a request against the schema
  # asserts that an intentionally broken request is well formed, which is meaningless, and
  # Committee correctly raises `InvalidRequest` before it ever looks at the response.
  def assert_openapi_response_conform(expected_status)
    reset_committee_memoisation!

    assert_response_schema_confirm(expected_status)
  end

  private

  def reset_committee_memoisation!
    @request_object = nil
    @schema_validator = nil
  end
end
