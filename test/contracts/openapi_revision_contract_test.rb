# frozen_string_literal: true

require "test_helper"
require_relative "../support/openapi_contract"

# Validates the machine-readable deployment identifier `GET /api/v0/revision.json` against each
# surface description.
#
# The text `GET /revision` endpoint answers `text/plain` and is not described: only this JSON
# representation is a contract. Both derive the same value from `Rails.application.revision`.
class OpenapiRevisionContractTest < ActionDispatch::IntegrationTest
  include OpenapiContract

  REVISION = "0123456789abcdef0123456789abcdef01234567"

  SURFACE_HOSTS = {
    "app" => ENV.fetch("PRIVATE_CORE_SERVICE_URL"),
    "com" => ENV.fetch("PRIVATE_CORE_CORPORATE_URL"),
    "org" => ENV.fetch("PRIVATE_CORE_STAFF_URL"),
  }.freeze

  SURFACE_HOSTS.each do |surface, host|
    test "GET /api/v0/revision.json conforms to the #{surface} description with a revision" do
      self.openapi_surface = surface
      host! host

      Rails.application.stub(:revision, REVISION) do
        get "/api/v0/revision.json", headers: { "Accept" => "application/json" }
      end

      assert_response :success
      assert_equal "application/json", response.media_type
      assert_equal({ "revision" => REVISION }, response.parsed_body)
      assert_openapi_conform 200
    end

    test "GET /api/v0/revision.json conforms to the #{surface} description with a null revision" do
      self.openapi_surface = surface
      host! host

      Rails.application.stub(:revision, nil) do
        get "/api/v0/revision.json", headers: { "Accept" => "application/json" }
      end

      assert_response :success
      assert_equal({ "revision" => nil }, response.parsed_body)
      assert_openapi_conform 200
    end

    test "GET /api/v0/revision.json refuses a non-JSON Accept with 406 and an empty body on #{surface}" do
      self.openapi_surface = surface
      host! host

      Rails.application.stub(:revision, REVISION) do
        get "/api/v0/revision.json", headers: { "Accept" => "text/plain" }
      end

      assert_response :not_acceptable
      assert_empty response.body
      assert_equal "no-store", response.headers["Cache-Control"]
    end
  end

  test "the revision member is described as a nullable string on every surface" do
    SURFACE_HOSTS.each_key do |surface|
      document = YAML.safe_load_file(OpenapiContract.schema_path(surface), aliases: true)
      get_op = document.dig("paths", "/api/v0/revision.json", "get")

      assert get_op, "#{surface} description is missing GET /api/v0/revision.json"

      schema = resolve_revision_schema(document, get_op)

      assert_equal "string", schema.fetch("type")
      assert schema.fetch("nullable"),
             "#{surface} revision member must be nullable: true (OpenAPI 3.0.4)"
    end
  end

  private

  def resolve_revision_schema(document, get_op)
    body_schema = get_op.dig("responses", "200", "content", "application/json", "schema")
    body_schema = dereference(document, body_schema)
    revision = body_schema.fetch("properties").fetch("revision")
    dereference(document, revision)
  end

  def dereference(document, node)
    ref = node["$ref"]
    return node unless ref

    pointer = ref.delete_prefix("#/").split("/")
    document.dig(*pointer)
  end
end
