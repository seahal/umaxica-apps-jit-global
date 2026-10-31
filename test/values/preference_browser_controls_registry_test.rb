# frozen_string_literal: true

require "test_helper"

class PreferenceBrowserControlsRegistryTest < ActiveSupport::TestCase
  API_THEME = "/api/v0/preferences/theme"
  API_COOKIE = "/api/v0/preferences/cookie"

  test "Base declares same-origin theme and cookie endpoints on app and org" do
    %w(app org).each do |surface|
      controls = PreferenceBrowserControlsRegistry.fetch(family: "base", surface: surface)

      assert_equal API_THEME, controls.theme_endpoint_path, "base/#{surface} theme"
      assert_equal API_COOKIE, controls.cookie_endpoint_path, "base/#{surface} cookie"
    end
  end

  test "Auth, Core, and Warp keep preference display read-only" do
    %w(auth core warp).each do |family|
      %w(app org).each do |surface|
        controls = PreferenceBrowserControlsRegistry.fetch(family: family, surface: surface)

        assert_nil controls.theme_endpoint_path, "#{family}/#{surface} theme"
        assert_nil controls.cookie_endpoint_path, "#{family}/#{surface} cookie"
      end
    end
  end

  test "Base com keeps its anonymous browser preference controls" do
    controls = PreferenceBrowserControlsRegistry.fetch(family: "base", surface: "com")

    assert_equal API_THEME, controls.theme_endpoint_path
    assert_equal API_COOKIE, controls.cookie_endpoint_path
  end

  test "warp com declares no preference controls" do
    controls = PreferenceBrowserControlsRegistry.fetch(family: "warp", surface: "com")

    assert_nil controls.theme_endpoint_path
    assert_nil controls.cookie_endpoint_path
  end

  test "palm app declares no preference controls" do
    controls = PreferenceBrowserControlsRegistry.fetch(family: "palm", surface: "app")

    assert_nil controls.theme_endpoint_path
    assert_nil controls.cookie_endpoint_path
  end

  test "edit org declares no preference controls" do
    controls = PreferenceBrowserControlsRegistry.fetch(family: "edit", surface: "org")

    assert_nil controls.theme_endpoint_path
    assert_nil controls.cookie_endpoint_path
  end

  # Surface alone does not decide: Base and Palm share the app surface but differ.
  test "the same surface answers differently per family" do
    base = PreferenceBrowserControlsRegistry.fetch(family: "base", surface: "app")
    palm = PreferenceBrowserControlsRegistry.fetch(family: "palm", surface: "app")

    assert_not_equal base, palm
  end

  test "family and surface symbols resolve like strings" do
    assert_equal PreferenceBrowserControlsRegistry.fetch(family: "base", surface: "org"),
                 PreferenceBrowserControlsRegistry.fetch(family: :base, surface: :org)
  end

  test "every declared endpoint path is origin-relative" do
    PreferenceBrowserControlsRegistry::MATRIX.each_value do |surfaces|
      surfaces.each_value do |controls|
        [controls.theme_endpoint_path, controls.cookie_endpoint_path].compact.each do |path|
          assert_match %r{\A/(?!/)}, path
        end
      end
    end
  end

  test "an unknown family raises" do
    error = assert_raises(KeyError) { PreferenceBrowserControlsRegistry.fetch(family: "unknown", surface: "app") }

    assert_match "unknown", error.message
  end

  test "a family/surface pair that does not exist raises" do
    [%w(palm com), %w(palm org), %w(edit app), %w(edit com), %w(core dev), %w(core net),
     %w(base dev), %w(auth com), %w(core com), %w(visa com),].each do |family, surface|
      assert_raises(KeyError, "#{family}/#{surface}") do
        PreferenceBrowserControlsRegistry.fetch(family: family, surface: surface)
      end
    end
  end

  test "nil and empty family or surface raise" do
    assert_raises(KeyError) { PreferenceBrowserControlsRegistry.fetch(family: nil, surface: "app") }
    assert_raises(KeyError) { PreferenceBrowserControlsRegistry.fetch(family: "", surface: "app") }
    assert_raises(KeyError) { PreferenceBrowserControlsRegistry.fetch(family: "base", surface: nil) }
    assert_raises(KeyError) { PreferenceBrowserControlsRegistry.fetch(family: "base", surface: "") }
  end
end
