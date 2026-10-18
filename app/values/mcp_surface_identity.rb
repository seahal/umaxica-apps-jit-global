# typed: false
# frozen_string_literal: true

# Identifies which realm and surface an MCP endpoint belongs to.
#
# Every MCP endpoint serves exactly one realm/surface pair. The pair is declared by the concrete
# controller and handed to the tool layer through `server_context`, so a tool never re-derives the
# surface from `request.host`. That keeps the six endpoints from leaking into one another even
# though they share one tool implementation, and it keeps request state out of globals.
class McpSurfaceIdentity
  REALMS = %w(base warp).freeze
  SURFACES = %w(app com org).freeze

  attr_reader :realm, :surface

  def initialize(realm:, surface:)
    @realm = realm.to_s
    @surface = surface.to_s

    raise ArgumentError, "unsupported MCP realm: #{@realm}" unless REALMS.include?(@realm)
    raise ArgumentError, "unsupported MCP surface: #{@surface}" unless SURFACES.include?(@surface)

    freeze
  end

  # Health profiles are keyed by surface, not by realm: every realm probes the same surface
  # dependency allowlist. Listing all three explicitly keeps this exhaustive; an unsupported value
  # cannot reach here because the constructor already rejects it.
  def health_profile
    case surface
    when "app" then ::Health::Profiles::App
    when "com" then ::Health::Profiles::Com
    when "org" then ::Health::Profiles::Org
    else raise ArgumentError, "unsupported MCP surface: #{surface}"
    end
  end

  # Name reported to MCP clients as the server identity.
  def server_name
    "umaxica-#{realm}-#{surface}"
  end

  def as_public_json
    { realm: realm, surface: surface }
  end

  def ==(other)
    other.is_a?(self.class) && other.realm == realm && other.surface == surface
  end
  alias eql? ==

  def hash
    [self.class, realm, surface].hash
  end
end
