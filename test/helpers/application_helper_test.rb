# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class ApplicationHelperTest < ActionView::TestCase
  include ActiveSupport::Testing::TimeHelpers

  fixtures :client_banners, :operator_banners, :clients, :client_statuses, :operators,
           :operator_statuses

  setup do
    @helper_context = view
    @helper_context.extend(ApplicationHelper)
    define_singleton_method(:theme_cookie_value) { |value = nil| @helper_context.theme_cookie_value(value) }
    define_singleton_method(:theme_html_class) { |value = nil| @helper_context.theme_html_class(value) }
    define_singleton_method(:edge_host) { @helper_context.edge_host }
    define_singleton_method(:current_banner_for) { |**kwargs| @helper_context.current_banner_for(**kwargs) }
  end

  def stub_request_host(host)
    cookie_hash = {}
    @helper_context.define_singleton_method(:request) { Struct.new(:host, :cookies).new(host, cookie_hash) }
  end

  def with_edge_env(overrides)
    keys = %w(PUBLIC_EDGE_SERVICE_URL PUBLIC_EDGE_STAFF_URL PUBLIC_EDGE_CORPORATE_URL EDGE_SERVICE_URL EDGE_STAFF_URL
              EDGE_CORPORATE_URL)
    previous = keys.index_with { |key| ENV[key] }

    overrides.each do |key, value|
      value.nil? ? ENV.delete(key) : ENV[key] = value
    end

    yield
  ensure
    previous.each do |key, value|
      value.nil? ? ENV.delete(key) : ENV[key] = value
    end
  end

  test "theme_cookie_value maps the Preference theme codes and names" do
    { "dr" => "dark", "dark" => "dark", "li" => "light", "light" => "light",
      "sy" => "system", "system" => "system", }.each do |value, expected|
      assert_equal expected, theme_cookie_value(value), value
    end
  end

  test "theme_cookie_value reads the request Actor display value" do
    Actor.install_context!(preferences: Actor::Preference.new(theme: "dr"))

    assert_equal "dark", theme_cookie_value
  ensure
    Actor.clear
  end

  test "theme_cookie_value uses system for a missing or unsupported value" do
    Actor.install_context!(preferences: Actor::Preference::NULL)

    assert_equal "system", theme_cookie_value
    assert_equal "system", theme_cookie_value("unknown")
  ensure
    Actor.clear
  end

  test "theme_html_class includes dark class only for dark Preference theme" do
    assert_equal "theme-dark dark", theme_html_class("dr")
    assert_equal "theme-light", theme_html_class("li")
    assert_equal "theme-system", theme_html_class("sy")
  end

  test "page_title sets content for with title" do
    view.extend(ApplicationHelper)
    view.content_for(:page_title, nil)

    view.page_title("Test Title")

    assert_equal "Test Title", view.content_for(:page_title)
  end

  test "page_title returns blank when no title set so the site title stands alone" do
    view.extend(ApplicationHelper)

    assert_predicate view.page_title, :blank?
  end

  test "theme_class is backward compatible alias for theme_html_class" do
    Actor.install_context!(preferences: Actor::Preference.new(theme: "dr"))

    assert_equal theme_html_class, @helper_context.theme_class
  ensure
    Actor.clear
  end

  test "current_banner_for returns current banner for each surface" do
    travel_to Time.zone.parse("2026-03-18 00:00:00 UTC") do
      assert_equal client_banners(:newer_current_user_banner), current_banner_for(tld: :app, region: :jp, domain: :news)
      assert_equal operator_banners(:current_staff_banner), current_banner_for(tld: :org, region: :jp, domain: :news)
    end
  end

  test "current_banner_for uses the writing connection" do
    travel_to Time.zone.parse("2026-03-18 00:00:00 UTC") do
      roles = []

      AppZenithRecord.stub(
        :connected_to, ->(role:, &block) do
                         roles << role
                         block.call
                       end,
      ) do
        assert_equal client_banners(:newer_current_user_banner),
                     current_banner_for(tld: :app, region: :jp, domain: :news)
      end

      assert_equal [:writing], roles
    end
  end

  test "edge_host returns nil when matching edge env is unset" do
    stub_request_host(ENV["MAIN_CORPORATE_URL"])

    with_edge_env("PUBLIC_EDGE_CORPORATE_URL" => nil, "EDGE_CORPORATE_URL" => nil) do
      assert_raises(KeyError) { edge_host }
    end
  end

  test "edge_host resolves service edge host for user surface" do
    stub_request_host(ENV["MAIN_SERVICE_URL"])

    with_edge_env("PUBLIC_EDGE_SERVICE_URL" => "https://edge.app.localhost:5171") do
      assert_equal "edge.com.localhost", edge_host
    end
  end

  test "edge_host resolves staff edge host for staff surface" do
    stub_request_host(ENV["PUBLIC_WARP_STAFF_URL"])

    with_edge_env("PUBLIC_EDGE_STAFF_URL" => "edge.org.localhost", "EDGE_STAFF_URL" => nil) do
      assert_equal "edge.org.localhost", edge_host
    end
  end

  test "edge_host resolves corporate edge host for client surface" do
    stub_request_host(ENV["PRIVATE_DOCS_CORPORATE_URL"])

    with_edge_env("PUBLIC_EDGE_CORPORATE_URL" => "http://edge.com.localhost", "EDGE_CORPORATE_URL" => nil) do
      assert_equal "edge.com.localhost", edge_host
    end
  end

  test "current_banner_for returns nil when the connection is unavailable" do
    travel_to Time.zone.parse("2026-03-18 00:00:00 UTC") do
      AppZenithRecord.stub(
        :connected_to,
        ->(*) {
          raise ActiveRecord::ConnectionNotEstablished
        },
      ) do
        assert_nil current_banner_for(tld: :app, region: :jp, domain: :news)
      end
    end
  end

  test "current_banner_for normalizes a :global region to :ww for sign and acme domains" do
    travel_to Time.zone.parse("2026-03-18 00:00:00 UTC") do
      assert_equal client_banners(:newer_current_user_banner),
                   current_banner_for(tld: :app, region: :global, domain: :sign)
      assert_equal client_banners(:newer_current_user_banner),
                   current_banner_for(tld: :app, region: :global, domain: :acme)
    end
  end

  private
end
