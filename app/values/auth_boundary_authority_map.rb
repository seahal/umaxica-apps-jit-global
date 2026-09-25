# typed: false
# frozen_string_literal: true

# Canonical authority and RP surface map for the Auth-boundary consolidation.
# Controllers and registries must converge on this map; tests assert its invariants.
module AuthBoundaryAuthorityMap
  module_function

  FIRST_PARTY_RP_CLIENT_IDS = %w(
    core-app
    core-com
    core-org
    side-app
    side-com
    side-org
    edit-org
  ).freeze

  # Approved expand-and-contract target. The active seven-client registry above remains in place
  # until each caller, URI, key namespace, and RP-session binding has migrated.
  REGIONAL_RP_CLIENT_IDS = %w(
    core-app-jp
    core-app-us
    core-com-jp
    core-com-us
    core-org-jp
    core-org-us
    side-app-jp
    side-app-us
    side-com-jp
    side-com-us
    side-org-jp
    side-org-us
  ).freeze

  APPROVED_RP_CLIENT_IDS = (REGIONAL_RP_CLIENT_IDS + ["edit-org"]).freeze

  APPROVED_RP_FACES = {
    "core-app-jp" => { surface: "core", face: "app", region: "jp", actor: "client" },
    "core-app-us" => { surface: "core", face: "app", region: "us", actor: "client" },
    "core-com-jp" => { surface: "core", face: "com", region: "jp", actor: "visitor" },
    "core-com-us" => { surface: "core", face: "com", region: "us", actor: "visitor" },
    "core-org-jp" => { surface: "core", face: "org", region: "jp", actor: "operator" },
    "core-org-us" => { surface: "core", face: "org", region: "us", actor: "operator" },
    "side-app-jp" => { surface: "warp", face: "app", region: "jp", actor: "client" },
    "side-app-us" => { surface: "warp", face: "app", region: "us", actor: "client" },
    "side-com-jp" => { surface: "warp", face: "com", region: "jp", actor: "visitor" },
    "side-com-us" => { surface: "warp", face: "com", region: "us", actor: "visitor" },
    "side-org-jp" => { surface: "warp", face: "org", region: "jp", actor: "operator" },
    "side-org-us" => { surface: "warp", face: "org", region: "us", actor: "operator" },
    "edit-org" => { surface: "edit", face: "org", region: nil, actor: "operator" },
  }.freeze

  DEPRECATED_SHARED_BROWSER_CLIENT_IDS = %w(
    sign-rp
    base-rails-rp
    side-rails-rp
    core-next-rp
  ).freeze

  RETIRED_BROWSER_PATHS = %w(
    /lobby
    /sign/out/complete
    /sign/in
    /sign/in/callback
  ).freeze

  RETIRED_AUTH_BROWSER_PATHS = %w(/dashboard).freeze

  RP_FACES = {
    "core-app" => { surface: "core", face: "app", actor: "client" },
    "core-com" => { surface: "core", face: "com", actor: "visitor" },
    "core-org" => { surface: "core", face: "org", actor: "operator" },
    "side-app" => { surface: "warp", face: "app", actor: "client" },
    "side-com" => { surface: "warp", face: "com", actor: "visitor" },
    "side-org" => { surface: "warp", face: "org", actor: "operator" },
    "edit-org" => { surface: "edit", face: "org", actor: "operator" },
  }.freeze

  CANONICAL_RP_CALLBACK_PATH = "/sign/callback"
  CANONICAL_RP_SIGN_IN_PATH = "/sign"
  CANONICAL_RP_SIGN_OUT_PATH = "/sign/out"

  AUTH_CEREMONY_FACES = %w(app com org).freeze
  BASE_AUTHORITY_FACES = %w(app com org).freeze

  def first_party_rp_client_ids
    FIRST_PARTY_RP_CLIENT_IDS
  end

  def approved_rp_client_ids
    APPROVED_RP_CLIENT_IDS
  end

  def approved_rp_faces
    APPROVED_RP_FACES
  end

  def deprecated_shared_browser_client_ids
    DEPRECATED_SHARED_BROWSER_CLIENT_IDS
  end

  def retired_browser_paths
    RETIRED_BROWSER_PATHS
  end

  def retired_auth_browser_paths
    RETIRED_AUTH_BROWSER_PATHS
  end

  def rp_faces
    RP_FACES
  end

  def unique_client_ids?
    FIRST_PARTY_RP_CLIENT_IDS.uniq.size == FIRST_PARTY_RP_CLIENT_IDS.size
  end

  def no_overlap_with_deprecated_ids?
    (FIRST_PARTY_RP_CLIENT_IDS & DEPRECATED_SHARED_BROWSER_CLIENT_IDS).empty?
  end

  def callback_path_for(_client_id)
    CANONICAL_RP_CALLBACK_PATH
  end

  def sign_out_path_for(_client_id)
    CANONICAL_RP_SIGN_OUT_PATH
  end

  def authority_surface
    "base"
  end

  def ceremony_surface
    "auth"
  end
end
