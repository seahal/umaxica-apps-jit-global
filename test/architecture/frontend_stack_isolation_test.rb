# typed: false
# frozen_string_literal: true

require "minitest/autorun"
require "active_support"
require "active_support/test_case"
require "json"
require "pathname"
require "yaml"

class FrontendStackIsolationTest < ActiveSupport::TestCase
  ROOT = Pathname.new(__dir__).join("../..").expand_path
  MAPPING = YAML.load_file(ROOT.join("config/frontend_stacks.yml"), aliases: false)

  def test_mapping_covers_every_application_layout
    mapped = MAPPING.fetch("stacks").except("excluded").values.flatten
    excluded = MAPPING.fetch("stacks").fetch("excluded", [])
    layouts =
      Dir[ROOT.join("app/views/layouts/**/*application.html.erb")].map { |path|
        path.delete_prefix(ROOT.join("app/views/layouts/").to_s).delete_suffix(".html.erb")
      }

    assert_equal layouts.sort, (mapped.grep(/application\z/) + excluded).sort
    assert_equal mapped.uniq.size, mapped.size
  end

  def test_importmap_and_vite_layouts_are_isolated
    MAPPING.fetch("stacks").fetch("importmap").each do |surface|
      html = ROOT.join("app/views/layouts", "#{surface}.html.erb").read

      assert_includes html, "javascript_importmap_tags", surface
      assert_not_includes html, "vite_", surface
      assert_not_includes html, "inertia_root", surface
    end
    MAPPING.fetch("stacks").fetch("vite").grep(/inertia\z/).each do |surface|
      html = ROOT.join("app/views/layouts", "#{surface}.html.erb").read

      assert_includes html, "vite_typescript_tag", surface
      assert_includes html, "inertia_root", surface
      assert_not_includes html, "javascript_importmap_tags", surface
    end
  end

  def test_vite_content_templates_stay_vite_only
    MAPPING.fetch("stacks").fetch("vite").grep(/root\z/).each do |surface|
      path = ROOT.join("app/views", "#{surface.sub(%r{/root\z}, "/roots/index")}.html.erb")
      html = path.read

      assert_includes html, "vite_stylesheet_tag", surface
      assert_not_includes html, "javascript_importmap_tags", surface
    end
  end

  def test_both_stacks_have_csp_nonces_and_separate_css_ownership
    Dir[ROOT.join("app/views/layouts/**/*application.html.erb")].each { |path|
      assert_includes File.read(path), "nonce: true" unless path.end_with?("email/application.html.erb")
    }

    Dir[ROOT.join("app/views/layouts/**/*inertia.html.erb")].each { |path|
      assert_includes File.read(path), "nonce: true"
    }
    assert_predicate ROOT.join("app/assets/stylesheets/application.css"), :exist?
    assert_predicate ROOT.join("src/styles/surfaces"), :directory?
  end

  def test_frontend_toolchain_has_one_portable_package_manager
    package = JSON.parse(ROOT.join("package.json").read)
    containerfile = ROOT.join("Containerfile").read
    workflow = ROOT.join(".github/workflows/ci.yml").read
    hook = ROOT.join("lefthook.yml").read

    assert_match(/\Abun@/, package.fetch("packageManager"))
    assert_operator package.fetch("engines").fetch("bun"), :start_with?, ">="
    assert_predicate ROOT.join("bun.lock"), :file?
    assert_includes containerfile, "ARG BUN_VERSION"
    assert_includes containerfile, "FROM docker.io/oven/bun:${BUN_VERSION} AS bun-toolchain"
    assert_includes containerfile, "bun install --frozen-lockfile"
    assert_includes workflow, "oven-sh/setup-bun@v2"
    assert_includes workflow, "bun install --frozen-lockfile"
    assert_includes hook, "bun run ci"
  end
end
