# typed: false
# frozen_string_literal: true

# Fixed process-to-cell bindings for R5. A request may carry a client identifier, but it never
# selects the database connection; callers resolve this value from trusted boot configuration.
class RpCellBinding
  Cell = Data.define(:connection, :client_id, :realm, :region, :record_prefix)

  CELLS = {
    "rp_base_app" => Cell.new(
      connection: "rp_base_app", client_id: "base-app-ww", realm: "app", region: "ww",
      record_prefix: "RpBaseApp",
    ),
    "rp_core_app" => Cell.new(
      connection: "rp_core_app", client_id: "core-app-jp", realm: "app", region: "jp",
      record_prefix: "RpCoreApp",
    ),
    "rp_warp_app" => Cell.new(
      connection: "rp_warp_app", client_id: "warp-app-jp", realm: "app", region: "jp",
      record_prefix: "RpWarpApp",
    ),
    "rp_palm_app" => Cell.new(
      connection: "rp_palm_app", client_id: "palm-app-jp", realm: "app", region: "jp",
      record_prefix: "RpPalmApp",
    ),
    "rp_base_com" => Cell.new(
      connection: "rp_base_com", client_id: "base-com-ww", realm: "com", region: "ww",
      record_prefix: "RpBaseCom",
    ),
    "rp_core_com" => Cell.new(
      connection: "rp_core_com", client_id: "core-com-jp", realm: "com", region: "jp",
      record_prefix: "RpCoreCom",
    ),
    "rp_warp_com" => Cell.new(
      connection: "rp_warp_com", client_id: "warp-com-jp", realm: "com", region: "jp",
      record_prefix: "RpWarpCom",
    ),
    "rp_base_org" => Cell.new(
      connection: "rp_base_org", client_id: "base-org-ww", realm: "org", region: "ww",
      record_prefix: "RpBaseOrg",
    ),
    "rp_core_org" => Cell.new(
      connection: "rp_core_org", client_id: "core-org-jp", realm: "org", region: "jp",
      record_prefix: "RpCoreOrg",
    ),
    "rp_warp_org" => Cell.new(
      connection: "rp_warp_org", client_id: "warp-org-jp", realm: "org", region: "jp",
      record_prefix: "RpWarpOrg",
    ),
    "rp_edit_org" => Cell.new(
      connection: "rp_edit_org", client_id: "edit-org-ww", realm: "org", region: "ww",
      record_prefix: "RpEditOrg",
    ),
    "rp_tech_org" => Cell.new(
      connection: "rp_tech_org", client_id: "tech-org-ww", realm: "org", region: "ww",
      record_prefix: "RpTechOrg",
    ),
  }.freeze

  class UnknownCell < KeyError; end

  class << self
    public

    def fetch(connection)
      CELLS.fetch(connection.to_s) { raise UnknownCell, "unknown RP cell connection: #{connection.inspect}" }
    end

    def for_client(client_id)
      cell = CELLS.values.find { |candidate| candidate.client_id == client_id.to_s }
      return cell if cell

      raise UnknownCell, "unknown RP client binding: #{client_id.inspect}"
    end

    def connections
      CELLS.keys
    end
  end
end
