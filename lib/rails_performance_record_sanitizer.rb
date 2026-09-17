# typed: false
# frozen_string_literal: true

require_relative "observability_redactor"

# Strips secrets out of a rails_performance request record before it reaches Valkey.
#
# `config.filter_parameters` is not sufficient here, and assuming it is would be the mistake. Of
# the three free-text fields `RailsPerformance::Models::RequestRecord#save` persists, it covers
# exactly one, partially:
#
#   path             Rails sets this from `request.filtered_path`, so parameters named in
#                    config/initializers/filter_parameter_logging.rb are already `[FILTERED]`.
#                    Anything not on that list is not -- a one-off debug parameter, a vendor
#                    callback's own naming, a secret in a path segment rather than a query
#                    parameter. The list is also the wrong shape for this job: it was written for
#                    log lines, where a partial redaction is still useful.
#   http_referer     stored verbatim on 404s. `filter_parameters` never touches it, and a Referer
#                    carries the referring page's entire query string -- which, for an
#                    authorization redirect, is where the code, state, and token live.
#   exception        `payload[:exception]` is [class name, message] joined. Exception messages
#                    quote the values that caused them.
#
# So each is handled explicitly:
#
#   path             query string removed entirely, not redacted. Nothing downstream needs it --
#                    the dashboard aggregates by controller#action -- and "no query string is
#                    stored" is a property that stays true as parameter names change, which
#                    "every sensitive parameter is on the filter list" does not. It also keeps
#                    `|` out of a record key that is `|`-delimited.
#   http_referer     reduced to scheme://host/path by ObservabilityRedactor.scrub_url, the same
#                    treatment config/initializers/sentry.rb gives a referring URL.
#   exception        class name only. The class is what the dashboard groups crashes by; the
#                    message is the part that quotes data.
#
# The backtrace rails_performance stores alongside these is left alone: it is file paths and line
# numbers from this repository and its gems.
module RailsPerformanceRecordSanitizer
  module_function

  # @param path [String, nil] the request path, possibly carrying a query string
  # @return [String, nil] the path with any query string and fragment removed
  def sanitize_path(path)
    return path if path.nil?

    path.to_s.split(/[?#]/, 2).first.to_s
  end

  # @param referer [String, nil] a Referer header value
  # @return [String, nil] origin and path only, or nil when there was no referer
  def sanitize_referer(referer)
    return nil if referer.nil?

    ObservabilityRedactor.scrub_url(referer)
  end

  # @param exception [String, nil] "ClassName message", as RequestRecord joins it
  # @return [String, nil] the class name alone
  def sanitize_exception(exception)
    return exception if exception.nil?

    text = exception.to_s
    return text if text.empty?

    text.split(" ", 2).first
  end

  # Prepended to RailsPerformance::Models::RequestRecord so sanitisation happens on the way to
  # Valkey rather than on the way out of it. Redacting at read time would leave the secret sitting
  # in the store, where `redis.keys` and any operator with a Valkey connection would still find it.
  module RequestRecordPatch
    def save
      @path = RailsPerformanceRecordSanitizer.sanitize_path(@path)
      @http_referer = RailsPerformanceRecordSanitizer.sanitize_referer(@http_referer)
      @exception = RailsPerformanceRecordSanitizer.sanitize_exception(@exception)
      super
    end
  end
end
