# frozen_string_literal: true

require "useragent"

class BrowserBlockNotificationSubscriber
  EVENT_NAME = "security.browser_block.blocked"
  FAILURE_EVENT_NAME = "security.browser_block.subscriber_failed"

  public

  def emit(event)
    payload = event.payload
    request = payload[:request]
    parsed_user_agent = UserAgent.parse(request&.user_agent)

    Rails.logger.info(
      JitLogEvent.format(
        EVENT_NAME,
        controller: request&.controller_class&.name,
        action: request&.path_parameters&.[](:action),
        host: request&.host,
        path: request&.path,
        browser: parsed_user_agent.browser,
        browser_version: parsed_user_agent.version.to_s,
        required_versions: payload[:versions].to_s,
      ),
    )
  rescue StandardError => e
    Rails.logger.error(
      JitLogEvent.format(
        FAILURE_EVENT_NAME,
        error_class: e.class.name,
      ),
    )
  end
end
