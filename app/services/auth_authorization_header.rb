# typed: false
# frozen_string_literal: true

module AuthAuthorizationHeader
  module_function

  def bearer_token(request)
    token_for_scheme(request, "Bearer")
  end

  def dpop_token(request)
    token_for_scheme(request, "DPoP")
  end

  def access_token(request)
    bearer_token(request) || dpop_token(request)
  end

  def scheme(request)
    authorization_value_for(request).to_s.split(/\s+/, 2).first.presence
  end

  def scheme?(request, expected)
    scheme(request).to_s.casecmp?(expected)
  end

  def token_for_scheme(request, expected)
    header = authorization_value_for(request).to_s
    match = header.match(/\A#{Regexp.escape(expected)}\s+(.+)\z/i)
    match&.[](1).to_s.strip.presence
  end

  def token_and_options(request)
    header = authorization_value_for(request)
    return nil if header.blank?

    ActionController::HttpAuthentication::Token.token_and_options(
      Struct.new(:authorization).new(normalize_scheme(header)),
    )
  end

  def authorization_value_for(request)
    if request.respond_to?(:authorization) && request.authorization.present?
      return request.authorization
    end

    return nil unless request.respond_to?(:headers)

    request.headers[AuthIoKeys::Headers::AUTHORIZATION]
  end

  def normalize_scheme(header)
    header.sub(/\A(token|bearer)\b/i) { |scheme| scheme.capitalize }
  end
  private_class_method :dpop_token, :authorization_value_for, :normalize_scheme, :token_for_scheme
end
