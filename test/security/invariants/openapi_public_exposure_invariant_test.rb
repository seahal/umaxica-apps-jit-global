# typed: false
# frozen_string_literal: true

# rubocop:disable I18n/RailsI18n/DecorateString

require "test_helper"
# Same lazy require the contract tests use: `OpenapiContract` pulls in Committee, which is
# `require: false` in the Gemfile and is wanted on as few test files' load paths as possible.
require_relative "../../support/openapi_contract"

module Security
  module Invariants
    # The bundled OpenAPI descriptions enumerate every internal JSON endpoint, its parameters, and
    # its response shapes. They lived under `public/` until they were moved to `openapi/bundled/`,
    # and `public/` is served statically in development
    # (config/environments/development.rb sets public_file_server.enabled = true), so any file put
    # back there is readable, without a credential, from every host Host Authorization admits.
    #
    # The only intended HTTP reader is Swagger UI on swagger.umaxica.dev, which gets them through
    # rswag-api behind that host's Basic Auth (config/initializers/rswag_api.rb).
    #
    # Production has never served them (production.rb sets public_file_server.enabled = false), so
    # this invariant guards a development exposure. It is still worth pinning: `public/` is the
    # obvious place to put a generated document, and a future `redocly.yaml` edit or a hand-copied
    # file would reopen it silently.
    class OpenapiPublicExposureInvariantTest < ActiveSupport::TestCase
      self.fixture_table_names = []

      test "no OpenAPI description is present under public/" do
        exposed = Dir.glob(Rails.public_path.join("**", "openapi*.{yml,yaml,json}")).sort

        assert_empty exposed,
                     "OpenAPI descriptions found under public/: #{exposed.inspect}. public/ is served " \
                     "statically in development, so these are readable with no credential from every " \
                     "admitted host. The bundle belongs in #{OpenapiContract::BUNDLE_DIRECTORY}/, which " \
                     "rswag-api serves behind the swagger host's Basic Auth."
      end

      test "every surface description resolves inside the bundle directory and exists" do
        bundle_directory = Rails.root.join(OpenapiContract::BUNDLE_DIRECTORY)

        OpenapiContract::SURFACES.each do |surface|
          path = Pathname.new(OpenapiContract.schema_path(surface))

          assert_path_exists path,
                             "The #{surface} OpenAPI description is missing. Committee, Redocly, and " \
                             "rswag-ui all read this one file; regenerate it with `bun run openapi:bundle`."
          assert_equal bundle_directory.to_s, path.dirname.to_s,
                       "The #{surface} OpenAPI description resolved to #{path.dirname}, outside " \
                       "#{bundle_directory}. One directory is the point: Committee, Redocly, and Swagger " \
                       "UI must not drift onto separate copies."
        end
      end

      test "redocly bundles to the same directory the test suite reads" do
        redocly = YAML.safe_load_file(Rails.root.join("redocly.yaml"))
        outputs = redocly.fetch("apis").values.map { |api| api.fetch("output") }

        assert_equal OpenapiContract::SURFACES.size, outputs.size,
                     "redocly.yaml describes #{outputs.size} APIs but the suite validates against " \
                     "#{OpenapiContract::SURFACES.size} surfaces."

        outputs.each do |output|
          assert_equal OpenapiContract::BUNDLE_DIRECTORY, File.dirname(output),
                       "redocly.yaml writes a bundle to #{output}, which the test suite does not read. " \
                       "A bundle written anywhere else is either dead or a second, unguarded copy."
        end
      end
    end
  end
end

# rubocop:enable I18n/RailsI18n/DecorateString
