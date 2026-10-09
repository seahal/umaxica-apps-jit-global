# typed: false
# frozen_string_literal: true

# MCP tool exposing the deployment identifier.
#
# Discloses exactly what the existing `PUBLIC_REVISION` entrypoint discloses and no more: the
# deployment revision, read from `Rails.application.revision`, with no database, actor, session, or
# environment access. Returns a null revision when none is set rather than substituting a
# placeholder.
class McpVersionTool < MCP::Tool
  tool_name "system_version"
  title "Deployment revision"
  # MCP tool metadata is protocol payload consumed by MCP clients, not user-facing UI copy, so it
  # is not localized.
  description "Returns the deployment revision identifier of this application." # rubocop:disable I18n/RailsI18n/DecorateString

  input_schema(properties: {}, required: [])

  annotations(read_only_hint: true, destructive_hint: false, idempotent_hint: true)

  class << self
    # The SDK always passes `server_context:`; the revision is surface-independent, so this tool
    # ignores it rather than pretending to vary by surface.
    def call(server_context:)
      revision = Rails.application.revision&.to_s

      MCP::Tool::Response.new([{ type: "text", text: { revision: revision }.to_json }])
    end
  end
end
