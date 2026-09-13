# typed: false
# frozen_string_literal: true

# The explicit allowlist of fully qualified domain names this Rails application serves, and the
# availability slot each one belongs to.
#
# The kill switch in `FqdnAvailabilityGate` selects a Flipper feature from the *slot*, never from the
# `Host` header. A header that does not appear here resolves to nil and the gate fails closed, so an
# attacker cannot invent a feature name -- or reach a surface -- by sending an arbitrary `Host`.
#
# The hostname lists mirror the `constraints(host:)` declarations in `config/routes/*.rb` exactly:
# same boot-config slots, same environment variables, same literal development aliases.
# `Security::Invariants::FqdnAvailabilityRegistryInvariantTest` fails when the two drift apart.
#
# Note on naming: `ConfigValues::HostFamilyValues` also carries an `acme_*` family whose values are
# the `base.*.localhost` development aliases already listed under the `base_*` slots here. There is
# no separate `acme_*` slot because no route constrains on one.
module FqdnAvailabilityRegistry
  Slot = Data.define(:name, :hostnames)

  # Slot name => the hostnames that reach it. Values are resolved once per boot, because
  # `config/routes/*.rb` resolves the same sources once per boot when the routes are drawn.
  SLOT_SOURCES = {
    base_service: ->(hosts) { [hosts.base_service.host, ENV["PUBLIC_BASE_SERVICE_URL"], "base.app.localhost"] },
    base_corporate: ->(hosts) { [hosts.base_corporate.host, ENV["PUBLIC_BASE_CORPORATE_URL"], "base.com.localhost"] },
    base_staff: ->(hosts) { [hosts.base_staff.host, ENV["PUBLIC_BASE_STAFF_URL"], "base.org.localhost"] },
    base_network: ->(_hosts) { [ENV["PRIVATE_BASE_NETWORK_URL"], "base.net.localhost"] },
    base_developer: lambda { |_hosts|
      [ENV["PUBLIC_BASE_DEVELOPER_URL"], ENV["PRIVATE_BASE_DEVELOPER_URL"], "base.dev.localhost"]
    },
    auth_service: ->(hosts) { [hosts.auth_service.host, ENV["PUBLIC_AUTH_SERVICE_URL"], "auth.app.localhost"] },
    auth_corporate: ->(hosts) { [hosts.auth_corporate.host, ENV["PUBLIC_AUTH_CORPORATE_URL"], "auth.com.localhost"] },
    auth_staff: ->(hosts) { [hosts.auth_staff.host, ENV["PUBLIC_AUTH_STAFF_URL"], "auth.org.localhost"] },
    core_service: ->(hosts) { [hosts.core_service.host, ENV["PRIVATE_CORE_SERVICE_URL"]] },
    core_corporate: ->(hosts) { [hosts.core_corporate.host, ENV["PRIVATE_CORE_CORPORATE_URL"]] },
    core_staff: ->(hosts) { [hosts.core_staff.host, ENV["PRIVATE_CORE_STAFF_URL"]] },
    core_network: lambda { |_hosts|
      [ENV["PRIVATE_CORE_NETWORK_URL"] || ENV["CORE_NETWORK_URL"], "core.net.localhost"]
    },
    core_developer: lambda { |_hosts|
      [ENV["PRIVATE_CORE_DEVELOPER_URL"] || ENV["CORE_DEVELOPER_URL"], "core.dev.localhost"]
    },
    docs_service: ->(_hosts) { [ENV["PRIVATE_DOCS_SERVICE_URL"], "docs.jp.umaxica.app", "docs.app.localhost"] },
    docs_corporate: ->(_hosts) { [ENV["PRIVATE_DOCS_CORPORATE_URL"], "docs.jp.umaxica.com", "docs.com.localhost"] },
    docs_staff: ->(_hosts) { [ENV["PRIVATE_DOCS_STAFF_URL"], "docs.jp.umaxica.org", "docs.org.localhost"] },
    news_service: ->(_hosts) { [ENV["PRIVATE_NEWS_SERVICE_URL"], "news.jp.umaxica.app", "news.app.localhost"] },
    news_corporate: ->(_hosts) { [ENV["PRIVATE_NEWS_CORPORATE_URL"], "news.jp.umaxica.com", "news.com.localhost"] },
    news_staff: ->(_hosts) { [ENV["PRIVATE_NEWS_STAFF_URL"], "news.jp.umaxica.org", "news.org.localhost"] },
    help_service: ->(hosts) { [hosts.help_service.host, "help.jp.umaxica.app", "help.app.localhost"] },
    help_corporate: ->(hosts) { [hosts.help_corporate.host, "help.jp.umaxica.com", "help.com.localhost"] },
    help_staff: ->(hosts) { [hosts.help_staff.host, "help.jp.umaxica.org", "help.org.localhost"] },
    info_service: ->(hosts) { [hosts.info_service.host, "info.app.localhost", "info.umaxica.app"] },
    info_corporate: ->(hosts) { [hosts.info_corporate.host, "info.com.localhost", "info.umaxica.com"] },
    info_staff: ->(hosts) { [hosts.info_staff.host, "info.org.localhost", "info.umaxica.org"] },
    guid_service: lambda { |hosts|
      [hosts.guid_service.host, ENV["PRIVATE_GUID_SERVICE_URL"], "guid.umaxica.net", "guid.net.localhost"]
    },
    edit_staff: lambda { |hosts|
      [hosts.edit_staff.host, ENV["PUBLIC_EDIT_STAFF_URL"], ENV["PRIVATE_EDIT_STAFF_URL"],
       "edit.umaxica.org", "edit.org.localhost",]
    },
    side_service: ->(hosts) { [hosts.side_service.host, "wide.app.localhost"] },
    side_corporate: ->(hosts) { [hosts.side_corporate.host, "wide.com.localhost"] },
    side_staff: ->(hosts) { [hosts.side_staff.host, "wide.org.localhost"] },
    palm_service: ->(hosts) { [hosts.palm_service.host, "palm.app.localhost"] },
  }.freeze

  SLOT_NAMES = SLOT_SOURCES.keys.freeze

  FLAG_PREFIX = "fqdn_available_"

  module_function

  def flag_name_for(slot) = :"#{FLAG_PREFIX}#{slot}"

  def flag_names = SLOT_NAMES.map { |slot| flag_name_for(slot) }

  # @return [Symbol, nil] the slot the hostname belongs to, or nil when the hostname is not served.
  def slot_for(hostname)
    return nil if hostname.blank?

    index.fetch(normalize(hostname), nil)
  end

  def slots
    @slots ||= SLOT_SOURCES.map do |name, source|
      Slot.new(name: name, hostnames: hostnames_from(source))
    end.freeze
  end

  # hostname => slot. Built once per boot and frozen.
  def index
    @index ||= slots.each_with_object({}) do |slot, map|
      slot.hostnames.each do |hostname|
        claimed = map[hostname]

        if claimed && claimed != slot.name
          raise ArgumentError,
                "FQDN #{hostname} is claimed by both #{claimed} and #{slot.name}; " \
                "one hostname cannot have two availability switches"
        end

        map[hostname] = slot.name
      end
    end.freeze
  end

  def hostnames_from(source)
    hostnames =
      source.call(Rails.configuration.x.boot_config.fetch(:hosts)).compact_blank.map do |value|
        normalize(value)
      end
    hostnames.uniq!
    hostnames.freeze
  end

  def normalize(value) = value.to_s.strip.downcase
end
