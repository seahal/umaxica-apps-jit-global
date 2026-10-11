# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class SignOrgSettingsActivityLogPresenterTest < ActiveSupport::TestCase
  ActivityStub = Struct.new(:event_id, :occurred_at, :created_at, :ip_address, :context, keyword_init: true)

  def stub_activity(event_id: 1, ip: "192.168.1.1", context: {}, occurred_at: nil, created_at: Time.current)
    ActivityStub.new(
      event_id: event_id, occurred_at: occurred_at, created_at: created_at, ip_address: ip,
      context: context,
    )
  end

  setup do
    @log = Auth::Org::Settings::ActivityLogPresenter.new(operators(:one))
  end

  test "occurred_at returns occurred_at when present" do
    time = Time.zone.parse("2024-01-01 12:00:00 UTC")
    activity = stub_activity(occurred_at: time)

    assert_equal time, @log.occurred_at(activity)
  end

  test "occurred_at does not use persistence metadata when the event time is absent" do
    time = Time.zone.parse("2024-01-01 12:00:00 UTC")
    activity = stub_activity(occurred_at: nil, created_at: time)

    assert_nil @log.occurred_at(activity)
  end

  test "event_label translates known event" do
    activity = stub_activity(event_id: OperatorChronicleEvent::LOGGED_IN)
    I18n.with_locale(:en) do
      label = @log.event_label(activity)

      assert_kind_of String, label
      assert_predicate label, :present?
    end
  end

  test "event_label falls back for unknown event" do
    activity = stub_activity(event_id: 999_999)
    I18n.with_locale(:en) do
      label = @log.event_label(activity)

      assert_includes label, "999999"
    end
  end

  test "ip_address masks IPv4" do
    activity = stub_activity(ip: "203.0.113.42")

    assert_equal "203.0.113.x", @log.ip_address(activity)
  end

  test "ip_address returns dash for blank" do
    activity = stub_activity(ip: "")

    assert_equal "-", @log.ip_address(activity)
  end

  test "ip_address returns raw value for non-IPv4" do
    activity = stub_activity(ip: "2001:db8::1")

    assert_equal "2001:db8::1", @log.ip_address(activity)
  end

  test "context_text filters sensitive keys" do
    activity = stub_activity(context: { "user_agent" => "Chrome", "secret_credential" => "abc", "browser" => "Chrome" })

    text = @log.context_text(activity)
    parsed = JSON.parse(text)

    assert_includes parsed, "browser"
    assert_not_includes parsed, "secret_credential"
    assert_not_includes parsed, "user_agent"
  end

  test "context_text returns empty hash for non-hash context" do
    activity = stub_activity(context: "string")

    assert_equal "{}", @log.context_text(activity)
  end

  test "user_agent_summary detects Chrome desktop" do
    activity = stub_activity(context: { "user_agent" => "Mozilla/5.0 Chrome/120.0.0.0 Safari/537.36" })

    assert_equal "Chrome / Desktop", @log.user_agent_summary(activity)
  end

  test "user_agent_summary detects Edge mobile" do
    activity = stub_activity(context: { "user_agent" => "Mozilla/5.0 Edg/120.0 iPhone" })

    assert_equal "Edge / Mobile", @log.user_agent_summary(activity)
  end

  test "user_agent_summary returns dash for blank" do
    activity = stub_activity(context: {})

    assert_equal "-", @log.user_agent_summary(activity)
  end

  test "login_method returns method from context" do
    activity = stub_activity(context: { "auth_method" => "passkey" })

    assert_equal "passkey", @log.login_method(activity)
  end

  test "login_method falls back to method key" do
    activity = stub_activity(context: { "method" => "email_otp" })

    assert_equal "email_otp", @log.login_method(activity)
  end

  test "login_method returns dash when blank" do
    activity = stub_activity(context: {})

    assert_equal "-", @log.login_method(activity)
  end

  test "detect_browser identifies browsers" do
    assert_equal "Edge", @log.send(:detect_browser, "Edg/120")
    assert_equal "Chrome", @log.send(:detect_browser, "Chrome/120")
    assert_equal "Safari", @log.send(:detect_browser, "Safari/605.1")
    assert_equal "Firefox", @log.send(:detect_browser, "Firefox/120")
    assert_equal "Other", @log.send(:detect_browser, "UnknownBrowser/1.0")
  end

  test "detect_device_type identifies devices" do
    assert_equal "Mobile", @log.send(:detect_device_type, "Mobile Safari")
    assert_equal "Mobile", @log.send(:detect_device_type, "iPhone")
    assert_equal "Tablet", @log.send(:detect_device_type, "iPad")
    assert_equal "Desktop", @log.send(:detect_device_type, "Windows Chrome")
  end

  test "sensitive_context_key detects sensitive patterns" do
    assert @log.send(:sensitive_context_key?, "authorization")
    assert @log.send(:sensitive_context_key?, "token_value")
    assert_not @log.send(:sensitive_context_key?, "browser")
  end

  test "context_text handles non-serializable context" do
    bad_context = Object.new

    def bad_context.is_a?(klass) = (klass == Hash) ? true : super

    def bad_context.deep_stringify_keys
      raise TypeError, "can't convert to JSON"
    end

    activity = stub_activity(context: bad_context)

    assert_equal "{}", @log.context_text(activity)
  end

  test "activities returns an enumerable" do
    result = @log.activities

    assert_kind_of Enumerable, result
  end
end
