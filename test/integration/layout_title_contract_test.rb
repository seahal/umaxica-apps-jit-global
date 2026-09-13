# typed: false
# frozen_string_literal: true

require "test_helper"

# Source-level guard for the brand title contract. The rendered contract lives in
# HtmlTitleContractTest; this test keeps the layouts themselves from drifting back
# to a surface-flavoured site title or to a hand-rolled title abstraction.
class LayoutTitleContractTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  CANONICAL_LAYOUTS = {
    "app/views/layouts/auth/app/application.html.erb" => "APP",
    "app/views/layouts/auth/com/application.html.erb" => "COM",
    "app/views/layouts/auth/org/application.html.erb" => "ORG",
    "app/views/layouts/base/app/application.html.erb" => "APP",
    "app/views/layouts/base/app/inertia.html.erb" => "APP",
    "app/views/layouts/base/com/application.html.erb" => "COM",
    "app/views/layouts/base/org/application.html.erb" => "ORG",
    "app/views/layouts/core/app/application.html.erb" => "APP",
    "app/views/layouts/core/com/application.html.erb" => "COM",
    "app/views/layouts/core/org/application.html.erb" => "ORG",
    "app/views/layouts/side/app/application.html.erb" => "APP",
    "app/views/layouts/side/com/application.html.erb" => "COM",
    "app/views/layouts/side/org/application.html.erb" => "ORG",
    "app/views/layouts/palm/app/application.html.erb" => "APP",
  }.freeze

  # Routing and deployment vocabulary. None of it is brand vocabulary, so none of
  # it may appear in the site title.
  FORBIDDEN_SITE_WORDS = %w(Auth Base Core Side Palm Jump Global Rails Inertia API).freeze

  test "canonical layouts hand the brand contract to meta-tags" do
    CANONICAL_LAYOUTS.each do |path, tld|
      contents = Rails.root.join(path).read

      assert_predicate Rails.root.join(path), :exist?
      assert_includes contents, %(site: "\#{ENV.fetch("BRAND_NAME").upcase} (#{tld})"),
                      "missing the brand site title in #{path}"
      assert_includes contents, %(separator: "—"), "missing the EM DASH separator in #{path}"
      assert_includes contents, "reverse: true",
                      "#{path} must set reverse: true, otherwise meta-tags emits SITE — PAGE"
      assert_includes contents, "display_meta_tags", "#{path} must render its title through meta-tags"
    end
  end

  test "canonical layouts keep surface and runtime names out of the site title" do
    CANONICAL_LAYOUTS.each_key do |path|
      site_title = Rails.root.join(path).read[/site: "([^"]*)"/, 1]

      assert_predicate site_title, :present?, "no site title found in #{path}"

      FORBIDDEN_SITE_WORDS.each do |word|
        assert_no_match(/\b#{word}\b/, site_title, "#{path} leaks #{word} into the site title")
      end
    end
  end

  test "canonical layouts do not reintroduce a local title variable" do
    CANONICAL_LAYOUTS.each_key do |path|
      contents = Rails.root.join(path).read

      assert_not_includes contents, "title_site", "layout #{path} must not precompute a title_site local"
      assert_not_includes contents, "surface =", "layout #{path} must not define a surface variable"
      assert_not_includes contents, "tld =", "layout #{path} must not define a tld variable"
    end
  end

  test "no layout or view builds a title outside meta-tags except the standalone documents" do
    allowed =
      %w(
        app/views/layouts/mailer/app/mailer.html.erb
        app/views/layouts/mailer/com/mailer.html.erb
        app/views/layouts/mailer/org/mailer.html.erb
        app/views/guid/net/roots/index.html.erb
      ).map { |path| Rails.root.join(path).to_s }

    offenders =
      Rails.root.glob("app/views/**/*.html.erb").select do |path|
        path.read.include?("<title>") && allowed.exclude?(path.to_s)
      end

    assert_empty offenders.map { |path| path.relative_path_from(Rails.root).to_s },
                 "these HTML views hand-roll a <title>; render it through meta-tags instead"
  end

  test "canonical layout roots remain constrained to the current surfaces" do
    assert_predicate Rails.root.join("app/views/layouts/palm/app/application.html.erb"), :exist?
    assert_not_predicate Rails.root.join("app/views/layouts/palm/com"), :exist?
    assert_not_predicate Rails.root.join("app/views/layouts/palm/org"), :exist?

    %w(acme sign apex).each do |legacy_root|
      assert_empty Rails.root.glob("app/views/layouts/#{legacy_root}/**/*")
    end
  end
end
