# typed: false
# frozen_string_literal: true

require "test_helper"

# Edit (Publishing management) and GUID policy roots start every response from
# `Cache-Control: no-store` (adr/global-and-publishing-default-no-store-policy.md), including
# authentication redirects and responses the FQDN availability gate ends before the action runs.
class DefaultNoStoreEditGuidTest < ActionDispatch::IntegrationTest
  test "Edit org ApplicationController root page is no-store" do
    host!("edit.org.localhost")

    get("/", params: { ri: "jp" })

    assert_response :success
    assert_includes response.headers.fetch("Cache-Control"), "no-store"
  end

  test "Edit org ApplicationController Publishing management region redirect is no-store" do
    host!("edit.org.localhost")

    get("/publishing/info/org/entries")

    assert_response :found
    assert_equal "no-store", response.headers.fetch("Cache-Control")
  end

  test "Edit org ApplicationController response halted by the availability gate is no-store" do
    Flipper.disable(FqdnAvailabilityRegistry.flag_name_for(:edit_staff))
    host!("edit.org.localhost")

    get("/publishing/info/org/entries")

    assert_response :service_unavailable
    assert_equal "no-store", response.headers.fetch("Cache-Control")
  end

  test "Edit org BareController revision is no-store" do
    host!("edit.org.localhost")

    get("/revision")

    assert_response :success
    assert_equal "no-store", response.headers.fetch("Cache-Control")
  end

  test "Edit org BareController response halted by the availability gate is no-store" do
    Flipper.disable(FqdnAvailabilityRegistry.flag_name_for(:edit_staff))
    host!("edit.org.localhost")

    get("/revision")

    assert_response :service_unavailable
    assert_equal "no-store", response.headers.fetch("Cache-Control")
  end

  test "Guid net BareController service page is no-store" do
    host!("guid.net.localhost")

    get("/")

    assert_response :success
    assert_equal "no-store", response.headers.fetch("Cache-Control")
  end

  test "Guid net BareController response halted by the availability gate is no-store" do
    Flipper.disable(FqdnAvailabilityRegistry.flag_name_for(:guid_service))
    host!("guid.net.localhost")

    get("/")

    assert_response :service_unavailable
    assert_equal "no-store", response.headers.fetch("Cache-Control")
  end
end
