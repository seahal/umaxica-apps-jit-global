# typed: false
# frozen_string_literal: true

require "test_helper"

# Xper policy roots start every response from `Cache-Control: no-store`
# (adr/global-and-publishing-default-no-store-policy.md), including responses the FQDN availability
# gate ends before the action runs.
class DefaultNoStoreXperTest < ActionDispatch::IntegrationTest
  test "Xper app ApplicationController landing page is no-store" do
    host!("xper.app.localhost")

    get("/")

    assert_response :success
    assert_equal "no-store", response.headers.fetch("Cache-Control")
  end

  test "Xper app ApplicationController response halted by the availability gate is no-store" do
    Flipper.disable(FqdnAvailabilityRegistry.flag_name_for(:xper_service))
    host!("xper.app.localhost")

    get("/")

    assert_response :service_unavailable
    assert_equal "no-store", response.headers.fetch("Cache-Control")
  end

  test "Xper com ApplicationController landing page is no-store" do
    host!("xper.com.localhost")

    get("/")

    assert_response :success
    assert_equal "no-store", response.headers.fetch("Cache-Control")
  end

  test "Xper com ApplicationController response halted by the availability gate is no-store" do
    Flipper.disable(FqdnAvailabilityRegistry.flag_name_for(:xper_corporate))
    host!("xper.com.localhost")

    get("/")

    assert_response :service_unavailable
    assert_equal "no-store", response.headers.fetch("Cache-Control")
  end

  test "Xper org ApplicationController landing page is no-store" do
    host!("xper.org.localhost")

    get("/")

    assert_response :success
    assert_equal "no-store", response.headers.fetch("Cache-Control")
  end

  test "Xper org ApplicationController response halted by the availability gate is no-store" do
    Flipper.disable(FqdnAvailabilityRegistry.flag_name_for(:xper_staff))
    host!("xper.org.localhost")

    get("/")

    assert_response :service_unavailable
    assert_equal "no-store", response.headers.fetch("Cache-Control")
  end

  test "Xper app BareController robots.txt is no-store" do
    host!("xper.app.localhost")

    get("/robots.txt")

    assert_response :success
    assert_equal "no-store", response.headers.fetch("Cache-Control")
  end

  test "Xper app BareController response halted by the availability gate is no-store" do
    Flipper.disable(FqdnAvailabilityRegistry.flag_name_for(:xper_service))
    host!("xper.app.localhost")

    get("/sitemap.xml")

    assert_response :service_unavailable
    assert_equal "no-store", response.headers.fetch("Cache-Control")
  end

  test "Xper com BareController robots.txt is no-store" do
    host!("xper.com.localhost")

    get("/robots.txt")

    assert_response :success
    assert_equal "no-store", response.headers.fetch("Cache-Control")
  end

  test "Xper com BareController response halted by the availability gate is no-store" do
    Flipper.disable(FqdnAvailabilityRegistry.flag_name_for(:xper_corporate))
    host!("xper.com.localhost")

    get("/sitemap.xml")

    assert_response :service_unavailable
    assert_equal "no-store", response.headers.fetch("Cache-Control")
  end

  test "Xper org BareController robots.txt is no-store" do
    host!("xper.org.localhost")

    get("/robots.txt")

    assert_response :success
    assert_equal "no-store", response.headers.fetch("Cache-Control")
  end

  test "Xper org BareController response halted by the availability gate is no-store" do
    Flipper.disable(FqdnAvailabilityRegistry.flag_name_for(:xper_staff))
    host!("xper.org.localhost")

    get("/sitemap.xml")

    assert_response :service_unavailable
    assert_equal "no-store", response.headers.fetch("Cache-Control")
  end
end
