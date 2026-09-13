# typed: false
# frozen_string_literal: true

# The banner currently published for a (tld, domain, region) stream.
#
# This used to be an ApplicationHelper method called from a layout partial, which made it reachable
# only from a view. The Inertia surface layout is React, so the banner is now read while building
# shared props and the query has to be callable from a controller. Keeping it here rather than in a
# helper also means the one database read the page chrome performs is visible as a query object.
#
# Behaviour is deliberately unchanged from the helper it replaces, including the connection role and
# the rescue: a banner is optional chrome, and an unreachable banner store must not turn every page
# of the surface into a 500.
module CurrentBannerQuery
  module_function

  ALLOWED_TLDS = %i(app org com).freeze
  ALLOWED_DOMAINS = %i(sign core acme docs news help).freeze

  BANNER_MODELS = {
    app: "ClientBanner",
    org: "OperatorBanner",
    com: "VisitorBanner",
  }.freeze

  def call(tld:, region:, domain:)
    region = :ww if region&.to_sym == :global
    validate!(tld: tld, region: region, domain: domain)

    banner_model = banner_model_for(tld)
    return if banner_model.blank?

    read_current(banner_model)
  rescue ActiveRecord::ConnectionNotEstablished, ActiveRecord::DatabaseConnectionError
    nil
  end

  def validate!(tld:, region:, domain:)
    raise ArgumentError, "Invalid tld: #{tld}" unless ALLOWED_TLDS.include?(tld&.to_sym)
    raise ArgumentError, "Invalid domain: #{domain}" unless ALLOWED_DOMAINS.include?(domain&.to_sym)

    allowed_regions =
      case domain.to_sym
      when :sign, :acme then [:ww]
      else [:jp, :us]
      end

    return if allowed_regions.include?(region&.to_sym)

    raise ArgumentError, "Invalid region: #{region} for domain: #{domain}"
  end

  def banner_model_for(tld)
    BANNER_MODELS[tld&.to_sym]&.safe_constantize
  end

  def read_current(banner_model)
    connection_owner = connection_owner_for(banner_model)
    return banner_model.current.first if connection_owner.blank?

    operation =
      lambda do
        connection_owner.connected_to(role: :writing) do
          banner_model.current.first
        end
      end

    defined?(Prosopite) ? Prosopite.pause(&operation) : operation.call
  end

  def connection_owner_for(banner_model)
    banner_model.ancestors.find do |ancestor|
      ancestor.is_a?(Class) && ancestor < ActiveRecord::Base && ancestor.abstract_class?
    end
  end
  private_class_method :validate!, :banner_model_for, :read_current, :connection_owner_for
end
