# typed: false
# frozen_string_literal: true

# Bounds an authorization request before any transaction is allocated: each query parameter must be
# a plain string of at most MAX_PARAMETER_BYTES, and the whole query at most MAX_QUERY_BYTES. The
# limits were decided for the Sign capacity table (plans/active/sign-fqdn-integrated-plan.md
# section 5). The including controller opts in with its own `before_action`.
module OauthAuthorizeRequestSizeLimit
  extend ActiveSupport::Concern

  MAX_PARAMETER_BYTES = 2048
  MAX_QUERY_BYTES = 8192

  private

  def enforce_oauth_authorize_request_size!
    return unless oauth_authorize_request_oversized?

    render json: { error: "invalid_request", error_description: "authorization request is too large" },
           status: :bad_request
  end

  def oauth_authorize_request_oversized?
    return true if request.query_string.bytesize > MAX_QUERY_BYTES

    request.query_parameters.any? do |_name, value|
      !value.is_a?(String) || value.bytesize > MAX_PARAMETER_BYTES
    end
  end
end
