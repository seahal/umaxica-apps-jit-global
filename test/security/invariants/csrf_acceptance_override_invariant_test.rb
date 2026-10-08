# typed: false
# frozen_string_literal: true

require "test_helper"

# D-80: request forgery protection is the installed Rails implementation. No class may redefine
# what counts as a verified request or an acceptable Origin, and forgery protection is skipped only
# by the CSP report endpoint, which browsers post without credentials or a token.
class CsrfAcceptanceOverrideInvariantTest < ActiveSupport::TestCase
  SCANNED = %w(app lib).freeze
  ACCEPTANCE_OVERRIDE =
    /^\s*def\s+(?:self\.)?(valid_request_origin\?|verified_request\?|verified_request_for_forgery_protection\?)/
  SKIP = Regexp.union(
    /skip_forgery_protection/,
    /skip_before_action\s+:verify_authenticity_token/,
    /protect_from_forgery\s+with:\s+:null_session/,
  )
  PERMITTED_SKIPS = { "app/controllers/concerns/csp_violation_report.rb" => 1 }.freeze

  test "no class redefines verified-request or Origin acceptance" do
    offenders = matches(ACCEPTANCE_OVERRIDE)

    assert_empty offenders, "custom CSRF acceptance must not exist:\n#{offenders.join("\n")}"
  end

  test "forgery protection is skipped only by the CSP report endpoint" do
    counts = matches(SKIP).map { |entry| entry.split(":").first }.tally

    assert_equal PERMITTED_SKIPS, counts
  end

  test "the scan covers Ruby sources in app and lib" do
    assert_operator ruby_files.size, :>, 1000
    assert(ruby_files.any? { |path| path.start_with?("lib/") })
  end

  private

  def ruby_files
    SCANNED.flat_map { |root| Rails.root.glob("#{root}/**/*.rb") }
      .map { |path| path.relative_path_from(Rails.root).to_s }
  end

  def matches(pattern)
    ruby_files.flat_map do |path|
      Rails.root.join(path).each_line.with_index(1).filter_map do |line, number|
        "#{path}:#{number}:#{line.strip}" if line.match?(pattern) && !line.lstrip.start_with?("#")
      end
    end
  end
end
