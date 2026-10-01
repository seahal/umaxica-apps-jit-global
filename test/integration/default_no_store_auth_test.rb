# typed: false
# frozen_string_literal: true

require "test_helper"

# Auth policy roots start every response from `Cache-Control: no-store`
# (adr/global-and-publishing-default-no-store-policy.md): rendered pages, redirects issued by
# callbacks, and responses the FQDN availability gate ends before the action runs.
class DefaultNoStoreAuthTest < ActionDispatch::IntegrationTest
  test "Auth app ApplicationController root page is no-store" do
    host!("auth.app.localhost")

    get("/", params: { ri: "jp" })

    assert_response :success
    assert_includes response.headers.fetch("Cache-Control"), "no-store"
  end

  test "Auth app ApplicationController region redirect issued by a callback is no-store" do
    host!("auth.app.localhost")

    get("/sign/in")

    assert_response :found
    assert_equal "no-store", response.headers.fetch("Cache-Control")
  end

  test "Auth app ApplicationController response halted by the availability gate is no-store" do
    Flipper.disable(FqdnAvailabilityRegistry.flag_name_for(:auth_service))
    host!("auth.app.localhost")

    get("/sign/in", params: { ri: "jp" })

    assert_response :service_unavailable
    assert_equal "no-store", response.headers.fetch("Cache-Control")
  end

  test "Auth com ApplicationController root page is no-store" do
    host!("auth.com.localhost")

    get("/", params: { ri: "jp" })

    assert_response :success
    assert_includes response.headers.fetch("Cache-Control"), "no-store"
  end

  test "Auth com ApplicationController region redirect issued by a callback is no-store" do
    host!("auth.com.localhost")

    get("/sign/in")

    assert_response :found
    assert_equal "no-store", response.headers.fetch("Cache-Control")
  end

  test "Auth com ApplicationController response halted by the availability gate is no-store" do
    Flipper.disable(FqdnAvailabilityRegistry.flag_name_for(:auth_corporate))
    host!("auth.com.localhost")

    get("/sign/in", params: { ri: "jp" })

    assert_response :service_unavailable
    assert_equal "no-store", response.headers.fetch("Cache-Control")
  end

  test "Auth org ApplicationController root page is no-store" do
    host!("auth.org.localhost")

    get("/", params: { ri: "jp" })

    assert_response :success
    assert_includes response.headers.fetch("Cache-Control"), "no-store"
  end

  test "Auth org ApplicationController region redirect issued by a callback is no-store" do
    host!("auth.org.localhost")

    get("/sign/in")

    assert_response :found
    assert_equal "no-store", response.headers.fetch("Cache-Control")
  end

  test "Auth org ApplicationController response halted by the availability gate is no-store" do
    Flipper.disable(FqdnAvailabilityRegistry.flag_name_for(:auth_staff))
    host!("auth.org.localhost")

    get("/sign/in", params: { ri: "jp" })

    assert_response :service_unavailable
    assert_equal "no-store", response.headers.fetch("Cache-Control")
  end

  test "Auth app BareController robots.txt is no-store" do
    host!("auth.app.localhost")

    get("/robots.txt")

    assert_response :success
    assert_equal "no-store", response.headers.fetch("Cache-Control")
  end

  test "Auth app BareController sitemap keeps its explicit public cache opt-in" do
    host!("auth.app.localhost")

    get("/sitemap.xml")

    assert_response :success
    cache_control = response.headers.fetch("Cache-Control").split(", ")

    assert_includes cache_control, "public"
    assert_includes cache_control, "max-age=300"
    assert_includes cache_control, "s-maxage=600"
    assert_not_includes cache_control, "no-store"
  end

  test "Auth app BareController response halted by the availability gate is no-store" do
    Flipper.disable(FqdnAvailabilityRegistry.flag_name_for(:auth_service))
    host!("auth.app.localhost")

    get("/robots.txt")

    assert_response :service_unavailable
    assert_equal "no-store", response.headers.fetch("Cache-Control")
  end

  test "Auth com BareController robots.txt is no-store" do
    host!("auth.com.localhost")

    get("/robots.txt")

    assert_response :success
    assert_equal "no-store", response.headers.fetch("Cache-Control")
  end

  test "Auth com BareController sitemap keeps its explicit public cache opt-in" do
    host!("auth.com.localhost")

    get("/sitemap.xml")

    assert_response :success
    cache_control = response.headers.fetch("Cache-Control").split(", ")

    assert_includes cache_control, "public"
    assert_includes cache_control, "max-age=300"
    assert_includes cache_control, "s-maxage=600"
    assert_not_includes cache_control, "no-store"
  end

  test "Auth com BareController response halted by the availability gate is no-store" do
    Flipper.disable(FqdnAvailabilityRegistry.flag_name_for(:auth_corporate))
    host!("auth.com.localhost")

    get("/robots.txt")

    assert_response :service_unavailable
    assert_equal "no-store", response.headers.fetch("Cache-Control")
  end

  test "Auth org BareController robots.txt is no-store" do
    host!("auth.org.localhost")

    get("/robots.txt")

    assert_response :success
    assert_equal "no-store", response.headers.fetch("Cache-Control")
  end

  test "Auth org BareController sitemap keeps its explicit public cache opt-in" do
    host!("auth.org.localhost")

    get("/sitemap.xml")

    assert_response :success
    cache_control = response.headers.fetch("Cache-Control").split(", ")

    assert_includes cache_control, "public"
    assert_includes cache_control, "max-age=300"
    assert_includes cache_control, "s-maxage=600"
    assert_not_includes cache_control, "no-store"
  end

  test "Auth org BareController response halted by the availability gate is no-store" do
    Flipper.disable(FqdnAvailabilityRegistry.flag_name_for(:auth_staff))
    host!("auth.org.localhost")

    get("/robots.txt")

    assert_response :service_unavailable
    assert_equal "no-store", response.headers.fetch("Cache-Control")
  end

  test "Auth RedirectOnlyController authority redirect is no-store" do
    host!("auth.org.localhost")

    get("/iam")

    assert_response :see_other
    assert_equal "no-store", response.headers.fetch("Cache-Control")
  end

  test "Auth RedirectOnlyController authority redirect on the app host is no-store" do
    host!("auth.app.localhost")

    get("/billings")

    assert_response :see_other
    assert_equal "no-store", response.headers.fetch("Cache-Control")
  end
end
