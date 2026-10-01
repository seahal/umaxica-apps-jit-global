# typed: false
# frozen_string_literal: true

require "rack/utils"

# Carries a confirmed browser-credential deletion through the exception response path.
#
# A refused access cookie is detached in the controller through the cookie jar, but when a later
# boundary check raises (the Home/Dashboard 404 contract raises `ActiveRecord::RecordNotFound`),
# the exception renderer (`ShowExceptions`, or `DebugExceptions` where requests are local) replaces
# the downstream response and the jar is never written, so the deletion is lost
# (adr/invalid-browser-credential-recovery.md).
#
# This middleware sits outside both renderers and appends a registered deletion only when the
# response carries no Set-Cookie for that name: the ordinary path, where the jar already wrote the
# deletion or a later issuance replaced it, is left untouched. It never flushes the cookie jar, so
# any other cookie mutation prepared by a failed request (issuance, rotation, preference) stays
# uncommitted.
class CredentialDeletionFinalizer
  ENV_KEY = "umaxica.credential_deletions"

  public

  class << self
    public

    # Records a deletion the controller has already decided on. `options` are the issued cookie's
    # deletion options, so the emitted header matches the cookie's identity attributes.
    def register(env, name, options)
      raise ArgumentError, "credential cookie name is blank" if name.blank?

      deletions = (env[ENV_KEY] ||= {})
      deletions[name.to_s] = options.except(:domain, :expires, :max_age, :value).freeze
    end
  end

  def initialize(app)
    @app = app
  end

  def call(env)
    status, headers, body = @app.call(env)
    deletions = env[ENV_KEY]
    return [status, headers, body] if deletions.blank?

    written = set_cookie_names(headers)
    deletions.each do |name, options|
      next if written.include?(name)

      Rack::Utils.delete_cookie_header!(headers, name, options)
    end
    [status, headers, body]
  end

  private

  def set_cookie_names(headers)
    lines = headers[Rack::SET_COOKIE]
    lines = lines.split("\n") if lines.is_a?(String)
    Array(lines).map { |line| line.split("=", 2).first.to_s.strip }
  end
end
