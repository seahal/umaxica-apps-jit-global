# typed: false
# frozen_string_literal: true

require "uri"

module JitHostOriginEnv
  LOCAL_HOSTS = %w(localhost 127.0.0.1 0.0.0.0 ::1).freeze

  module_function

  def trusted_origins(*hosts)
    result = hosts.flatten.compact_blank.flat_map { |host| origins_for(host) }
    result.uniq!
    result
  end

  def origins_for(host)
    raw = host.to_s.strip
    return [] if raw.blank?
    return [] if production_local_origin?(raw)
    return [raw] if raw.match?(%r{\Ahttps?://})
    return [] if production_local_host?(raw)

    return ["http://#{raw}", "https://#{raw}"] if Rails.env.local?

    ["https://#{raw}"]
  end

  def production_local_origin?(raw)
    return false if Rails.env.local?
    return false unless raw.match?(%r{\Ahttps?://})

    production_local_host?(URI.parse(raw).host)
  rescue URI::InvalidURIError
    false
  end

  def production_local_host?(host)
    return false if Rails.env.local?

    normalized = host.to_s.downcase.delete_prefix("[").delete_suffix("]")
    LOCAL_HOSTS.include?(normalized) || normalized.end_with?(".localhost")
  end

  private_class_method :production_local_origin?, :production_local_host?
end
