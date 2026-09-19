# typed: false
# frozen_string_literal: true

require "test_helper"

# Layouts name Vite entrypoints as strings, so a renamed or deleted entrypoint fails at request
# time on the surface that references it rather than at build time. These assertions read the
# layouts and the sources they name, which is why they need neither a Vite build nor a manifest.
class ViteEntrypointContractTest < ActiveSupport::TestCase
  LAYOUT_ROOT = Rails.root.join("app/views/layouts")
  ENTRYPOINT_ROOT = Rails.root.join("src/entrypoints")
  PAGE_ROOT = Rails.root.join("src/pages")
  ENTRYPOINT_REFERENCE = /vite_typescript_tag\s+"([^"]+)"/

  test "every entrypoint named by a layout exists in the Vite source tree" do
    references = layout_entrypoint_references

    assert_predicate references, :any?, "expected the layouts to reference Vite entrypoints"

    references.each do |layout, name|
      assert entrypoint_source(name),
             "#{layout} references Vite entrypoint #{name.inspect}, which has no source under src/"
    end
  end

  # Each trust boundary boots its own Inertia application. A layout pointing at another surface's
  # entrypoint would load that surface's page bundle on this FQDN.
  test "every Inertia layout loads the entrypoint belonging to its own surface" do
    layouts = inertia_layouts

    assert_equal 13, layouts.size, "expected one Inertia layout per user-facing FQDN"

    layouts.each do |layout|
      family, surface = layout.relative_path_from(LAYOUT_ROOT).each_filename.first(2)
      expected = "entrypoints/inertia/#{family}_#{surface}.tsx"

      assert_includes layout.read, %(vite_typescript_tag "#{expected}"),
                      "#{layout} must load #{expected}"
    end
  end

  # The page glob is what actually enforces the boundary in the browser bundle: an entrypoint that
  # globs a wider directory can resolve another surface's page component.
  test "every Inertia entrypoint globs only its own surface page directory" do
    inertia_layouts.each do |layout|
      family, surface = layout.relative_path_from(LAYOUT_ROOT).each_filename.first(2)
      source = ENTRYPOINT_ROOT.join("inertia/#{family}_#{surface}.tsx")

      assert_path_exists source

      contents = source.read

      assert_includes contents, "import.meta.glob(\"../../pages/#{family}/#{surface}/**/*.tsx\"",
                      "#{source} must resolve pages from src/pages/#{family}/#{surface} only"
      assert_includes contents, "bootSurfaceInertiaApp(",
                      "#{source} must boot through the shared surface application"
      assert_includes contents, "\"#{family}/#{surface}\",",
                      "#{source} must reject page names from other surfaces"
      assert_path_exists PAGE_ROOT.join(family, surface)
    end
  end

  # The entrypoints hand their glob and their surface name to one shared boot function, so the
  # resolver that refuses another surface's page name is asserted where it now lives. Without this
  # the check above would pass for a boot function that ignored the surface it was given.
  test "the shared surface application resolves pages through the surface resolver" do
    source = Rails.root.join("src/inertia/surface.ts")

    assert_path_exists source

    contents = source.read

    assert_includes contents, "export function bootSurfaceInertiaApp(",
                    "#{source} must expose the shared boot function the entrypoints call"
    assert_includes contents, "surfacePageResolver(modules, surface, SurfaceLayout)",
                    "#{source} must resolve pages through the surface resolver"
  end

  # The base family typography is not a surface of its own: it is imported by the three base surface
  # stylesheets and by nothing else, so a family rule cannot reach the auth, side, palm, or core
  # surfaces.
  BASE_FAMILY_IMPORT = %(@import "../base_family.css";)
  BASE_FAMILY_STYLESHEETS = %w(base_app.css base_com.css base_org.css).freeze

  test "the base family typography is imported by every base surface stylesheet and no other" do
    expected = BASE_FAMILY_STYLESHEETS.map { |name| SURFACE_STYLESHEET_ROOT.join(name) }

    expected.each do |stylesheet|
      assert_path_exists stylesheet
      assert_includes stylesheet.read, BASE_FAMILY_IMPORT,
                      "#{stylesheet} must load the base family typography"
    end

    (Dir.glob(SURFACE_STYLESHEET_ROOT.join("*.css")).map { |path| Pathname.new(path) } - expected).each do |stylesheet|
      assert_not_includes stylesheet.read, BASE_FAMILY_IMPORT,
                          "#{stylesheet} is not a base surface and must not load the base family typography"
    end
  end

  # CSS carries the same boundary as the page glob: one FQDN links one surface stylesheet, and that
  # file names its own `@source` roots, so a utility generated for another surface's markup cannot
  # reach this one. A layout linking a second surface's stylesheet would break that silently.
  VIEW_ROOT = Rails.root.join("app/views")
  STYLESHEET_ROOT = Rails.root.join("src/styles")
  SURFACE_STYLESHEET_ROOT = Rails.root.join("src/styles/surfaces")
  SURFACE_STYLESHEET_REFERENCE = /vite_stylesheet_tag\s+"~\/styles\/surfaces\/([^"]+)"/

  test "every template links only the surface stylesheet belonging to its own surface" do
    linked = surface_stylesheet_references

    assert_predicate linked, :any?, "expected the templates to link surface stylesheets"

    linked.each do |template, names|
      family, surface = template_surface(template)

      assert_equal ["#{family}_#{surface}.css"], names,
                   "#{template} must link only src/styles/surfaces/#{family}_#{surface}.css"
      assert_path_exists SURFACE_STYLESHEET_ROOT.join("#{family}_#{surface}.css")
    end
  end

  test "every surface stylesheet is linked by a template" do
    referenced = surface_stylesheet_references.values.flatten.uniq
    present = Dir.glob(SURFACE_STYLESHEET_ROOT.join("*.css")).map { |path| File.basename(path) }

    assert_equal present.sort, referenced.sort,
                 "every surface stylesheet must be linked, and every link must resolve to a file"
  end

  # There is no aggregate stylesheet: every partial reaches the browser because a surface stylesheet
  # imports it. A partial nobody imports is either dead or, worse, an umbrella file waiting to be
  # linked by a layout again, which is how one surface's rules used to reach every other.
  test "every shared stylesheet is imported by a surface stylesheet" do
    surfaces = Dir.glob(SURFACE_STYLESHEET_ROOT.join("*.css")).map { |path| File.read(path) }
    partials = Dir.glob(STYLESHEET_ROOT.join("*.css")).map { |path| File.basename(path) }

    assert_predicate partials, :any?, "expected shared stylesheets under src/styles"

    partials.each do |partial|
      assert surfaces.any? { |contents| contents.include?(%(@import "../#{partial}";)) },
             "src/styles/#{partial} is imported by no surface stylesheet"
    end
  end

  # Line breaking is language behaviour, not surface behaviour, so `base.css` owns it for all
  # Inertia surfaces. A surface stylesheet or a family partial redefining it would silently give
  # one FQDN different kinsoku from the rest, and the last chunk emitted would decide the winner.
  LINE_BREAKING_PROPERTIES = %w(line-break word-break overflow-wrap).freeze

  test "the Japanese line breaking baseline lives only in base.css" do
    base = STYLESHEET_ROOT.join("base.css").read

    LINE_BREAKING_PROPERTIES.each do |property|
      assert_match(
        /^\s*#{Regexp.escape(property)}:/, base,
        "src/styles/base.css must declare #{property} for every surface",
      )
    end
    assert_includes base, ":lang(ja) {",
                    "src/styles/base.css must scope line breaking to Japanese"

    others = Dir.glob(STYLESHEET_ROOT.join("**/*.css")).reject { |path| File.basename(path) == "base.css" }

    others.each do |path|
      contents = File.read(path)

      LINE_BREAKING_PROPERTIES.each do |property|
        assert_no_match(
          /^\s*#{Regexp.escape(property)}:/, contents,
          "#{path} must not redefine #{property}; base.css owns line breaking",
        )
      end
    end
  end

  # `source(none)` is what turns off Tailwind's automatic source detection. Without it Tailwind
  # scans the whole Vite root and every surface stylesheet ends up carrying every other surface's
  # utilities, which is the leak these files exist to prevent.
  test "every surface stylesheet scopes Tailwind to its own sources" do
    Dir.glob(SURFACE_STYLESHEET_ROOT.join("*.css")).each do |path|
      stylesheet = Pathname.new(path)
      family, surface = stylesheet.basename(".css").to_s.split("_")
      contents = stylesheet.read

      assert_includes contents, %(@import "tailwindcss" source(none);),
                      "#{stylesheet} must disable Tailwind automatic source detection"

      own_pages = "#{family}/#{surface}"

      if PAGE_ROOT.join(own_pages).directory?
        assert_includes contents, %(@source "../../pages/#{own_pages}";),
                        "#{stylesheet} must scan its own page directory"
      end

      foreign = contents.scan(%r{@source "\.\./\.\./pages/([^"]+)";}).flatten - [own_pages]

      assert_empty foreign, "#{stylesheet} must not scan another surface's pages"
    end
  end

  # `ViteRuby::Manifest#resolve_entries` drops every stylesheet from `vite_javascript_tag` while the
  # dev server runs, so CSS reaching a page only through a JavaScript import arrives as a runtime
  # <style> after the module graph executes: an unstyled first paint on every reload. Templates link
  # their surface stylesheet instead, and importing CSS here again would ship the same bytes twice
  # and let the later tag win.
  test "no Vite entrypoint imports a stylesheet" do
    Dir.glob(ENTRYPOINT_ROOT.join("**/*.{ts,tsx}")).each do |path|
      assert_no_match(
        /^import\s+"@styles\//, Pathname.new(path).read,
        "#{path} must not import CSS; the template links it with vite_stylesheet_tag",
      )
    end
  end

  private

  def layout_entrypoint_references
    Dir.glob(LAYOUT_ROOT.join("**/*.html.erb")).flat_map do |path|
      File.read(path).scan(ENTRYPOINT_REFERENCE).flatten.map { |name| [path, name] }
    end
  end

  def entrypoint_source(name)
    relative = name.delete_prefix("entrypoints/")

    [relative, "#{relative}.ts", "#{relative}.tsx"]
      .map { |candidate| ENTRYPOINT_ROOT.join(candidate) }
      .find(&:file?)
  end

  def inertia_layouts
    Dir.glob(LAYOUT_ROOT.join("*/*/inertia.html.erb")).map { |path| Pathname.new(path) }
  end

  def surface_stylesheet_references
    Dir.glob(VIEW_ROOT.join("**/*.html.erb")).each_with_object({}) do |path, references|
      names = File.read(path).scan(SURFACE_STYLESHEET_REFERENCE).flatten
      references[Pathname.new(path)] = names if names.any?
    end
  end

  # Layouts live at layouts/<family>/<surface>/, and a template that owns its whole document lives
  # at <family>/<surface>/. Both name the surface in the first two segments once `layouts/` is gone.
  def template_surface(template)
    relative = template.relative_path_from(VIEW_ROOT).each_filename.to_a
    relative.shift if relative.first == "layouts"
    relative.first(2)
  end
end
