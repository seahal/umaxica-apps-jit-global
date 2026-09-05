# frozen_string_literal: true

require "test_helper"
require_relative "../support/openapi_contract"

# A structural regression guard for the bundled OpenAPI descriptions, independent of any single
# endpoint.
#
# `OpenapiRouteCoverageTest` proves the router and the descriptions agree on which operations
# exist; the per-endpoint contract tests prove individual payloads conform. Neither catches a
# description that is the wrong OpenAPI version, carries 3.1-only syntax that 3.0 tooling silently
# ignores (the defect repaired when the entry schemas moved off `openapi: 3.2.0`), reuses an
# `operationId`, or has a dangling `$ref`.
class OpenapiDocumentValidityTest < ActiveSupport::TestCase
  SURFACES = OpenapiContract::SURFACES

  # Members that only exist in OpenAPI 3.1 / JSON Schema 2020-12. `nullable: true` is the 3.0 way
  # to say "or null"; `type: [..., "null"]`, `const:`, `prefixItems:`, and `$schema:` inside a
  # schema all signal a document that was authored against the wrong dialect.
  THREE_ONE_ONLY = %w($schema const prefixItems unevaluatedProperties patternProperties).freeze

  SURFACES.each do |surface|
    test "the #{surface} description is OpenAPI 3.0.x" do
      document = load(surface)
      version = document.fetch("openapi")

      assert_match(/\A3\.0\.\d+\z/, version, "#{surface} description is #{version}, not OpenAPI 3.0.x")
    end

    test "the #{surface} description carries no OpenAPI 3.1-only syntax" do
      raw = File.read(OpenapiContract.schema_path(surface))

      THREE_ONE_ONLY.each do |token|
        assert_no_match(
          /^\s*#{Regexp.escape(token)}:/, raw,
          "#{surface} description uses the 3.1-only keyword #{token}",
        )
      end

      # `type: ["string", "null"]` (inline or block sequence) is the 3.1 nullable form.
      assert_no_match(/type:\s*\[.*null.*\]/, raw, "#{surface} description uses 3.1 union-with-null typing")
      each_schema(load(surface)) do |schema|
        next unless schema.is_a?(Hash)

        assert_not schema["type"].is_a?(Array),
                   "#{surface} description declares an array `type` (3.1 union), not `nullable: true`"
      end
    end

    test "the #{surface} description has no duplicate operationId" do
      ids = operation_ids(load(surface))

      assert_equal ids.uniq.sort, ids.sort,
                   "#{surface} description reuses operationId(s): #{ids.tally.select { |_, n| n > 1 }.keys.join(", ")}"
    end

    test "every $ref in the #{surface} description resolves" do
      document = load(surface)
      dangling = []

      each_ref(document) do |ref|
        next unless ref.start_with?("#/")

        pointer = ref.delete_prefix("#/").split("/").map { |seg| seg.gsub("~1", "/").gsub("~0", "~") }
        dangling << ref if document.dig(*pointer).nil?
      end

      assert_empty dangling, "#{surface} description has unresolvable $ref(s): #{dangling.uniq.join(", ")}"
    end
  end

  private

  def load(surface)
    YAML.safe_load_file(OpenapiContract.schema_path(surface), aliases: true)
  end

  def operation_ids(node, acc = [])
    case node
    when Hash
      acc << node["operationId"] if node.key?("operationId")
      node.each_value { |value| operation_ids(value, acc) }
    when Array
      node.each { |value| operation_ids(value, acc) }
    end
    acc
  end

  def each_ref(node, &)
    case node
    when Hash
      node.each { |key, value| (key == "$ref") ? yield(value) : each_ref(value, &) }
    when Array
      node.each { |value| each_ref(value, &) }
    end
  end

  def each_schema(node, &)
    case node
    when Hash
      yield node
      node.each_value { |value| each_schema(value, &) }
    when Array
      node.each { |value| each_schema(value, &) }
    end
  end
end
