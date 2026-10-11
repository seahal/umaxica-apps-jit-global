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

  DEPRECATED_SHARED_BROWSER_CLIENT_IDS = %w(
    sign-rp
    base-rails-rp
    side-rails-rp
    core-next-rp
  ).freeze

  RETIRED_BROWSER_PATHS = %w(
    /dashboard
    /lobby
    /sign/out/complete
  ).freeze

  RP_FACES = {
    "core-app" => { surface: "core", face: "app", actor: "client" },
    "core-com" => { surface: "core", face: "com", actor: "visitor" },
    "core-org" => { surface: "core", face: "org", actor: "operator" },
    "side-app" => { surface: "side", face: "app", actor: "client" },
    "side-com" => { surface: "side", face: "com", actor: "visitor" },
    "side-org" => { surface: "side", face: "org", actor: "operator" },
    "edit-org" => { surface: "edit", face: "org", actor: "operator" },
  }.freeze

  CANONICAL_RP_CALLBACK_PATH = "/sign/in/callback"
  CANONICAL_RP_SIGN_IN_PATH = "/sign/in"
  CANONICAL_RP_SIGN_OUT_PATH = "/sign/out"

  AUTH_CEREMONY_FACES = %w(app com org).freeze
  BASE_AUTHORITY_FACES = %w(app com org).freeze

  def first_party_rp_client_ids
    FIRST_PARTY_RP_CLIENT_IDS
  end

  def deprecated_shared_browser_client_ids
    DEPRECATED_SHARED_BROWSER_CLIENT_IDS
  end

  def retired_browser_paths
    RETIRED_BROWSER_PATHS
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
