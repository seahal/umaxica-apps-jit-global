# typed: false
# frozen_string_literal: true

# rubocop:disable I18n/RailsI18n/DecorateString

require "test_helper"

# Rails 8.2 instruments CSRF outcomes as ActiveSupport::Notifications events
# (rails/rails#56355): csrf_request_blocked, csrf_javascript_blocked, and
# csrf_token_fallback, all on the .action_controller namespace.
#
# config/initializers/csrf_notifications.rb subscribes CsrfNotificationSubscriber
# to those three names. test/subscribers/csrf_notification_subscriber_test.rb covers
# the subscriber in isolation by handing it a synthetic event, which cannot show that
# Rails actually emits anything here or that the subscription is attached. These tests
# close that gap by driving a real request.
class CsrfNotificationEmissionTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  SUBSCRIBED_EVENTS = %w(
    csrf_request_blocked.action_controller
    csrf_javascript_blocked.action_controller
    csrf_token_fallback.action_controller
  ).freeze

  test "the application is subscribed to every CSRF event Rails emits" do
    SUBSCRIBED_EVENTS.each do |event_name|
      assert ActiveSupport::Notifications.notifier.listening?(event_name),
             "Nothing is subscribed to #{event_name}. A CSRF failure would leave no trace."
    end
  end

  test "the subscribed names match the names Rails 8.2 actually instruments" do
    source = Rails.root.join(
      "vendor/bundle/ruby/4.0.0/bundler/gems",
    ).glob("rails-*/actionpack/lib/action_controller/metal/request_forgery_protection.rb").first

    skip "Rails source is not vendored in this environment" if source.nil?

    instrumented = source.read.scan(/instrument_csrf_event\s+"([^"]+)"/).flatten.uniq

    assert_equal SUBSCRIBED_EVENTS.sort, instrumented.sort,
                 "Rails instruments #{instrumented.inspect} but the initializer subscribes to " \
                 "#{SUBSCRIBED_EVENTS.inspect}. A renamed or added event would go unrecorded."
  end

  test "a cross-site POST is blocked and emits csrf_request_blocked with a usable payload" do
    events =
      capture_csrf_events do
        with_forgery_protection do
          post(
            auth_app_sign_in_email_url(ri: "jp"),
            params: { user_email: { address: "csrf-probe@example.com" } },
            headers: { "Host" => ENV.fetch("PUBLIC_AUTH_SERVICE_URL", "auth.app.localhost"),
                       "Sec-Fetch-Site" => "cross-site", },
          )
        end
      end

    blocked = events.find { |event| event.name == "csrf_request_blocked.action_controller" }

    assert_not_nil blocked, "A cross-site POST must emit csrf_request_blocked. Got: #{events.map(&:name).inspect}"
    assert_equal "cross-site", blocked.payload[:sec_fetch_site]
    assert_predicate blocked.payload[:controller], :present?
    assert_predicate blocked.payload[:action], :present?
  end

  test "the subscriber records a blocked request without logging the request or message" do
    output = capture_logs { post_cross_site_sign_in }

    assert_match "security.csrf.request_blocked", output,
                 "The subscriber must turn the Rails event into an application log event."
    # The Rails payload also carries :request and :message. Neither is safe to log:
    # the request object and the unverified-request warning both quote the URL.
    assert_no_match(/csrf-probe@example\.com/, output)
    assert_no_match(/#<ActionDispatch::Request/, output)
  end

  # Every phrasing unverified_request_warning_message can produce. Rails'
  # ActionController::LogSubscriber writes payload[:message] verbatim when
  # log_warning_on_csrf_failure is on, which puts an Origin/base_url pair into the log
  # as free text - outside JitLogEvent.format, so ObservabilityRedactor never sees it.
  # config/application.rb turns that off so the redacted event is the only record;
  # config/environments/development.rb turns it back on for local diagnosis.
  FRAMEWORK_WARNING_SHAPES = [
    /\AHTTP Origin header .*didn't match request\.base_url/,
    /\ASec-Fetch-Site header \(cross-site\) indicates a cross-site request/,
    /\ASec-Fetch-Site header is missing or invalid/,
    /\ACan't verify CSRF token authenticity/,
  ].freeze

  # A blocked request also produces `rescue_from handled ActionController::
  # InvalidCrossOriginRequest (<message>) - <backtrace>` from
  # ActionController::LogSubscriber#rescue_from_handled (log_subscriber.rb:48-58). That is
  # a different event (`rescue_from_handled.action_controller`), it is not governed by
  # log_warning_on_csrf_failure, and it applies to every rescue_from in the application
  # rather than to CSRF specifically. It is excluded here so this test measures only what
  # the CSRF setting controls.
  #
  # It is worth knowing that the exception message it prints is the same
  # unverified_request_warning_message, so on the Origin-mismatch branch that line does
  # carry an Origin/base_url pair outside JitLogEvent.format. Narrowing it is an
  # application-wide decision about rescue_from reporting, not a CSRF change, so it is
  # deliberately out of scope for this test.
  RESCUE_FROM_LINE_MARKER = "rescue_from handled"

  test "a blocked request is recorded once, by the subscriber, with no framework CSRF warning" do
    output = capture_logs { post_cross_site_sign_in }

    assert_equal 1, output.scan("security.csrf.request_blocked").size,
                 "The blocked request must be recorded exactly once."

    csrf_warning_lines =
      output.lines
        .reject { |line| line.include?(RESCUE_FROM_LINE_MARKER) }
        .select { |line| FRAMEWORK_WARNING_SHAPES.any? { |shape| line.match?(shape) } }

    assert_empty csrf_warning_lines,
                 "Rails' own CSRF warning is still being written. It carries the Origin and " \
                 "base_url as free text, which bypasses ObservabilityRedactor. Set " \
                 "config.action_controller.log_warning_on_csrf_failure = false."
  end

  private

  def post_cross_site_sign_in
    with_forgery_protection do
      post(
        auth_app_sign_in_email_url(ri: "jp"),
        params: { user_email: { address: "csrf-probe@example.com" } },
        headers: { "Host" => ENV.fetch("PUBLIC_AUTH_SERVICE_URL", "auth.app.localhost"),
                   "Sec-Fetch-Site" => "cross-site", },
      )
    end
  end

  # Both loggers have to be swapped: the application subscriber writes through
  # Rails.logger, while ActionController::LogSubscriber writes through
  # ActionController::Base.logger, which is captured at boot and does not follow a later
  # reassignment of Rails.logger. Capturing only one would make the "recorded once"
  # assertion pass vacuously.
  def capture_logs
    buffer = StringIO.new
    capture_logger = ActiveSupport::Logger.new(buffer)
    previous_rails_logger = Rails.logger
    previous_controller_logger = ActionController::Base.logger
    Rails.logger = capture_logger
    ActionController::Base.logger = capture_logger

    yield

    buffer.string
  ensure
    Rails.logger = previous_rails_logger
    ActionController::Base.logger = previous_controller_logger
  end

  def capture_csrf_events(&)
    captured = []
    subscriptions =
      SUBSCRIBED_EVENTS.map do |event_name|
        ActiveSupport::Notifications.subscribe(event_name) { |event| captured << event }
      end
    yield
    captured
  ensure
    subscriptions&.each { |subscription| ActiveSupport::Notifications.unsubscribe(subscription) }
  end

  def with_forgery_protection
    previous = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    yield
  ensure
    ActionController::Base.allow_forgery_protection = previous
  end
end

# rubocop:enable I18n/RailsI18n/DecorateString
