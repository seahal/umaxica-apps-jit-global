# frozen_string_literal: true

require "time"
require "observability_redactor"

class DeprecationNotificationSubscriber
  NOTIFICATION_PATTERN = /\Adeprecation\..+\z/.freeze
  LOG_EVENT_NAME = "rails.deprecation"
  MAX_LOG_BYTES = 8 * 1024
  MAX_MESSAGE_CODEPOINTS = 1000
  MAX_FIELD_CODEPOINTS = 100
  MAX_CALLSITE_CODEPOINTS = 512

  URL_PATTERN = %r{https?://[^\s<>"']+}i.freeze
  AUTHORIZATION_CREDENTIAL_PATTERN = /\bauthorization\s*[:=]\s*(?:Basic|Bearer)\s+[^\s,;]+/i.freeze
  COOKIE_HEADER_PATTERN = /\b(?:set-cookie|cookie)\s*[:=][^\r\n]*/i.freeze
  SECRET_ASSIGNMENT_PATTERN = /
    (?<key>
      \b[a-z0-9_.-]*
      (?:authorization|cookie|token|secret|password|api[_-]?key|private[_-]?key|session(?:[_-]?id)?)
      [a-z0-9_.-]*
    )
    \s*[:=]\s*
    (?:"[^"]*"|'[^']*'|[^\s,;]+)
  /ix.freeze
  CONTROL_CHARACTER_PATTERN = /[\u0000-\u001f\u007f-\u009f]/.freeze
  STRING_BACKTRACE_PATTERN = /\A(?<path>.+):(?<line>[1-9][0-9]*)(?::in .*)?\z/.freeze

  public

  # Production reports deprecations through :notify; an exception here would reach the deprecated
  # call site and fail an unrelated request, so a record that cannot be built is reported as an
  # error record carrying only the error class.
  def emit(event)
    Rails.logger.warn(deprecation_record(event))
  rescue ArgumentError, KeyError, RangeError => e
    Rails.logger.error(JitLogEvent.format("#{LOG_EVENT_NAME}.unrecordable", error_class: e.class.name))
  end

  private

  def deprecation_record(event)
    unless event.name.is_a?(String) && NOTIFICATION_PATTERN.match?(event.name)
      raise ArgumentError, "unsupported deprecation notification"
    end

    payload = event.payload
    raise ArgumentError, "deprecation notification payload must be a Hash" unless payload.is_a?(Hash)

    message, message_changed = normalized_text(payload.fetch(:message))
    message, message_truncated = limited_text(message, MAX_MESSAGE_CODEPOINTS)
    gem_name, gem_name_changed = normalized_text(payload.fetch(:gem_name))
    gem_name, gem_name_truncated = limited_text(gem_name, MAX_FIELD_CODEPOINTS)
    deprecation_horizon, horizon_changed = normalized_text(payload.fetch(:deprecation_horizon))
    deprecation_horizon, horizon_truncated = limited_text(deprecation_horizon, MAX_FIELD_CODEPOINTS)
    callsite, callsite_changed, callsite_truncated = callsite_for(payload.fetch(:callstack))

    fields = {
      message: message,
      gem_name: gem_name,
      deprecation_horizon: deprecation_horizon,
      callsite: callsite,
      at: Time.now.utc.iso8601(6),
    }
    fields[:truncated] = true if [
      message_changed, message_truncated, gem_name_changed, gem_name_truncated,
      horizon_changed, horizon_truncated, callsite_changed, callsite_truncated,
    ].any?

    bounded_json(fields)
  end

  def normalized_text(value)
    raise ArgumentError, "deprecation field must be a String" unless value.is_a?(String)

    utf8 = value.encode(Encoding::UTF_8, invalid: :replace, undef: :replace)
    utf8_without_authorization = utf8.gsub(AUTHORIZATION_CREDENTIAL_PATTERN, "Authorization=[FILTERED]")
    # Cookie values span semicolon-separated pairs; redact the header's whole line before
    # control-character normalization removes the line boundary.
    utf8_without_headers = utf8_without_authorization.gsub(COOKIE_HEADER_PATTERN, "Cookie=[FILTERED]")
    redacted = ObservabilityRedactor.scrub(utf8_without_headers)
    redacted =
      redacted.gsub(SECRET_ASSIGNMENT_PATTERN) do
        "#{Regexp.last_match[:key]}=[FILTERED]"
      end
    redacted = redacted.gsub(URL_PATTERN, "[FILTERED_URL]")
    redacted = redacted.gsub(CONTROL_CHARACTER_PATTERN, " ")
    [redacted, redacted != utf8]
  end

  def limited_text(value, maximum)
    return [value, false] if value.length <= maximum

    [value[0, maximum], true]
  end

  def callsite_for(callstack)
    unless callstack.is_a?(Array) && callstack.any?
      raise ArgumentError, "deprecation callstack must contain a frame"
    end

    path, line = callsite_location(callstack.first)
    unless path.is_a?(String) && line.is_a?(Integer) && line.positive?
      raise ArgumentError, "deprecation callstack location is invalid"
    end

    path, changed_before_limit = normalized_text(path)
    pathname = Pathname.new(path)
    relative_path = pathname.absolute? ? pathname.relative_path_from(Rails.root).to_s : pathname.cleanpath.to_s
    relative_path, changed_after_limit = normalized_text(relative_path)
    relative_path, truncated = limited_text(relative_path, MAX_CALLSITE_CODEPOINTS)

    [
      { file: relative_path, line: line },
      changed_before_limit || changed_after_limit,
      truncated,
    ]
  end

  def callsite_location(frame)
    if frame.is_a?(String)
      match = STRING_BACKTRACE_PATTERN.match(frame)
      raise ArgumentError, "deprecation callstack frame is invalid" unless match

      return [match[:path], Integer(match[:line], 10)]
    end

    unless frame.respond_to?(:path) && frame.respond_to?(:lineno)
      raise ArgumentError, "deprecation callstack frame is invalid"
    end

    [frame.path, frame.lineno]
  end

  def bounded_json(fields)
    json = JitLogEvent.format(LOG_EVENT_NAME, **fields)
    return json if valid_bounded_json?(json)

    original_message = fields.fetch(:message)
    minimum = 0
    maximum = original_message.length
    best_fit = nil

    while minimum <= maximum
      middle = (minimum + maximum) / 2
      candidate_fields = fields.merge(message: original_message[0, middle], truncated: true)
      candidate_json = JitLogEvent.format(LOG_EVENT_NAME, **candidate_fields)

      if valid_bounded_json?(candidate_json)
        best_fit = candidate_json
        minimum = middle + 1
      else
        maximum = middle - 1
      end
    end

    raise RangeError, "bounded deprecation record exceeds the log size limit" unless best_fit

    best_fit
  end

  def valid_bounded_json?(json)
    json.valid_encoding? && json.bytesize <= MAX_LOG_BYTES
  end
end
