# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class PageTitlePresenceTest < ActiveSupport::TestCase
  # Patterns that indicate a page title is set
  PAGE_TITLE_PATTERNS = [
    /content_for\s+:page_title/,
    /provide\s*\(\s*:page_title/,
    /page_title\s+/, # ApplicationHelper#page_title
    /<%=?\s*title\s+/, # meta-tags gem helper
    /set_meta_tags.*title/,
    %r{<title[^>]*>},  # standalone full-page views that own their own <title> tag
    /display_meta_tags/, # standalone full-page views rendering their title through meta-tags
  ].freeze

  # Files excluded from page_title requirement with reasons
  EXCLUDED_PATHS = [
    # Email/mailer views: rendered inside mailer layouts (separate title mechanism)
    %r{^/app/views/email/},
    # Layouts are not "page views"
    %r{^/app/views/layouts/},
  ].freeze

  test "all non-partial views have a page_title declaration" do
    view_root = Rails.root.join("app/views")
    view_files = Dir.glob(view_root.join("**", "*.html.erb"))

    # Filter to non-partial, non-layout views
    page_views =
      view_files.reject do |path|
        relative = path.to_s.sub("#{Rails.root}", "")
        File.basename(path).start_with?("_") || # partials
          EXCLUDED_PATHS.any? { |pat| relative.match?(pat) }
      end

    missing = []
    page_views.each do |path|
      content = File.read(path)
      has_title = PAGE_TITLE_PATTERNS.any? { |pat| content.match?(pat) }
      relative = path.sub("#{Rails.root.join}", "")
      missing << relative unless has_title
    end

    assert_empty missing,
                 "#{missing.size} view(s) missing page_title declaration:\n  #{missing.join("\n  ")}"
  end
  private

  # Pure static analysis test - no database/fixtures needed. `use_transactional_tests = false`
  # was the wrong tool for that: it makes Rails clear the process-wide fixture cache
  # (`@@already_loaded_fixtures`) on every run, which forces every other `fixtures :all` test
  # class to reload all ~200 fixture tables (~600 extra queries) on its next example. Overriding
  # these two hooks as no-ops opts this class out of the fixtures machinery entirely, without that
  # side effect, while keeping every other `ActiveSupport::TestCase` behavior (assertions, the
  # `test` DSL) intact. See docs/guides/test-profiling.md.
  def setup_fixtures(*)
  end

  def teardown_fixtures(*)
  end
end
