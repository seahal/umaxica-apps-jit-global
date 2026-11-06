# typed: false
# frozen_string_literal: true

# Canonical authority and RP surface map for the Auth-boundary consolidation.
# Controllers and registries must converge on this map; tests assert its invariants.
module AuthBoundaryAuthorityMap
  module_function

  FIRST_PARTY_RP_CLIENT_IDS = %w(
    core-app-jp
    core-org-jp
    warp-app-jp
    warp-org-jp
    edit-org-ww
    base-app-ww
    base-org-ww
    palm-app-jp
    tech-org-ww
  ).freeze

  BASE_SELF_RP_CLIENT_IDS = %w(base-app-ww base-org-ww).freeze

  # Approved RP faces include regional cells and global first-party surfaces.
  REGIONAL_RP_CLIENT_IDS = %w(
    core-app-jp
    core-app-us
    core-org-jp
    core-org-us
    warp-app-jp
    warp-app-us
    warp-org-jp
    warp-org-us
  ).freeze

  APPROVED_RP_CLIENT_IDS = (REGIONAL_RP_CLIENT_IDS + %w(edit-org-ww palm-app-jp tech-org-ww)).freeze

  APPROVED_RP_FACES = {
    "core-app-jp" => { surface: "core", face: "app", region: "jp", actor: "client" },
    "core-app-us" => { surface: "core", face: "app", region: "us", actor: "client" },
    "core-org-jp" => { surface: "core", face: "org", region: "jp", actor: "operator" },
    "core-org-us" => { surface: "core", face: "org", region: "us", actor: "operator" },
    "warp-app-jp" => { surface: "warp", face: "app", region: "jp", actor: "client" },
    "warp-app-us" => { surface: "warp", face: "app", region: "us", actor: "client" },
    "warp-org-jp" => { surface: "warp", face: "org", region: "jp", actor: "operator" },
    "warp-org-us" => { surface: "warp", face: "org", region: "us", actor: "operator" },
    "edit-org-ww" => { surface: "edit", face: "org", region: nil, actor: "operator" },
    "palm-app-jp" => { surface: "palm", face: "app", region: nil, actor: "client" },
    "tech-org-ww" => { surface: "tech", face: "org", region: nil, actor: "operator" },
  }.freeze

  DEPRECATED_SHARED_BROWSER_CLIENT_IDS = %w(
    sign-rp
    base-rails-rp
  ).freeze

  RETIRED_BROWSER_PATHS = %w(
    /lobby
    /sign/out/complete
    /sign/in
    /sign/in/callback
  ).freeze

  RETIRED_AUTH_BROWSER_PATHS = %w(/dashboard).freeze

  RP_FACES = {
    "core-app-jp" => { surface: "core", face: "app", actor: "client" },
    "core-org-jp" => { surface: "core", face: "org", actor: "operator" },
    "warp-app-jp" => { surface: "warp", face: "app", actor: "client" },
    "warp-org-jp" => { surface: "warp", face: "org", actor: "operator" },
    "edit-org-ww" => { surface: "edit", face: "org", actor: "operator" },
    "base-app-ww" => { surface: "base", face: "app", actor: "client" },
    "base-org-ww" => { surface: "base", face: "org", actor: "operator" },
    "palm-app-jp" => { surface: "palm", face: "app", actor: "client" },
    "tech-org-ww" => { surface: "tech", face: "org", actor: "operator" },
  }.freeze

  CANONICAL_RP_CALLBACK_PATH = "/oidc/callback"
  BASE_STEP_UP_CALLBACK_PATHS = {
    "base-app-ww" => "/verification/oidc/callback",
    "base-org-ww" => "/verification/oidc/callback",
  }.freeze
  CANONICAL_RP_SIGN_IN_PATH = "/sign"
  CANONICAL_RP_SIGN_OUT_PATH = "/sign/out/completion"

  AUTH_CEREMONY_FACES = %w(app org).freeze
  BASE_AUTHORITY_FACES = %w(app org).freeze

  def first_party_rp_client_ids
    FIRST_PARTY_RP_CLIENT_IDS
  end

  def base_self_rp_client_ids
    BASE_SELF_RP_CLIENT_IDS
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

  def step_up_callback_path_for(client_id)
    BASE_STEP_UP_CALLBACK_PATHS.fetch(client_id.to_s) do
      raise KeyError, "no registered Base step-up callback for #{client_id.inspect}"
    end
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
