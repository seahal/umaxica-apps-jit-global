# frozen_string_literal: true

# The single trusted execution role of this process (docs/security/role-secret-isolation.md).
#
# A role decides which controllers this process serves and which private signing keys it requires.
# It is read once from the process environment at boot and is never derived from request input
# (Host, `ri`, token claims). An unknown role aborts boot.
#
# A role does not select credentials or a database login: every process reads the Rails-standard
# config/credentials/<env>.yml.enc and the same database.yml (user decision 2026-10-19,
# adr/runtime-secret-isolation-deferred.md).
module RuntimeRole
  # `shared` is the pre-R5 process that serves every surface. It is a bounded transitional role: it
  # exists only because the development container is intentionally not split (user decision
  # 2026-10-17) and every cell is still served by one listener. Exit condition: R5-WU19 cell activation, after which a
  # cell process must boot with its own `rp-*` role and never as `shared`.
  SHARED = "shared"

  # OP issuers: hold their realm's token signing key.
  OP_ROLES = %w(op-base-app op-base-com op-base-org).freeze
  # Auth ceremony hosts: hold OmniAuth, OTP, HMAC and sending secrets; no OP signer.
  AUTH_ROLES = %w(auth-app auth-com auth-org).freeze
  # Twelve JP-development RP cells (one.md section 5.1): each requires only its own client assertion
  # private key and serves only its own local store.
  RP_ROLES = %w(
    rp-base-app-ww rp-base-com-ww rp-base-org-ww rp-edit-org-ww rp-tech-org-ww
    rp-core-app-jp rp-core-com-jp rp-core-org-jp
    rp-warp-app-jp rp-warp-com-jp rp-warp-org-jp
    rp-palm-app-jp
  ).freeze
  # Canonical domain authorities: their own stores and protocol secrets only.
  DOMAIN_ROLES = %w(domain-publishing domain-avatar domain-org).freeze

  ALL = ([SHARED] + OP_ROLES + AUTH_ROLES + RP_ROLES + DOMAIN_ROLES).freeze

  class UnknownRole < ArgumentError; end

  module_function

  # Required: a process without an explicit role must not boot (no silent default to `shared`).
  def current
    name = ENV.fetch("UMAXICA_RUNTIME_ROLE")
    raise UnknownRole, "unknown runtime role: #{name.inspect}" unless ALL.include?(name)

    name
  end

  def shared?(name = current)
    name == SHARED
  end

  # The cell store connection of an RP role, e.g. rp-core-app-jp -> rp_core_app.
  def cell_connection(name = current)
    raise UnknownRole, "#{name} is not an RP cell role" unless RP_ROLES.include?(name)

    name.delete_prefix("rp-").split("-").first(2).unshift("rp").join("_")
  end

  # Private signing material an RP cell process may hold (one.md section 1: "RP execution has no OP
  # signing key"): its own private_key_jwt client key, its surface's Jump RT key, and the
  # preference cookie keyset every surface signs with. Public keysets are not restricted.
  def rp_private_env_names(name = current)
    raise UnknownRole, "#{name} is not an RP cell role" unless RP_ROLES.include?(name)

    family, realm, region = name.delete_prefix("rp-").split("-")
    client_namespace = (family == "base") ? "BASE_RP_#{realm}_#{region}" : "#{family}_#{realm}_#{region}"
    surface_namespace = "#{family}_#{realm}"
    [
      "OIDC_CLIENT_#{client_namespace.upcase}_PRIVATE_KEY",
      "JWT_#{surface_namespace.upcase}_PRIVATE_KEY",
      "PREFERENCE_JWT_PRIVATE_KEYSET",
    ].freeze
  end

  BROWSER_ADMISSION_STATES = %w(open closed).freeze
  # Controllers an RP cell serves while its browser entry is closed (R5-WU19): protocol-only
  # back-channel logout receivers, so durable revocation can still land, and process health.
  CLOSED_CELL_PATHS = %r{/(oidc/closures|health|healths|revisions)\z}

  # The cell's trusted local deployment admission; required in every rp-* process, never derived
  # from a request. A new cell process starts closed until its exact manifest is enabled.
  def rp_browser_admission_open?
    state = ENV.fetch("UMAXICA_RP_BROWSER_ADMISSION")
    raise UnknownRole, "UMAXICA_RP_BROWSER_ADMISSION must be open or closed" unless
      BROWSER_ADMISSION_STATES.include?(state)

    state == "open"
  end

  class UnownedRoute < ArgumentError; end

  # Any role may serve these: process health, revision, crawler files, CSP reports and the
  # browser preference cookie, none of which reads a credential or an actor.
  ANY_ROLE = "*"

  # Base keeps only the protocol exceptions that still execute with the authority base: its own
  # Jump/JWKS endpoint and the re-verification ceremony binding confirmation. OIDC authorization,
  # token, logout, root-session and credential-management routes are owned by Visa or by the Base
  # RP respectively; they must not become OP-owned merely because they remain under `Base::`.
  BASE_OP_PREFIXES = %w(ceremony_binding_confirmations well_known).freeze

  # Base paths the Base Self-RP cell serves: its own entry, callback, Refresh, logout receivers and
  # the relay pages whose logic lives at an HTTPS owner.
  BASE_RP_PREFIXES = %w(
    sign/entries sign/interruptions oidc/callbacks oidc/closures sign/cookie_purges roots
    switchers accounts organizations avatars avatar_ownership_transfers dashboard_avatar_images groups
    group_avatar_memberships billing billings iam support audit configurations system
    identity identities verification verifications secrets secret_issuances secret_presentations
    selectors welcomes social sign_outs api/v0/identity api/v0/membership
  ).freeze

  BASE_ANY_PREFIXES = %w(
    health healths revisions robots sitemaps csp_violation_reports preference preferences
    api/v0/healths api/v0/revisions api/v0/preferences
  ).freeze

  VISA_OP_PREFIXES = %w(
    ceremony_binding_confirmations edge/v0/token oauth oidc roots sign_byes sign/in well_known
  ).freeze
  VISA_ANY_PREFIXES = %w(
    health healths revisions robots csp_violation_reports api/v0/healths api/v0/revisions
  ).freeze

  # Owner APIs of the canonical domain authorities (R5-WU12/13/14).
  BASE_DOMAIN_PREFIXES = {
    "api/v0/avatar" => "domain-avatar",
    "api/v0/publishing" => "domain-publishing",
    "api/v0/iam" => "domain-org",
    "api/v0/support" => "domain-org",
    "api/v0/tech_capability_checks" => "op-base-org",
  }.freeze

  CONTENT_FAMILIES = %w(docs help info news guid).freeze

  # The single role allowed to serve a routed controller, or ANY_ROLE. An unclassified controller
  # raises: a new route must be assigned an owner explicitly, never inherit one by accident.
  def route_owner(controller_path)
    family, realm, rest = controller_path.to_s.split("/", 3)
    case family
    when "auth" then "auth-#{realm}"
    when "core", "warp" then %w(dev net).include?(realm) ? ANY_ROLE : "rp-#{family}-#{realm}-jp"
    when "palm" then "rp-palm-app-jp"
    when "edit", "tech" then "rp-#{family}-org-ww"
    when "base" then base_route_owner(realm, rest.to_s)
    when "visa" then visa_route_owner(realm, rest.to_s)
    when "unknown_hosts" then ANY_ROLE
    when *CONTENT_FAMILIES then "domain-publishing"
    else raise UnownedRoute, "no runtime role owns #{controller_path.inspect}"
    end
  end

  def base_route_owner(realm, rest)
    return ANY_ROLE if %w(dev net).include?(realm)

    matches = ->(prefix) { rest == prefix || rest.start_with?("#{prefix}/") }
    BASE_DOMAIN_PREFIXES.each { |prefix, role| return role if matches.call(prefix) }
    return ANY_ROLE if BASE_ANY_PREFIXES.any?(&matches)
    return "op-base-#{realm}" if BASE_OP_PREFIXES.any?(&matches)
    return "rp-base-#{realm}-ww" if BASE_RP_PREFIXES.any?(&matches)

    raise UnownedRoute, "no runtime role owns base/#{realm}/#{rest}"
  end

  def visa_route_owner(realm, rest)
    return ANY_ROLE if VISA_ANY_PREFIXES.any? { |prefix| rest == prefix || rest.start_with?("#{prefix}/") }
    return "op-base-#{realm}" if VISA_OP_PREFIXES.any? { |prefix| rest == prefix || rest.start_with?("#{prefix}/") }

    raise UnownedRoute, "no runtime role owns visa/#{realm}/#{rest}"
  end

  # True when this process may serve the controller; the shared transitional role serves all. An
  # RP cell whose browser admission is closed serves only CLOSED_CELL_PATHS.
  def serves?(controller_path, name = current)
    return true if shared?(name)

    owner = route_owner(controller_path)
    return false unless owner == ANY_ROLE || owner == name
    return true unless RP_ROLES.include?(name)

    rp_browser_admission_open? || CLOSED_CELL_PATHS.match?(controller_path)
  rescue UnownedRoute
    false
  end
end
