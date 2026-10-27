# frozen_string_literal: true

require "test_helper"

class RetiredSignOutRouteTest < ActionDispatch::IntegrationTest
  RP_HOSTS = %w(
    base.app.localhost base.com.localhost base.org.localhost
    core.app.localhost core.com.localhost core.org.localhost
    warp.app.localhost warp.com.localhost warp.org.localhost
    edit.org.localhost palm.app.localhost tech.org.localhost
  ).freeze
  VISA_HOSTS = %w(visa.app.localhost visa.com.localhost visa.org.localhost).freeze

  test "retired browser receipt and cookie purge endpoints are not routed" do
    (VISA_HOSTS + RP_HOSTS).each do |host|
      %i(get post).each do |method|
        assert_unrouted(host, "/sign/bye", method)
      end
    end

    RP_HOSTS.each do |host|
      assert_unrouted(host, "/sign/out/purge", :post)
    end
  end

  test "A10-4: retired refresh-delivery receipt endpoints are not routed" do
    VISA_HOSTS.each do |host|
      %i(get post).each do |method|
        assert_raises(ActionController::RoutingError, "#{method} #{host}") do
          Rails.application.routes.recognize_path("https://#{host}/oauth/refresh-deliveries/query", method: method)
        end
      end
    end
  end

  private

  def assert_unrouted(host, path, method)
    assert_raises(ActionController::RoutingError, "#{method.to_s.upcase} #{host}#{path}") do
      Rails.application.routes.recognize_path("https://#{host}#{path}", method: method)
    end
  end
end
