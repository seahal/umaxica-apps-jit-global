# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

# DBSC registration/refresh URLs are a device-binding contract: the advertised `path`
# and the proof `aud` must be identical across registration and refresh. PreferenceGlobal
# merges per-request context params (ri/lx/...) into generated URLs, so the DBSC helpers
# must strip them. These tests pin the canonicalization at the helper and at the
# token_dbsc_path / token_dbsc_url route helpers.
class DbscCanonicalUrlTest < ActiveSupport::TestCase
  class Harness
    include DbscCanonicalUrl

    public :dbsc_canonical_url
  end

  setup { @harness = Harness.new }

  test "strips a single context query param" do
    assert_equal "/edge/v0/token/dbsc",
                 @harness.dbsc_canonical_url("/edge/v0/token/dbsc?ri=jp")
  end

  test "strips multiple context query params" do
    assert_equal "https://log.umaxica.app/edge/v0/token/dbsc",
                 @harness.dbsc_canonical_url("https://log.umaxica.app/edge/v0/token/dbsc?ri=us&lx=en&tz=UTC")
  end

  test "strips a fragment as well" do
    assert_equal "/edge/v0/dbsc", @harness.dbsc_canonical_url("/edge/v0/dbsc#frag")
  end

  test "leaves an already-canonical url unchanged" do
    assert_equal "/edge/v0/token/dbsc", @harness.dbsc_canonical_url("/edge/v0/token/dbsc")
    assert_equal "https://log.umaxica.app/edge/v0/token/dbsc",
                 @harness.dbsc_canonical_url("https://log.umaxica.app/edge/v0/token/dbsc")
  end

  test "returns blank input unchanged" do
    assert_nil @harness.dbsc_canonical_url(nil)
    assert_equal "", @harness.dbsc_canonical_url("")
  end

  test "token_dbsc_path strips context params injected by default_url_options" do
    controller = Auth::App::Edge::V0::Token::ChecksController.new
    controller.define_singleton_method(:resource_type) { "client" }
    # Simulate PreferenceGlobal#default_url_options leaking the region param into the
    # generated route helper.
    controller.define_singleton_method(:auth_app_edge_v0_token_dbsc_path) do
      "/edge/v0/token/dbsc?ri=jp"
    end

    assert_equal "/edge/v0/token/dbsc", controller.send(:token_dbsc_path)
  end

  test "token_dbsc_url strips context params so the audience stays stable" do
    controller = Auth::App::Edge::V0::Token::ChecksController.new
    controller.define_singleton_method(:resource_type) { "client" }
    controller.define_singleton_method(:auth_app_edge_v0_token_dbsc_url) do
      "https://log.umaxica.app/edge/v0/token/dbsc?ri=jp&lx=ja"
    end

    assert_equal "https://log.umaxica.app/edge/v0/token/dbsc", controller.send(:token_dbsc_url)
  end

  test "core preference dbsc controllers use the canonical API audience" do
    {
      Core::App::Api::V0::Preferences::DbscController => :core_app_api_v0_preferences_dbsc_url,
      Core::Com::Api::V0::Preferences::DbscController => :core_com_api_v0_preferences_dbsc_url,
      Core::Org::Api::V0::Preferences::DbscController => :core_org_api_v0_preferences_dbsc_url,
    }.each do |controller_class, helper|
      controller = controller_class.new
      controller.define_singleton_method(helper) do
        "https://core.example/api/v0/preferences/dbsc"
      end

      assert_equal "https://core.example/api/v0/preferences/dbsc", controller.send(:dbsc_url)
    end
  end
end

# DAMP local route helper aliases for former shared test support.
class DbscCanonicalUrlTest
  SURFACE_ROUTE_PREFIX_MAP = {
    "sign_app_" => "auth_app_",
    "sign_org_" => "auth_org_",
    "sign_com_" => "auth_com_",
    "acme_app_" => "base_app_",
    "acme_org_" => "base_org_",
    "acme_com_" => "base_com_",
  }.freeze unless const_defined?(:SURFACE_ROUTE_PREFIX_MAP, false)

  private

  def method_missing(name, ...)
    aliased_name = aliased_surface_route_helper_name(name)
    return public_send(aliased_name, ...) if aliased_name && respond_to?(aliased_name, true)

    super
  end

  def respond_to_missing?(name, include_private = false)
    aliased_name = aliased_surface_route_helper_name(name)
    (aliased_name && respond_to?(aliased_name, include_private)) || super
  end

  def aliased_surface_route_helper_name(name)
    helper_name = name.to_s
    self.class::SURFACE_ROUTE_PREFIX_MAP.each do |source_prefix, target_prefix|
      return helper_name.sub(source_prefix, target_prefix).to_sym if helper_name.start_with?(source_prefix)
    end
    nil
  end
end
