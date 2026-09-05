# typed: false
# frozen_string_literal: true

# Enforces the API's media type contract: JSON out, JSON in.
#
# These endpoints previously ignored `Accept` entirely -- one of them overwrote `request.format`
# outright -- and accepted a request body of any declared type. Overwriting the client's stated
# preference is not negotiation; it is answering a question that was never asked.
#
# Both checks answer with Problem Details. A 406 is still served as `application/problem+json` even
# though the caller said it accepts neither: RFC 9110 15.5.7 permits sending a representation the
# client did not ask for, and an unreadable explanation beats an empty body.
#
# See docs/reference/api-design-standards.md ("Content negotiation").
module ApiContentNegotiation
  extend ActiveSupport::Concern

  # Errors on these endpoints are `application/problem+json` and successes are `application/json`, so
  # a caller that accepts neither cannot be served.
  ACCEPTABLE_RESPONSE_TYPES = %w(application/json application/problem+json).freeze

  # RFC 9110 12.5.1 range forms that cover the types above.
  ACCEPTABLE_RANGES = %w(*/* application/*).freeze

  REQUEST_MEDIA_TYPE = "application/json"

  # before_action is the request filter contract for JSON endpoints. Installing
  # it at inclusion is intentional: negotiation must run before every action,
  # and listing the filters on each including controller would duplicate them.
  included do
    before_action :enforce_api_acceptable_response_type!
    before_action :enforce_api_request_media_type!
  end

  private

  def enforce_api_acceptable_response_type!
    accepted = request.accepts.filter_map { |mime| mime.to_s.presence }
    # RFC 9110 12.5.1: a request with no `Accept` accepts anything. Rails also yields an empty list
    # when the header is absent, so this is the same condition.
    return if accepted.empty?
    return if accepted.any? { |value| acceptable_response_type?(value) }

    render_problem(:not_acceptable)
  end

  def acceptable_response_type?(value)
    ACCEPTABLE_RANGES.include?(value) || ACCEPTABLE_RESPONSE_TYPES.include?(value)
  end

  def enforce_api_request_media_type!
    return unless api_request_body_present?
    return if request.media_type == REQUEST_MEDIA_TYPE

    render_problem(:unsupported_media_type)
  end

  # Only a request that actually carries a body has a media type to reject. A bodyless POST -- the
  # token refresh, which carries its credential in a cookie and its CSRF token in a header -- must
  # not be refused for declaring nothing.
  def api_request_body_present?
    request.content_length.to_i.positive? || request.headers["Transfer-Encoding"].present?
  end
end
