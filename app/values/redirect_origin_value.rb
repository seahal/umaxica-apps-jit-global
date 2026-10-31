# frozen_string_literal: true

# Compares the complete browser origin of two absolute HTTP(S) URLs.
class RedirectOriginValue
  def self.same_origin?(target:, origin:)
    target_uri = URI.parse(target.to_s)
    origin_uri = URI.parse(origin.to_s)
    return false unless target_uri.is_a?(URI::HTTP) && origin_uri.is_a?(URI::HTTP)
    return false if target_uri.host.blank? || origin_uri.host.blank?
    return false unless target_uri.userinfo.nil? && origin_uri.userinfo.nil?

    target_uri.scheme.casecmp?(origin_uri.scheme) && target_uri.host.casecmp?(origin_uri.host) &&
      target_uri.port == origin_uri.port
  rescue URI::InvalidURIError
    false
  end
  public_class_method :same_origin?
end
