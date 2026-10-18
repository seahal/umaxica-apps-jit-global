# typed: false
# frozen_string_literal: true

# Renders unhandled exceptions and routing failures on API paths as RFC 9457 Problem Details.
#
# Without this, Rails' default `ActionDispatch::PublicExceptions` serves `public/404.html` and
# `public/500.html` for every failure, so an API client asking for JSON receives an HTML page. A
# routing miss such as `/api/v0/unknown` never reaches a controller at all, so no `rescue_from` can
# cover it; the exceptions app is the only place that sees both cases.
#
# Non-API paths keep the existing HTML pages: this changes the API boundary, not the site.
#
# See docs/reference/api-design-standards.md and adr/api-error-format-problem-details.md.
class ApiProblemExceptionsApp
  CONTENT_TYPE = "application/problem+json"

  # Scoped to the namespace that actually renders Problem Details today. `/edge/v0` and `/web/v0`
  # still emit their own shapes, so claiming them here would produce two different error formats on
  # one endpoint depending on whether the failure reached a controller.
  API_PATH_PREFIX = "/api/"

  class << self
    def call(env)
      new(env).call
    end
  end

  def initialize(env)
    @env = env
  end

  def call
    unless api_request?
      status_code, response_headers, response_body = public_exceptions.call(env)
      response_headers["cache-control"] = "private, no-store" if status_code == 404
      return [status_code, response_headers, response_body]
    end

    [status, headers, [body]]
  end

  private

  attr_reader :env

  def api_request?
    original_path.start_with?(API_PATH_PREFIX)
  end

  # ActionDispatch::ShowExceptions overwrites PATH_INFO with "/<status>" before delegating, and
  # stashes the real path here. Falling back to PATH_INFO covers a direct invocation in tests.
  def original_path
    env["action_dispatch.original_path"].presence || env["PATH_INFO"].to_s
  end

  # The status Rails decided on. It wins over the registry entry's own status so the `status` member
  # and the status line always agree (RFC 9457 3.1.3).
  def status
    @status ||= env["PATH_INFO"].to_s.delete_prefix("/").to_i.then { |code| code.positive? ? code : 500 }
  end

  def problem
    @problem ||= ProblemType.for_status(status)
  end

  def headers
    { "content-type" => CONTENT_TYPE, "cache-control" => "no-store" }
  end

  # No `detail`: the exception message may carry parameters, identifiers, or internal state, and this
  # document is returned to the caller. The request id is what correlates the response to the logged
  # exception.
  def body
    document = {
      type: problem.uri,
      title: problem.title,
      status: status,
      instance: original_path,
      request_id: env["action_dispatch.request_id"],
    }
    document.to_json
  end

  def public_exceptions
    @public_exceptions ||= ActionDispatch::PublicExceptions.new(Rails.public_path)
  end
end
