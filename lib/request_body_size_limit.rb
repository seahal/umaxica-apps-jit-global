# typed: false
# frozen_string_literal: true

require "json"
require "securerandom"
require "stringio"

# Bounds JSON request bodies before Rails or a controller asks Rack to parse them.
#
# This is deliberately a Rack boundary rather than a controller concern: the controller layer is
# too late for a request whose parameter parser has already consumed an unbounded body. Multipart
# and other upload bodies are not covered here; they have separate application-level limits.
class RequestBodySizeLimit
  MAX_JSON_BODY_BYTES = 1.megabyte
  READ_CHUNK_BYTES = 16.kilobytes
  PROBLEM_CONTENT_TYPE = "application/problem+json"
  SUPPORTED_CONTENT_ENCODINGS = [nil, "", "identity"].freeze

  public

  def initialize(app)
    @app = app
  end

  def call(env)
    return @app.call(env) unless json_request?(env)
    return problem_response(env, :unsupported_media_type) unless supported_content_encoding?(env)

    declared_length = declared_content_length(env)
    return problem_response(env, :bad_request) if declared_length == :invalid
    return problem_response(env, :content_too_large) if declared_length && declared_length > MAX_JSON_BODY_BYTES

    body = read_bounded(env["rack.input"] || StringIO.new)
    return problem_response(env, :content_too_large) if body.bytesize > MAX_JSON_BODY_BYTES

    env["rack.input"] = StringIO.new(body)
    @app.call(env)
  end

  private

  def json_request?(env)
    media_type = Rack::MediaType.type(env["CONTENT_TYPE"].to_s)
    media_type == "application/json" || media_type.to_s.end_with?("+json")
  end

  def supported_content_encoding?(env)
    SUPPORTED_CONTENT_ENCODINGS.include?(env["HTTP_CONTENT_ENCODING"].to_s.strip.downcase.presence)
  end

  def declared_content_length(env)
    raw_length = env["CONTENT_LENGTH"]
    return nil if raw_length.blank?

    length = Integer(raw_length, 10)
    return :invalid if length.negative?

    length
  rescue ArgumentError
    :invalid
  end

  def read_bounded(input)
    body = +""
    loop do
      remaining = MAX_JSON_BODY_BYTES + 1 - body.bytesize
      break if remaining <= 0

      chunk = input.read([READ_CHUNK_BYTES, remaining].min)
      break if chunk.blank?

      body << chunk
    end
    body
  end

  def problem_response(env, slug)
    problem = ProblemType.fetch(slug)
    document = {
      type: problem.uri,
      title: problem.title,
      status: problem.status_code,
      instance: env["PATH_INFO"].to_s,
      request_id: env["action_dispatch.request_id"].presence || SecureRandom.uuid,
    }
    body = JSON.generate(document)
    [
      problem.status_code,
      {
        "Content-Type" => PROBLEM_CONTENT_TYPE,
        "Content-Length" => body.bytesize.to_s,
        "Cache-Control" => "no-store",
      },
      [body],
    ]
  end
end
