# typed: false
# frozen_string_literal: true

require "test_helper"

# Base policy roots start every response from `Cache-Control: no-store`
# (adr/global-and-publishing-default-no-store-policy.md): rendered pages, redirects issued by
# authentication callbacks, and responses the FQDN availability gate ends before the action runs.
# Explicit opt-ins (sitemap, JWKS) keep their public cache contract.
class DefaultNoStoreBaseTest < ActionDispatch::IntegrationTest
  test "Base app ApplicationController root page is no-store" do
    host!("base.app.localhost")

    get("/", params: { ri: "jp" })

    assert_response :success
    assert_includes response.headers.fetch("Cache-Control"), "no-store"
  end

  test "Base app ApplicationController authentication redirect is no-store" do
    host!("base.app.localhost")

    get("/groups", params: { ri: "jp" })

    assert_response :found
    assert_equal "no-store", response.headers.fetch("Cache-Control")
  end

  test "Base app ApplicationController response halted by the availability gate is no-store" do
    Flipper.disable(FqdnAvailabilityRegistry.flag_name_for(:base_service))
    host!("base.app.localhost")

    get("/groups", params: { ri: "jp" })

    assert_response :service_unavailable
    assert_equal "no-store", response.headers.fetch("Cache-Control")
  end

  test "Base com ApplicationController root page is no-store" do
    host!("base.com.localhost")

    get("/", params: { ri: "jp" })

    assert_response :success
    assert_includes response.headers.fetch("Cache-Control"), "no-store"
  end

  test "Base com ApplicationController authentication redirect is no-store" do
    host!("base.com.localhost")

    get("/accounts", params: { ri: "jp" })

    assert_response :found
    assert_equal "no-store", response.headers.fetch("Cache-Control")
  end

  test "Base com ApplicationController response halted by the availability gate is no-store" do
    Flipper.disable(FqdnAvailabilityRegistry.flag_name_for(:base_corporate))
    host!("base.com.localhost")

    get("/accounts", params: { ri: "jp" })

    assert_response :service_unavailable
    assert_equal "no-store", response.headers.fetch("Cache-Control")
  end

  test "Base org ApplicationController root page is no-store" do
    host!("base.org.localhost")

    get("/", params: { ri: "jp" })

    assert_response :success
    assert_includes response.headers.fetch("Cache-Control"), "no-store"
  end

  test "Base org ApplicationController authentication redirect is no-store" do
    host!("base.org.localhost")

    get("/configuration", params: { ri: "jp" })

    assert_response :found
    assert_equal "no-store", response.headers.fetch("Cache-Control")
  end

  test "Base org ApplicationController response halted by the availability gate is no-store" do
    Flipper.disable(FqdnAvailabilityRegistry.flag_name_for(:base_staff))
    host!("base.org.localhost")

    get("/configuration", params: { ri: "jp" })

    assert_response :service_unavailable
    assert_equal "no-store", response.headers.fetch("Cache-Control")
  end

  test "Base dev ApplicationController root page is no-store" do
    host!("base.dev.localhost")

    get("/")

    assert_response :success
    assert_equal "no-store", response.headers.fetch("Cache-Control")
  end

  test "Base dev ApplicationController response halted by the availability gate is no-store" do
    Flipper.disable(FqdnAvailabilityRegistry.flag_name_for(:base_developer))
    host!("base.dev.localhost")

    get("/")

    assert_response :service_unavailable
    assert_equal "no-store", response.headers.fetch("Cache-Control")
  end

  test "Base net ApplicationController root page is no-store" do
    host!("base.net.localhost")

    get("/")

    assert_response :success
    assert_equal "no-store", response.headers.fetch("Cache-Control")
  end

  test "Base net ApplicationController response halted by the availability gate is no-store" do
    Flipper.disable(FqdnAvailabilityRegistry.flag_name_for(:base_network))
    host!("base.net.localhost")

    get("/")

    assert_response :service_unavailable
    assert_equal "no-store", response.headers.fetch("Cache-Control")
  end

  test "Base app BareController robots.txt is no-store" do
    host!("base.app.localhost")

    get("/robots.txt")

    assert_response :success
    assert_equal "no-store", response.headers.fetch("Cache-Control")
  end

  test "Base app BareController sitemap keeps its explicit public cache opt-in" do
    host!("base.app.localhost")

    get("/sitemap.xml")

    assert_response :success
    cache_control = response.headers.fetch("Cache-Control").split(", ")

    assert_includes cache_control, "public"
    assert_includes cache_control, "max-age=300"
    assert_includes cache_control, "s-maxage=600"
    assert_not_includes cache_control, "no-store"
  end

  test "Base app BareController JWKS keeps its explicit public cache opt-in" do
    host!("base.app.localhost")

    get("/.well-known/jwks.json")

    assert_response :success
    assert_equal "max-age=3600, public", response.headers.fetch("Cache-Control")
  end

  test "Base app BareController response halted by the availability gate is no-store" do
    Flipper.disable(FqdnAvailabilityRegistry.flag_name_for(:base_service))
    host!("base.app.localhost")

    get("/robots.txt")

    assert_response :service_unavailable
    assert_equal "no-store", response.headers.fetch("Cache-Control")
  end

  test "Base com BareController robots.txt is no-store" do
    host!("base.com.localhost")

    get("/robots.txt")

    assert_response :success
    assert_equal "no-store", response.headers.fetch("Cache-Control")
  end

  test "Base com BareController sitemap keeps its explicit public cache opt-in" do
    host!("base.com.localhost")

    get("/sitemap.xml")

    assert_response :success
    cache_control = response.headers.fetch("Cache-Control").split(", ")

    assert_includes cache_control, "public"
    assert_includes cache_control, "max-age=300"
    assert_includes cache_control, "s-maxage=600"
    assert_not_includes cache_control, "no-store"
  end

  test "Base com BareController response halted by the availability gate is no-store" do
    Flipper.disable(FqdnAvailabilityRegistry.flag_name_for(:base_corporate))
    host!("base.com.localhost")

    get("/robots.txt")

    assert_response :service_unavailable
    assert_equal "no-store", response.headers.fetch("Cache-Control")
  end

  test "Base org BareController robots.txt is no-store" do
    host!("base.org.localhost")

    get("/robots.txt")

    assert_response :success
    assert_equal "no-store", response.headers.fetch("Cache-Control")
  end

  test "Base org BareController sitemap keeps its explicit public cache opt-in" do
    host!("base.org.localhost")

    get("/sitemap.xml")

    assert_response :success
    cache_control = response.headers.fetch("Cache-Control").split(", ")

    assert_includes cache_control, "public"
    assert_includes cache_control, "max-age=300"
    assert_includes cache_control, "s-maxage=600"
    assert_not_includes cache_control, "no-store"
  end

  test "Base org BareController response halted by the availability gate is no-store" do
    Flipper.disable(FqdnAvailabilityRegistry.flag_name_for(:base_staff))
    host!("base.org.localhost")

    get("/robots.txt")

    assert_response :service_unavailable
    assert_equal "no-store", response.headers.fetch("Cache-Control")
  end

  test "Base dev BareController revision is no-store" do
    host!("base.dev.localhost")

    get("/revision")

    assert_response :success
    assert_equal "no-store", response.headers.fetch("Cache-Control")
  end

  test "Base dev BareController response halted by the availability gate is no-store" do
    Flipper.disable(FqdnAvailabilityRegistry.flag_name_for(:base_developer))
    host!("base.dev.localhost")

    get("/revision")

    assert_response :service_unavailable
    assert_equal "no-store", response.headers.fetch("Cache-Control")
  end

  test "Base net BareController revision is no-store" do
    host!("base.net.localhost")

    get("/revision")

    assert_response :success
    assert_equal "no-store", response.headers.fetch("Cache-Control")
  end

  test "Base net BareController response halted by the availability gate is no-store" do
    Flipper.disable(FqdnAvailabilityRegistry.flag_name_for(:base_network))
    host!("base.net.localhost")

    get("/revision")

    assert_response :service_unavailable
    assert_equal "no-store", response.headers.fetch("Cache-Control")
  end
end
