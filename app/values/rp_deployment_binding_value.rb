# typed: false
# frozen_string_literal: true

# Trusted deployment binding for Browser RP client identifiers (one.md section 5.1, R4-WU01/02A).
#
# Every concrete Client ID is exactly eleven characters: `<family>-<realm>-<scope>`. Regional
# families (core, warp, palm) take the scope of this deployment's region; Base, Edit and Tech are
# worldwide (`ww`) regardless of where they are placed in development.
#
# The region comes only from the process environment set by the trusted launcher
# (`UMAXICA_DEPLOYMENT_REGION`). It is never read from a Host, an `ri` parameter, a token claim or
# any other request input, and there is no default: a process without it refuses to resolve a
# regional client rather than silently becoming JP.
class RpDeploymentBindingValue
  # Approved regions. US is declared so its static catalog can be validated, but no US runtime
  # environment exists yet (`US_ENVIRONMENT_NOT_PROVISIONED`).
  REGIONS = %w(jp us).freeze
  WORLDWIDE = "ww"

  # Family-realm pairs whose client scope is the deployment region.
  REGIONAL_RPS = %w(core-app core-com core-org warp-app warp-com warp-org palm-app).freeze
  # Family-realm pairs that are always worldwide.
  WORLDWIDE_RPS = %w(base-app base-com base-org edit-org tech-org).freeze

  class UnknownRegion < ArgumentError; end

  class UnknownRp < KeyError; end

  class << self
    public

    # This process's region, from trusted startup configuration only.
    def region
      value = ENV.fetch("UMAXICA_DEPLOYMENT_REGION")
      raise UnknownRegion, "unknown deployment region: #{value.inspect}" unless REGIONS.include?(value)

      value
    end

    # The exact Client ID this deployment uses for a family-realm pair, e.g. "core-app" -> "core-app-jp".
    def client_id(family_realm)
      key = family_realm.to_s
      return "#{key}-#{WORLDWIDE}" if WORLDWIDE_RPS.include?(key)
      return "#{key}-#{region}" if REGIONAL_RPS.include?(key)

      raise UnknownRp, "unknown RP family/realm: #{family_realm.inspect}"
    end

    # The full declared catalog (5 worldwide + 7 per region = 19 for JP+US). Metadata only: a US
    # entry is declared, not provisioned or active.
    def catalog
      WORLDWIDE_RPS.map { |key| "#{key}-#{WORLDWIDE}" } +
        REGIONS.flat_map { |scope| REGIONAL_RPS.map { |key| "#{key}-#{scope}" } }
    end

    # Client IDs this deployment actually serves: worldwide plus its own region only.
    def active_client_ids
      (WORLDWIDE_RPS + REGIONAL_RPS).map { |key| client_id(key) }
    end
  end
end
