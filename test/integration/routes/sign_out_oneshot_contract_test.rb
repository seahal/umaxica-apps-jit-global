# typed: false
# frozen_string_literal: true

require "test_helper"

class SignOutOneshotContractTest < ActionDispatch::IntegrationTest
  test "every first-party Browser RP exposes a GET-only OIDC logout return route" do
    hosts = Rails.configuration.x.boot_config.fetch(:hosts)
    cases = [
      [hosts.core_service.host, "core/app/sign/outs"],
      [hosts.core_corporate.host, "core/com/sign/outs"],
      [hosts.core_staff.host, "core/org/sign/outs"],
      [hosts.warp_service.host, "warp/app/sign/outs"],
      [hosts.warp_corporate.host, "warp/com/sign/outs"],
      [hosts.warp_staff.host, "warp/org/sign/outs"],
      [hosts.edit_staff.host, "edit/org/sign/outs"],
      [hosts.base_service.host, "base/app/sign_outs"],
      [hosts.base_corporate.host, "base/com/sign_outs"],
      [hosts.base_staff.host, "base/org/sign_outs"],
      [hosts.palm_service.host, "palm/app/sign/out/completions"],
      [hosts.tech_staff.host, "tech/org/sign/out/completions"],
    ]

    cases.each do |host, controller|
      get_route = Rails.application.routes.recognize_path("https://#{host}/sign/out/completion", method: :get)

      assert_equal controller, get_route.fetch(:controller), host
      assert_equal "show", get_route.fetch(:action), host
      assert_raises(ActionController::RoutingError, host) do
        Rails.application.routes.recognize_path("https://#{host}/sign/out/completion", method: :post)
      end
    end
  end

  test "Browser RP sign-out start does not expose a DELETE cancellation route" do
    hosts = Rails.configuration.x.boot_config.fetch(:hosts)
    browser_rp_hosts = [
      hosts.core_service.host,
      hosts.core_corporate.host,
      hosts.core_staff.host,
      hosts.warp_service.host,
      hosts.warp_corporate.host,
      hosts.warp_staff.host,
      hosts.edit_staff.host,
      hosts.palm_service.host,
      hosts.tech_staff.host,
    ]

    browser_rp_hosts.each do |host|
      assert_raises(ActionController::RoutingError, host) do
        Rails.application.routes.recognize_path("https://#{host}/sign/out", method: :delete)
      end
    end
  end

  test "/sign/out/complete is unroutable and completions controllers are gone" do
    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("/sign/out/complete", method: :get)
    end

    %w(Auth Core Warp).each do |surface|
      %w(App Com Org).each do |face|
        assert_not Object.const_defined?("#{surface}::#{face}::Sign::Outs::CompletionsController")
      end
    end

    assert_equal 5.minutes, Valkey::AuthState::SignOutNoticeStore::TTL
  end
end
