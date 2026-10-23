# typed: false
# frozen_string_literal: true

# Every cookie is host-only (D-58, D-115): no `Domain` and no `Partitioned` attribute.
module CoreCookieOptions
  module_function

  def for(request:, same_site: nil, expires: nil, httponly: true, secure: nil, path: nil)
    options = {
      httponly: httponly,
      secure: secure.nil? ? resolve_secure(request) : secure,
    }
    options[:same_site] = same_site if same_site
    options[:expires] = expires if expires
    options[:path] = path if path
    options
  end

  def resolve_secure(request)
    Rails.env.production? || ENV["FORCE_SECURE_COOKIES"] == "1" || request.ssl?
  end
  private_class_method :resolve_secure
end
