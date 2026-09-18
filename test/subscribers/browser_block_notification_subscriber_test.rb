# frozen_string_literal: true

require "test_helper"

class BrowserBlockNotificationSubscriberTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  FakeRequest = Struct.new(:controller_class, :path_parameters, :host, :path, :user_agent)

  test "logs the parsed browser and requested resource without the raw user agent" do
    messages = []
    request = FakeRequest.new(
      Base::App::RootsController,
      { action: "index" },
      "app.umaxica.test",
      "/",
      "Mozilla/5.0 (Windows NT 6.1) AppleWebKit/537.36 Chrome/41.0.2228.0 Safari/537.36",
    )
    event = ActiveSupport::Notifications::Event.new(
      "browser_block.action_controller",
      Time.current,
      Time.current,
      "event-id",
      { request: request, versions: :modern },
    )

    Rails.logger.stub(:info, ->(message) { messages << message }) do
      BrowserBlockNotificationSubscriber.new.emit(event)
    end

    parsed = JSON.parse(messages.fetch(0))

    assert_equal "security.browser_block.blocked", parsed.fetch("event")
    assert_equal(
      {
        "controller" => "Base::App::RootsController",
        "action" => "index",
        "host" => "app.umaxica.test",
        "path" => "/",
        "browser" => "Chrome",
        "browser_version" => "41.0.2228.0",
        "required_versions" => "modern",
      },
      parsed.fetch("data"),
    )
    assert_not_includes messages.fetch(0), "AppleWebKit"
  end

  test "subscriber failures do not expose payload values" do
    messages = []
    logger = Object.new
    logger.define_singleton_method(:info) { |_message| raise RuntimeError, "logger unavailable" }
    logger.define_singleton_method(:error) { |message| messages << message }
    request = FakeRequest.new(nil, {}, "app.umaxica.test", "/", "Mozilla/5.0")
    event = ActiveSupport::Notifications::Event.new(
      "browser_block.action_controller",
      Time.current,
      Time.current,
      "event-id",
      { request: request, versions: :modern },
    )

    Rails.stub(:logger, logger) do
      BrowserBlockNotificationSubscriber.new.emit(event)
    end

    parsed = JSON.parse(messages.fetch(0))

    assert_equal BrowserBlockNotificationSubscriber::FAILURE_EVENT_NAME, parsed.fetch("event")
    assert_equal({ "error_class" => "RuntimeError" }, parsed.fetch("data"))
  end

  test "registered notification subscriber logs Rails browser_block events in process" do
    messages = []
    request = FakeRequest.new(nil, {}, "app.umaxica.test", "/", "Mozilla/5.0")

    Rails.logger.stub(:info, ->(message) { messages << message }) do
      ActiveSupport::Notifications.instrument(
        "browser_block.action_controller",
        request: request,
        versions: :modern,
      )
    end

    assert_equal "security.browser_block.blocked", JSON.parse(messages.fetch(0)).fetch("event")
  end
end
