# typed: false
# frozen_string_literal: true

module SurfaceRouteAliasHelper
  PREFIX_MAP = {
    "auth_app_" => "sign_app_",
    "auth_org_" => "sign_org_",
    "base_app_" => "acme_app_",
    "base_org_" => "acme_org_",
    "base_com_" => "acme_com_",
  }.freeze

  def method_missing(name, ...)
    aliased_name = aliased_surface_helper_name(name)
    return super if aliased_name.nil?
    return public_send(aliased_name, ...) if respond_to?(aliased_name, true)

    super
  end

  def respond_to_missing?(name, include_private = false)
    aliased_name = aliased_surface_helper_name(name)
    return true if aliased_name && respond_to?(aliased_name, include_private)

    super
  end

  private

  def aliased_surface_helper_name(name)
    helper_name = name.to_s
    PREFIX_MAP.each do |source_prefix, target_prefix|
      return helper_name.sub(target_prefix, source_prefix) if helper_name.start_with?(target_prefix)
    end

    nil
  end
end
