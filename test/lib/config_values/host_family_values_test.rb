# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"
require Rails.root.join("lib/config_values_origin_value").to_s
require Rails.root.join("lib/config_values_host_family_values").to_s

class ConfigValuesHostFamilyValuesTest < ActiveSupport::TestCase
  test "build in non-production mode applies localhost fallbacks for every family" do
    values = ConfigValues::HostFamilyValues.build(env: {}, production: false)

    assert_equal "https://base.app.localhost", values.acme_service.to_s
    assert_equal "https://base.com.localhost", values.acme_corporate.to_s
    assert_equal "https://base.org.localhost", values.acme_staff.to_s

    assert_equal "https://sign.app.localhost", values.sign_service.to_s
    assert_equal "https://sign.com.localhost", values.sign_corporate.to_s
    assert_equal "https://sign.org.localhost", values.sign_staff.to_s

    assert_equal "https://jp.umaxica.app", values.core_service.to_s
    assert_equal "https://jp.umaxica.com", values.core_corporate.to_s
    assert_equal "https://jp.umaxica.org", values.core_staff.to_s

    assert_equal "https://www.umaxica.app", values.base_service.to_s
    assert_equal "https://www.umaxica.com", values.base_corporate.to_s
    assert_equal "https://www.umaxica.org", values.base_staff.to_s

    assert_equal "https://www-jp.umaxica.app", values.warp_service.to_s
    assert_equal "https://www-jp.umaxica.com", values.warp_corporate.to_s
    assert_equal "https://www-jp.umaxica.org", values.warp_staff.to_s

    assert_equal "https://palm-jp.umaxica.app", values.palm_service.to_s

    assert_equal "https://help.app.localhost", values.help_service.to_s
    assert_equal "https://help.com.localhost", values.help_corporate.to_s
    assert_equal "https://help.org.localhost", values.help_staff.to_s

    assert_equal "https://info.app.localhost", values.info_service.to_s
    assert_equal "https://info.com.localhost", values.info_corporate.to_s
    assert_equal "https://info.org.localhost", values.info_staff.to_s
    assert_equal "https://guid.net.localhost", values.guid_service.to_s
  end

  test "origins helpers group each family into its three surfaces" do
    values = ConfigValues::HostFamilyValues.build(env: {}, production: false)

    assert_equal 3, values.acme_origins.size
    assert_equal [values.acme_service, values.acme_corporate, values.acme_staff], values.acme_origins

    assert_equal 3, values.sign_origins.size
    assert_equal [values.sign_service, values.sign_corporate, values.sign_staff], values.sign_origins

    assert_equal 3, values.core_origins.size
    assert_equal [values.core_service, values.core_corporate, values.core_staff], values.core_origins

    assert_equal 3, values.base_origins.size
    assert_equal [values.base_service, values.base_corporate, values.base_staff], values.base_origins

    assert_equal [values.xper_service, values.xper_corporate, values.xper_staff], values.xper_origins

    assert_equal 3, values.warp_origins.size
    assert_equal [values.warp_service, values.warp_corporate, values.warp_staff], values.warp_origins

    assert_equal 3, values.info_origins.size
    assert_equal [values.info_service, values.info_corporate, values.info_staff], values.info_origins

    assert_equal values.sign_service, values.auth_service
    assert_equal values.sign_corporate, values.auth_corporate
    assert_equal values.sign_staff, values.auth_staff
    assert_equal [values.auth_service, values.auth_corporate, values.auth_staff], values.auth_origins
  end

  test "build in production mode prefers ENV overrides over fallbacks" do
    env = {
      "AUTH_SERVICE_URL" => "sign.example.test",
      "AUTH_CORPORATE_URL" => "sign-com.example.test",
      "AUTH_STAFF_URL" => "sign-org.example.test",
      "CORE_SERVICE_URL" => "jpx.example.test",
      "CORE_CORPORATE_URL" => "jpx-com.example.test",
      "CORE_STAFF_URL" => "jpx-org.example.test",
      "BASE_SERVICE_URL" => "base.example.test",
      "BASE_CORPORATE_URL" => "base-com.example.test",
      "BASE_STAFF_URL" => "base-org.example.test",
      "PUBLIC_XPER_SERVICE_URL" => "umaxica.app",
      "PUBLIC_XPER_CORPORATE_URL" => "umaxica.com",
      "PUBLIC_XPER_STAFF_URL" => "umaxica.org",
      "PUBLIC_WARP_SERVICE_URL" => "warp.example.test",
      "PUBLIC_WARP_CORPORATE_URL" => "warp-com.example.test",
      "PUBLIC_WARP_STAFF_URL" => "warp-org.example.test",
      "PALM_SERVICE_URL" => "palm.example.test",
      "HELP_SERVICE_URL" => "help.example.test",
      "HELP_CORPORATE_URL" => "help-com.example.test",
      "HELP_STAFF_URL" => "help-org.example.test",
      "INFO_SERVICE_URL" => "info.example.test",
      "INFO_CORPORATE_URL" => "info-com.example.test",
      "INFO_STAFF_URL" => "info-org.example.test",
      "PRIVATE_DOCS_SERVICE_URL" => "docs.example.test",
      "PRIVATE_DOCS_CORPORATE_URL" => "docs-com.example.test",
      "PRIVATE_DOCS_STAFF_URL" => "docs-org.example.test",
      "PRIVATE_NEWS_SERVICE_URL" => "news.example.test",
      "PRIVATE_NEWS_CORPORATE_URL" => "news-com.example.test",
      "PRIVATE_NEWS_STAFF_URL" => "news-org.example.test",
      "GUID_SERVICE_URL" => "guid.example.test",
      "EDIT_STAFF_URL" => "edit-org.example.test",
    }
    values = ConfigValues::HostFamilyValues.build(env: env, production: true)

    assert_equal "https://base.example.test", values.acme_service.to_s
    assert_equal "https://sign-org.example.test", values.sign_staff.to_s
    assert_equal "https://umaxica.app", values.xper_service.to_s
    assert_equal "https://umaxica.com", values.xper_corporate.to_s
    assert_equal "https://umaxica.org", values.xper_staff.to_s
    %w(PUBLIC_XPER_SERVICE_URL PUBLIC_XPER_CORPORATE_URL PUBLIC_XPER_STAFF_URL).each do |key|
      missing = env.except(key)
      error = assert_raises(KeyError) { ConfigValues::HostFamilyValues.build(env: missing, production: true) }

      assert_includes error.message, key
      [nil, ""].each do |empty|
        assert_raises(ArgumentError) { ConfigValues::HostFamilyValues.build(env: env.merge(key => empty), production: true) }
      end
    end

    assert_equal "https://warp.example.test", values.warp_service.to_s
    assert_equal "https://info-org.example.test", values.info_staff.to_s
    assert_equal "https://guid.example.test", values.guid_service.to_s
    assert_equal "https://edit-org.example.test", values.edit_staff.to_s
    assert_not values.acme_origins.any?(&:nil?)
  end

  test "build in production mode raises KeyError when a required ENV key is missing" do
    assert_raises(KeyError) do
      ConfigValues::HostFamilyValues.build(env: {}, production: true)
    end
  end

  test "base origins fall back to PUBLIC_BASE_*_URL when BASE_*_URL is absent" do
    env = {
      "PUBLIC_BASE_SERVICE_URL" => "www.umaxica.app",
      "PUBLIC_BASE_CORPORATE_URL" => "www.umaxica.com",
      "PUBLIC_BASE_STAFF_URL" => "www.umaxica.org",
    }
    values = ConfigValues::HostFamilyValues.build(env: env, production: false)

    assert_equal "www.umaxica.app", values.base_service.host
    assert_equal "www.umaxica.com", values.base_corporate.host
    assert_equal "www.umaxica.org", values.base_staff.host
  end

  test "PUBLIC_WARP_*_URL configures Warp origins separately from Base origins" do
    env = {
      "PUBLIC_WARP_SERVICE_URL" => "warp.umaxica.app",
      "PUBLIC_WARP_CORPORATE_URL" => "warp.umaxica.com",
      "PUBLIC_WARP_STAFF_URL" => "warp.umaxica.org",
      "PUBLIC_BASE_SERVICE_URL" => "www.umaxica.app",
      "PUBLIC_BASE_CORPORATE_URL" => "www.umaxica.com",
      "PUBLIC_BASE_STAFF_URL" => "www.umaxica.org",
    }
    values = ConfigValues::HostFamilyValues.build(env: env, production: false)

    assert_equal "www.umaxica.app", values.base_service.host
    assert_equal "www.umaxica.com", values.base_corporate.host
    assert_equal "www.umaxica.org", values.base_staff.host
    assert_equal "warp.umaxica.app", values.warp_service.host
    assert_equal "warp.umaxica.com", values.warp_corporate.host
    assert_equal "warp.umaxica.org", values.warp_staff.host
  end

  test "BASE_*_URL takes precedence over PUBLIC_BASE_*_URL for base origins" do
    env = {
      "BASE_SERVICE_URL" => "base.umaxica.app",
      "BASE_CORPORATE_URL" => "base.umaxica.com",
      "BASE_STAFF_URL" => "base.umaxica.org",
      "PUBLIC_BASE_SERVICE_URL" => "www.umaxica.app",
      "PUBLIC_BASE_CORPORATE_URL" => "www.umaxica.com",
      "PUBLIC_BASE_STAFF_URL" => "www.umaxica.org",
    }
    values = ConfigValues::HostFamilyValues.build(env: env, production: false)

    assert_equal "base.umaxica.app", values.base_service.host
    assert_equal "base.umaxica.com", values.base_corporate.host
    assert_equal "base.umaxica.org", values.base_staff.host
  end

  test "sign origins fall back to PUBLIC_AUTH_*_URL instead of a localhost default" do
    env = {
      "PUBLIC_AUTH_SERVICE_URL" => "auth.umaxica.app",
      "PUBLIC_AUTH_CORPORATE_URL" => "auth.umaxica.com",
      "PUBLIC_AUTH_STAFF_URL" => "auth.umaxica.org",
    }
    values = ConfigValues::HostFamilyValues.build(env: env, production: false)

    assert_equal "auth.umaxica.app", values.sign_service.host
    assert_equal "auth.umaxica.com", values.sign_corporate.host
    assert_equal "auth.umaxica.org", values.sign_staff.host
  end

  # Only the Base, Warp, Auth, and Core families read a PUBLIC_* key. Widening the
  # fallback to every family moves the OIDC issuer and authorize hosts off their
  # development defaults, which breaks the SSO redirect contract.
  test "other families keep their localhost defaults when only PUBLIC_* keys exist" do
    env = {
      "PUBLIC_HELP_SERVICE_URL" => "help.umaxica.app",
      "PUBLIC_INFO_SERVICE_URL" => "info.umaxica.app",
    }
    values = ConfigValues::HostFamilyValues.build(env: env, production: false)

    assert_equal "help.app.localhost", values.help_service.host
    assert_equal "info.app.localhost", values.info_service.host
  end

  # Deployments publish this family as PUBLIC_CORE_*_URL. Without this fallback the core
  # origins kept the jpx.umaxica.* development defaults, so production Host Authorization
  # and the core-next-rp redirect URIs named jpx while config/routes/core.rb routed the
  # surface on the PUBLIC_CORE_* value.
  test "core origins fall back to PUBLIC_CORE_*_URL instead of the jpx default" do
    env = {
      "PUBLIC_CORE_SERVICE_URL" => "core-jp.umaxica.app",
      "PUBLIC_CORE_CORPORATE_URL" => "core-jp.umaxica.com",
      "PUBLIC_CORE_STAFF_URL" => "core-jp.umaxica.org",
    }
    values = ConfigValues::HostFamilyValues.build(env: env, production: false)

    assert_equal "core-jp.umaxica.app", values.core_service.host
    assert_equal "core-jp.umaxica.com", values.core_corporate.host
    assert_equal "core-jp.umaxica.org", values.core_staff.host
  end

  test "CORE_*_URL still configures core origins when no PUBLIC_CORE_* key exists" do
    env = { "CORE_SERVICE_URL" => "core.example.test" }
    values = ConfigValues::HostFamilyValues.build(env: env, production: false)

    assert_equal "core.example.test", values.core_service.host
  end

  # Reverse of the Base/Warp/Auth precedence, and deliberately so: config/routes/core.rb
  # constrains the surface on `PUBLIC_CORE_*_URL || CORE_*_URL`, so boot config must resolve
  # the same host the route constraint accepts.
  test "PUBLIC_CORE_*_URL takes precedence over CORE_*_URL for core origins" do
    env = {
      "PUBLIC_CORE_SERVICE_URL" => "core-jp.umaxica.app",
      "CORE_SERVICE_URL" => "jpx.umaxica.app",
    }
    values = ConfigValues::HostFamilyValues.build(env: env, production: false)

    assert_equal "core-jp.umaxica.app", values.core_service.host
  end

  test "AUTH_*_URL takes precedence over PUBLIC_AUTH_*_URL for sign origins" do
    env = {
      "AUTH_SERVICE_URL" => "sign.example.test",
      "PUBLIC_AUTH_SERVICE_URL" => "auth.umaxica.app",
    }
    values = ConfigValues::HostFamilyValues.build(env: env, production: false)

    assert_equal "sign.example.test", values.sign_service.host
  end

  test "origin adds an https scheme when the raw value lacks one" do
    env = {
      "AUTH_SERVICE_URL" => "https://sign.example.test",
      "AUTH_CORPORATE_URL" => "sign-com.example.test",
      "AUTH_STAFF_URL" => "sign-org.example.test",
      "CORE_SERVICE_URL" => "jpx.example.test",
      "CORE_CORPORATE_URL" => "jpx-com.example.test",
      "CORE_STAFF_URL" => "jpx-org.example.test",
      "BASE_SERVICE_URL" => "base.example.test",
      "BASE_CORPORATE_URL" => "base-com.example.test",
      "BASE_STAFF_URL" => "base-org.example.test",
      "PUBLIC_XPER_SERVICE_URL" => "umaxica.app",
      "PUBLIC_XPER_CORPORATE_URL" => "umaxica.com",
      "PUBLIC_XPER_STAFF_URL" => "umaxica.org",
      "PUBLIC_WARP_SERVICE_URL" => "warp.example.test",
      "PUBLIC_WARP_CORPORATE_URL" => "warp-com.example.test",
      "PUBLIC_WARP_STAFF_URL" => "warp-org.example.test",
      "PALM_SERVICE_URL" => "palm.example.test",
      "HELP_SERVICE_URL" => "help.example.test",
      "HELP_CORPORATE_URL" => "help-com.example.test",
      "HELP_STAFF_URL" => "help-org.example.test",
      "INFO_SERVICE_URL" => "info.example.test",
      "INFO_CORPORATE_URL" => "info-com.example.test",
      "INFO_STAFF_URL" => "info-org.example.test",
      "PRIVATE_DOCS_SERVICE_URL" => "docs.example.test",
      "PRIVATE_DOCS_CORPORATE_URL" => "docs-com.example.test",
      "PRIVATE_DOCS_STAFF_URL" => "docs-org.example.test",
      "PRIVATE_NEWS_SERVICE_URL" => "news.example.test",
      "PRIVATE_NEWS_CORPORATE_URL" => "news-com.example.test",
      "PRIVATE_NEWS_STAFF_URL" => "news-org.example.test",
      "GUID_SERVICE_URL" => "guid.example.test",
      "EDIT_STAFF_URL" => "edit-org.example.test",
    }
    values = ConfigValues::HostFamilyValues.build(env: env, production: true)

    assert_equal "https://base.example.test", values.acme_service.to_s
    assert_equal "https://sign.example.test", values.sign_service.to_s
    assert_equal "https://help.example.test", values.help_service.to_s
    assert_equal "https://info.example.test", values.info_service.to_s
    assert_equal "https://guid.example.test", values.guid_service.to_s
  end
end
