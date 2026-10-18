# frozen_string_literal: true

require "test_helper"

class CsrfNotificationSubscriberTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "logs an allowlisted fallback payload at info level" do
    messages = []
    event = ActiveSupport::Notifications::Event.new(
      "csrf_token_fallback.action_controller",
      Time.current,
      Time.current,
      "event-id",
      {
        request: Object.new,
        controller: "Base::App::Api::V0::Preferences::ThemesController",
        action: "update",
        sec_fetch_site: nil,
        message: "contains request-derived details",
      },
    )

    Rails.logger.stub(:info, ->(message) { messages << message }) do
      CsrfNotificationSubscriber.new.emit(event)
    end

    parsed = JSON.parse(messages.fetch(0))

    assert_equal "security.csrf.token_fallback", parsed.fetch("event")
    assert_equal(
      {
        "controller" => "Base::App::Api::V0::Preferences::ThemesController",
        "action" => "update",
        "sec_fetch_site" => "missing",
      },
      parsed.fetch("data"),
    )
  end

  test "logs blocked requests at warn level without request or message data" do
    messages = []
    event = ActiveSupport::Notifications::Event.new(
      "csrf_request_blocked.action_controller",
      Time.current,
      Time.current,
      "event-id",
      {
        request: Object.new,
        controller: "Base::App::Api::V0::Preferences::ThemesController",
        action: "update",
        sec_fetch_site: "cross-site",
        message: "Origin https://untrusted.example did not match",
      },
    )

    Rails.logger.stub(:warn, ->(message) { messages << message }) do
      CsrfNotificationSubscriber.new.emit(event)
    end

    parsed = JSON.parse(messages.fetch(0))

    assert_equal "security.csrf.request_blocked", parsed.fetch("event")
    assert_equal "cross-site", parsed.dig("data", "sec_fetch_site")
    assert_not_includes messages.fetch(0), "untrusted.example"
  end

  test "normalizes unexpected Sec-Fetch-Site values" do
    messages = []
    event = ActiveSupport::Notifications::Event.new(
      "csrf_request_blocked.action_controller",
      Time.current,
      Time.current,
      "event-id",
      {
        controller: "ExampleController",
        action: "create",
        sec_fetch_site: "attacker-controlled",
      },
    )

    Rails.logger.stub(:warn, ->(message) { messages << message }) do
      CsrfNotificationSubscriber.new.emit(event)
    end

    assert_equal "invalid", JSON.parse(messages.fetch(0)).dig("data", "sec_fetch_site")
  end

  test "subscriber failures do not expose payload values" do
    messages = []
    logger = Object.new
    logger.define_singleton_method(:warn) { |_message| raise RuntimeError, "logger unavailable" }
    logger.define_singleton_method(:error) { |message| messages << message }
    event = ActiveSupport::Notifications::Event.new(
      "csrf_request_blocked.action_controller",
      Time.current,
      Time.current,
      "event-id",
      {
        controller: "ExampleController",
        action: "create",
        message: "Origin https://untrusted.example did not match",
      },
    )

    Rails.stub(:logger, logger) do
      CsrfNotificationSubscriber.new.emit(event)
    end

    parsed = JSON.parse(messages.fetch(0))

    assert_equal CsrfNotificationSubscriber::FAILURE_EVENT_NAME, parsed.fetch("event")
    assert_equal({ "error_class" => "RuntimeError" }, parsed.fetch("data"))
    assert_not_includes messages.fetch(0), "untrusted.example"
  end

  test "registered notification subscriber logs Rails CSRF events in process" do
    messages = []

    Rails.logger.stub(:info, ->(message) { messages << message }) do
      ActiveSupport::Notifications.instrument(
        "csrf_token_fallback.action_controller",
        controller: "ExampleController",
        action: "create",
        sec_fetch_site: nil,
      )
    end

    assert_equal "security.csrf.token_fallback", JSON.parse(messages.fetch(0)).fetch("event")
  end
end
