# frozen_string_literal: true

# Filters the final response after Cookies and CookieStore have committed their headers.
class AuthPhaseRefusalResponseBoundary
  ENV_KEY = "umaxica.auth_phase_refusal"
  COOKIE_NAMES = %w(
    __Host-session session __Host-auth_sid auth_sid __Host-auth_access auth_access
    __Host-auth_refresh auth_refresh __Host-auth_dbsc auth_dbsc
  ).freeze
  COMBINED_AUTH_COOKIE = /,\s*(?:#{COOKIE_NAMES.map { |name| Regexp.escape(name) }.join("|")})=/.freeze
  DBSC_HEADERS = %w(
    secure-session-registration secure-session-challenge secure-session-id secure-session-response
    secure-session-skipped sec-session-registration sec-session-challenge sec-session-id
    sec-session-response sec-session-skipped
  ).freeze

  public

  def initialize(app)
    @app = app
  end

  def call(env)
    status, headers, body = @app.call(env)
    return [status, headers, body] unless env[ENV_KEY] == true && status == 409

    filter_response(env, headers, body)
  end

  private

  def filter_response(env, headers, body)
    filtered = headers.dup
    filtered.keys.each do |key|
      raise ArgumentError, "invalid response header" unless key.is_a?(String)

      name = key.downcase
      filtered.delete(key) if %w(location cache-control).include?(name) || DBSC_HEADERS.include?(name)
      next unless name == "set-cookie"

      filter_cookies!(filtered, key)
    end
    filtered["cache-control"] = "private, no-store"
    if env["REQUEST_METHOD"] == "HEAD"
      body.close if body.respond_to?(:close)
      body = []
      filtered.delete_if { |key, _| key.casecmp("content-length").zero? }
    end
    [409, filtered, body]
  rescue StandardError => e
    Rails.logger.error("auth phase refusal response filtering failed: #{e.class.name}")
    body.close if body.respond_to?(:close)
    failure_body = (env["REQUEST_METHOD"] == "HEAD") ? [] : ["Internal Server Error"]
    [500, { "content-type" => "text/plain", "cache-control" => "private, no-store" }, failure_body]
  end

  def filter_cookies!(headers, key)
    value = headers.fetch(key)
    lines = value.is_a?(String) ? value.split("\n", -1) : value
    raise ArgumentError, "invalid cookie header" unless lines.is_a?(Array) && lines.all?(String)

    lines.each do |line|
      raise ArgumentError, "invalid cookie header" unless line.match?(/\A[^=;\s,]+=/) && !line.match?(/[\r\n]/)
      raise ArgumentError, "combined cookie header" if line.match?(COMBINED_AUTH_COOKIE)
    end
    kept = lines.reject { |line| COOKIE_NAMES.include?(line.split("=", 2).first) }
    kept.empty? ? headers.delete(key) : headers[key] = value.is_a?(String) ? kept.join("\n") : kept
  end
end
