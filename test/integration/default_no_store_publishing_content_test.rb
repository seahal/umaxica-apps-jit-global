# typed: false
# frozen_string_literal: true

require "test_helper"

# Info, Docs, News, and Help surface-local BareControllers are Publishing policy roots
# (adr/global-and-publishing-default-no-store-policy.md). Pages start from `Cache-Control: no-store`;
# the read API's entries actions opt into public caching from the action, so they keep `public`,
# `max-age`, validators, and `304` revalidation without `no-store`.
class DefaultNoStorePublishingContentTest < ActionDispatch::IntegrationTest
  test "Info app BareController root page is no-store" do
    host!("info.app.localhost")

    get("/")

    assert_response :success
    assert_equal "no-store", response.headers.fetch("Cache-Control")
  end

  test "Info app BareController entries index keeps its explicit public cache opt-in and revalidates" do
    host!("info.app.localhost")

    get("/api/v0/entries", params: { locale: "ja" })

    assert_response :success
    cache_control = response.headers.fetch("Cache-Control").split(", ")

    assert_includes cache_control, "public"
    assert_includes cache_control, "max-age=60"
    assert_not_includes cache_control, "no-store"
    etag = response.headers.fetch("ETag")

    get("/api/v0/entries", params: { locale: "ja" }, headers: { "If-None-Match" => etag })

    assert_response :not_modified
    assert_empty response.body
  end

  test "Info app BareController response halted by the availability gate is no-store" do
    Flipper.disable(FqdnAvailabilityRegistry.flag_name_for(:info_service))
    host!("info.app.localhost")

    get("/")

    assert_response :service_unavailable
    assert_equal "no-store", response.headers.fetch("Cache-Control")
  end

  test "Info com BareController root page is no-store" do
    host!("info.com.localhost")

    get("/")

    assert_response :success
    assert_equal "no-store", response.headers.fetch("Cache-Control")
  end

  test "Info com BareController entries index keeps its explicit public cache opt-in and revalidates" do
    host!("info.com.localhost")

    get("/api/v0/entries", params: { locale: "ja" })

    assert_response :success
    cache_control = response.headers.fetch("Cache-Control").split(", ")

    assert_includes cache_control, "public"
    assert_includes cache_control, "max-age=60"
    assert_not_includes cache_control, "no-store"
    etag = response.headers.fetch("ETag")

    get("/api/v0/entries", params: { locale: "ja" }, headers: { "If-None-Match" => etag })

    assert_response :not_modified
    assert_empty response.body
  end

  test "Info com BareController response halted by the availability gate is no-store" do
    Flipper.disable(FqdnAvailabilityRegistry.flag_name_for(:info_corporate))
    host!("info.com.localhost")

    get("/")

    assert_response :service_unavailable
    assert_equal "no-store", response.headers.fetch("Cache-Control")
  end

  test "Info org BareController root page is no-store" do
    host!("info.org.localhost")

    get("/")

    assert_response :success
    assert_equal "no-store", response.headers.fetch("Cache-Control")
  end

  test "Info org BareController entries index keeps its explicit public cache opt-in and revalidates" do
    host!("info.org.localhost")

    get("/api/v0/entries", params: { locale: "ja" })

    assert_response :success
    cache_control = response.headers.fetch("Cache-Control").split(", ")

    assert_includes cache_control, "public"
    assert_includes cache_control, "max-age=60"
    assert_not_includes cache_control, "no-store"
    etag = response.headers.fetch("ETag")

    get("/api/v0/entries", params: { locale: "ja" }, headers: { "If-None-Match" => etag })

    assert_response :not_modified
    assert_empty response.body
  end

  test "Info org BareController response halted by the availability gate is no-store" do
    Flipper.disable(FqdnAvailabilityRegistry.flag_name_for(:info_staff))
    host!("info.org.localhost")

    get("/")

    assert_response :service_unavailable
    assert_equal "no-store", response.headers.fetch("Cache-Control")
  end

  test "Docs app BareController root page is no-store" do
    host!("docs.app.localhost")

    get("/")

    assert_response :success
    assert_equal "no-store", response.headers.fetch("Cache-Control")
  end

  test "Docs app BareController entries index keeps its explicit public cache opt-in and revalidates" do
    host!("docs.app.localhost")

    get("/api/v0/entries", params: { locale: "ja" })

    assert_response :success
    cache_control = response.headers.fetch("Cache-Control").split(", ")

    assert_includes cache_control, "public"
    assert_includes cache_control, "max-age=60"
    assert_not_includes cache_control, "no-store"
    etag = response.headers.fetch("ETag")

    get("/api/v0/entries", params: { locale: "ja" }, headers: { "If-None-Match" => etag })

    assert_response :not_modified
    assert_empty response.body
  end

  test "Docs app BareController response halted by the availability gate is no-store" do
    Flipper.disable(FqdnAvailabilityRegistry.flag_name_for(:docs_service))
    host!("docs.app.localhost")

    get("/")

    assert_response :service_unavailable
    assert_equal "no-store", response.headers.fetch("Cache-Control")
  end

  test "Docs com BareController root page is no-store" do
    host!("docs.com.localhost")

    get("/")

    assert_response :success
    assert_equal "no-store", response.headers.fetch("Cache-Control")
  end

  test "Docs com BareController entries index keeps its explicit public cache opt-in and revalidates" do
    host!("docs.com.localhost")

    get("/api/v0/entries", params: { locale: "ja" })

    assert_response :success
    cache_control = response.headers.fetch("Cache-Control").split(", ")

    assert_includes cache_control, "public"
    assert_includes cache_control, "max-age=60"
    assert_not_includes cache_control, "no-store"
    etag = response.headers.fetch("ETag")

    get("/api/v0/entries", params: { locale: "ja" }, headers: { "If-None-Match" => etag })

    assert_response :not_modified
    assert_empty response.body
  end

  test "Docs com BareController response halted by the availability gate is no-store" do
    Flipper.disable(FqdnAvailabilityRegistry.flag_name_for(:docs_corporate))
    host!("docs.com.localhost")

    get("/")

    assert_response :service_unavailable
    assert_equal "no-store", response.headers.fetch("Cache-Control")
  end

  test "Docs org BareController root page is no-store" do
    host!("docs.org.localhost")

    get("/")

    assert_response :success
    assert_equal "no-store", response.headers.fetch("Cache-Control")
  end

  test "Docs org BareController entries index keeps its explicit public cache opt-in and revalidates" do
    host!("docs.org.localhost")

    get("/api/v0/entries", params: { locale: "ja" })

    assert_response :success
    cache_control = response.headers.fetch("Cache-Control").split(", ")

    assert_includes cache_control, "public"
    assert_includes cache_control, "max-age=60"
    assert_not_includes cache_control, "no-store"
    etag = response.headers.fetch("ETag")

    get("/api/v0/entries", params: { locale: "ja" }, headers: { "If-None-Match" => etag })

    assert_response :not_modified
    assert_empty response.body
  end

  test "Docs org BareController response halted by the availability gate is no-store" do
    Flipper.disable(FqdnAvailabilityRegistry.flag_name_for(:docs_staff))
    host!("docs.org.localhost")

    get("/")

    assert_response :service_unavailable
    assert_equal "no-store", response.headers.fetch("Cache-Control")
  end

  test "News app BareController root page is no-store" do
    host!("news.app.localhost")

    get("/")

    assert_response :success
    assert_equal "no-store", response.headers.fetch("Cache-Control")
  end

  test "News app BareController entries index keeps its explicit public cache opt-in and revalidates" do
    host!("news.app.localhost")

    get("/api/v0/entries", params: { locale: "ja" })

    assert_response :success
    cache_control = response.headers.fetch("Cache-Control").split(", ")

    assert_includes cache_control, "public"
    assert_includes cache_control, "max-age=60"
    assert_not_includes cache_control, "no-store"
    etag = response.headers.fetch("ETag")

    get("/api/v0/entries", params: { locale: "ja" }, headers: { "If-None-Match" => etag })

    assert_response :not_modified
    assert_empty response.body
  end

  test "News app BareController response halted by the availability gate is no-store" do
    Flipper.disable(FqdnAvailabilityRegistry.flag_name_for(:news_service))
    host!("news.app.localhost")

    get("/")

    assert_response :service_unavailable
    assert_equal "no-store", response.headers.fetch("Cache-Control")
  end

  test "News com BareController root page is no-store" do
    host!("news.com.localhost")

    get("/")

    assert_response :success
    assert_equal "no-store", response.headers.fetch("Cache-Control")
  end

  test "News com BareController entries index keeps its explicit public cache opt-in and revalidates" do
    host!("news.com.localhost")

    get("/api/v0/entries", params: { locale: "ja" })

    assert_response :success
    cache_control = response.headers.fetch("Cache-Control").split(", ")

    assert_includes cache_control, "public"
    assert_includes cache_control, "max-age=60"
    assert_not_includes cache_control, "no-store"
    etag = response.headers.fetch("ETag")

    get("/api/v0/entries", params: { locale: "ja" }, headers: { "If-None-Match" => etag })

    assert_response :not_modified
    assert_empty response.body
  end

  test "News com BareController response halted by the availability gate is no-store" do
    Flipper.disable(FqdnAvailabilityRegistry.flag_name_for(:news_corporate))
    host!("news.com.localhost")

    get("/")

    assert_response :service_unavailable
    assert_equal "no-store", response.headers.fetch("Cache-Control")
  end

  test "News org BareController root page is no-store" do
    host!("news.org.localhost")

    get("/")

    assert_response :success
    assert_equal "no-store", response.headers.fetch("Cache-Control")
  end

  test "News org BareController entries index keeps its explicit public cache opt-in and revalidates" do
    host!("news.org.localhost")

    get("/api/v0/entries", params: { locale: "ja" })

    assert_response :success
    cache_control = response.headers.fetch("Cache-Control").split(", ")

    assert_includes cache_control, "public"
    assert_includes cache_control, "max-age=60"
    assert_not_includes cache_control, "no-store"
    etag = response.headers.fetch("ETag")

    get("/api/v0/entries", params: { locale: "ja" }, headers: { "If-None-Match" => etag })

    assert_response :not_modified
    assert_empty response.body
  end

  test "News org BareController response halted by the availability gate is no-store" do
    Flipper.disable(FqdnAvailabilityRegistry.flag_name_for(:news_staff))
    host!("news.org.localhost")

    get("/")

    assert_response :service_unavailable
    assert_equal "no-store", response.headers.fetch("Cache-Control")
  end

  test "Help app BareController root page is no-store" do
    host!("help.app.localhost")

    get("/")

    assert_response :success
    assert_equal "no-store", response.headers.fetch("Cache-Control")
  end

  test "Help app BareController entries index keeps its explicit public cache opt-in and revalidates" do
    host!("help.app.localhost")

    get("/api/v0/entries", params: { locale: "ja" })

    assert_response :success
    cache_control = response.headers.fetch("Cache-Control").split(", ")

    assert_includes cache_control, "public"
    assert_includes cache_control, "max-age=60"
    assert_not_includes cache_control, "no-store"
    etag = response.headers.fetch("ETag")

    get("/api/v0/entries", params: { locale: "ja" }, headers: { "If-None-Match" => etag })

    assert_response :not_modified
    assert_empty response.body
  end

  test "Help app BareController response halted by the availability gate is no-store" do
    Flipper.disable(FqdnAvailabilityRegistry.flag_name_for(:help_service))
    host!("help.app.localhost")

    get("/")

    assert_response :service_unavailable
    assert_equal "no-store", response.headers.fetch("Cache-Control")
  end

  test "Help com BareController root page is no-store" do
    host!("help.com.localhost")

    get("/")

    assert_response :success
    assert_equal "no-store", response.headers.fetch("Cache-Control")
  end

  test "Help com BareController entries index keeps its explicit public cache opt-in and revalidates" do
    host!("help.com.localhost")

    get("/api/v0/entries", params: { locale: "ja" })

    assert_response :success
    cache_control = response.headers.fetch("Cache-Control").split(", ")

    assert_includes cache_control, "public"
    assert_includes cache_control, "max-age=60"
    assert_not_includes cache_control, "no-store"
    etag = response.headers.fetch("ETag")

    get("/api/v0/entries", params: { locale: "ja" }, headers: { "If-None-Match" => etag })

    assert_response :not_modified
    assert_empty response.body
  end

  test "Help com BareController response halted by the availability gate is no-store" do
    Flipper.disable(FqdnAvailabilityRegistry.flag_name_for(:help_corporate))
    host!("help.com.localhost")

    get("/")

    assert_response :service_unavailable
    assert_equal "no-store", response.headers.fetch("Cache-Control")
  end

  test "Help org BareController root page is no-store" do
    host!("help.org.localhost")

    get("/")

    assert_response :success
    assert_equal "no-store", response.headers.fetch("Cache-Control")
  end

  test "Help org BareController entries index keeps its explicit public cache opt-in and revalidates" do
    host!("help.org.localhost")

    get("/api/v0/entries", params: { locale: "ja" })

    assert_response :success
    cache_control = response.headers.fetch("Cache-Control").split(", ")

    assert_includes cache_control, "public"
    assert_includes cache_control, "max-age=60"
    assert_not_includes cache_control, "no-store"
    etag = response.headers.fetch("ETag")

    get("/api/v0/entries", params: { locale: "ja" }, headers: { "If-None-Match" => etag })

    assert_response :not_modified
    assert_empty response.body
  end

  test "Help org BareController response halted by the availability gate is no-store" do
    Flipper.disable(FqdnAvailabilityRegistry.flag_name_for(:help_staff))
    host!("help.org.localhost")

    get("/")

    assert_response :service_unavailable
    assert_equal "no-store", response.headers.fetch("Cache-Control")
  end
end
